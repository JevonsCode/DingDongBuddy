import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/device_link/ui/device_link_manager_app.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/platform/multi_window_device_link_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows connection manager close hides without exiting', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const String windowId = 'device-manager-close-test';
    const MethodChannel registry = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    const MethodChannel channels = MethodChannel(
      'mixin.one/desktop_multi_window/channels',
    );
    const MethodChannel windowManager = MethodChannel('window_manager');
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    final List<MethodCall> windowCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(registry, (MethodCall call) async {
      if (call.method == 'getWindowDefinition') {
        return <String, String>{'windowId': windowId, 'windowArgument': ''};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(channels, (_) async => null);
    messenger.setMockMethodCallHandler(windowManager, (MethodCall call) async {
      windowCalls.add(call);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(registry, null);
      messenger.setMockMethodCallHandler(channels, null);
      messenger.setMockMethodCallHandler(windowManager, null);
    });

    await tester.pumpWidget(
      DeviceLinkManagerApp(
        controller: RemoteDeviceLinkManagement(
          parentController: WindowController.fromWindowId('main-window'),
        ),
        settings: const AppSettings(),
        windowController: WindowController.fromWindowId(windowId),
      ),
    );
    await tester.pump();

    expect(
      windowCalls.any(
        (MethodCall call) =>
            call.method == 'setPreventClose' &&
            (call.arguments as Map<Object?, Object?>)['isPreventClose'] == true,
      ),
      isTrue,
    );
    windowCalls.clear();
    await _sendWindowManagerEvent(messenger, 'close');
    await tester.pump();
    expect(windowCalls.map((MethodCall call) => call.method), contains('hide'));
    expect(
      windowCalls.map((MethodCall call) => call.method),
      isNot(contains('destroy')),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });
}

Future<void> _sendWindowManagerEvent(
  TestDefaultBinaryMessenger messenger,
  String eventName,
) async {
  final Completer<void> handled = Completer<void>();
  await messenger.handlePlatformMessage(
    'window_manager',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('onEvent', <String, Object?>{'eventName': eventName}),
    ),
    (_) => handled.complete(),
  );
  await handled.future;
}
