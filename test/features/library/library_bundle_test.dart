import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/library_routes.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:dingdong/features/library/domain/resource_update_fetcher.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final timestamp = DateTime.utc(2026);
  final scoped = Resource(
    id: 'scoped',
    type: ResourceType.skill,
    title: 'Review Skill',
    content: 'Run review',
    createdAt: timestamp,
    updatedAt: timestamp,
    strictProjectSkill: true,
    skillProjectPaths: const ['/sender/private'],
    triggerGroupIds: const ['sender-group'],
    skillDeliveryByAgent: const {'Codex': SkillDeliveryMode.nativeProject},
  );
  TriggerRule rule(TriggerRuleField field, String value) => TriggerRule(
    field: field,
    operator: TriggerRuleOperator.equals,
    value: value,
  );
  final sourceRule = rule(TriggerRuleField.source, 'Codex');
  final repoRule = rule(
    TriggerRuleField.repositoryUrl,
    'git@example.org:team/repo.git',
  );
  final local = rule(TriggerRuleField.projectPath, '/sender/private');
  final mixedGroup = TriggerGroup(
    id: 'sender-group',
    name: '/sender/private',
    rules: [
      local,
      rule(TriggerRuleField.repositoryUrl, r'C:\sender\private'),
      rule(TriggerRuleField.repositoryUrl, 'file:///sender/private'),
      sourceRule,
      repoRule,
    ],
    createdAt: timestamp,
    updatedAt: timestamp,
  );

  test(
    'API export and import preserve portable conditions with recipient-owned IDs',
    () async {
      final sender = LibraryRoutes(
        InMemoryResourceStore([scoped]),
        triggerGroupStore: InMemoryTriggerGroupStore([mixedGroup]),
      );
      final exported = (await sender.export({})).json;
      final wire = jsonEncode(exported);
      for (final value in [
        '/sender/private',
        'sender-group',
        'nativeProject',
        'file://',
        'C:',
      ]) {
        expect(wire, isNot(contains(value)));
      }
      expect(scoped.enabled, isTrue);
      final recipientStore = InMemoryResourceStore();
      final groups = InMemoryTriggerGroupStore([mixedGroup]);
      final recipient = LibraryRoutes(
        recipientStore,
        triggerGroupStore: groups,
      );
      final response = await recipient.importResources(wire);
      expect(response.json['disabledForRuleReview'], ['scoped']);
      final imported = (await recipientStore.load()).single;
      expect(imported.enabled, isFalse);
      expect(imported.strictProjectSkill, isFalse);
      expect(imported.skillProjectPaths, isEmpty);
      expect(imported.skillDeliveryByAgent, isEmpty);
      final binding = imported.triggerGroupIds.single;
      expect(binding, isNot('sender-group'));
      expect((await groups.load()).singleWhere((g) => g.id == binding).rules, [
        sourceRule,
        repoRule,
      ]);
      await recipientStore.save([imported.copyWith(enabled: true)]);
      final duplicate = await recipient.importResources(wire);
      expect(duplicate.json['disabledForRuleReview'], isNull);
      expect((await recipientStore.load()).single.enabled, isTrue);
      expect(await groups.load(), hasLength(2));
    },
  );

  test(
    'legacy and hand-edited bundles discard local scope before committing',
    () async {
      final item = {
        ...scoped.toJson(),
        'packagePath': '/sender/private/package',
        'portableRules': [local.toJson()],
      };
      final plain = {...scoped.toJson(), 'id': 'plain', 'content': 'plain'}
        ..remove('strictProjectSkill')
        ..remove('skillProjectPaths')
        ..remove('triggerGroupIds')
        ..remove('skillDeliveryByAgent');
      final result = LibraryBundle.importPayload({
        'schemaVersion': 2,
        'items': [item, plain],
      }, existing: []);
      expect(result.reviewRules.keys, ['scoped']);
      expect(result.reviewRules['scoped'], isEmpty);
      expect(result.imported.first.skillProjectPaths, isEmpty);
      expect(result.imported.first.packagePath, isNull);
      expect(result.imported.first.triggerGroupIds, isEmpty);
      expect(result.imported.first.enabled, isFalse);
      expect(result.imported.last.enabled, isTrue);
    },
  );

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

  test(
    'preview and install honor both bundle and recipient selections',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 13);
      Resource resource(String id) => Resource(
        id: id,
        type: ResourceType.skill,
        title: id,
        content: 'local $id',
        updateUrl: 'https://example.test/$id',
        createdAt: now,
        updatedAt: now,
      );
      final payload = LibraryBundle.payload([
        resource('chosen'),
        resource('unchecked'),
        resource('excluded-by-sender'),
      ], generatedAt: now)..['selectedIds'] = ['chosen', 'unchecked'];
      final contents = jsonEncode(payload);

      final preview = LibraryBundle.preview(contents);
      expect(preview.map((item) => item.id), ['chosen', 'unchecked']);
      expect(preview.first.updateUrl, 'https://example.test/chosen');

      final selected = LibraryBundle.select(contents, {
        'chosen',
        'excluded-by-sender',
      });
      expect(LibraryBundle.preview(selected).map((item) => item.id), [
        'chosen',
      ]);
      final selectedJson = jsonDecode(selected) as Map<String, Object?>;
      final items = (selectedJson['items'] as List<Object?>)
          .cast<Map<String, Object?>>();
      expect(items, hasLength(1));
      expect(items.single['contentURL'], 'https://example.test/chosen');
    },
  );

  test('rejects bundles from removed schema and service versions', () {
    expect(
      () => LibraryBundle.importPayload(<String, Object?>{
        'service': 'DingDong',
        'schemaVersion': 1,
        'items': const <Object?>[],
      }, existing: const <Resource>[]),
      throwsFormatException,
    );
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

    expect(item['content'], isNull);
    expect(item['contentURL'], 'https://private.example/token');
    expect(item, isNot(contains('source')));
    expect(item, isNot(contains('updateURL')));
    expect(jsonEncode(payload), isNot(contains(directory.path)));
  });

  test(
    'online resources export a link and resolve it before importing',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 13);
      final Resource online = Resource(
        id: 'online-review',
        type: ResourceType.skill,
        title: 'Online review',
        content: 'private snapshot',
        updateUrl: 'https://example.com/review.md',
        createdAt: now,
        updatedAt: now,
      );
      final String encoded = LibraryBundle.encode(<Resource>[
        online,
      ], generatedAt: now);
      final Map<String, Object?> item =
          ((jsonDecode(encoded) as Map<String, Object?>)['items']
                      as List<Object?>)
                  .single
              as Map<String, Object?>;

      expect(item['content'], isNull);
      expect(item['contentURL'], online.updateUrl);
      expect(encoded, isNot(contains('private snapshot')));

      final LibraryBundleImportResult result = await LibraryBundle.decodeOnline(
        encoded,
        existing: const <Resource>[],
        fetcher: _MapUpdateFetcher(<String, String>{
          online.updateUrl!: '# fetched review',
        }),
      );

      expect(result.imported.single.content, '# fetched review');
      expect(result.imported.single.updateUrl, online.updateUrl);
      expect(result.onlineResources.single.title, 'Online review');
    },
  );

  test(
    'online duplicate checks use fetched content before committing',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 13);
      final Resource existing = Resource(
        id: 'existing-review',
        type: ResourceType.skill,
        title: 'Existing review',
        content: '# fetched review',
        createdAt: now,
        updatedAt: now,
      );
      final Resource online = Resource(
        id: 'online-review',
        type: ResourceType.skill,
        title: 'Online review',
        content: 'private snapshot',
        updateUrl: 'https://example.com/review.md',
        createdAt: now,
        updatedAt: now,
      );
      final LibraryBundleImportResult result = await LibraryBundle.decodeOnline(
        LibraryBundle.encode(<Resource>[online], generatedAt: now),
        existing: <Resource>[existing],
        fetcher: _MapUpdateFetcher(<String, String>{
          online.updateUrl!: '# fetched review',
        }),
      );

      expect(result.imported, isEmpty);
      expect(result.duplicateIds, <String>['online-review']);
      expect(result.onlineResources.single.title, 'Online review');
    },
  );
}

final class _MapUpdateFetcher implements ResourceUpdateFetcher {
  _MapUpdateFetcher(this.values);

  final Map<String, String> values;

  @override
  Future<String> fetch(Uri uri) async {
    final String? value = values[uri.toString()];
    if (value == null) {
      throw StateError('Unexpected fetch: $uri');
    }
    return value;
  }
}
