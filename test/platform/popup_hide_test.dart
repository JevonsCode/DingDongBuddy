import 'dart:async';
import 'package:dingdong/platform/plugin_desktop_shell_gateway.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('main popup hides even while auxiliary cleanup is pending', () async {
    final cleanup = Completer<void>();
    final calls = <String>[];
    const channel = MethodChannel('window_manager');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    final gateway = PluginDesktopShellGateway(
      onHideAuxiliaryWindows: () => cleanup.future,
    );
    final hiding = gateway.hide();
    await Future<void>.delayed(Duration.zero);
    expect(calls, contains('hide'));
    cleanup.complete();
    await hiding;
  });
}
