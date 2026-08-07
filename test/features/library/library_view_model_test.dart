import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:dingdong/features/library/domain/library_import_history.dart';
import 'package:dingdong/features/library/domain/resource_update_fetcher.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('group filters preserve the compact library browsing context', () async {
    final DateTime now = DateTime.utc(2026);
    final LibraryViewModel model = LibraryViewModel(
      _FakeResourceStore(<Resource>[
        Resource(
          id: 'prompt',
          type: ResourceType.prompt,
          title: 'Prompt',
          content: 'Prompt content',
          group: 'Writing',
          createdAt: now,
          updatedAt: now,
        ),
        Resource(
          id: 'skill',
          type: ResourceType.skill,
          title: 'Skill',
          content: 'Skill content',
          group: 'Engineering',
          createdAt: now,
          updatedAt: now,
        ),
        Resource(
          id: 'mcp',
          type: ResourceType.mcp,
          title: 'MCP',
          content: 'MCP content',
          group: 'MCP Servers',
          createdAt: now,
          updatedAt: now,
        ),
        Resource(
          id: 'dingdong.builtin.reply-marker-prompt.v1',
          type: ResourceType.prompt,
          title: 'Built-in marker',
          content: 'Built-in content',
          group: 'DingDong',
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    );
    await model.load();

    model.setGroupFilter('Engineering');

    expect(model.groups, <String>['Writing', 'Engineering', 'MCP Servers']);
    expect(model.selectedGroup, 'Engineering');
    expect(model.visibleResources.single.title, 'Skill');
  });

  test(
    'default type groups do not appear as duplicate custom groups',
    () async {
      final DateTime now = DateTime.utc(2026);
      final LibraryViewModel model = LibraryViewModel(
        _FakeResourceStore(<Resource>[
          Resource(
            id: 'prompt',
            type: ResourceType.prompt,
            title: 'Prompt',
            content: 'Prompt content',
            createdAt: now,
            updatedAt: now,
          ),
          Resource(
            id: 'skill',
            type: ResourceType.skill,
            title: 'Skill',
            content: 'Skill content',
            createdAt: now,
            updatedAt: now,
          ),
          Resource(
            id: 'mcp',
            type: ResourceType.mcp,
            title: 'MCP',
            content: 'MCP content',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );
      await model.load();

      expect(model.groups, isEmpty);
    },
  );

  test(
    'knowledge stays stored but is hidden from resource management',
    () async {
      final DateTime now = DateTime.utc(2026);
      final LibraryViewModel model = LibraryViewModel(
        _FakeResourceStore(<Resource>[
          Resource(
            id: 'prompt',
            type: ResourceType.prompt,
            title: 'Prompt',
            content: 'Prompt content',
            createdAt: now,
            updatedAt: now,
          ),
          Resource(
            id: 'knowledge',
            type: ResourceType.knowledge,
            title: 'Legacy knowledge',
            content: 'Preserve this data',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );

      await model.load();

      expect(model.allResources, hasLength(2));
      expect(model.visibleResources.map((Resource item) => item.id), <String>[
        'prompt',
      ]);
      expect(model.groups, isNot(contains('Knowledge')));
      expect(model.configurableResources, hasLength(1));
      expect(ResourceType.knowledge.isConfigurableAgentResource, isFalse);
    },
  );

  test(
    'saving a resource keeps the active search and selects the saved row',
    () async {
      final DateTime now = DateTime.utc(2026);
      final Resource original = Resource(
        id: '43755C70-E357-4A6B-87CB-A98F23B67E8A',
        type: ResourceType.prompt,
        title: 'Alpha',
        content: 'Original',
        createdAt: now,
        updatedAt: now,
      );
      final _FakeResourceStore repository = _FakeResourceStore(<Resource>[
        original,
      ]);
      final LibraryViewModel model = LibraryViewModel(repository);
      await model.load();
      model.setQuery('alp');
      final Resource updated = Resource(
        id: original.id,
        type: original.type,
        title: 'Alpha updated',
        content: original.content,
        createdAt: original.createdAt,
        updatedAt: DateTime.utc(2026, 1, 2),
      );

      await model.save(updated);

      expect(model.query, 'alp');
      expect(model.selectedResource, updated);
      expect(model.visibleResources, <Resource>[updated]);
      expect(repository.savedResources, <Resource>[updated]);
    },
  );

  test(
    'deleting the selected resource persists removal and clears selection',
    () async {
      final DateTime now = DateTime.utc(2026);
      final Resource resource = Resource(
        id: '12AE073B-887C-48D9-AB93-B7FC2C7F0A34',
        type: ResourceType.skill,
        title: 'Skill',
        content: 'Skill content',
        createdAt: now,
        updatedAt: now,
      );
      final _FakeResourceStore repository = _FakeResourceStore(<Resource>[
        resource,
      ]);
      final LibraryViewModel model = LibraryViewModel(repository);
      await model.load();
      model.selectResource(resource);

      await model.deleteSelected();

      expect(model.selectedResource, isNull);
      expect(model.visibleResources, isEmpty);
      expect(repository.savedResources, isEmpty);
    },
  );

  test(
    'syncing a resource fetches its update link and persists new content',
    () async {
      final DateTime now = DateTime.utc(2026);
      final Resource resource = Resource(
        id: 'resource-1',
        type: ResourceType.prompt,
        title: 'Review',
        content: 'Old content',
        updateUrl: 'https://example.com/review.md',
        createdAt: now,
        updatedAt: now,
      );
      final _FakeResourceStore repository = _FakeResourceStore(<Resource>[
        resource,
      ]);
      final LibraryViewModel model = LibraryViewModel(
        repository,
        updateFetcher: _FakeUpdateFetcher('# New review instructions'),
        now: () => now.add(const Duration(days: 1)),
      );
      await model.load();
      model.selectResource(resource);

      final updated = await model.syncSelectedFromUpdateLink();

      expect(updated?.content, '# New review instructions');
      expect(
        repository.savedResources.single.updatedAt,
        DateTime.utc(2026, 1, 2),
      );
    },
  );

  test('exports only selected resources and skips them on re-import', () async {
    final DateTime now = DateTime.utc(2026, 7, 13);
    Resource resource(String id) => Resource(
      id: id,
      type: ResourceType.skill,
      title: 'Skill $id',
      content: 'Content $id',
      createdAt: now,
      updatedAt: now,
    );
    final LibraryViewModel source = LibraryViewModel(
      _FakeResourceStore(<Resource>[resource('one'), resource('two')]),
      now: () => now,
    );
    await source.load();
    source.toggleSelection('two');

    final String bundle = source.exportJson();
    final List<Object?> items =
        (jsonDecode(bundle) as Map<String, Object?>)['items'] as List<Object?>;
    expect(items, hasLength(1));
    expect((items.single as Map<String, Object?>)['id'], 'two');

    final _FakeResourceStore targetStore = _FakeResourceStore(<Resource>[]);
    final LibraryViewModel target = LibraryViewModel(targetStore);
    await target.load();
    final first = await target.importBundleJson(bundle);
    final second = await target.importBundleJson(bundle);

    expect(first.imported.single.id, 'two');
    expect(second.imported, isEmpty);
    expect(second.duplicateIds, <String>['two']);
    expect(targetStore.savedResources, hasLength(1));
  });

  test(
    'link imports resolve before commit and are written to history',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 13);
      final Resource online = Resource(
        id: 'linked-skill',
        type: ResourceType.skill,
        title: 'Linked skill',
        content: 'local snapshot',
        updateUrl: 'https://example.com/linked-skill.md',
        createdAt: now,
        updatedAt: now,
      );
      final String bundle = LibraryBundle.encode(<Resource>[
        online,
      ], generatedAt: now);
      final InMemoryLibraryImportHistoryStore history =
          InMemoryLibraryImportHistoryStore();
      final _FakeResourceStore repository = _FakeResourceStore(<Resource>[]);
      final LibraryViewModel model = LibraryViewModel(
        repository,
        updateFetcher: _RoutingUpdateFetcher(<String, String>{
          'https://example.com/library.json': bundle,
          online.updateUrl!: '# fetched skill',
        }),
        importHistoryStore: history,
        now: () => now,
      );
      await model.load();

      final LibraryBundleImportResult prepared = await model
          .prepareBundleJsonFromUrl('https://example.com/library.json');
      expect(repository.savedResources, isEmpty);
      expect(prepared.onlineResources.single.title, 'Linked skill');
      expect(prepared.imported.single.content, '# fetched skill');

      await model.commitBundleImport(
        prepared,
        source: 'https://example.com/library.json',
        kind: LibraryImportSourceKind.link,
      );

      expect(repository.savedResources.single.content, '# fetched skill');
      expect(model.importHistory, hasLength(1));
      expect(model.importHistory.single.kind, LibraryImportSourceKind.link);
      expect(model.importHistory.single.onlineTitles, <String>['Linked skill']);
      expect(
        (await history.load()).single.source,
        'https://example.com/library.json',
      );
    },
  );

  test('new resource inherits the active type filter', () async {
    final LibraryViewModel model = LibraryViewModel(
      _FakeResourceStore(<Resource>[]),
    );
    await model.load();

    model.setTypeFilter(ResourceType.mcp);
    model.startCreating();

    expect(model.isCreating, isTrue);
    expect(model.creatingType, ResourceType.mcp);
  });

  test('failed resource saves restore the visible enabled state', () async {
    final DateTime now = DateTime.utc(2026, 7, 22);
    final Resource resource = Resource(
      id: 'skill',
      type: ResourceType.skill,
      title: 'Reviewer',
      content: 'Skill content',
      enabled: false,
      createdAt: now,
      updatedAt: now,
    );
    final LibraryViewModel model = LibraryViewModel(
      _FailingResourceStore(<Resource>[resource]),
    );
    await model.load();

    await expectLater(
      model.save(resource.copyWith(enabled: true)),
      throwsStateError,
    );

    expect(model.visibleResources.single.enabled, isFalse);
    expect(model.selectedResource, isNull);
  });

  test(
    'trigger groups persist and deleting one clears resource membership',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 16);
      final TriggerGroup group = TriggerGroup(
        id: 'group-1',
        name: 'DingDong',
        rules: <TriggerRule>[
          TriggerRule(
            field: TriggerRuleField.projectPath,
            operator: TriggerRuleOperator.contains,
            value: 'dingdong',
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      final _FakeResourceStore resources = _FakeResourceStore(<Resource>[
        Resource(
          id: 'skill',
          type: ResourceType.skill,
          title: 'Skill',
          content: 'Skill content',
          triggerGroupIds: const <String>['group-1'],
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final InMemoryTriggerGroupStore triggerGroups = InMemoryTriggerGroupStore(
        <TriggerGroup>[group],
      );
      final LibraryViewModel model = LibraryViewModel(
        resources,
        triggerGroupStore: triggerGroups,
        now: () => now.add(const Duration(hours: 1)),
      );
      await model.load();
      model.selectResource(resources.savedResources.single);

      await model.deleteTriggerGroup('group-1');

      expect(model.triggerGroups, isEmpty);
      expect(resources.savedResources.single.triggerGroupIds, isEmpty);
      expect(model.selectedResource?.triggerGroupIds, isEmpty);
      expect(resources.savedResources.single.enabled, isFalse);
      expect(model.selectedResource?.enabled, isFalse);
    },
  );

  test(
    'strict Skill group edits stay exact and refresh canonical paths',
    () async {
      final Directory first = Directory.systemTemp.createTempSync(
        'dingdong-view-model-first-',
      );
      final Directory second = Directory.systemTemp.createTempSync(
        'dingdong-view-model-second-',
      );
      addTearDown(() => first.deleteSync(recursive: true));
      addTearDown(() => second.deleteSync(recursive: true));
      final String firstPath = first.resolveSymbolicLinksSync();
      final String secondPath = second.resolveSymbolicLinksSync();
      final DateTime now = DateTime.utc(2026, 7, 29);
      final TriggerGroup group = TriggerGroup(
        id: 'project',
        name: 'Project',
        rules: <TriggerRule>[
          TriggerRule(
            field: TriggerRuleField.projectPath,
            operator: TriggerRuleOperator.equals,
            value: firstPath,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );
      final _FakeResourceStore resources = _FakeResourceStore(<Resource>[
        Resource(
          id: 'reviewer',
          type: ResourceType.skill,
          title: 'Reviewer',
          content: '---\nname: reviewer\ndescription: Review code\n---\n',
          strictProjectSkill: true,
          triggerGroupIds: const <String>['project'],
          skillProjectPaths: <String>[firstPath],
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final InMemoryTriggerGroupStore triggerGroups = InMemoryTriggerGroupStore(
        <TriggerGroup>[group],
      );
      final LibraryViewModel model = LibraryViewModel(
        resources,
        triggerGroupStore: triggerGroups,
        now: () => now.add(const Duration(hours: 1)),
      );
      await model.load();

      await expectLater(
        model.updateTriggerGroup(
          group.copyWith(
            rules: <TriggerRule>[
              TriggerRule(
                field: TriggerRuleField.projectPath,
                operator: TriggerRuleOperator.contains,
                value: 'dingdong',
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
      expect(
        (await triggerGroups.load()).single.rules.single.operator,
        TriggerRuleOperator.equals,
      );
      expect(resources.savedResources.single.skillProjectPaths, <String>[
        firstPath,
      ]);

      await model.updateTriggerGroup(
        group.copyWith(
          rules: <TriggerRule>[
            TriggerRule(
              field: TriggerRuleField.projectPath,
              operator: TriggerRuleOperator.equals,
              value: secondPath,
            ),
          ],
        ),
      );

      expect(resources.savedResources.single.skillProjectPaths, <String>[
        secondPath,
      ]);
    },
  );
}

final class _FakeUpdateFetcher implements ResourceUpdateFetcher {
  _FakeUpdateFetcher(this.content);

  final String content;

  @override
  Future<String> fetch(Uri uri) async => content;
}

final class _RoutingUpdateFetcher implements ResourceUpdateFetcher {
  _RoutingUpdateFetcher(this.values);

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

final class _FakeResourceStore implements ResourceStore {
  _FakeResourceStore(this.savedResources);

  List<Resource> savedResources;

  @override
  Future<List<Resource>> load() async => List<Resource>.of(savedResources);

  @override
  Future<void> save(List<Resource> resources) async {
    savedResources = List<Resource>.of(resources);
  }
}

final class _FailingResourceStore implements ResourceStore {
  _FailingResourceStore(this.resources);

  final List<Resource> resources;

  @override
  Future<List<Resource>> load() async => List<Resource>.of(resources);

  @override
  Future<void> save(List<Resource> resources) {
    throw StateError('sync failed');
  }
}
