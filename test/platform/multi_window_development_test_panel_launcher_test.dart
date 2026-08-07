import 'dart:convert';

import 'package:dingdong/platform/multi_window_development_test_panel_launcher.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an existing DEV test panel is shown and focused', () async {
    const MethodChannel windows = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    const MethodChannel channels = MethodChannel(
      'mixin.one/desktop_multi_window/channels',
    );
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final List<MethodCall> windowCalls = <MethodCall>[];
    final List<MethodCall> channelCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(windows, (MethodCall call) async {
      windowCalls.add(call);
      if (call.method == 'getAllWindows') {
        return <Object?>[
          <String, String>{
            'windowId': 'test-panel-window',
            'windowArgument': jsonEncode(<String, String>{
              'kind': developmentTestPanelWindowKind,
            }),
          },
        ];
      }
      return null;
    });
    messenger.setMockMethodCallHandler(channels, (MethodCall call) async {
      channelCalls.add(call);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(windows, null);
      messenger.setMockMethodCallHandler(channels, null);
    });

    await const MultiWindowDevelopmentTestPanelLauncher(
      parentWindowId: 'main-window',
    ).show();

    expect(
      windowCalls.map((MethodCall call) => call.method),
      contains('window_show'),
    );
    expect(channelCalls, hasLength(1));
    expect(channelCalls.single.arguments, <String, Object?>{
      'channel': 'mixin.one/window_controller/test-panel-window',
      'method': 'window_focus',
      'arguments': null,
    });
  });

  test('a new DEV test panel receives its parent window id', () async {
    const MethodChannel windows = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MethodCall? createCall;
    messenger.setMockMethodCallHandler(windows, (MethodCall call) async {
      if (call.method == 'getAllWindows') {
        return <Object?>[];
      }
      if (call.method == 'createWindow') {
        createCall = call;
        return 'test-panel-window';
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(windows, null);
    });

    await const MultiWindowDevelopmentTestPanelLauncher(
      parentWindowId: 'main-window',
    ).show();

    final Map<Object?, Object?> configuration =
        createCall!.arguments! as Map<Object?, Object?>;
    expect(configuration['hiddenAtLaunch'], isTrue);
    expect(jsonDecode(configuration['arguments']! as String), <String, Object?>{
      'kind': developmentTestPanelWindowKind,
      'parentWindowId': 'main-window',
    });
  });
}
