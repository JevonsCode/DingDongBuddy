import 'dart:async';
import 'package:dingdong/features/selection/data/selection_model_client.dart';
import 'package:dingdong/features/selection/domain/selection_plugin_configuration.dart';
import 'package:dingdong/platform/windows_selection_plugin_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _Tokens implements SelectionTokenStore {
  String? value;
  bool unavailable = false;
  @override
  Future<String?> read() async {
    if (unavailable) throw StateError('storage unavailable');
    return value;
  }

  @override
  Future<void> write(String token) async {
    value = token;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

class _Overlay implements SelectionOverlayHost {
  final states = <Map<String, Object?>>[];
  int hides = 0;
  @override
  Future<void> present(Map<String, Object?> state) async {
    states.add(state);
  }

  @override
  Future<void> hide() async {
    hides++;
  }
}

class _Model implements SelectionModelClient {
  final replies = <Completer<String>>[];
  final cancellations = <SelectionCancellation>[];
  final histories = <List<Map<String, String>>>[];
  @override
  Future<String> complete({
    required SelectionPluginConfiguration configuration,
    required String? token,
    required List<Map<String, String>> messages,
    required SelectionCancellation cancellation,
  }) {
    histories.add(messages);
    cancellations.add(cancellation);
    final reply = Completer<String>();
    replies.add(reply);
    return reply.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('test/selection');
  late _Model model;
  late _Overlay overlay;
  late _Tokens tokens;
  late WindowsSelectionPluginGateway gateway;
  late List<MethodCall> nativeCalls;
  Future<void> flush() async {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> select(String text) => gateway.handleNativeCall(
    MethodCall('selected', {
      'text': text,
      'x': 10.0,
      'y': 20.0,
      'width': 50.0,
      'height': 18.0,
    }),
  );
  Future<Object?> action(String name, {String? prompt, int? id}) =>
      gateway.handleWindowCall(
        MethodCall('selection_action', {
          'action': name,
          'selectionId': id ?? gateway.state['selectionId'],
          'prompt': prompt,
        }),
      );
  setUp(() {
    model = _Model();
    overlay = _Overlay();
    tokens = _Tokens();
    nativeCalls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          nativeCalls.add(call);
          return {
            'running':
                call.method == 'status' ||
                (call.arguments as Map)['enabled'] == true,
          };
        });
    gateway = WindowsSelectionPluginGateway(
      parentWindowId: 'main',
      channel: channel,
      modelClient: model,
      tokenStore: tokens,
      overlayHost: overlay,
    );
  });
  tearDown(() async {
    await gateway.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'disabled by default and selection alone never sends to a model',
    () async {
      await select('ignored');
      expect(overlay.states, isEmpty);
      await gateway.apply(const SelectionPluginConfiguration(enabled: true));
      await select('private selection');
      expect(gateway.state['text'], 'private selection');
      expect(model.replies, isEmpty);
      expect(nativeCalls.first.arguments, {'enabled': true});
    },
  );

  test(
    'explicit action sends selection and follow-up includes conversation',
    () async {
      await gateway.apply(const SelectionPluginConfiguration(enabled: true));
      await select('selected words');
      await action('translate');
      await flush();
      expect(
        model.histories.single.last['content'],
        contains('selected words'),
      );
      model.replies.single.complete('translation');
      await flush();
      expect(gateway.state['result'], 'translation');
      await action('follow_up', prompt: 'make shorter');
      await flush();
      expect(model.histories.last.map((e) => e['role']), [
        'system',
        'user',
        'assistant',
        'user',
      ]);
      model.replies.last.complete('short');
      await flush();
      expect(gateway.state['result'], 'short');
    },
  );

  test(
    'late completion from cancelled selection cannot overwrite new selection',
    () async {
      await gateway.apply(const SelectionPluginConfiguration(enabled: true));
      await select('old');
      final oldId = gateway.state['selectionId'] as int;
      await action('explain');
      await flush();
      await select('new');
      expect(model.cancellations.first.cancelled, true);
      model.replies.first.complete('stale response');
      await flush();
      expect(gateway.state['text'], 'new');
      expect(gateway.state['result'], '');
      await action('translate', id: oldId);
      await flush();
      expect(model.replies.length, 1);
    },
  );

  test(
    'cancel retry and disable clear sensitive state and abort in-flight request',
    () async {
      await gateway.apply(const SelectionPluginConfiguration(enabled: true));
      await select('private');
      await action('polish');
      await flush();
      await action('cancel');
      expect(model.cancellations.first.cancelled, true);
      await action('retry');
      await flush();
      expect(model.replies.length, 2);
      await gateway.apply(const SelectionPluginConfiguration(enabled: false));
      expect(model.cancellations.last.cancelled, true);
      expect(gateway.state['text'], '');
      expect(gateway.state['active'], false);
      model.replies.first.complete('old');
      model.replies.last.complete('late');
      await flush();
      expect(gateway.state['result'], '');
    },
  );

  test(
    'token goes only to secure store and model errors expose only safe codes',
    () async {
      await gateway.saveToken('secret');
      expect(tokens.value, 'secret');
      await gateway.apply(const SelectionPluginConfiguration(enabled: true));
      await select('words');
      await action('translate');
      await flush();
      model.replies.single.completeError(Exception('secret endpoint response'));
      await flush();
      expect(gateway.state['error'], 'network');
      expect(gateway.state.toString(), isNot(contains('secret')));
      expect(nativeCalls.toString(), isNot(contains('secret')));
      await gateway.clearToken();
      expect(tokens.value, null);
    },
  );

  test(
    'local model remains usable when credential storage is unavailable',
    () async {
      tokens.unavailable = true;
      final status = await gateway.apply(
        const SelectionPluginConfiguration(enabled: true),
      );
      expect(status.running, true);
      expect(status.tokenConfigured, false);
      await select('words');
      await action('translate');
      await flush();
      expect(model.replies.length, 1);
      model.replies.single.complete('local answer');
      await flush();
      expect(gateway.state['result'], 'local answer');
    },
  );

  test(
    'failed native enable never begins accepting selection events',
    () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if ((call.arguments as Map)['enabled'] == true) {
              throw PlatformException(code: 'unavailable');
            }
            return {'running': false};
          });
      await expectLater(
        gateway.apply(const SelectionPluginConfiguration(enabled: true)),
        throwsA(isA<PlatformException>()),
      );
      await select('ignored');
      expect(gateway.state['text'], '');
    },
  );
}
