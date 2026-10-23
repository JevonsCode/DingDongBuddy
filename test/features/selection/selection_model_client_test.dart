import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/selection/data/selection_model_client.dart';
import 'package:dingdong/features/selection/domain/selection_plugin_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });
  tearDown(() async {
    await server.close(force: true);
  });

  SelectionPluginConfiguration config(
    SelectionModelProvider provider,
  ) => SelectionPluginConfiguration(
    enabled: true,
    provider: provider,
    endpoint:
        'http://127.0.0.1:${server.port}${provider == SelectionModelProvider.ollama ? '' : '/v1'}',
    model: 'test-model',
  );
  const messages = [
    {'role': 'system', 'content': 'instruction'},
    {'role': 'user', 'content': 'selected words'},
  ];

  for (final provider in SelectionModelProvider.values) {
    test(
      '${provider.name} uses correct wire protocol and parses text',
      () async {
        final handled = Completer<void>();
        server.listen((request) async {
          try {
            final body =
                jsonDecode(await utf8.decoder.bind(request).join()) as Map;
            expect(request.method, 'POST');
            expect(body['model'], 'test-model');
            expect(body['stream'], false);
            if (provider == SelectionModelProvider.ollama) {
              expect(request.uri.path, '/api/chat');
              expect(body['keep_alive'], 0);
              request.response.write(
                jsonEncode({
                  'message': {'content': 'answer'},
                }),
              );
            } else if (provider == SelectionModelProvider.anthropicCompatible) {
              expect(request.uri.path, '/v1/messages');
              expect(request.headers.value('x-api-key'), 'test-secret');
              expect(body['system'], 'instruction');
              expect((body['messages'] as List).length, 1);
              request.response.write(
                jsonEncode({
                  'content': [
                    {'type': 'text', 'text': 'answer'},
                  ],
                }),
              );
            } else {
              expect(request.uri.path, '/v1/chat/completions');
              expect(
                request.headers.value('authorization'),
                'Bearer test-secret',
              );
              request.response.write(
                jsonEncode({
                  'choices': [
                    {
                      'message': {'content': 'answer'},
                    },
                  ],
                }),
              );
            }
            await request.response.close();
            handled.complete();
          } catch (e, stack) {
            handled.completeError(e, stack);
          }
        });
        expect(
          await HttpSelectionModelClient().complete(
            configuration: config(provider),
            token: 'test-secret',
            messages: messages,
            cancellation: SelectionCancellation(),
          ),
          'answer',
        );
        await handled.future;
      },
    );
  }

  test('HTTP failures discard server bodies and credentials', () async {
    server.listen((r) async {
      r.response.statusCode = 401;
      r.response.write('secret test-secret');
      await r.response.close();
    });
    await expectLater(
      HttpSelectionModelClient().complete(
        configuration: config(SelectionModelProvider.openAICompatible),
        token: 'test-secret',
        messages: messages,
        cancellation: SelectionCancellation(),
      ),
      throwsA(
        isA<SelectionModelFailure>().having(
          (e) => e.code,
          'code',
          'authentication',
        ),
      ),
    );
  });

  test('redirects are rejected without forwarding credentials', () async {
    var requests = 0;
    server.listen((r) async {
      requests++;
      r.response.statusCode = 307;
      r.response.headers.set('location', '/leak');
      await r.response.close();
    });
    await expectLater(
      HttpSelectionModelClient().complete(
        configuration: config(SelectionModelProvider.openAICompatible),
        token: 'test-secret',
        messages: messages,
        cancellation: SelectionCancellation(),
      ),
      throwsA(
        isA<SelectionModelFailure>().having((e) => e.code, 'code', 'server'),
      ),
    );
    expect(requests, 1);
  });

  test('response bound rejects oversized response', () async {
    server.listen((r) async {
      r.response.write('x' * 1000);
      await r.response.close();
    });
    await expectLater(
      HttpSelectionModelClient(maxResponseBytes: 50).complete(
        configuration: config(SelectionModelProvider.ollama),
        token: null,
        messages: messages,
        cancellation: SelectionCancellation(),
      ),
      throwsA(
        isA<SelectionModelFailure>().having(
          (e) => e.code,
          'code',
          'response_too_large',
        ),
      ),
    );
  });

  test('whole request timeout bounds a silent server', () async {
    server.listen((r) {});
    await expectLater(
      HttpSelectionModelClient(
        timeout: const Duration(milliseconds: 80),
      ).complete(
        configuration: config(SelectionModelProvider.ollama),
        token: null,
        messages: messages,
        cancellation: SelectionCancellation(),
      ),
      throwsA(
        isA<SelectionModelFailure>().having((e) => e.code, 'code', 'timeout'),
      ),
    );
  });

  test('cancel aborts active connection', () async {
    final entered = Completer<void>();
    server.listen((r) {
      entered.complete();
    });
    final cancellation = SelectionCancellation();
    final future = HttpSelectionModelClient().complete(
      configuration: config(SelectionModelProvider.ollama),
      token: null,
      messages: messages,
      cancellation: cancellation,
    );
    final expectation = expectLater(
      future,
      throwsA(
        isA<SelectionModelFailure>().having((e) => e.code, 'code', 'cancelled'),
      ),
    );
    await entered.future;
    cancellation.cancel();
    await expectation;
  });

  test('required token checked before network access', () async {
    await expectLater(
      HttpSelectionModelClient().complete(
        configuration: config(SelectionModelProvider.gemini),
        token: null,
        messages: messages,
        cancellation: SelectionCancellation(),
      ),
      throwsA(
        isA<SelectionModelFailure>().having(
          (e) => e.code,
          'code',
          'token_required',
        ),
      ),
    );
  });
}
