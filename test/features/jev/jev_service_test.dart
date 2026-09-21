import 'dart:async';
import 'dart:convert';

import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/conversation_footer_protocol.dart';
import 'package:dingdong/features/agent_api/data/http_request_data.dart';
import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';
import 'package:dingdong/features/agent_api/data/mcp_server.dart';
import 'package:dingdong/features/jev/data/jev_routes.dart';
import 'package:dingdong/features/jev/data/jev_service.dart';
import 'package:dingdong/features/jev/data/jev_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

class FakeVault implements JevVault {
  String? value;
  bool failDelete = false;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> delete() async {
    if (failDelete) throw StateError('secret-vault-failure');
    value = null;
  }
}

const input = <String, Object?>{
  'state': 'Three red balls',
  'instructions': 'Any red balls?',
  'source': 'Codex',
  'conversationId': 'one',
};
Map<String, Object?> reply({Object? answer, Object? usage}) => {
  'model': JevService.model,
  'answers': {
    'decision': answer ?? {'type': 'noul', 'noul': 0.99},
  },
  'usage': usage ?? {'input_tokens': 288, 'output_tokens': 20},
};

void main() {
  late Database db;
  late JevStore store;
  late FakeVault vault;
  late JevService service;
  int calls = 0;
  setUp(() {
    db = sqlite3.openInMemory();
    store = JevStore(db);
    vault = FakeVault();
    calls = 0;
    service = JevService(
      store,
      vault,
      transport: (key, body) async {
        calls++;
        expect(key, 'test-key-only-not-a-real-secret');
        expect(body.keys, unorderedEquals(['model', 'state', 'questions']));
        return reply();
      },
    );
  });
  tearDown(() => db.close());
  Future<void> ready() async {
    await service.install();
    await service.saveKey('test-key-only-not-a-real-secret');
    await service.setEnabled(true);
  }

  test('install and key save are free; explicit opt-in required', () async {
    expect((await service.status())['installed'], false);
    await expectLater(
      service.decide('noul', input),
      throwsA(isA<JevException>()),
    );
    await service.install();
    await service.install();
    await service.saveKey('test-key-only-not-a-real-secret');
    expect(store.enabled, false);
    await expectLater(
      service.decide('noul', input),
      throwsA(isA<JevException>()),
    );
    expect(calls, 0);
    expect(store.usage()['requests'], 0);
    await service.setEnabled(true);
    await service.decide('noul', input);
    expect(calls, 1);
  });
  test(
    'real response fields drive separate durable ledger; no prompts or key',
    () async {
      await ready();
      await service.decide('noul', input);
      await service.decide('noul', {...input, 'conversationId': 'two'});
      expect(store.usage()['total_tokens'], 616);
      expect(
        store.usage(source: 'Codex', conversation: 'one')['total_tokens'],
        308,
      );
      expect(JevStore(db).usage()['requests'], 2);
      expect(store.usage()['estimated_usd'], closeTo(0.000024192, 1e-12));
      expect(
        jsonEncode(db.select('SELECT * FROM jev_usage')),
        isNot(contains('Three red balls')),
      );
      expect(jsonEncode(await service.status()), isNot(contains(vault.value!)));
    },
  );
  test('timeout/error never retries and preserves unknown usage', () async {
    await ready();
    service = JevService(
      store,
      vault,
      transport: (_, _) async {
        calls++;
        throw StateError('SECRET');
      },
    );
    await expectLater(
      service.decide('noul', input),
      throwsA(
        isA<JevException>().having((e) => e.code, 'code', 'request_failed'),
      ),
    );
    expect(calls, 1);
    expect(store.usage()['unknown_usage_requests'], 1);
    expect(store.usage()['successes'], 0);
  });
  test('invalid judgments still account for known billed tokens', () async {
    await ready();
    service = JevService(
      store,
      vault,
      transport: (_, _) async => reply(answer: {'type': 'noul', 'noul': 9}),
    );
    await expectLater(
      service.decide('noul', input),
      throwsA(isA<JevException>()),
    );
    expect(store.usage()['input_tokens'], 288);
    expect(store.usage()['successes'], 0);
    expect(store.usage()['unknown_usage_requests'], 0);
  });
  test(
    'missing usage remains unknown; validation blocks network before ledger',
    () async {
      await ready();
      await expectLater(
        service.decide('choice', input),
        throwsA(isA<JevException>()),
      );
      await expectLater(
        service.decide('noul', {...input, 'state': '界' * 20000}),
        throwsA(isA<JevException>()),
      );
      expect(calls, 0);
      expect(store.usage()['requests'], 0);
      service = JevService(
        store,
        vault,
        transport: (_, _) async => reply(usage: {}),
      );
      await expectLater(
        service.decide('noul', input),
        throwsA(isA<JevException>()),
      );
      expect(store.usage()['unknown_usage_requests'], 1);
    },
  );
  test('choice and score reject distributions with foreign options', () async {
    await ready();
    service = JevService(
      store,
      vault,
      transport: (_, _) async => reply(
        answer: {
          'type': 'choice',
          'confidence': 0.8,
          'choice': 'x',
          'probabilities': {'x': 0.9, 'y': 0.1},
        },
      ),
    );
    await expectLater(
      service.decide('choice', {
        ...input,
        'criteria': {'a': null, 'b': null},
      }),
      throwsA(isA<JevException>()),
    );
    service = JevService(
      store,
      vault,
      transport: (_, _) async => reply(
        answer: {
          'type': 'score',
          'confidence': 0.8,
          'score': 0.1,
          'probabilities': {'0': 0.9, '1': 0.1},
        },
      ),
    );
    expect(
      (await service.decide('score', {
        ...input,
        'criteria': ['low', 'high'],
      }))['status'],
      'ok',
    );
  });
  test(
    'disable, replace key and uninstall deny future requests; history retained',
    () async {
      await ready();
      await service.decide('noul', input);
      await service.saveKey('replacement-test-key-not-secret');
      expect(store.enabled, false);
      await service.setEnabled(true);
      await service.uninstall();
      expect(vault.value, null);
      expect(store.installed, false);
      await expectLater(
        service.decide('noul', input),
        throwsA(isA<JevException>()),
      );
      await service.install();
      expect(store.enabled, false);
      expect(store.usage()['requests'], 1);
    },
  );
  test(
    'keychain deletion failure leaves calls disabled and retryable',
    () async {
      await ready();
      vault.failDelete = true;
      await expectLater(service.uninstall(), throwsStateError);
      expect(store.enabled, false);
      expect(store.installed, true);
      vault.failDelete = false;
      await service.uninstall();
      expect(store.installed, false);
    },
  );
  test('disable while key is being read prevents a late request', () async {
    await ready();
    final gate = Completer<String?>();
    final lateVault = _WaitingVault(gate);
    final other = JevService(
      store,
      lateVault,
      transport: (_, _) async {
        calls++;
        return reply();
      },
    );
    final pending = other.decide('noul', input);
    store.setEnabled(false);
    gate.complete(vault.value);
    await expectLater(pending, throwsA(isA<JevException>()));
    expect(calls, 0);
  });
  test(
    'MCP discovery follows installation and routes preserve session usage',
    () async {
      final router = AgentRouter(jevRoutes: JevRoutes(service));
      final executor = LoopbackMcpToolExecutor(
        _Transport(router),
        sourceResolver: () => 'Codex',
        conversationIdResolver: () => 'one',
      );
      final server = McpServer(executor: executor);
      Future<List> tools() async =>
          ((jsonDecode(
                        (await server.handleLine(
                          '{"id":1,"method":"tools/list"}',
                        ))!,
                      )
                      as Map)['result']
                  as Map)['tools']
              as List;
      expect(
        (await tools()).where(
          (e) => ((e as Map)['name'] as String).contains('_jev_'),
        ),
        isEmpty,
      );
      await ready();
      expect(
        (await tools())
            .where((e) => ((e as Map)['name'] as String).contains('_jev_'))
            .length,
        4,
      );
      await executor.execute('dingdong_jev_check', {
        'state': 'red balls',
        'instructions': 'any red?',
      });
      expect(store.usage(source: 'Codex', conversation: 'one')['requests'], 1);
      final blocked = await router.route(
        const HttpRequestData(
          method: 'POST',
          uri: '/plugins/jev/install',
          body: '{}',
        ),
      );
      expect(blocked.statusCode, 404);
      await service.uninstall();
      expect(
        (await tools()).where(
          (e) => ((e as Map)['name'] as String).contains('_jev_'),
        ),
        isEmpty,
      );
    },
  );
  test(
    'footer keeps Jev out of host token total and reports unknown requests',
    () {
      final footer = buildDingDongConversationFooter(
        items: [
          {'type': 'mcp', 'title': 'Jev'},
        ],
        jevUsage: {'total_tokens': 308, 'unknown_usage_requests': 1},
      );
      expect(footer['line'], contains('Jev 308 Token (+1 unknown)'));
      expect((footer['capsule'] as Map)['tokenUsage'], isNull);
    },
  );
}

class _WaitingVault extends FakeVault {
  _WaitingVault(this.gate);
  final Completer<String?> gate;
  @override
  Future<String?> read() => gate.future;
}

class _Transport implements McpHttpTransport {
  _Transport(this.router);
  final AgentRouter router;
  @override
  Future<Map<String, Object?>> request({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Map<String, Object?>? body,
  }) async {
    final r = await router.route(
      HttpRequestData(method: method, uri: path, body: jsonEncode(body)),
    );
    if (r.statusCode >= 400) throw StateError('${r.json}');
    return r.json;
  }
}
