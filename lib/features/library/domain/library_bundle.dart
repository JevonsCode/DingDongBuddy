import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:path/path.dart' as path;

/// Portable, selective resource bundle with stable-ID and content deduplication.
final class LibraryBundle {
  const LibraryBundle._();

  static String encode(
    Iterable<Resource> resources, {
    required DateTime generatedAt,
  }) {
    return const JsonEncoder.withIndent(
      '  ',
    ).convert(payload(resources, generatedAt: generatedAt));
  }

  static Map<String, Object?> payload(
    Iterable<Resource> resources, {
    required DateTime generatedAt,
  }) {
    final List<Resource> items = resources
        .where((Resource resource) => resource.type.isLibraryResource)
        .toList(growable: false);
    return <String, Object?>{
      'service': 'DingDongBuddy',
      'schemaVersion': 2,
      'generatedAt': generatedAt.toUtc().toIso8601String(),
      'selectedIds': items
          .map((Resource resource) => resource.id)
          .toList(growable: false),
      'items': items.map(_portableJson).toList(growable: false),
    };
  }

  static LibraryBundleImportResult decode(
    String contents, {
    required List<Resource> existing,
  }) {
    final Object? decoded = jsonDecode(contents);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Library bundle must be a JSON object.');
    }
    return importPayload(decoded, existing: existing);
  }

  static LibraryBundleImportResult importPayload(
    Map<String, Object?> payload, {
    required List<Resource> existing,
  }) {
    final Object? schemaVersion = payload['schemaVersion'];
    if (schemaVersion != null && schemaVersion != 1 && schemaVersion != 2) {
      throw FormatException(
        'Unsupported library bundle schema: $schemaVersion.',
      );
    }
    final Object? service = payload['service'];
    if (service != null &&
        service != 'DingDong' &&
        service != 'DingDongBuddy') {
      throw const FormatException('Library bundle is for another service.');
    }
    final Object? rawItems = payload['items'];
    if (rawItems is! List<Object?>) {
      throw const FormatException('Library bundle items must be a list.');
    }
    final Set<String>? selectedIds = switch (payload['selectedIds']) {
      final List<Object?> values =>
        values.map((Object? value) => value as String).toSet(),
      _ => null,
    };
    final Map<String, Resource> existingById = <String, Resource>{
      for (final Resource resource in existing) resource.id: resource,
    };
    final Set<String> knownContent = existing.map(_contentKey).toSet();
    final List<Resource> imported = <Resource>[];
    final List<String> duplicateIds = <String>[];
    final List<String> conflictIds = <String>[];

    for (final Object? rawItem in rawItems) {
      if (rawItem is! Map<String, Object?>) {
        throw const FormatException('Library bundle item must be an object.');
      }
      final Resource candidate = Resource.fromJson(rawItem);
      if (!candidate.type.isLibraryResource ||
          (selectedIds != null && !selectedIds.contains(candidate.id))) {
        continue;
      }
      final Resource? sameId = existingById[candidate.id];
      if (sameId != null) {
        if (_contentKey(sameId) == _contentKey(candidate)) {
          duplicateIds.add(candidate.id);
        } else {
          conflictIds.add(candidate.id);
        }
        continue;
      }
      final String contentKey = _contentKey(candidate);
      if (knownContent.contains(contentKey)) {
        duplicateIds.add(candidate.id);
        continue;
      }
      imported.add(candidate);
      existingById[candidate.id] = candidate;
      knownContent.add(contentKey);
    }

    return LibraryBundleImportResult(
      imported: imported,
      duplicateIds: duplicateIds,
      conflictIds: conflictIds,
    );
  }

  static List<List<String>> duplicateGroups(Iterable<Resource> resources) {
    final Map<String, List<String>> grouped = <String, List<String>>{};
    for (final Resource resource in resources) {
      grouped
          .putIfAbsent(_contentKey(resource), () => <String>[])
          .add(resource.id);
    }
    return grouped.values
        .where((List<String> ids) => ids.length > 1)
        .map(List<String>.unmodifiable)
        .toList(growable: false);
  }
}

Map<String, Object?> _portableJson(Resource resource) {
  final Map<String, Object?> json = Map<String, Object?>.of(resource.toJson());
  json['content'] = _portableContent(resource);
  // These fields can contain machine-specific paths or private URLs and are
  // intentionally not transferred to another computer.
  json.remove('source');
  json.remove('updateURL');
  return json;
}

String _portableContent(Resource resource) {
  if (resource.type == ResourceType.prompt ||
      !_looksLikeLocalPath(resource.content)) {
    return resource.content;
  }
  final String expanded = resource.content.startsWith('~/')
      ? path.join(
          Platform.environment['HOME'] ?? '~',
          resource.content.substring(2),
        )
      : resource.content;
  final FileSystemEntityType entityType = FileSystemEntity.typeSync(
    expanded,
    followLinks: false,
  );
  if (entityType == FileSystemEntityType.file) {
    return File(expanded).readAsStringSync();
  }
  if (entityType != FileSystemEntityType.directory) {
    throw FormatException(
      'Resource ${resource.id} points to a local path that cannot be shared.',
    );
  }
  final Directory directory = Directory(expanded);
  if (resource.type == ResourceType.skill) {
    return _firstPortableFile(directory, const <String>[
      'SKILL.md',
      'skill.md',
    ]).readAsStringSync();
  }
  if (resource.type == ResourceType.mcp) {
    return _firstPortableFile(directory, const <String>[
      'mcp.json',
      'server.json',
      'package.json',
    ]).readAsStringSync();
  }
  return _portableKnowledgeDirectory(directory);
}

File _firstPortableFile(Directory directory, List<String> names) {
  for (final String name in names) {
    final File file = File(path.join(directory.path, name));
    if (file.existsSync()) {
      return file;
    }
  }
  throw FormatException(
    'No portable resource entry was found in ${directory.path}.',
  );
}

String _portableKnowledgeDirectory(Directory directory) {
  final List<File> files =
      directory
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where(
            (File file) => <String>{
              '.md',
              '.markdown',
              '.txt',
              '.json',
              '.yaml',
              '.yml',
            }.contains(path.extension(file.path).toLowerCase()),
          )
          .take(30)
          .toList(growable: false)
        ..sort((File left, File right) => left.path.compareTo(right.path));
  final StringBuffer output = StringBuffer();
  for (final File file in files) {
    final String section =
        '## ${path.relative(file.path, from: directory.path)}\n\n'
        '${file.readAsStringSync()}\n\n';
    if (output.length + section.length > 100000) {
      break;
    }
    output.write(section);
  }
  final String content = output.toString().trim();
  if (content.isEmpty) {
    throw FormatException(
      'Knowledge resource ${directory.path} has no portable text files.',
    );
  }
  return content;
}

bool _looksLikeLocalPath(String value) {
  final String trimmed = value.trim();
  return trimmed.startsWith('/') ||
      trimmed.startsWith('~/') ||
      RegExp(r'^[A-Za-z]:[\\/]').hasMatch(trimmed);
}

final class LibraryBundleImportResult {
  const LibraryBundleImportResult({
    required this.imported,
    required this.duplicateIds,
    required this.conflictIds,
  });

  final List<Resource> imported;
  final List<String> duplicateIds;
  final List<String> conflictIds;

  int get skippedCount => duplicateIds.length + conflictIds.length;
}

String _contentKey(Resource resource) {
  final String normalized = resource.content
      .replaceAll('\r\n', '\n')
      .trim()
      .replaceAll(RegExp(r'[ \t]+'), ' ');
  return '${resource.type.name}\u0000$normalized';
}
