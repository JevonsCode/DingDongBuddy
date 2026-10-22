import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:dingdong/core/files/safe_managed_file.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/serialization/strict_json.dart';
import 'package:dingdong/features/library/domain/skill_version.dart';
import 'package:path/path.dart' as path;

/// Content-addressed Skill snapshots, separate from disposable installed packages.
final class SkillVersionHistory {
  SkillVersionHistory(this.root, {this.beforeManifestWrite});
  SkillVersionHistory.memory() : root = null, beforeManifestWrite = null;

  final Directory? root;
  final Future<void> Function(String resourceId)? beforeManifestWrite;
  final Map<String, String> _memory = <String, String>{};

  String resourceKey(String id) {
    if (id.isEmpty) {
      throw const FormatException('Empty Skill resource identifier.');
    }
    final Hash hash = const DartSha256().hashSync(utf8.encode(id));
    final String key = hash.bytes
        .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return key;
  }

  String _manifestName(String id) => 'manifests/${resourceKey(id)}.json';

  String _snapshotName(String id) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      throw const FormatException('Invalid Skill snapshot identifier.');
    }
    return 'snapshots/$id.json';
  }

  Future<ManagedFileSnapshot> _read(String name) async {
    final Directory? directory = root;
    if (directory == null) {
      return ManagedFileSnapshot(
        exists: _memory.containsKey(name),
        contents: _memory[name] ?? '',
        mode: null,
      );
    }
    final File file = File(path.join(directory.path, name));
    await _requireSafeAncestors(file.path);
    await _requireSafeAncestors('${file.path}.lock');
    return SafeManagedFile(file).snapshot();
  }

  Future<void> _replace(
    String name,
    ManagedFileSnapshot expected,
    String? contents,
  ) async {
    final Directory? directory = root;
    if (directory == null) {
      if (_memory.containsKey(name) != expected.exists ||
          (_memory[name] ?? '') != expected.contents) {
        throw ManagedFileConflictException(name);
      }
      if (contents == null) {
        _memory.remove(name);
      } else {
        _memory[name] = contents;
      }
      return;
    }
    final File file = File(path.join(directory.path, name));
    await _requireSafeAncestors(file.path);
    await _requireSafeAncestors('${file.path}.lock');
    final SafeManagedFile managed = SafeManagedFile(file);
    if (contents == null) {
      await managed.deleteIfUnchanged(expected);
    } else {
      await managed.replaceIfUnchanged(expected, contents);
    }
  }

  Future<List<SkillVersion>> versions(String resourceId) async {
    final ManagedFileSnapshot stored = await _read(_manifestName(resourceId));
    return _decodeManifest(resourceId, stored);
  }

  Future<List<SkillVersion>> _decodeManifest(
    String resourceId,
    ManagedFileSnapshot stored,
  ) async {
    if (!stored.exists) return <SkillVersion>[];
    final Map<String, Object?> json =
        (decodeStrictJson(stored.contents) as Map<String, Object?>);
    if (json['format'] != 1 || json['resourceId'] != resourceId) {
      throw const FormatException('Invalid Skill history manifest.');
    }
    final List<SkillVersion> result = (json['versions'] as List<Object?>)
        .map(
          (Object? value) =>
              SkillVersion.fromJson(value as Map<String, Object?>),
        )
        .toList();
    if (result.isEmpty) {
      throw const FormatException('Skill history manifest is empty.');
    }
    for (int i = 0; i < result.length; i++) {
      final SkillVersion version = result[i];
      if (version.number != i + 1 ||
          (version.restoredFrom != null &&
              (version.source != SkillVersionSource.restored ||
                  version.restoredFrom! < 1 ||
                  version.restoredFrom! > i))) {
        throw const FormatException('Invalid Skill history sequence.');
      }
      _snapshotName(version.snapshotId);
    }
    return result;
  }

  Future<SkillSnapshot> snapshot(String id) async {
    final ManagedFileSnapshot stored = await _read(_snapshotName(id));
    if (!stored.exists || await _digest(stored.contents) != id) {
      throw const FormatException('Skill snapshot is missing or corrupted.');
    }
    final SkillSnapshot result = SkillSnapshot.fromJson(
      decodeStrictJson(stored.contents) as Map<String, Object?>,
    );
    _validateSnapshot(result);
    return result;
  }

  Future<SkillSnapshot> capture(Resource resource) async {
    _manifestName(resource.id);
    final Map<String, SkillVersionFile> files = <String, SkillVersionFile>{};
    final List<String> directories = <String>[];
    final String? packagePath = resource.packagePath;
    final bool hasPackage = packagePath != null && packagePath.isNotEmpty;
    if (hasPackage) {
      await _requireSafeAncestors(packagePath);
      final Directory directory = Directory(packagePath);
      if (!await directory.exists()) {
        throw FileSystemException('Skill package is missing.', packagePath);
      }
      await for (final FileSystemEntity entity in directory.list(
        recursive: true,
        followLinks: false,
      )) {
        final String name = path
            .relative(entity.path, from: packagePath)
            .split(path.separator)
            .join('/');
        _validateRelativePath(name);
        final FileSystemEntityType type = await FileSystemEntity.type(
          entity.path,
          followLinks: false,
        );
        if (type == FileSystemEntityType.directory) {
          directories.add(name);
        } else if (type == FileSystemEntityType.file) {
          files[name] = SkillVersionFile(
            bytes: await File(entity.path).readAsBytes(),
            executable:
                !Platform.isWindows && (await entity.stat()).mode & 0x49 != 0,
          );
        } else {
          throw FileSystemException(
            'Skill snapshots require regular files and directories.',
            entity.path,
          );
        }
      }
      files['SKILL.md'] = SkillVersionFile(
        bytes: utf8.encode(resource.content),
        executable: files['SKILL.md']?.executable ?? false,
      );
    }
    final SkillSnapshot result = SkillSnapshot(
      title: resource.title,
      document: resource.content,
      sourceUrl: resource.updateUrl,
      files: files,
      directories: directories,
      hasPackage: hasPackage,
    );
    _validateSnapshot(result);
    return result;
  }

  /// Prepares all manifests before changing any; a failed batch restores them all.
  Future<SkillHistoryTransaction> prepare(
    List<Resource> previous,
    List<Resource> proposed, {
    SkillVersionSource? source,
    String? restoredResourceId,
    int? restoredFrom,
    bool baselineOnly = false,
  }) async {
    final Map<String, Resource> old = <String, Resource>{
      for (final Resource resource in previous)
        if (resource.type == ResourceType.skill) resource.id: resource,
    };
    final List<_ManifestChange> changes = <_ManifestChange>[];
    final Map<String, Resource> next = <String, Resource>{
      for (final Resource resource in proposed)
        if (resource.type == ResourceType.skill) resource.id: resource,
    };
    for (final Resource resource in <Resource>[
      ...next.values,
      ...old.values.where((Resource item) => !next.containsKey(item.id)),
    ]) {
      final String name = _manifestName(resource.id);
      final ManagedFileSnapshot before = await _read(name);
      final List<SkillVersion> entries = await _decodeManifest(
        resource.id,
        before,
      );
      if (baselineOnly && entries.isNotEmpty) continue;
      final Resource? prior = old[resource.id];
      if (entries.isEmpty && prior != null) {
        entries.add(
          await _entry(await capture(prior), 1, SkillVersionSource.initial),
        );
      }
      final bool removed = !next.containsKey(resource.id);
      if (removed && before.exists) continue;
      final SkillSnapshot current = removed
          ? await snapshot(entries.last.snapshotId)
          : await capture(resource);
      final String id = await _digest(jsonEncode(current.toJson()));
      final bool restored = resource.id == restoredResourceId;
      if (!removed &&
          (entries.isEmpty || entries.last.snapshotId != id || restored)) {
        bool online = prior == null
            ? resource.updateUrl != null || current.hasPackage
            : (prior.packagePath != resource.packagePath ||
                  prior.updateUrl != resource.updateUrl ||
                  prior.skillPackageDigest != resource.skillPackageDigest);
        if (!online &&
            source == null &&
            entries.isNotEmpty &&
            current.hasPackage) {
          final SkillSnapshot priorSnapshot = await snapshot(
            entries.last.snapshotId,
          );
          online = _packageContents(priorSnapshot) != _packageContents(current);
        }
        entries.add(
          await _entry(
            current,
            entries.length + 1,
            restored
                ? SkillVersionSource.restored
                : source ??
                      (online
                          ? SkillVersionSource.online
                          : SkillVersionSource.manual),
            restoredFrom: restored ? restoredFrom : null,
          ),
        );
      }
      final String contents = jsonEncode(<String, Object?>{
        'format': 1,
        'resourceId': resource.id,
        'versions': entries
            .map((SkillVersion version) => version.toJson())
            .toList(),
      });
      if (!before.exists || before.contents != contents) {
        changes.add(_ManifestChange(resource.id, name, before, contents));
      }
    }
    return SkillHistoryTransaction._(this, changes);
  }

  Future<SkillVersion> _entry(
    SkillSnapshot value,
    int number,
    SkillVersionSource source, {
    int? restoredFrom,
  }) async {
    final String contents = jsonEncode(value.toJson());
    final String id = await _digest(contents);
    final String name = _snapshotName(id);
    final ManagedFileSnapshot before = await _read(name);
    if (before.exists) {
      await snapshot(id);
    } else {
      await _replace(name, before, contents);
    }
    return SkillVersion(
      number: number,
      createdAt: DateTime.now().toUtc(),
      source: source,
      snapshotId: id,
      restoredFrom: restoredFrom,
    );
  }

  Future<Directory> materialize(SkillSnapshot value) async {
    _validateSnapshot(value);
    final Directory? directory = root;
    if (directory != null) {
      await _requireSafeAncestors(directory.path);
      await directory.create(recursive: true);
    }
    final Directory staging = await (directory ?? Directory.systemTemp)
        .createTemp('.skill-restore-');
    try {
      for (final String name in value.directories) {
        await Directory(path.join(staging.path, name)).create(recursive: true);
      }
      for (final MapEntry<String, SkillVersionFile> entry
          in value.files.entries) {
        final File file = File(path.join(staging.path, entry.key));
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.value.bytes, flush: true);
        if (!Platform.isWindows && entry.value.executable) {
          final ProcessResult result = await Process.run('chmod', <String>[
            '755',
            file.path,
          ]);
          if (result.exitCode != 0) {
            throw FileSystemException(
              'Could not restore executable mode.',
              file.path,
            );
          }
        }
      }
      await File(
        path.join(staging.path, 'SKILL.md'),
      ).writeAsString(value.document, flush: true);
      return staging;
    } on Object {
      await staging.delete(recursive: true);
      rethrow;
    }
  }
}

final class _ManifestChange {
  const _ManifestChange(this.resourceId, this.name, this.before, this.contents);
  final String resourceId;
  final String name;
  final ManagedFileSnapshot before;
  final String contents;
}

final class SkillHistoryTransaction {
  SkillHistoryTransaction._(this._history, this._changes);
  final SkillVersionHistory _history;
  final List<_ManifestChange> _changes;
  final List<_ManifestChange> _committed = <_ManifestChange>[];

  Future<void> commit() async {
    try {
      for (final _ManifestChange change in _changes) {
        await _history.beforeManifestWrite?.call(change.resourceId);
        await _history._replace(change.name, change.before, change.contents);
        _committed.add(change);
      }
    } on Object {
      await rollback();
      rethrow;
    }
  }

  Future<void> rollback() async {
    for (final _ManifestChange change in _committed.reversed) {
      final ManagedFileSnapshot current = await _history._read(change.name);
      if (current.contents != change.contents) {
        throw ManagedFileConflictException(change.name);
      }
      await _history._replace(
        change.name,
        current,
        change.before.exists ? change.before.contents : null,
      );
    }
    _committed.clear();
  }
}

void _validateRelativePath(String name) {
  final List<String> segments = name.split('/');
  if (name.isEmpty ||
      name.contains('\\') ||
      name.contains(':') ||
      name.contains('\u0000') ||
      RegExp(r'[<>"|?*\x00-\x1F]').hasMatch(name) ||
      path.posix.isAbsolute(name) ||
      segments.any(
        (String segment) =>
            segment.isEmpty ||
            segment == '.' ||
            segment == '..' ||
            segment.endsWith('.') ||
            segment.endsWith(' ') ||
            RegExp(
              r'^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)',
              caseSensitive: false,
            ).hasMatch(segment),
      )) {
    throw FormatException('Unsafe Skill snapshot path: $name');
  }
}

void _validateSnapshot(SkillSnapshot value) {
  final Set<String> files = <String>{};
  final Set<String> directories = <String>{};
  for (final String name in value.files.keys) {
    _validateRelativePath(name);
    if (!files.add(name.toLowerCase())) {
      throw const FormatException('Duplicate Skill snapshot path.');
    }
  }
  for (final String name in value.directories) {
    _validateRelativePath(name);
    if (!directories.add(name.toLowerCase()) ||
        files.contains(name.toLowerCase())) {
      throw const FormatException('Conflicting Skill snapshot path.');
    }
  }
  for (final String name in <String>[...files, ...directories]) {
    String parent = path.posix.dirname(name);
    while (parent != '.') {
      if (files.contains(parent)) {
        throw const FormatException(
          'Skill snapshot file is a parent directory.',
        );
      }
      parent = path.posix.dirname(parent);
    }
  }
  if (!value.hasPackage && (files.isNotEmpty || directories.isNotEmpty)) {
    throw const FormatException(
      'Document-only Skill snapshot contains package files.',
    );
  }
  if (value.hasPackage && value.files['SKILL.md']?.text != value.document) {
    throw const FormatException(
      'Skill snapshot document does not match SKILL.md.',
    );
  }
}

Future<void> _requireSafeAncestors(String target) async {
  String current = path.absolute(target);
  while (true) {
    final FileSystemEntityType type = await FileSystemEntity.type(
      current,
      followLinks: false,
    );
    if (type == FileSystemEntityType.link) {
      throw FileSystemException(
        'Symlinks are not supported in Skill history.',
        current,
      );
    }
    final String parent = path.dirname(current);
    if (parent == current) return;
    current = parent;
  }
}

Future<String> _digest(String contents) async {
  final Hash hash = await Sha256().hash(utf8.encode(contents));
  return hash.bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

String _packageContents(SkillSnapshot snapshot) {
  final Map<String, Object?> content = snapshot.toJson()
    ..remove('title')
    ..remove('document')
    ..remove('sourceUrl');
  final Map<String, Object?> files = content['files']! as Map<String, Object?>;
  // The resource document is edited manually; other package bytes and file
  // permissions count as package updates even when a caller reuses a path.
  if (files.containsKey('SKILL.md')) {
    files['SKILL.md'] = <String, Object?>{
      'executable': snapshot.files['SKILL.md']!.executable,
    };
  }
  return jsonEncode(content);
}
