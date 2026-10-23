import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/screenshot/domain/screenshot_plugin.dart';
import 'package:dingdong/platform/native_screenshot_plugin_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('dingdong/screenshot_plugin');
  const windows = MethodChannel('mixin.one/desktop_multi_window');
  const bridge = MethodChannel('mixin.one/desktop_multi_window/channels');
  const codec = StandardMethodCodec();

  Future<Object?> incoming(String channel, String method, Object? args) {
    final result = Completer<Object?>();
    ServicesBinding.instance.channelBuffers.push(
      channel,
      codec.encodeMethodCall(MethodCall(method, args)),
      (data) {
        try {
          result.complete(codec.decodeEnvelope(data!));
        } catch (error, stack) {
          result.completeError(error, stack);
        }
      },
    );
    return result.future;
  }

  Future<Object?> sessionCall(String method, int session) =>
      incoming(bridge.name, 'methodCall', {
        'channel': 'dingdong/screenshot-editor',
        'method': method,
        'arguments': session,
      });

  test(
    'handoff contains only session metadata; disable clears pixels and invalidates stale finish',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final nativeCalls = <String>[];
      final windowCalls = <MethodCall>[];
      String? encodedArguments;
      messenger.setMockMethodCallHandler(native, (call) async {
        nativeCalls.add(call.method);
        return {'supported': true, 'running': true, 'capturing': false};
      });
      messenger.setMockMethodCallHandler(windows, (call) async {
        if (call.method == 'getAllWindows') return [];
        if (call.method == 'createWindow') {
          encodedArguments = (call.arguments as Map)['arguments'] as String;
          return 'editor-1';
        }
        return null;
      });
      messenger.setMockMethodCallHandler(bridge, (call) async {
        windowCalls.add(call);
        return null;
      });
      final gateway = NativeScreenshotPluginGateway(labels: () => {});
      await gateway.apply(const ScreenshotConfiguration(enabled: true));
      final png = Uint8List.fromList([137, 80, 78, 71, 1, 2, 3]);
      await incoming(native.name, 'edit', png);
      final args = jsonDecode(encodedArguments!) as Map;
      expect(args.keys, unorderedEquals(['kind', 'session']));
      expect(args['kind'], 'screenshot-editor');
      final session = args['session'] as int;
      expect(await sessionCall('read', session), png);
      await gateway.apply(const ScreenshotConfiguration(enabled: false));
      expect(await sessionCall('read', session), isNull);
      expect(
        windowCalls.any(
          (call) =>
              call.method == 'invokeMethod' &&
              (call.arguments as Map)['method'] == 'dismiss',
        ),
        isTrue,
      );
      final finishCount = nativeCalls
          .where((method) => method == 'finish')
          .length;
      await sessionCall('finish', session);
      expect(
        nativeCalls.where((method) => method == 'finish').length,
        finishCount,
      );
      await NativeScreenshotPluginGateway.editorChannel.setMethodCallHandler(
        null,
      );
      native.setMethodCallHandler(null);
      messenger.setMockMethodCallHandler(native, null);
      messenger.setMockMethodCallHandler(windows, null);
      messenger.setMockMethodCallHandler(bridge, null);
    },
    skip: !Platform.isWindows,
  );
}
