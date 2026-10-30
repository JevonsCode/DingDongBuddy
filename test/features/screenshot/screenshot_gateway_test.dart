import 'package:dingdong/features/screenshot/domain/screenshot_plugin.dart';
import 'package:dingdong/platform/native_screenshot_plugin_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const native = MethodChannel('dingdong/screenshot_plugin');
  const windows = MethodChannel('mixin.one/desktop_multi_window');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(native, null);
    messenger.setMockMethodCallHandler(windows, null);
  });

  for (final platform in [TargetPlatform.macOS, TargetPlatform.windows]) {
    test(
      '$platform: configure and capture delegate only to the system host',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        final calls = <MethodCall>[];
        var windowCalls = 0;
        messenger.setMockMethodCallHandler(windows, (call) async {
          windowCalls++;
          return null;
        });
        messenger.setMockMethodCallHandler(native, (call) async {
          calls.add(call);
          return call.method == 'capture'
              ? null
              : {'supported': true, 'running': true, 'capturing': false};
        });
        final gateway = NativeScreenshotPluginGateway(
          labels: () => {'captureError': 'Could not open system capture.'},
        );
        final status = await gateway.apply(
          const ScreenshotConfiguration(enabled: true),
        );
        expect(status.running, isTrue);
        expect(
          (calls.single.arguments as Map).keys,
          unorderedEquals(['enabled', 'shortcut', 'labels']),
        );
        await gateway.capture();
        await gateway.status();
        await gateway.apply(const ScreenshotConfiguration());
        expect(calls.map((call) => call.method), [
          'configure',
          'capture',
          'status',
          'configure',
        ]);
        expect((calls.last.arguments as Map)['enabled'], isFalse);
        expect(windowCalls, 0);
      },
    );
  }

  test('system launch failure is reported as a screenshot error', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    messenger.setMockMethodCallHandler(
      native,
      (_) async => throw PlatformException(code: 'capture_failed'),
    );
    final gateway = NativeScreenshotPluginGateway(labels: () => {});
    await expectLater(
      gateway.capture(),
      throwsA(
        isA<ScreenshotPluginException>().having(
          (error) => error.code,
          'code',
          'capture_failed',
        ),
      ),
    );
  });

  test('unsupported platforms never invoke the native host', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    messenger.setMockMethodCallHandler(
      native,
      (_) async => fail('Unexpected native call'),
    );
    final gateway = NativeScreenshotPluginGateway(labels: () => {});
    expect((await gateway.status()).supported, isFalse);
    await expectLater(
      gateway.capture(),
      throwsA(isA<ScreenshotPluginException>()),
    );
  });
}
