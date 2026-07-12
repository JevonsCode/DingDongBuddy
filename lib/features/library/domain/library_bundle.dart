import 'dart:convert';

import 'package:dingdong/core/models/resource.dart';

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
      'items': items
          .map((Resource resource) => resource.toJson())
          .toList(growable: false),
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
