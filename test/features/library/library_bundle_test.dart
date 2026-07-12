import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selective bundles preserve stable IDs and usage metadata', () {
    final DateTime now = DateTime.utc(2026, 7, 13);
    final Resource skill = Resource(
      id: 'stable-skill-id',
      type: ResourceType.skill,
      title: 'Release skill',
      content: 'Run the release checklist.',
      usageCount: 4,
      lastUsedAt: now,
      createdAt: now,
      updatedAt: now,
    );
    final String encoded = LibraryBundle.encode(<Resource>[
      skill,
    ], generatedAt: now);

    final LibraryBundleImportResult result = LibraryBundle.decode(
      encoded,
      existing: const <Resource>[],
    );

    expect(result.imported.single.id, 'stable-skill-id');
    expect(result.imported.single.usageCount, 4);
    expect(result.imported.single.lastUsedAt, now);
    expect((jsonDecode(encoded) as Map<String, Object?>)['schemaVersion'], 2);
  });

  test('repeated imports skip matching IDs and matching content', () {
    final DateTime now = DateTime.utc(2026, 7, 13);
    final Resource existing = Resource(
      id: 'existing-id',
      type: ResourceType.prompt,
      title: 'Review prompt',
      content: 'Review this change.',
      createdAt: now,
      updatedAt: now,
    );
    final Resource sameContent = Resource(
      id: 'different-id',
      type: ResourceType.prompt,
      title: 'Renamed review prompt',
      content: 'Review this change.',
      createdAt: now,
      updatedAt: now,
    );
    final Map<String, Object?> payload = LibraryBundle.payload(<Resource>[
      existing,
      sameContent,
    ], generatedAt: now);

    final LibraryBundleImportResult result = LibraryBundle.importPayload(
      payload,
      existing: <Resource>[existing],
    );

    expect(result.imported, isEmpty);
    expect(result.duplicateIds, <String>['existing-id', 'different-id']);
    expect(result.conflictIds, isEmpty);
  });

  test('selectedIds imports only the requested bundle entries', () {
    final DateTime now = DateTime.utc(2026, 7, 13);
    Resource resource(String id) => Resource(
      id: id,
      type: ResourceType.skill,
      title: id,
      content: 'content-$id',
      createdAt: now,
      updatedAt: now,
    );
    final Map<String, Object?> payload = LibraryBundle.payload(<Resource>[
      resource('one'),
      resource('two'),
    ], generatedAt: now)..['selectedIds'] = <String>['two'];

    final LibraryBundleImportResult result = LibraryBundle.importPayload(
      payload,
      existing: const <Resource>[],
    );

    expect(result.imported.map((Resource item) => item.id), <String>['two']);
  });

  test('local-path skills export portable text without path metadata', () {
    final Directory directory = Directory.systemTemp.createTempSync(
      'dingdong-portable-skill-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    File('${directory.path}/SKILL.md').writeAsStringSync('# Portable skill');
    final DateTime now = DateTime.utc(2026, 7, 13);
    final Resource resource = Resource(
      id: 'portable-skill',
      type: ResourceType.skill,
      title: 'Portable skill',
      content: directory.path,
      source: '/private/company/workspace',
      updateUrl: 'https://private.example/token',
      createdAt: now,
      updatedAt: now,
    );

    final Map<String, Object?> payload = LibraryBundle.payload(<Resource>[
      resource,
    ], generatedAt: now);
    final Map<String, Object?> item =
        (payload['items'] as List<Object?>).single as Map<String, Object?>;

    expect(item['content'], '# Portable skill');
    expect(item, isNot(contains('source')));
    expect(item, isNot(contains('updateURL')));
    expect(jsonEncode(payload), isNot(contains(directory.path)));
  });
}
