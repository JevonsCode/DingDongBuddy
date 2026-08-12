import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/agent_bridge.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full Skill load merges usage without replacing the library', () async {
    final DateTime now = DateTime.utc(2026, 8, 12);
    final _UsageMergeOnlyStore store = _UsageMergeOnlyStore(<Resource>[
      Resource(
        id: 'reviewer',
        type: ResourceType.skill,
        title: 'Reviewer',
        content:
            '---\nname: reviewer\ndescription: Review changes\n---\n\n# Reviewer',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final AgentBridge bridge = AgentBridge(store, now: () => now);

    final response = await bridge.loadSkill(<String, String>{
      'name': 'reviewer',
      'source': 'Claude Code',
      'workspacePath': '/workspace/project',
    });

    expect(response.statusCode, 200);
    expect(store.recordUsageCalls, 1);
    expect(store.saveCalls, 0);
    expect((await store.load()).single.usageCount, 1);
  });
}

final class _UsageMergeOnlyStore
    implements ResourceStore, ResourceUsageStore, ExclusiveResourceStore {
  _UsageMergeOnlyStore(List<Resource> resources)
    : _resources = List<Resource>.of(resources);

  List<Resource> _resources;
  int recordUsageCalls = 0;
  int saveCalls = 0;

  @override
  Future<T> exclusiveMutation<T>(Future<T> Function() action) => action();

  @override
  Future<List<Resource>> load() async => List<Resource>.of(_resources);

  @override
  Future<List<Resource>> recordUsage(
    Set<String> resourceIds,
    DateTime usedAt,
  ) async {
    recordUsageCalls += 1;
    _resources = _resources
        .map(
          (Resource resource) => resourceIds.contains(resource.id)
              ? resource.copyWith(
                  usageCount: resource.usageCount + 1,
                  lastUsedAt: usedAt,
                )
              : resource,
        )
        .toList(growable: false);
    return List<Resource>.of(_resources);
  }

  @override
  Future<void> save(List<Resource> resources) async {
    saveCalls += 1;
    throw StateError('Full-library replacement is not allowed for usage.');
  }
}
