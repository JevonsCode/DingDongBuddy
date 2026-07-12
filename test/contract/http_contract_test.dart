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
            '{"type":"prompt","title":" Bug triage ","content":"Find risky changes","tags":["review"],"source":"Codex","pinned":true}',
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
      final AgentRouter router = AgentRouter(
        resourceStore: InMemoryResourceStore(<Resource>[
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
        ]),
      );

      final response = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/agent/bridge',
          body:
              '{"task":"Ship Flutter release","source":"Codex","expand":"prompts"}',
        ),
      );
      final active = response.json['active'] as Map<String, Object?>;
      final prompts = active['prompts'] as List<Object?>;
      final skills = active['skills'] as List<Object?>;

      expect(
        (prompts.single as Map<String, Object?>)['content'],
        contains('checklist'),
      );
      expect(
        (skills.single as Map<String, Object?>),
        isNot(contains('content')),
      );
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
          body: '{"title":"Updated prompt","pinned":true}',
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
      expect((exported.json['items'] as List<Object?>), hasLength(1));
      expect(deleted.json['status'], 'deleted');
      expect(await store.load(), isEmpty);
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
      expect(seeded.json['inserted'], 0);
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
