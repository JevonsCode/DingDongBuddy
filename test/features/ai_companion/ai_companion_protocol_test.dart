import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/ai_companion/data/ai_companion_client.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_models.dart';
import 'package:flutter_test/flutter_test.dart';

AiCompanionSettings settings({
  String protocol = 'auto',
  String endpoint = 'http://127.0.0.1:3456',
  String model = 'test-model',
}) => AiCompanionSettings.fromJson({
  'protocol': protocol,
  'providerEndpoint': endpoint,
  'model': model,
});

const openAI = '{"choices":[{"message":{"content":"OK"}}]}';
const anthropic =
    '{"content":[{"type":"thinking","thinking":"private reasoning"},{"type":"text","text":"OK"},{"type":"text","text":" again"}]}';

typedef Reply =
    AiCompanionHttpResponse Function(
      Uri,
      Map<String, String>,
      Map<String, dynamic>,
    );

class Transport implements AiCompanionTransport {
  Transport(this.reply);
  final Reply reply;
  final paths = <String>[];
  @override
  Future<AiCompanionHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    paths.add(uri.path);
    return reply(uri, headers, jsonDecode(body) as Map<String, dynamic>);
  }

  @override
  void close() {}
}

void main() {
  test(
    'Anthropic supplies a stable random session ID for Claude-compatible gateways',
    () async {
      final ids = <String?>[];
      final transport = Transport((uri, headers, body) {
        ids.add(headers['X-Claude-Code-Session-Id']);
        return const AiCompanionHttpResponse(200, anthropic);
      });
      final client = AiCompanionClient(transport: transport);
      await client.testConnection(settings(protocol: 'anthropic'), null);
      await client.testConnection(settings(protocol: 'anthropic'), null);
      await AiCompanionClient(
        transport: transport,
      ).testConnection(settings(protocol: 'anthropic'), null);
      expect(
        ids.first,
        matches(
          RegExp(
            r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
          ),
        ),
      );
      expect(ids[0], ids[1]);
      expect(ids[0], isNot(ids[2]));
    },
  );

  test(
    'HTTP transport sends Content-Length for gateways rejecting chunked JSON',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final received = Completer<int>();
      server.listen((request) async {
        received.complete(request.contentLength);
        await request.drain<void>();
        request.response.write(openAI);
        await request.response.close();
      });
      final client = AiCompanionClient();
      addTearDown(client.dispose);
      await client.testConnection(
        settings(endpoint: 'http://127.0.0.1:${server.port}'),
        null,
      );
      expect(await received.future, greaterThan(0));
    },
  );

  test(
    'disposing during failed auto probe cannot start a second request',
    () async {
      final transport = PendingTransport();
      final client = AiCompanionClient(transport: transport);
      final result = client.testConnection(settings(), null);
      final assertion = expectLater(
        result,
        throwsA(isA<AiCompanionException>()),
      );
      client.dispose();
      transport.pending.complete(const AiCompanionHttpResponse(404, ''));
      await assertion;
      expect(transport.calls, 1);
    },
  );
  test('timed out auto probe cannot start a late fallback', () async {
    final transport = PendingTransport();
    final client = AiCompanionClient(
      transport: transport,
      timeout: const Duration(milliseconds: 5),
    );
    await expectLater(
      client.testConnection(settings(), null),
      throwsA(isA<AiCompanionException>()),
    );
    transport.pending.complete(const AiCompanionHttpResponse(404, ''));
    await Future<void>.delayed(Duration.zero);
    expect(transport.calls, 1);
  });
  test('protocol persists and old settings default to auto', () {
    expect(AiCompanionSettings.fromJson({}).toJson()['protocol'], 'auto');
    expect(
      settings(
        protocol: 'anthropic',
      ).copyWith(model: 'another').toJson()['protocol'],
      'anthropic',
    );
  });
  test('accepts explicit HTTP services and provider model IDs', () {
    for (final host in ['gateway.example.com', '192.168.1.2', '127.0.0.1']) {
      expect(
        AiCompanionClient.validateProvider(
          settings(endpoint: 'http://$host/v1', model: 'claude-opus-5-5[1m]'),
        ).host,
        host,
      );
    }
  });
  test(
    'Anthropic normalizes root, prefixed base and complete Messages URLs',
    () {
      for (final entry in {
        'http://localhost:3456': '/v1/messages',
        'http://localhost:3456/custom/messages': '/custom/messages',
        'http://localhost:3456/v1/': '/v1/messages',
        'http://localhost:3456/coding-plan': '/coding-plan/v1/messages',
        'http://localhost:3456/coding-plan/v1': '/coding-plan/v1/messages',
        'http://localhost:3456/coding-plan/v1/messages/':
            '/coding-plan/v1/messages',
      }.entries) {
        expect(
          AiCompanionClient.validateProvider(
            settings(protocol: 'anthropic', endpoint: entry.key),
          ).path,
          entry.value,
        );
      }
    },
  );
  test(
    'Anthropic resource selection separates system and parses only text blocks',
    () async {
      final transport = Transport((uri, headers, body) {
        expect(uri.path, '/v1/messages');
        expect(headers['anthropic-version'], '2023-06-01');
        expect(headers['x-api-key'], 'dummy');
        expect(headers['Authorization'], 'Bearer dummy');
        expect(body['system'], contains('Select optional resources'));
        expect(body['messages'], hasLength(1));
        expect(
          ((body['messages'] as List).single as Map<String, dynamic>)['role'],
          'user',
        );
        expect(body['max_tokens'], 600);
        expect(body['stream'], false);
        return AiCompanionHttpResponse(
          200,
          jsonEncode({
            'content': [
              {'type': 'thinking', 'thinking': 'private'},
              {
                'type': 'text',
                'text': jsonEncode({
                  'confident': true,
                  'selected': ['r0'],
                }),
              },
            ],
          }),
        );
      });
      final client = AiCompanionClient(transport: transport);
      expect(
        await client.selectResources(
          settings(protocol: 'anthropic').copyWith(autoResourceSelection: true),
          'dummy',
          {'task': 'Review code', 'resources': []},
        ),
        <String>{'r0'},
      );
    },
  );
  test(
    'auto retries missing OpenAI route using Anthropic on the same origin',
    () async {
      final transport = Transport((uri, headers, body) {
        expect(uri.host, '127.0.0.1');
        expect(body['model'], 'test-model');
        return uri.path == '/v1/chat/completions'
            ? const AiCompanionHttpResponse(404, '')
            : const AiCompanionHttpResponse(200, anthropic);
      });
      await AiCompanionClient(
        transport: transport,
      ).testConnection(settings(), null);
      expect(transport.paths, ['/v1/chat/completions', '/v1/messages']);
    },
  );
  test(
    'auto recognizes a complete Messages URL without OpenAI probe',
    () async {
      final transport = Transport(
        (uri, headers, body) => const AiCompanionHttpResponse(200, anthropic),
      );
      await AiCompanionClient(transport: transport).testConnection(
        settings(endpoint: 'http://localhost:3456/v1/messages'),
        null,
      );
      expect(transport.paths, ['/v1/messages']);
    },
  );
  test(
    'OpenAI remains compatible with custom base and complete endpoint',
    () async {
      for (final endpoint in [
        'https://host.example/api/v1',
        'https://host.example/api/v1/chat/completions/',
      ]) {
        final transport = Transport((uri, headers, body) {
          expect(headers.containsKey('anthropic-version'), false);
          expect(headers['Authorization'], 'Bearer dummy');
          return const AiCompanionHttpResponse(200, openAI);
        });
        await AiCompanionClient(transport: transport).testConnection(
          settings(protocol: 'openAI', endpoint: endpoint),
          'dummy',
        );
        expect(transport.paths, ['/api/v1/chat/completions']);
      }
    },
  );
  test(
    'auto never retries authentication, throttle, server or malformed success errors',
    () async {
      for (final code in [400, 401, 403, 429, 500, 200]) {
        final transport = Transport(
          (uri, headers, body) => AiCompanionHttpResponse(code, 'invalid'),
        );
        await expectLater(
          AiCompanionClient(
            transport: transport,
          ).testConnection(settings(), null),
          throwsA(isA<AiCompanionException>()),
        );
        expect(transport.paths, hasLength(1));
      }
    },
  );
  test(
    'explicit protocol does not retry and exposes safe actionable error categories',
    () async {
      for (final entry in {
        401: 'authenticationFailed',
        403: 'authenticationFailed',
        404: 'endpointNotFound',
        405: 'endpointNotFound',
        429: 'rateLimited',
        500: 'providerUnavailable',
      }.entries) {
        final transport = Transport(
          (uri, headers, body) =>
              AiCompanionHttpResponse(entry.key, 'secret response'),
        );
        await expectLater(
          AiCompanionClient(
            transport: transport,
          ).testConnection(settings(protocol: 'openAI'), null),
          throwsA(
            isA<AiCompanionException>()
                .having((e) => e.code.name, 'error', entry.value)
                .having((e) => e.toString(), 'safe', isNot(contains('secret'))),
          ),
        );
        expect(transport.paths, hasLength(1));
      }
    },
  );
  test(
    'Anthropic rejects missing text, oversized text and sensitive output',
    () async {
      for (final body in [
        '{"content":[]}',
        '{"content":[{"type":"text","text":42}]}',
        jsonEncode({
          'content': [
            {'type': 'text', 'text': 'x' * 4001},
          ],
        }),
        '{"content":[{"type":"text","text":"Authorization: Bearer private-token-123456789"}]}',
      ]) {
        final transport = Transport(
          (uri, headers, payload) => AiCompanionHttpResponse(200, body),
        );
        await expectLater(
          AiCompanionClient(
            transport: transport,
          ).testConnection(settings(protocol: 'anthropic'), null),
          throwsA(isA<AiCompanionException>()),
        );
      }
    },
  );
}

class PendingTransport implements AiCompanionTransport {
  final pending = Completer<AiCompanionHttpResponse>();
  int calls = 0;
  @override
  Future<AiCompanionHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) {
    calls++;
    return pending.future;
  }

  @override
  void close() {}
}
