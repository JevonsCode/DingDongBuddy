import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/domain/resource_update_fetcher.dart';
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

  /// Returns one share-safe item for API and file exports.
  ///
  /// Resources backed by an online source carry only `contentURL`; local
  /// snapshots are intentionally excluded from the portable representation.
  static Map<String, Object?> portableItem(Resource resource) {
    return _portableJson(resource);
  }

  static LibraryBundleImportResult decode(
    String contents, {
    required List<Resource> existing,
  }) {
    return importPayload(_decodePayload(contents), existing: existing);
  }

  /// Decodes a bundle and resolves item-level online links before deduping.
  ///
  /// A bundle can contain any number of items. Online items use `contentURL`
  /// (or the legacy `updateURL`) as the canonical source and never copy that
  /// URL's body into the exported bundle again.
  static Future<LibraryBundleImportResult> decodeOnline(
    String contents, {
    required List<Resource> existing,
    required ResourceUpdateFetcher fetcher,
  }) async {
    final Map<String, Object?> payload = _decodePayload(contents);
    final Object? rawItems = payload['items'];
    if (rawItems is! List<Object?>) {
      throw const FormatException('Library bundle items must be a list.');
    }
    final Set<String>? selectedIds = switch (payload['selectedIds']) {
      final List<Object?> values => values.whereType<String>().toSet(),
      _ => null,
    };
    final List<Object?> resolvedItems = <Object?>[];
    final List<Resource> onlineCandidates = <Resource>[];
    final Set<String> onlineUrls = <String>{};
    for (final Object? rawItem in rawItems) {
      if (rawItem is! Map<String, Object?>) {
        throw const FormatException('Library bundle item must be an object.');
      }
      final String? id = rawItem['id'] as String?;
      if (selectedIds != null && id != null && !selectedIds.contains(id)) {
        resolvedItems.add(rawItem);
        continue;
      }
      final String? link = _onlineContentUrl(rawItem);
      if (link == null) {
        resolvedItems.add(rawItem);
        continue;
      }
      final Uri? uri = Uri.tryParse(link);
      if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
        throw FormatException('Invalid online resource link: $link');
      }
      final String fetched = await fetcher.fetch(uri);
      final Map<String, Object?> resolved = Map<String, Object?>.of(rawItem)
        ..['content'] = fetched
        ..['updateURL'] = link
        ..remove('contentURL')
        ..remove('sourceURL');
      resolvedItems.add(resolved);
      onlineCandidates.add(Resource.fromJson(resolved));
      onlineUrls.add(link);
    }
    final LibraryBundleImportResult result = importPayload(<String, Object?>{
      ...payload,
      'items': resolvedItems,
    }, existing: existing);
    return result.copyWith(
      onlineResources: onlineCandidates
          .where(
            (Resource resource) =>
                resource.updateUrl != null &&
                onlineUrls.contains(resource.updateUrl),
          )
          .toList(growable: false),
    );
  }

  static LibraryBundleImportResult importPayload(
    Map<String, Object?> payload, {
    required List<Resource> existing,
  }) {
    final Object? schemaVersion = payload['schemaVersion'];
    if (schemaVersion != 2) {
      throw FormatException(
        'Unsupported library bundle schema: $schemaVersion.',
      );
    }
    final Object? service = payload['service'];
    if (service != null &&
        service != 'DingDongBuddy' &&
        service != 'DingDong') {
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
  final String? updateUrl = resource.updateUrl;
  if (updateUrl != null) {
    // Online resources are shared by reference. The local snapshot remains
    // available to the current Agent, but it must not leak into a share file.
    json
      ..remove('content')
      ..remove('updateURL')
      ..remove('packagePath')
      ..['contentURL'] = updateUrl;
  } else {
    json['content'] = _portableContent(resource);
  }
  // These fields can contain machine-specific paths or private URLs and are
  // intentionally not transferred to another computer.
  json.remove('source');
  json.remove('packagePath');
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
    this.onlineResources = const <Resource>[],
  });

  final List<Resource> imported;
  final List<String> duplicateIds;
  final List<String> conflictIds;
  final List<Resource> onlineResources;

  int get skippedCount => duplicateIds.length + conflictIds.length;

  LibraryBundleImportResult copyWith({List<Resource>? onlineResources}) {
    return LibraryBundleImportResult(
      imported: imported,
      duplicateIds: duplicateIds,
      conflictIds: conflictIds,
      onlineResources: onlineResources ?? this.onlineResources,
    );
  }
}

Map<String, Object?> _decodePayload(String contents) {
  final Object? decoded = jsonDecode(contents);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Library bundle must be a JSON object.');
  }
  return decoded;
}

String? _onlineContentUrl(Map<String, Object?> item) {
  for (final String key in const <String>[
    'contentURL',
    'sourceURL',
    'updateURL',
  ]) {
    final String? value = item[key] as String?;
    if (value != null && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

String _contentKey(Resource resource) {
  final String normalized = resource.content
      .replaceAll('\r\n', '\n')
      .trim()
      .replaceAll(RegExp(r'[ \t]+'), ' ');
  return '${resource.type.name}\u0000$normalized';
}
