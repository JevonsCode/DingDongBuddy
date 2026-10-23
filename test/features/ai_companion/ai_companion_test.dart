import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/ai_companion/data/ai_companion_client.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_store.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_privacy.dart';
import 'package:dingdong/features/ai_companion/ui/ai_companion_controller.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('provider endpoint change drops the previous credential', () async {
    final _Transport transport = _Transport();
    final _Secrets secrets = _Secrets();
    final controller = _controller(transport: transport, secrets: secrets);
    addTearDown(controller.dispose);
    await controller.saveSettings(_configured, apiKey: 'dummy');
    await controller.saveSettings(
      controller.settings.copyWith(
        providerEndpoint: 'https://other.example/v1',
      ),
    );
    expect(controller.hasStoredApiKey, false);
    expect(secrets.value, isNull);
    await controller.testConnection();
    expect(controller.error, AiCompanionError.missingApiKey);
    expect(transport.requests, isEmpty);
  });

  test('provider URL validation permits explicit HTTP and HTTPS services', () {
    for (final String endpoint in <String>[
      'http://127.0.0.1:11434',
      'http://localhost:11434/v1',
      'http://[::1]:11434/v1',
      'https://provider.example/v1',
      'http://provider.example/v1',
      'http://192.168.1.2/v1',
    ]) {
      expect(
        AiCompanionClient.validateProvider(
          _configured.copyWith(providerEndpoint: endpoint),
        ).path,
        '/v1/chat/completions',
      );
    }
    for (final String endpoint in <String>[
      'https://user:password@provider.example/v1',
      'https://provider.example/v1?api_key=secret',
      'https://provider.example/v1#fragment',
      'file:///tmp/server',
      '',
    ]) {
      expect(
        () => AiCompanionClient.validateProvider(
          _configured.copyWith(providerEndpoint: endpoint),
        ),
        throwsA(
          isA<AiCompanionException>().having(
            (error) => error.code,
            'code',
            AiCompanionError.invalidProvider,
          ),
        ),
      );
    }
  });

  test(
    'real HTTP redirects never forward credentials or expose error bodies',
    () async {
      final HttpServer destination = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final HttpServer source = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => destination.close(force: true));
      addTearDown(() => source.close(force: true));
      int redirected = 0;
      destination.listen((request) {
        redirected++;
        request.response.close();
      });
      source.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          'location',
          'http://127.0.0.1:${destination.port}/stolen',
        );
        request.response.write('password=raw-provider-error');
        await request.response.close();
      });
      final client = AiCompanionClient();
      addTearDown(client.dispose);
      await expectLater(
        client.testConnection(
          _configured.copyWith(
            providerEndpoint: 'http://127.0.0.1:${source.port}/v1',
          ),
          'dummy',
        ),
        _fails(AiCompanionError.providerUnavailable),
      );
      expect(redirected, 0);
    },
  );

  test('real HTTP oversized response is bounded', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await request.drain<void>();
      request.response.write(List.filled(70000, 'x').join());
      await request.response.close();
    });
    final client = AiCompanionClient();
    addTearDown(client.dispose);
    await expectLater(
      client.testConnection(
        _configured.copyWith(
          providerEndpoint: 'http://127.0.0.1:${server.port}/v1',
        ),
        null,
      ),
      _fails(AiCompanionError.invalidResponse),
    );
  });

  test(
    'real HTTP timeout closes the request and next call can retry',
    () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      int count = 0;
      server.listen((request) async {
        await request.drain<void>();
        count++;
        if (count == 1) return; // Deliberately never finishes this response.
        request.response.write(_response('OK'));
        await request.response.close();
      });
      final client = AiCompanionClient(
        timeout: const Duration(milliseconds: 80),
      );
      addTearDown(client.dispose);
      final settings = _configured.copyWith(
        providerEndpoint: 'http://127.0.0.1:${server.port}/v1',
      );
      await expectLater(
        client.testConnection(settings, null),
        _fails(AiCompanionError.timeout),
      );
      await client.testConnection(settings, null);
      expect(count, 2);
    },
  );

  test(
    'failure diagnostics contain no raw provider body or exception message',
    () async {
      final transport = _Transport()
        ..status = 500
        ..reply = 'password=raw-provider-error';
      final client = AiCompanionClient(transport: transport);
      addTearDown(client.dispose);
      try {
        await client.testConnection(_configured, 'dummy');
        fail('expected failure');
      } on AiCompanionException catch (error) {
        expect(error.code, AiCompanionError.providerUnavailable);
        expect(error.toString(), 'AiCompanionException(providerUnavailable)');
      }
      expect(
        const AiCompanionPrivacy().isSafeText(
          'Review resource usage and enable task matching.',
        ),
        true,
      );
    },
  );
  test(
    'real HTTP lifecycle survives save, connection test, clear and retry',
    () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      final List<String> paths = <String>[];
      final List<String?> auth = <String?>[];
      final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
      server.listen((request) async {
        paths.add(request.uri.path);
        auth.add(request.headers.value('authorization'));
        payloads.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, Object?>,
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(_response('OK'));
        await request.response.close();
      });
      final controller = AiCompanionController(
        store: AiCompanionPreferencesStore(
          MemoryPreferencesBackend(),
          secretStore: _Secrets(),
        ),
      );
      addTearDown(controller.dispose);
      await controller.saveSettings(
        AiCompanionSettings(
          providerEndpoint: 'http://127.0.0.1:${server.port}/v1',
          model: 'local-model',
        ),
        apiKey: 'local-dummy',
      );
      await controller.testConnection();
      expect(controller.error, isNull);
      expect(controller.connectionVerified, true);
      await controller.testConnection();
      expect(paths, everyElement('/v1/chat/completions'));
      expect(auth, everyElement('Bearer local-dummy'));
      expect(payloads, hasLength(2));
      expect((payloads.last['messages'] as List).length, 1);
      expect(payloads.last.containsKey('tools'), false);
    },
  );

  test('connection test rejects sensitive provider output', () async {
    final transport = _Transport();
    final controller = _controller(transport: transport);
    addTearDown(controller.dispose);
    await controller.saveSettings(_configured, apiKey: 'private-key');
    for (final reply in ['password=leaked', 'private-key']) {
      transport.reply = reply;
      await controller.testConnection();
      expect(controller.error, AiCompanionError.sensitiveOutput);
      expect(controller.connectionVerified, false);
    }
  });
  test('changing settings discards a late connection response', () async {
    final pending = Completer<AiCompanionHttpResponse>();
    final transport = _Transport()..pending = pending;
    final controller = _controller(transport: transport);
    addTearDown(controller.dispose);
    await controller.saveSettings(_configured, apiKey: 'dummy');
    final connecting = controller.testConnection();
    while (transport.requests.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    await controller.saveSettings(const AiCompanionSettings());
    pending.complete(AiCompanionHttpResponse(200, _response('OK')));
    await connecting;
    expect(controller.connectionVerified, false);
    expect(controller.error, isNull);
    expect(controller.isLoading, false);
  });
}

const AiCompanionSettings _configured = AiCompanionSettings(
  providerEndpoint: 'https://provider.example/v1',
  model: 'test-model',
);

Matcher _fails(AiCompanionError code) => throwsA(
  isA<AiCompanionException>().having((error) => error.code, 'code', code),
);

AiCompanionController _controller({
  _Transport? transport,
  MemoryPreferencesBackend? backend,
  _Secrets? secrets,
}) => AiCompanionController(
  store: AiCompanionPreferencesStore(
    backend ?? MemoryPreferencesBackend(),
    secretStore: secrets ?? _Secrets(),
  ),
  client: AiCompanionClient(transport: transport ?? _Transport()),
);

final class _Secrets implements AiCompanionSecretStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

final class _Request {
  const _Request(this.uri, this.headers, this.body);
  final Uri uri;
  final Map<String, String> headers;
  final String body;
}

final class _Transport implements AiCompanionTransport {
  final List<_Request> requests = <_Request>[];
  String reply = 'Review rarely used resource scopes.';
  int status = 200;
  Completer<AiCompanionHttpResponse>? pending;
  @override
  Future<AiCompanionHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    requests.add(_Request(uri, headers, body));
    return pending == null
        ? AiCompanionHttpResponse(status, _response(reply))
        : pending!.future;
  }

  @override
  void close() {}
}

String _response(String content) => jsonEncode(<String, Object>{
  'choices': <Object>[
    <String, Object>{
      'message': <String, String>{'content': content},
    },
  ],
});
