import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/resource_update_fetcher.dart';
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
          group: 'Prompts',
          createdAt: now,
          updatedAt: now,
        ),
        Resource(
          id: 'skill',
          type: ResourceType.skill,
          title: 'Skill',
          content: 'Skill content',
          group: 'Skills',
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
      ]),
    );
    await model.load();

    model.setGroupFilter('Skills');

    expect(model.groups, <String>['Prompts', 'Skills', 'MCP Servers']);
    expect(model.selectedGroup, 'Skills');
    expect(model.visibleResources.single.title, 'Skill');
  });

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
}

final class _FakeUpdateFetcher implements ResourceUpdateFetcher {
  _FakeUpdateFetcher(this.content);

  final String content;

  @override
  Future<String> fetch(Uri uri) async => content;
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
