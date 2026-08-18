import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/agent_bridge.dart';
import 'package:dingdong/features/agent_api/data/conversation_token_usage_resolver.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/managed_mcp_identity.dart';
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

  test('Skill candidacy and confirmed full load stay separate', () async {
    final DateTime now = DateTime.utc(2026, 8, 18);
    final Resource skill = Resource(
      id: 'reviewer',
      type: ResourceType.skill,
      title: 'Reviewer',
      content:
          '---\nname: reviewer\ndescription: Review changes\n---\n\n# Reviewer',
      createdAt: now,
      updatedAt: now,
    );
    final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
      skill,
    ]);
    final AgentBridge bridge = AgentBridge(store, now: () => now);

    final response = await bridge.respond(
      '{"task":"review changes","source":"Claude Code"}',
    );

    expect(response.statusCode, 200);
    Resource tracked = (await store.load()).single;
    expect(tracked.candidateCount, 1);
    expect(tracked.lastCandidateAt, now);
    expect(tracked.usageCount, 0);

    final load = await bridge.loadSkill(<String, String>{
      'name': 'reviewer',
      'source': 'Claude Code',
    });

    expect(load.statusCode, 200);
    tracked = (await store.load()).single;
    expect(tracked.candidateCount, 1);
    expect(tracked.usageCount, 1);
    expect(tracked.lastUsedAt, now);
  });

  test('MCP candidacy and confirmed invocation stay separate', () async {
    final DateTime now = DateTime.utc(2026, 8, 18);
    final Resource mcp = Resource(
      id: 'figma-mcp-abcdef',
      type: ResourceType.mcp,
      title: 'Figma',
      content: '{"command":"figma-mcp"}',
      activation: ResourceActivation.always,
      usageCount: 41,
      createdAt: now,
      updatedAt: now,
    );
    final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[mcp]);
    final AgentBridge bridge = AgentBridge(store, now: () => now);

    final response = await bridge.respond(
      '{"task":"inspect design","source":"Claude Code"}',
    );

    expect(response.statusCode, 200);
    Resource tracked = (await store.load()).single;
    expect(tracked.usageCount, 41);
    expect(tracked.candidateCount, 1);
    expect(tracked.lastCandidateAt, now);
    expect(tracked.invocationCount, 0);

    final confirmation = await bridge.confirmMcpUse(<String, String>{
      'id': mcp.id,
      'serverName': managedMcpServerName(title: mcp.title, id: mcp.id),
      'toolName': 'read-design',
      'source': 'Claude Code',
    });

    expect(confirmation.statusCode, 200);
    tracked = (await store.load()).single;
    expect(tracked.usageCount, 41);
    expect(tracked.candidateCount, 1);
    expect(tracked.invocationCount, 1);
    expect(tracked.lastInvokedAt, now);
    expect(
      confirmation.json['mcp'] as Map<String, Object?>,
      containsPair('invocationCount', 1),
    );
  });

  test(
    'Bridge reads and shows usage only when the setting is enabled',
    () async {
      final DateTime now = DateTime.utc(2026, 8, 19);
      final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
        Resource(
          id: 'visible-prompt',
          type: ResourceType.prompt,
          title: 'Visible prompt',
          content: 'Follow this prompt.',
          pinned: true,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      var loads = 0;
      Future<ConversationTokenUsage?> loadUsage(
        ConversationTokenUsageRequest request,
      ) async {
        loads += 1;
        expect(request.source, 'Codex');
        expect(request.conversationId, 'thread-1');
        return const ConversationTokenUsage(
          source: ConversationTokenUsageSource.codex,
          totalTokens: 12500,
        );
      }

      final disabled = await AgentBridge(
        store,
        now: () => now,
        loadShowConversationTokenUsage: () async => false,
        loadConversationTokenUsage: loadUsage,
      ).respond('{"task":"work","source":"Codex","conversationId":"thread-1"}');
      expect(loads, 0);
      expect(
        (disabled.json['conversation']! as Map<String, Object?>)['line'],
        isNot(contains('Token')),
      );

      final enabled = await AgentBridge(
        store,
        now: () => now,
        loadShowConversationTokenUsage: () async => true,
        loadConversationTokenUsage: loadUsage,
      ).respond('{"task":"work","source":"Codex","conversationId":"thread-1"}');
      expect(loads, 1);
      expect(
        (enabled.json['conversation']! as Map<String, Object?>)['line'],
        'DingDong · ♥ Visible ... · 12.5K Token',
      );
    },
  );
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
