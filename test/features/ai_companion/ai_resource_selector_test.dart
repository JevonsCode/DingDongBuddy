import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/http_request_data.dart';
import 'package:dingdong/features/agent_api/domain/bridge_resource_selection.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_client.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_store.dart';
import 'package:dingdong/features/ai_companion/data/ai_resource_selector.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_models.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_usage.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/token_usage/data/local_token_usage_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class Store implements AiCompanionStore {
  AiCompanionSettings settings = const AiCompanionSettings(
    providerEndpoint: 'http://127.0.0.1:3456',
    model: 'small-model',
  );
  String? key;
  @override
  Future<AiCompanionSettings> loadSettings() async => settings;
  @override
  Future<void> saveSettings(AiCompanionSettings value) async {
    settings = value;
  }

  @override
  Future<String?> readApiKey() async => key;
  @override
  Future<void> writeApiKey(String? value) async {
    key = value;
  }

  @override
  Future<AiCompanionReport?> loadReport() async => null;
  @override
  Future<void> saveReport(AiCompanionReport? value) async {}
}

class Transport implements AiCompanionTransport {
  int calls = 0;
  String reply = '{"confident":true,"selected":["r0"]}';
  int status = 200;
  Map<String, Object?>? last;
  Completer<void>? pending;
  @override
  Future<AiCompanionHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    calls++;
    last = jsonDecode(body) as Map<String, Object?>;
    await pending?.future;
    return AiCompanionHttpResponse(
      status,
      jsonEncode({
        'choices': [
          {
            'message': {'content': reply},
          },
        ],
        'usage': {
          'prompt_tokens': 10,
          'completion_tokens': 3,
          'total_tokens': 13,
        },
      }),
    );
  }

  @override
  void close() {}
}

BridgeResourceSelectionRequest request({
  String task = 'Review database code',
  String context = '',
  String conversation = 'a',
  String workspace = '/project',
  String source = 'Codex',
  String version = 'v1',
}) => BridgeResourceSelectionRequest(
  task: task,
  taskContext: context,
  conversationId: conversation,
  workspacePath: workspace,
  repositoryUrl: '',
  source: source,
  candidates: [
    BridgeResourceCandidate(
      id: 'skill-id',
      type: 'skill',
      title: 'Review',
      description: 'Review database code',
      version: version,
    ),
    BridgeResourceCandidate(
      id: 'mcp-id',
      type: 'mcp',
      title: 'Database',
      description: 'Database read tool',
      version: 'v1',
    ),
  ],
);
void main() {
  test(
    'real Bridge toggle, hash and usage ledger work together without network when off',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'routing-ledger-',
      );
      final ledger = LocalTokenUsageRepository(
        databasePath: '${directory.path}/usage.db',
        homeDirectory: directory,
      );
      addTearDown(() async {
        await ledger.close();
        await directory.delete(recursive: true);
      });
      final store = Store();
      final transport = Transport();
      final selector = AiResourceSelector(
        store: store,
        client: AiCompanionClient(transport: transport),
        onUsage: ledger.recordInternalUsage,
      );
      Resource skill(String id) => Resource(
        id: id,
        type: ResourceType.skill,
        title: id,
        content: '---\nname: $id\ndescription: Review code\n---\nprivate body',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
      final router = AgentRouter(
        resourceStore: InMemoryResourceStore([skill('first'), skill('second')]),
        selectBridgeResources: selector.select,
      );
      Future<Map<String, Object?>> bridge({String? hash}) async =>
          (await router.route(
            HttpRequestData(
              method: 'POST',
              uri: '/agent/bridge',
              body: jsonEncode({
                'task': 'Review changes',
                'source': 'Codex',
                'conversationId': 'one',
                'acceptDelta': true,
                'knownHash': ?hash,
              }),
            ),
          )).json;
      final off = await bridge();
      expect(((off['active'] as Map)['skills'] as List).length, 2);
      expect(transport.calls, 0);
      store.settings = store.settings.copyWith(autoResourceSelection: true);
      final on = await bridge();
      expect(((on['active'] as Map)['skills'] as List).length, 1);
      expect(transport.calls, 1);
      expect((await bridge(hash: on['hash'] as String))['unchanged'], true);
      expect(transport.calls, 1);
      expect((await ledger.readSnapshot()).days, isEmpty);
      expect((await ledger.readInternalSnapshot()).totals.totalTokens, 13);
      expect(
        (await ledger.readSnapshot(includeInternal: true)).totals.totalTokens,
        13,
      );
      store.settings = store.settings.copyWith(autoResourceSelection: false);
      final revoked = await bridge(hash: on['hash'] as String);
      expect(revoked['mode'], 'delta');
      expect(transport.calls, 1);
      expect(
        (((revoked['delta'] as Map)['upsert'] as Map)['skills'] as List)
            .cast<Map<String, Object?>>()
            .single['id'],
        'second',
      );
    },
  );
  test(
    'parallel identical routing requests share one inference and cache eviction is bounded',
    () async {
      final store = Store();
      store.settings = store.settings.copyWith(autoResourceSelection: true);
      final transport = Transport()..pending = Completer<void>();
      final selector = AiResourceSelector(
        store: store,
        client: AiCompanionClient(transport: transport),
        capacity: 1,
      );
      final first = selector.select(request());
      final second = selector.select(request());
      while (transport.calls == 0) {
        await Future<void>.delayed(Duration.zero);
      }
      transport.pending!.complete();
      await Future.wait([first, second]);
      expect(transport.calls, 1);
      await selector.select(request(task: 'Changed'));
      await selector.select(request());
      expect(transport.calls, 3);
    },
  );

  test(
    'toggle defaults off and serializes independently from cloud analysis',
    () {
      expect(AiCompanionSettings.fromJson({}).autoResourceSelection, false);
      final settings = const AiCompanionSettings().copyWith(
        autoResourceSelection: true,
      );
      expect(
        AiCompanionSettings.fromJson(settings.toJson()).autoResourceSelection,
        true,
      );
      expect(settings.cloudAnalysis, false);
    },
  );
  test(
    'off makes no provider requests; on sends bounded explicit inputs only and records its purpose',
    () async {
      final store = Store();
      final transport = Transport();
      final usage = <AiCompanionUsageRecord>[];
      final selector = AiResourceSelector(
        store: store,
        client: AiCompanionClient(transport: transport),
        onUsage: (record) async {
          usage.add(record);
        },
      );
      expect(await selector.select(request()), isNull);
      expect(transport.calls, 0);
      store.settings = store.settings.copyWith(autoResourceSelection: true);
      expect(await selector.select(request(context: 'Check migrations')), {
        'skill-id',
      });
      expect(transport.calls, 1);
      expect(usage.single.purpose, AiCompanionUsagePurpose.resourceSelection);
      expect(usage.single.totals.totalTokens, 13);
      final sent = jsonEncode(transport.last);
      expect(sent, contains('Check migrations'));
      expect(sent, isNot(contains('/project')));
      expect(sent, isNot(contains('skill-id')));
      expect(sent, isNot(contains('mcp-id')));
    },
  );
  test(
    'cache isolates task/context/scope/catalog/config and suppresses duplicate requests',
    () async {
      final store = Store();
      store.settings = store.settings.copyWith(autoResourceSelection: true);
      final transport = Transport();
      final selector = AiResourceSelector(
        store: store,
        client: AiCompanionClient(transport: transport),
        capacity: 2,
      );
      await selector.select(request());
      await selector.select(request());
      expect(transport.calls, 1);
      for (final input in [
        request(task: 'Other'),
        request(context: 'Other'),
        request(conversation: 'b'),
        request(workspace: '/other'),
        request(source: 'Claude Code'),
        request(version: 'v2'),
      ]) {
        await selector.select(input);
      }
      expect(transport.calls, 7);
      store.key = 'new-key';
      await selector.select(request(version: 'v2'));
      expect(transport.calls, 8);
      store.settings = store.settings.copyWith(autoResourceSelection: false);
      expect(await selector.select(request()), isNull);
      store.settings = store.settings.copyWith(autoResourceSelection: true);
      await selector.select(request());
      expect(transport.calls, 9);
    },
  );
  test(
    'malformed, uncertain, unknown IDs, timeout and unsafe input fall back and cache failures',
    () async {
      final store = Store();
      store.settings = store.settings.copyWith(autoResourceSelection: true);
      final transport = Transport();
      final selector = AiResourceSelector(
        store: store,
        client: AiCompanionClient(
          transport: transport,
          timeout: const Duration(milliseconds: 5),
        ),
      );
      for (final reply in [
        'bad',
        '{"confident":false,"selected":[]}',
        '{"confident":true,"selected":["unknown"]}',
      ]) {
        transport.reply = reply;
        expect(await selector.select(request(task: reply)), isNull);
        final before = transport.calls;
        await selector.select(request(task: reply));
        expect(transport.calls, before);
      }
      transport.pending = Completer<void>();
      expect(await selector.select(request(task: 'Slow')), isNull);
      transport.pending!.complete();
      final before = transport.calls;
      expect(await selector.select(request(task: 'password=private')), isNull);
      expect(
        await selector.select(request(task: '{"apiKey":"short-secret"}')),
        isNull,
      );
      expect(await selector.select(request(context: 'x' * 4001)), isNull);
      expect(transport.calls, before);
    },
  );
  test('revoking during pending inference discards selection', () async {
    final store = Store();
    store.settings = store.settings.copyWith(autoResourceSelection: true);
    final transport = Transport()..pending = Completer<void>();
    final selector = AiResourceSelector(
      store: store,
      client: AiCompanionClient(transport: transport),
    );
    final result = selector.select(request());
    while (transport.calls == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    store.settings = store.settings.copyWith(autoResourceSelection: false);
    transport.pending!.complete();
    expect(await result, isNull);
  });
}
