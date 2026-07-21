import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/agent_api/data/http_request_data.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('GET /health retains the native response contract', () async {
    final AgentRouter router = AgentRouter();

    final response = await router.route(
      const HttpRequestData(method: 'GET', uri: '/health'),
    );

    expect(response.statusCode, 200);
    expect(response.json, <String, Object?>{
      'status': 'ok',
      'service': 'DingDong',
    });
  });

  test('POST /ding parses, clamps, and forwards the notification', () async {
    DingRequest? received;
    final AgentRouter router = AgentRouter(
      onDing: (DingRequest request) => received = request,
    );

    final response = await router.route(
      const HttpRequestData(
        method: 'POST',
        uri: '/ding',
        body:
            '{"message":" Deploy complete ","source":" Codex ","sound":"system","flashCount":99}',
      ),
    );

    expect(response.statusCode, 200);
    expect(response.json, <String, Object?>{
      'status': 'triggered',
      'message': 'Deploy complete',
    });
    expect(received?.source, 'Codex');
    expect(received?.sound, DingSound.system);
    expect(received?.flashCount, 30);
  });

  test('completion hook suppresses a duplicate Agent notification', () async {
    int notificationCount = 0;
    DateTime now = DateTime.utc(2026, 7, 17, 12);
    final AgentRouter router = AgentRouter(
      onDing: (DingRequest request) => notificationCount += 1,
      now: () => now,
    );

    await router.route(
      const HttpRequestData(
        method: 'POST',
        uri: '/ding',
        body: '{"message":"Done","source":"Codex"}',
      ),
    );
    now = now.add(const Duration(seconds: 1));
    final suppressed = await router.route(
      const HttpRequestData(
        method: 'POST',
        uri: '/ding',
        body: '{"message":"Codex 已完成本轮任务","source":"Codex","fallback":true}',
      ),
    );

    expect(notificationCount, 1);
    expect(suppressed.json['status'], 'suppressed');

    final otherAgent = await router.route(
      const HttpRequestData(
        method: 'POST',
        uri: '/ding',
        body:
            '{"message":"Claude Code 已完成本轮任务","source":"Claude Code","fallback":true}',
      ),
    );
    expect(notificationCount, 2);
    expect(otherAgent.json['status'], 'triggered');

    now = now.add(const Duration(seconds: 5));
    final triggered = await router.route(
      const HttpRequestData(
        method: 'POST',
        uri: '/ding',
        body: '{"message":"Codex 已完成本轮任务","source":"Codex","fallback":true}',
      ),
    );

    expect(notificationCount, 3);
    expect(triggered.json['status'], 'triggered');
  });

  test('POST /library creates a resource that GET /library can query', () async {
    final InMemoryResourceStore store = InMemoryResourceStore();
    final AgentRouter router = AgentRouter(
      resourceStore: store,
      idGenerator: () => '918BCED3-F338-43DF-B5B5-EBF37B19BDB6',
      now: () => DateTime.utc(2026, 7, 12),
    );

    final created = await router.route(
      const HttpRequestData(
        method: 'POST',
        uri: '/library',
        body:
            '{"type":"prompt","title":" Bug triage ","content":"Find risky changes","tags":["review"],"source":"Codex","pinned":true,"triggerGroupIds":["dingdong"]}',
      ),
    );
    final listed = await router.route(
      const HttpRequestData(method: 'GET', uri: '/library?q=triage'),
    );

    expect(created.statusCode, 201);
    expect(created.json['status'], 'created');
    expect(listed.statusCode, 200);
    final List<Object?> items = listed.json['items']! as List<Object?>;
    expect(items, hasLength(1));
    expect((items.single as Map<String, Object?>)['title'], 'Bug triage');
    expect((items.single as Map<String, Object?>)['group'], 'Prompts');
    expect((items.single as Map<String, Object?>)['activation'], 'always');
    expect((items.single as Map<String, Object?>)['triggerGroupIds'], <Object?>[
      'dingdong',
    ]);
  });

  test(
    'clipboard history is metadata-only and hides sensitive rows by default',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final InMemoryClipboardStore clipboardStore = InMemoryClipboardStore(
        <ClipboardRecord>[
          ClipboardRecord(
            id: 'safe',
            group: 'Commands',
            title: 'Run tests',
            content: 'flutter test',
            tags: const <String>['clipboard', 'command'],
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now,
            updatedAt: now,
          ),
          ClipboardRecord(
            id: 'secret',
            group: 'Sensitive',
            title: 'Sensitive token',
            content: 'token=abcdefghijklmnop',
            tags: const <String>['clipboard', 'sensitive'],
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      final AgentRouter router = AgentRouter(clipboardStore: clipboardStore);

      final response = await router.route(
        const HttpRequestData(method: 'GET', uri: '/clipboard/history'),
      );

      expect(response.statusCode, 200);
      expect(response.json['counts'], <String, Object?>{
        'matched': 2,
        'visible': 1,
        'returned': 1,
        'hiddenSensitive': 1,
      });
      final List<Object?> items = response.json['items']! as List<Object?>;
      final Map<String, Object?> item = items.single as Map<String, Object?>;
      expect(item['id'], 'safe');
      expect(item.containsKey('content'), isFalse);
      expect(item['contentCharacterCount'], 12);
    },
  );

  test(
    'POST /clipboard/capture stores the current platform clipboard',
    () async {
      final InMemoryClipboardStore clipboardStore = InMemoryClipboardStore();
      final ClipboardCaptureService captureService = ClipboardCaptureService(
        gateway: _StaticClipboardGateway(
          const ClipboardSnapshot(text: 'flutter test', source: 'API'),
        ),
        store: clipboardStore,
        idGenerator: () => 'captured',
        now: () => DateTime.utc(2026, 7, 12),
      );
      final AgentRouter router = AgentRouter(
        clipboardCaptureService: captureService,
        clipboardStore: clipboardStore,
      );

      final response = await router.route(
        const HttpRequestData(method: 'POST', uri: '/clipboard/capture'),
      );

      expect(response.statusCode, 201);
      expect(response.json['status'], 'captured');
      final Map<String, Object?> item =
          response.json['item']! as Map<String, Object?>;
      expect(item['title'], 'flutter test');
      expect(clipboardStore.list(limit: 10), hasLength(1));
    },
  );

  test(
    'POST /clipboard/restore writes the selected record through the platform seam',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final InMemoryClipboardStore clipboardStore = InMemoryClipboardStore(
        <ClipboardRecord>[
          ClipboardRecord(
            id: 'safe',
            group: 'Clipboard',
            title: 'Restore me',
            content: 'Restored content',
            tags: const <String>['clipboard', 'text'],
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      final _StaticClipboardGateway gateway = _StaticClipboardGateway(
        const ClipboardSnapshot(),
      );
      final AgentRouter router = AgentRouter(
        clipboardGateway: gateway,
        clipboardStore: clipboardStore,
      );

      final response = await router.route(
        const HttpRequestData(method: 'POST', uri: '/clipboard/restore/safe'),
      );

      expect(response.statusCode, 200);
      expect(response.json['status'], 'restored');
      expect(gateway.writtenText, 'Restored content');
    },
  );

  test('POST /clipboard/restore preserves file clipboard semantics', () async {
    final DateTime now = DateTime.utc(2026, 7, 12);
    final InMemoryClipboardStore clipboardStore = InMemoryClipboardStore(
      <ClipboardRecord>[
        ClipboardRecord(
          id: 'files',
          group: 'Files',
          title: 'Files: 2 items',
          content: '/tmp/one.txt\n/tmp/two.png',
          tags: const <String>['clipboard', 'file', 'file-url'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    final _StaticClipboardGateway gateway = _StaticClipboardGateway(
      const ClipboardSnapshot(),
    );
    final AgentRouter router = AgentRouter(
      clipboardGateway: gateway,
      clipboardStore: clipboardStore,
    );

    final response = await router.route(
      const HttpRequestData(method: 'POST', uri: '/clipboard/restore/files'),
    );

    expect(response.statusCode, 200);
    expect(gateway.writtenFiles, <String>['/tmp/one.txt', '/tmp/two.png']);
    expect(gateway.writtenText, isNull);
  });

  test(
    'GET /library/{id} defaults to summary and supports full mode',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final AgentRouter router = AgentRouter(
        resourceStore: InMemoryResourceStore(<Resource>[
          Resource(
            id: 'prompt-1',
            type: ResourceType.prompt,
            title: 'Release helper',
            content: 'Full private prompt body',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );

      final summary = await router.route(
        const HttpRequestData(method: 'GET', uri: '/library/prompt-1'),
      );
      final full = await router.route(
        const HttpRequestData(
          method: 'GET',
          uri: '/library/prompt-1?mode=full',
        ),
      );

      expect(
        (summary.json['item'] as Map<String, Object?>),
        isNot(contains('content')),
      );
      expect(
        (full.json['item'] as Map<String, Object?>)['content'],
        'Full private prompt body',
      );
    },
  );

  test(
    'POST /agent/bridge expands prompts while keeping other assets summarized',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
        Resource(
          id: 'prompt',
          type: ResourceType.prompt,
          title: 'Flutter release',
          content: 'Use the release checklist.',
          tags: const <String>['flutter', 'release'],
          pinned: true,
          createdAt: now,
          updatedAt: now,
        ),
        Resource(
          id: 'skill',
          type: ResourceType.skill,
          title: 'Flutter skill',
          content: 'Long skill instructions',
          tags: const <String>['flutter'],
          pinned: true,
          createdAt: now,
          updatedAt: now,
        ),
        Resource(
          id: 'mcp',
          type: ResourceType.mcp,
          title: 'Flutter MCP',
          content: '{"type":"stdio","command":"flutter-mcp"}',
          tags: const <String>['flutter'],
          pinned: true,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final AgentRouter router = AgentRouter(
        resourceStore: store,
        now: () => now.add(const Duration(hours: 1)),
      );

      final response = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/agent/bridge',
          body: '{"task":"Ship Flutter release","source":"Codex"}',
        ),
      );
      final active = response.json['active'] as Map<String, Object?>;
      final prompts = active['prompts'] as List<Object?>;
      final skills = active['skills'] as List<Object?>;
      final mcps = active['mcps'] as List<Object?>;

      expect(
        (prompts.single as Map<String, Object?>)['content'],
        contains('checklist'),
      );
      expect(
        (skills.single as Map<String, Object?>),
        isNot(contains('content')),
      );
      expect((mcps.single as Map<String, Object?>), isNot(contains('content')));
      expect(response.json['delivery'], <String, Object?>{
        'prompts': 'full-required-instructions',
        'skills': 'summary-load-on-match',
        'mcps': 'summary-call-on-demand',
      });
      expect(
        (await store.load()).map((Resource item) => item.usageCount),
        <int>[1, 1, 1],
      );
      expect(
        (await store.load()).first.lastUsedAt,
        now.add(const Duration(hours: 1)),
      );
    },
  );

  test('POST /agent/bridge never auto-activates manual resources', () async {
    final DateTime now = DateTime.utc(2026, 7, 12);
    final AgentRouter router = AgentRouter(
      resourceStore: InMemoryResourceStore(<Resource>[
        Resource(
          id: 'manual-prompt',
          type: ResourceType.prompt,
          title: 'Release checklist',
          content: 'Only load this checklist manually.',
          activation: ResourceActivation.manual,
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    );

    final response = await router.route(
      const HttpRequestData(
        method: 'POST',
        uri: '/agent/bridge',
        body: '{"task":"Use the release checklist"}',
      ),
    );
    final active = response.json['active'] as Map<String, Object?>;

    expect(active['prompts'], isEmpty);
  });

  test('POST /agent/bridge applies reusable project trigger groups', () async {
    final DateTime now = DateTime.utc(2026, 7, 16);
    final InMemoryResourceStore resources = InMemoryResourceStore(<Resource>[
      Resource(
        id: 'scoped',
        type: ResourceType.skill,
        title: 'DingDong skill',
        content: 'Only use inside DingDong.',
        pinned: true,
        triggerGroupIds: const <String>['dingdong'],
        createdAt: now,
        updatedAt: now,
      ),
      Resource(
        id: 'global',
        type: ResourceType.skill,
        title: 'Global skill',
        content: 'Available everywhere.',
        pinned: true,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final AgentRouter router = AgentRouter(
      resourceStore: resources,
      triggerGroupStore: InMemoryTriggerGroupStore(<TriggerGroup>[
        TriggerGroup(
          id: 'dingdong',
          name: 'DingDong projects',
          rules: <TriggerRule>[
            TriggerRule(
              field: TriggerRuleField.projectPath,
              operator: TriggerRuleOperator.contains,
              value: 'dingdong',
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    );

    final outside = await router.route(
      const HttpRequestData(
        method: 'POST',
        uri: '/agent/bridge',
        body: '{"task":"work","workspacePath":"/workspace/other"}',
      ),
    );
    final inside = await router.route(
      const HttpRequestData(
        method: 'POST',
        uri: '/agent/bridge',
        body: '{"task":"work","workspacePath":"/workspace/dingdong"}',
      ),
    );

    List<Object?> skills(Map<String, Object?> json) =>
        (json['active'] as Map<String, Object?>)['skills'] as List<Object?>;
    expect(skills(outside.json), hasLength(1));
    expect(skills(inside.json), hasLength(2));
    expect(
      (inside.json['context']
          as Map<String, Object?>)['matchedTriggerGroupIds'],
      <Object?>['dingdong'],
    );
  });

  test(
    'Agent API creates and updates project trigger groups for scoped resources',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 19);
      final InMemoryResourceStore resources = InMemoryResourceStore();
      final InMemoryTriggerGroupStore groups = InMemoryTriggerGroupStore();
      final AgentRouter router = AgentRouter(
        resourceStore: resources,
        triggerGroupStore: groups,
        idGenerator: () => 'checkout-scope',
        now: () => now,
      );

      final rejectedUnknownScope = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/library',
          body:
              '{"type":"prompt","title":"Broken policy","content":"Must not save","triggerGroupIds":["missing-scope"]}',
        ),
      );

      final createdGroup = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/library/trigger-groups',
          body:
              '{"name":"Checkout","rules":[{"field":"projectPath","operator":"contains","value":"/checkout/"},{"field":"repositoryUrl","operator":"equals","value":"https://github.com/acme/checkout.git"}]}',
        ),
      );
      final createdResource = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/library',
          body:
              '{"type":"prompt","title":"SKU sku-pro policy","content":"Check region and effective date before changing price.","tags":["sku:sku-pro","policy"],"triggerGroupIds":["checkout-scope"],"activation":"always"}',
        ),
      );
      final rejectedUnknownScopePatch = await router.route(
        const HttpRequestData(
          method: 'PATCH',
          uri: '/library/checkout-scope',
          body: '{"triggerGroupIds":["missing-scope"]}',
        ),
      );
      final listed = await router.route(
        const HttpRequestData(method: 'GET', uri: '/library/trigger-groups'),
      );
      final capabilities = await router.route(
        const HttpRequestData(method: 'GET', uri: '/agent/capabilities'),
      );

      expect(rejectedUnknownScope.statusCode, 400);
      expect(
        rejectedUnknownScope.json['message'],
        'Unknown trigger group IDs: missing-scope',
      );
      expect(createdGroup.statusCode, 201);
      expect(createdResource.statusCode, 201);
      expect(rejectedUnknownScopePatch.statusCode, 400);
      expect(listed.statusCode, 200);
      expect(listed.json['groups'], hasLength(1));
      final group =
          (listed.json['groups'] as List<Object?>).single
              as Map<String, Object?>;
      expect(group['id'], 'checkout-scope');
      expect(group['name'], 'Checkout');
      expect(group['rules'], hasLength(2));
      expect(
        capabilities.json['features'],
        contains('triggerGroupConfiguration'),
      );
      expect(
        capabilities.json['endpoints'],
        contains(
          predicate<Map<String, Object?>>(
            (Map<String, Object?> endpoint) =>
                endpoint['method'] == 'POST' &&
                endpoint['path'] == '/library/trigger-groups',
          ),
        ),
      );

      final updated = await router.route(
        const HttpRequestData(
          method: 'PATCH',
          uri: '/library/trigger-groups/checkout-scope',
          body:
              '{"name":"Checkout production","rules":[{"field":"repositoryUrl","operator":"equals","value":"https://github.com/acme/checkout.git"}]}',
        ),
      );
      expect(updated.statusCode, 200);
      expect(
        (updated.json['group'] as Map<String, Object?>)['name'],
        'Checkout production',
      );

      final outside = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/agent/bridge',
          body:
              '{"task":"change sku-pro price","workspacePath":"/work/checkout/","repositoryUrl":"https://github.com/acme/other.git","expand":"prompts"}',
        ),
      );
      final inside = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/agent/bridge',
          body:
              '{"task":"change sku-pro price","repositoryUrl":"https://github.com/acme/checkout.git","expand":"prompts"}',
        ),
      );
      List<Object?> prompts(Map<String, Object?> json) =>
          (json['active'] as Map<String, Object?>)['prompts'] as List<Object?>;
      expect(prompts(outside.json), isEmpty);
      expect(prompts(inside.json), hasLength(1));
    },
  );

  test('deleting a trigger group detaches it from resources', () async {
    final DateTime now = DateTime.utc(2026, 7, 19);
    final InMemoryResourceStore resources = InMemoryResourceStore(<Resource>[
      Resource(
        id: 'policy',
        type: ResourceType.prompt,
        title: 'Policy',
        content: 'Policy body',
        triggerGroupIds: const <String>['checkout', 'shared'],
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final InMemoryTriggerGroupStore groups = InMemoryTriggerGroupStore(
      <TriggerGroup>[
        TriggerGroup(
          id: 'checkout',
          name: 'Checkout',
          rules: <TriggerRule>[
            TriggerRule(
              field: TriggerRuleField.projectPath,
              operator: TriggerRuleOperator.contains,
              value: 'checkout',
            ),
          ],
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    final AgentRouter router = AgentRouter(
      resourceStore: resources,
      triggerGroupStore: groups,
      now: () => now.add(const Duration(minutes: 1)),
    );

    final response = await router.route(
      const HttpRequestData(
        method: 'DELETE',
        uri: '/library/trigger-groups/checkout',
      ),
    );

    expect(response.statusCode, 200);
    expect(await groups.load(), isEmpty);
    expect((await resources.load()).single.triggerGroupIds, <String>['shared']);
    expect(
      (await resources.load()).single.updatedAt,
      now.add(const Duration(minutes: 1)),
    );
  });

  test(
    'tracked full reads increment usage while ordinary reads do not',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 13);
      final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
        Resource(
          id: 'skill-1',
          type: ResourceType.skill,
          title: 'Review skill',
          content: 'Review carefully.',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final AgentRouter router = AgentRouter(
        resourceStore: store,
        now: () => now.add(const Duration(minutes: 5)),
      );

      await router.route(
        const HttpRequestData(method: 'GET', uri: '/library/skill-1'),
      );
      final tracked = await router.route(
        const HttpRequestData(
          method: 'GET',
          uri: '/library/skill-1?mode=full&trackUsage=true',
        ),
      );

      expect((await store.load()).single.usageCount, 1);
      expect((tracked.json['item'] as Map<String, Object?>)['usageCount'], 1);
    },
  );

  test(
    'library groups, patch, export, and delete preserve the public contract',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
        Resource(
          id: 'resource-1',
          type: ResourceType.prompt,
          group: 'Release',
          title: 'Release prompt',
          content: 'Original',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final AgentRouter router = AgentRouter(resourceStore: store);

      final groups = await router.route(
        const HttpRequestData(method: 'GET', uri: '/library/groups'),
      );
      final updated = await router.route(
        const HttpRequestData(
          method: 'PATCH',
          uri: '/library/resource-1',
          body:
              '{"title":"Updated prompt","pinned":true,"triggerGroupIds":["release-project"]}',
        ),
      );
      final exported = await router.route(
        const HttpRequestData(method: 'GET', uri: '/library/export'),
      );
      final deleted = await router.route(
        const HttpRequestData(method: 'DELETE', uri: '/library/resource-1'),
      );

      expect((groups.json['groups'] as List<Object?>), hasLength(1));
      expect(
        (updated.json['item'] as Map<String, Object?>)['title'],
        'Updated prompt',
      );
      expect(
        (updated.json['item'] as Map<String, Object?>)['triggerGroupIds'],
        <Object?>['release-project'],
      );
      expect((exported.json['items'] as List<Object?>), hasLength(1));
      expect(deleted.json['status'], 'deleted');
      expect(await store.load(), isEmpty);
    },
  );

  test(
    'library export returns all items with usage and duplicate analysis',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 13);
      final List<Resource> resources = List<Resource>.generate(
        550,
        (int index) => Resource(
          id: 'resource-$index',
          type: index.isEven ? ResourceType.prompt : ResourceType.skill,
          title: 'Resource $index',
          content: index == 0 || index == 2 ? 'duplicate body' : 'body $index',
          usageCount: index == 0 ? 3 : 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final AgentRouter router = AgentRouter(
        resourceStore: InMemoryResourceStore(resources),
        now: () => now,
      );

      final all = await router.route(
        const HttpRequestData(method: 'GET', uri: '/library/export'),
      );
      final selected = await router.route(
        const HttpRequestData(
          method: 'GET',
          uri: '/library/export?type=skill&ids=resource-1,resource-3',
        ),
      );

      expect(all.json['schemaVersion'], 2);
      expect(all.json['items'] as List<Object?>, hasLength(550));
      expect(
        (all.json['analysis'] as Map<String, Object?>)['unusedIds']
            as List<Object?>,
        hasLength(549),
      );
      expect(
        (all.json['analysis'] as Map<String, Object?>)['duplicateGroups']
            as List<Object?>,
        hasLength(1),
      );
      expect(selected.json['items'] as List<Object?>, hasLength(2));
    },
  );

  test(
    'bundle import preserves IDs and deduplicates repeated imports',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 13);
      final InMemoryResourceStore store = InMemoryResourceStore();
      final AgentRouter router = AgentRouter(resourceStore: store);
      final Map<String, Object?> item = Resource(
        id: 'shared-skill',
        type: ResourceType.skill,
        title: 'Shared skill',
        content: 'Shared instructions',
        createdAt: now,
        updatedAt: now,
      ).toJson();
      final String body = jsonEncode(<String, Object?>{
        'schemaVersion': 2,
        'selectedIds': <String>['shared-skill'],
        'items': <Object?>[item],
      });

      final first = await router.route(
        HttpRequestData(method: 'POST', uri: '/library/import', body: body),
      );
      final second = await router.route(
        HttpRequestData(method: 'POST', uri: '/library/import', body: body),
      );

      expect(first.json['importedCount'], 1);
      expect(second.json['importedCount'], 0);
      expect(second.json['duplicateIds'], <String>['shared-skill']);
      expect((await store.load()).single.id, 'shared-skill');
    },
  );

  test(
    'clipboard overview, groups, and organization patch preserve the public contract',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final InMemoryClipboardStore store = InMemoryClipboardStore(
        <ClipboardRecord>[
          ClipboardRecord(
            id: 'clip-1',
            group: 'Work',
            title: 'Deploy command',
            content: 'flutter build macos',
            tags: const <String>['clipboard', 'command'],
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      final AgentRouter router = AgentRouter(
        clipboardStore: store,
        now: () => now.add(const Duration(minutes: 1)),
      );

      final overview = await router.route(
        const HttpRequestData(method: 'GET', uri: '/clipboard/overview'),
      );
      final groups = await router.route(
        const HttpRequestData(method: 'GET', uri: '/clipboard/groups'),
      );
      final updated = await router.route(
        const HttpRequestData(
          method: 'PATCH',
          uri: '/clipboard/clip-1',
          body: '{"group":"Release","tags":["alias:build"],"pinned":true}',
        ),
      );

      expect((overview.json['overview'] as Map<String, Object?>)['total'], 1);
      expect((groups.json['groups'] as List<Object?>), hasLength(1));
      final item = updated.json['item'] as Map<String, Object?>;
      expect(item['group'], 'Release');
      expect(item['pinned'], isTrue);
      expect(item['tags'], containsAll(<String>['command', 'alias:build']));
    },
  );

  test(
    'clipboard snippets, digest, insights, and promotion preserve workflows',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final InMemoryClipboardStore clipboard = InMemoryClipboardStore(
        <ClipboardRecord>[
          ClipboardRecord(
            id: 'clip-1',
            group: 'Commands',
            title: 'Build desktop',
            content: 'flutter build windows',
            tags: const <String>['clipboard', 'command', 'alias:build'],
            pinned: true,
            enabled: true,
            activation: 'always',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      final InMemoryResourceStore resources = InMemoryResourceStore();
      final _StaticClipboardGateway gateway = _StaticClipboardGateway(
        const ClipboardSnapshot(),
      );
      final AgentRouter router = AgentRouter(
        clipboardStore: clipboard,
        clipboardGateway: gateway,
        resourceStore: resources,
        idGenerator: () => 'promoted-1',
        now: () => now,
      );

      final snippets = await router.route(
        const HttpRequestData(
          method: 'GET',
          uri: '/clipboard/snippets?alias=build&includeContent=true',
        ),
      );
      final digest = await router.route(
        const HttpRequestData(
          method: 'GET',
          uri: '/clipboard/digest?q=windows',
        ),
      );
      final insights = await router.route(
        const HttpRequestData(method: 'GET', uri: '/clipboard/insights'),
      );
      final restored = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/clipboard/snippet/build/restore',
        ),
      );
      final promoted = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/clipboard/promote/clip-1',
          body: '{"targetType":"knowledge"}',
        ),
      );

      expect((snippets.json['items'] as List<Object?>), hasLength(1));
      expect((digest.json['candidates'] as List<Object?>), hasLength(1));
      expect(insights.json['status'], 'ok');
      expect(restored.json['status'], 'restored');
      expect(gateway.writtenText, 'flutter build windows');
      expect(promoted.statusCode, 201);
      expect((await resources.load()).single.type, ResourceType.knowledge);
    },
  );

  test(
    'library import, knowledge index, and seed routes remain available',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-http-library-',
      );
      addTearDown(() => directory.delete(recursive: true));
      await File(
        '${directory.path}/review.md',
      ).writeAsString('# Review\nCheck risk.');
      final InMemoryResourceStore store = InMemoryResourceStore();
      final AgentRouter router = AgentRouter(
        resourceStore: store,
        idGenerator: () => 'imported-1',
        now: () => DateTime.utc(2026, 7, 12),
      );

      final imported = await router.route(
        HttpRequestData(
          method: 'POST',
          uri: '/library/import',
          body: jsonEncode(<String, Object?>{
            'type': 'prompt',
            'path': directory.path,
          }),
        ),
      );
      final indexed = await router.route(
        HttpRequestData(
          method: 'GET',
          uri:
              '/knowledge/index?root=${Uri.encodeQueryComponent(directory.path)}',
        ),
      );
      final seeded = await router.route(
        const HttpRequestData(method: 'POST', uri: '/library/seed-defaults'),
      );

      expect(imported.json['importedCount'], 1);
      expect((indexed.json['files'] as List<Object?>), hasLength(1));
      expect(seeded.json['inserted'], 1);
      expect(
        (await store.load()).any(
          (Resource resource) => resource.content == '每次完整回复的最后加一个「🌟」',
        ),
        isTrue,
      );
    },
  );

  test(
    'agent discovery and task context routes retain public availability',
    () async {
      final DateTime now = DateTime.utc(2026, 7, 12);
      final AgentRouter router = AgentRouter(
        resourceStore: InMemoryResourceStore(<Resource>[
          Resource(
            id: 'prompt-1',
            type: ResourceType.prompt,
            title: 'Review changes',
            content: 'Check risky changes',
            tags: const <String>['review'],
            pinned: true,
            createdAt: now,
            updatedAt: now,
          ),
        ]),
        clipboardStore: InMemoryClipboardStore(),
        now: () => now,
      );
      const List<String> paths = <String>[
        '/agent/templates',
        '/agent/capabilities',
        '/agent/manifest',
        '/.well-known/dingdong-agent.json',
        '/system/status',
        '/agent/toolkit',
        '/agent/startup?task=review',
        '/agent/bridge?task=review&source=Codex',
        '/agent/prepare?task=review',
        '/agent/workbench?task=review',
        '/agent/instructions?task=review',
        '/agent/brief',
        '/agent/recommend?q=review',
        '/agent/resolve?q=review',
        '/agent/resource/prompt-1?mode=full',
        '/agent/context?q=review',
        '/events',
      ];

      for (final String path in paths) {
        final response = await router.route(
          HttpRequestData(method: 'GET', uri: path),
        );
        expect(response.statusCode, isNot(404), reason: path);
        expect(
          response.json['status'] ?? response.json['service'],
          isNotNull,
          reason: path,
        );
      }
    },
  );

  test(
    'agent presence, sessions, memories, bundles, and handoffs coordinate state',
    () async {
      var sequence = 0;
      final InMemoryResourceStore resources = InMemoryResourceStore();
      final AgentRouter router = AgentRouter(
        resourceStore: resources,
        idGenerator: () => 'state-${++sequence}',
        now: () => DateTime.utc(2026, 7, 12),
      );

      final presence = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/agent/presence',
          body: '{"source":"Codex","status":"active","task":"Refactor"}',
        ),
      );
      final session = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/agent/session',
          body: '{"task":"Refactor","summary":"Flutter migration"}',
        ),
      );
      final memory = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/agent/memory',
          body:
              '{"title":"Testing rule","content":"Run tests first","kind":"rule","source":"Codex"}',
        ),
      );
      final bundle = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/agent/bundle',
          body: '{"title":"Refactor bundle","task":"Refactor"}',
        ),
      );
      final handoff = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/agent/handoff',
          body:
              '{"title":"Continue refactor","summary":"Finish QA","source":"Codex"}',
        ),
      );
      final sessions = await router.route(
        const HttpRequestData(method: 'GET', uri: '/agent/sessions'),
      );
      final memories = await router.route(
        const HttpRequestData(method: 'GET', uri: '/agent/memories'),
      );
      final handoffs = await router.route(
        const HttpRequestData(method: 'GET', uri: '/agent/handoffs'),
      );

      expect(presence.json['status'], 'active');
      expect(session.statusCode, 201);
      expect(memory.statusCode, 201);
      expect(bundle.statusCode, 201);
      expect(handoff.statusCode, 201);
      expect((sessions.json['sessions'] as List<Object?>), hasLength(1));
      expect((memories.json['memories'] as List<Object?>), hasLength(1));
      expect((handoffs.json['handoffs'] as List<Object?>), hasLength(1));
    },
  );

  test(
    'desktop control and clipboard collection routes invoke application seams',
    () async {
      bool? monitoring;
      int? shownWorkspace;
      final DateTime now = DateTime.utc(2026, 7, 12);
      final InMemoryResourceStore resources = InMemoryResourceStore();
      final AgentRouter router = AgentRouter(
        clipboardStore: InMemoryClipboardStore(<ClipboardRecord>[
          ClipboardRecord(
            id: 'clip-1',
            group: 'Commands',
            title: 'Flutter test',
            content: 'flutter test',
            tags: const <String>['clipboard', 'command'],
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
        resourceStore: resources,
        onClipboardMonitoring: (bool value) => monitoring = value,
        onShowUi: (int index) => shownWorkspace = index,
        idGenerator: () => 'collection-1',
        now: () => now,
      );

      final monitor = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/clipboard/monitor',
          body: '{"enabled":true}',
        ),
      );
      final shown = await router.route(
        const HttpRequestData(method: 'POST', uri: '/ui/show?tab=clipboard'),
      );
      final collected = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/clipboard/collect',
          body: '{"title":"Flutter commands","task":"flutter"}',
        ),
      );

      expect(monitor.json['status'], 'enabled');
      expect(monitoring, isTrue);
      expect(shown.json['tab'], 'clipboard');
      expect(shownWorkspace, 2);
      expect(collected.statusCode, 201);
      expect((await resources.load()).single.id, 'collection-1');
    },
  );
}

final class _StaticClipboardGateway implements ClipboardGateway {
  _StaticClipboardGateway(this.snapshot);

  final ClipboardSnapshot snapshot;
  String? writtenText;
  List<String>? writtenFiles;

  @override
  Future<ClipboardSnapshot> read() async => snapshot;

  @override
  Future<void> writeText(String text) async {
    writtenText = text;
  }

  @override
  Future<void> writeFiles(List<String> paths) async {
    writtenFiles = paths;
  }
}
