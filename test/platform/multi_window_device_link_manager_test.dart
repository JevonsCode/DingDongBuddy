import 'dart:convert';

import 'package:dingdong/platform/multi_window_device_link_manager.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an existing connection manager is shown and focused', () async {
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
            'windowId': 'device-link-window',
            'windowArgument': jsonEncode(<String, String>{
              'kind': deviceLinkManagerWindowKind,
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

    await const MultiWindowDeviceLinkManagerLauncher(
      parentWindowId: 'main-window',
    ).show();

    expect(
      windowCalls.map((MethodCall call) => call.method),
      contains('window_show'),
    );
    expect(channelCalls.single.arguments, <String, Object?>{
      'channel': 'mixin.one/window_controller/device-link-window',
      'method': 'window_focus',
      'arguments': null,
    });
  });

  test('a new connection manager receives the host window id', () async {
    const MethodChannel windows = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MethodCall? createCall;
    messenger.setMockMethodCallHandler(windows, (MethodCall call) async {
      if (call.method == 'getAllWindows') return <Object?>[];
      if (call.method == 'createWindow') {
        createCall = call;
        return 'device-link-window';
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(windows, null));

    await const MultiWindowDeviceLinkManagerLauncher(
      parentWindowId: 'main-window',
    ).show();

    final Map<Object?, Object?> configuration =
        createCall!.arguments! as Map<Object?, Object?>;
    expect(configuration['hiddenAtLaunch'], isTrue);
    expect(jsonDecode(configuration['arguments']! as String), <String, Object?>{
      'kind': deviceLinkManagerWindowKind,
      'parentWindowId': 'main-window',
    });
  });

  test('host state changes refresh only the connection manager', () async {
    const MethodChannel windows = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    const MethodChannel channels = MethodChannel(
      'mixin.one/desktop_multi_window/channels',
    );
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final List<MethodCall> channelCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(windows, (MethodCall call) async {
      if (call.method == 'getAllWindows') {
        return <Object?>[
          <String, String>{
            'windowId': 'resource-window',
            'windowArgument': jsonEncode(<String, String>{
              'kind': 'resource-manager',
            }),
          },
          <String, String>{
            'windowId': 'device-link-window',
            'windowArgument': jsonEncode(<String, String>{
              'kind': deviceLinkManagerWindowKind,
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

    await const MultiWindowDeviceLinkManagerLauncher(
      parentWindowId: 'main-window',
    ).refresh();

    expect(channelCalls, hasLength(1));
    expect(channelCalls.single.arguments, <String, Object?>{
      'channel': 'mixin.one/window_controller/device-link-window',
      'method': deviceLinkManagerChangedMethod,
      'arguments': null,
    });
  });
}
