import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

typedef ManagedFileTransform =
    FutureOr<String?> Function(ManagedFileSnapshot snapshot);
typedef ManagedFileValidator = void Function(String contents);

final class ManagedFileSnapshot {
  const ManagedFileSnapshot({
    required this.exists,
    required this.contents,
    required this.mode,
  });

  final bool exists;
  final String contents;
  final int? mode;
}

final class ManagedFileConflictException implements Exception {
  const ManagedFileConflictException(this.path);

  final String path;

  @override
  String toString() =>
      'ManagedFileConflictException: $path changed while DingDong was updating it.';
}

/// Serializes DingDong file mutations across isolates and processes, rejects
/// stale snapshots, and replaces files through validated sibling files.
final class SafeManagedFile {
  SafeManagedFile(this.file, {this.newFileMode});

  final File file;
  final int? newFileMode;

  static final Object _lockZoneKey = Object();
  static final Map<String, Future<void>> _barriers = <String, Future<void>>{};
  static var _temporarySequence = 0;

  Future<T> exclusive<T>(Future<T> Function() action) async {
    final String key = file.absolute.path;
    final Set<String> held =
        Zone.current[_lockZoneKey] as Set<String>? ?? const <String>{};
    if (held.contains(key)) {
      return action();
    }

    final Future<void> previous = _barriers[key] ?? Future<void>.value();
    final Completer<void> gate = Completer<void>();
    _barriers[key] = gate.future;
    await previous;
    await file.parent.create(recursive: true);
    final RandomAccessFile lock = await File(
      '${file.path}.lock',
    ).open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
      return await runZoned(
        action,
        zoneValues: <Object, Object>{
          _lockZoneKey: <String>{...held, key},
        },
      );
    } finally {
      try {
        await lock.unlock();
      } finally {
        await lock.close();
        gate.complete();
        if (identical(_barriers[key], gate.future)) {
          await _barriers.remove(key);
        }
      }
    }
  }

  Future<ManagedFileSnapshot> snapshot() => exclusive(_snapshotUnlocked);

  Future<bool> update(
    ManagedFileTransform transform, {
    ManagedFileValidator? validate,
  }) => exclusive(() async {
    final ManagedFileSnapshot before = await _snapshotUnlocked();
    final String? next = await transform(before);
    if (next == null || (before.exists && next == before.contents)) {
      return false;
    }
    validate?.call(next);
    await _replaceUnlocked(before, next);
    return true;
  });

  Future<bool> replaceIfUnchanged(
    ManagedFileSnapshot expected,
    String contents, {
    ManagedFileValidator? validate,
  }) => exclusive(() async {
    if (expected.exists && expected.contents == contents) {
      await _requireUnchanged(expected);
      return false;
    }
    validate?.call(contents);
    await _replaceUnlocked(expected, contents);
    return true;
  });

  Future<bool> deleteIfUnchanged(ManagedFileSnapshot expected) =>
      exclusive(() async {
        await _requireUnchanged(expected);
        if (!expected.exists) {
          return false;
        }
        final File removed = await _reserveSibling('dingdong-removed');
        await removed.delete();
        try {
          await file.rename(removed.path);
          await removed.delete();
        } finally {
          if (await removed.exists() && !await file.exists()) {
            await removed.rename(file.path);
          }
        }
        return true;
      });

  Future<ManagedFileSnapshot> _snapshotUnlocked() async {
    await _restoreInterruptedWrite();
    final FileSystemEntityType type = await FileSystemEntity.type(
      file.path,
      followLinks: false,
    );
    if (type == FileSystemEntityType.notFound) {
      return const ManagedFileSnapshot(exists: false, contents: '', mode: null);
    }
    if (type != FileSystemEntityType.file) {
      throw FileSystemException(
        'Managed target must be a regular non-symlink file',
        file.path,
      );
    }
    final FileStat stat = await file.stat();
    return ManagedFileSnapshot(
      exists: true,
      contents: await file.readAsString(),
      mode: stat.mode & 0xFFF,
    );
  }

  Future<void> _replaceUnlocked(
    ManagedFileSnapshot expected,
    String contents,
  ) async {
    await file.parent.create(recursive: true);
    final File temporary = await _reserveSibling('dingdong-tmp');
    File? backup;
    try {
      await temporary.writeAsString(contents, flush: true);
      await _preserveMode(temporary, expected.mode ?? newFileMode);
      await _requireUnchanged(expected);

      if (expected.exists) {
        backup = await _reserveSibling('dingdong-bak');
        await backup.delete();
        await file.rename(backup.path);
      }
      try {
        await temporary.rename(file.path);
      } on Object {
        if (!await file.exists() && backup != null && await backup.exists()) {
          await backup.rename(file.path);
        }
        rethrow;
      }

      if (await file.readAsString() != contents) {
        throw ManagedFileConflictException(file.path);
      }
      if (backup != null && await backup.exists()) {
        await backup.delete();
      }
    } finally {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      if (backup != null && await backup.exists() && await file.exists()) {
        await backup.delete();
      }
    }
  }

  Future<void> _requireUnchanged(ManagedFileSnapshot expected) async {
    final FileSystemEntityType type = await FileSystemEntity.type(
      file.path,
      followLinks: false,
    );
    if (!expected.exists) {
      if (type != FileSystemEntityType.notFound) {
        throw ManagedFileConflictException(file.path);
      }
      return;
    }
    if (type != FileSystemEntityType.file) {
      throw ManagedFileConflictException(file.path);
    }
    final FileStat stat = await file.stat();
    if (await file.readAsString() != expected.contents ||
        stat.mode & 0xFFF != expected.mode) {
      throw ManagedFileConflictException(file.path);
    }
  }

  Future<File> _reserveSibling(String marker) async {
    while (true) {
      _temporarySequence += 1;
      final File candidate = File(
        '${file.path}.$marker.$pid.$_temporarySequence',
      );
      try {
        return await candidate.create(exclusive: true);
      } on FileSystemException {
        continue;
      }
    }
  }

  Future<void> _preserveMode(File target, int? mode) async {
    if (mode == null || Platform.isWindows) {
      return;
    }
    final ProcessResult result = await Process.run('chmod', <String>[
      mode.toRadixString(8),
      target.path,
    ]);
    if (result.exitCode != 0) {
      throw FileSystemException(
        'Could not preserve managed file permissions',
        target.path,
      );
    }
  }

  Future<void> _restoreInterruptedWrite() async {
    if (await file.exists() || !await file.parent.exists()) {
      return;
    }
    final String name = path.normalize(file.absolute.path);
    final List<File> backups = await file.parent
        .list(followLinks: false)
        .where((FileSystemEntity entity) {
          if (entity is! File) {
            return false;
          }
          final String candidatePath = path.normalize(entity.absolute.path);
          return candidatePath == '$name.bak' ||
              candidatePath == '$name.dingdong-bak' ||
              (candidatePath.startsWith('$name.') &&
                  candidatePath.contains('.dingdong-bak.'));
        })
        .cast<File>()
        .toList();
    if (backups.isEmpty) {
      return;
    }
    backups.sort(
      (File left, File right) =>
          right.lastModifiedSync().compareTo(left.lastModifiedSync()),
    );
    await backups.first.rename(file.path);
  }
}
