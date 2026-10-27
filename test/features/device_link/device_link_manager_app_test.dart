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

  test(
    'child window reads addresses and forwards IP correction to its owner',
    () async {
      const channels = MethodChannel('mixin.one/desktop_multi_window/channels');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      var address = '192.168.31.153';
      final calls = <Map>[];
      messenger.setMockMethodCallHandler(channels, (call) async {
        final args = call.arguments as Map;
        calls.add(args);
        if (args['method'] == 'device_link_lan_address_set') {
          final values = args['arguments'] as Map;
          expect(values['id'], 'fixture-peer');
          if (values['address'] == '8.8.8.8') {
            return {'error': 'invalid_lan_address'};
          }
          address = values['address'] as String;
        }
        if (args['method'] == deviceLinkManagerSnapshotMethod) {
          return {
            'localDevice': {
              'id': 'fixture-local',
              'name': 'Fixture host',
              'platform': 'macos',
            },
            'devices': [],
            'statuses': {},
            'transports': {},
            'localComputerAddresses': ['192.168.31.180'],
            'computerAddresses': {'fixture-peer': address},
          };
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channels, null));
      final controller = RemoteDeviceLinkManagement(
        parentController: WindowController.fromWindowId('fixture-main'),
      );
      addTearDown(controller.dispose);
      await controller.reload();
      expect(controller.localComputerAddresses, ['192.168.31.180']);
      expect(controller.computerAddressOf('fixture-peer'), address);
      await controller.setComputerAddress('fixture-peer', '192.168.31.222');
      expect(controller.computerAddressOf('fixture-peer'), '192.168.31.222');
      await expectLater(
        controller.setComputerAddress('fixture-peer', '8.8.8.8'),
        throwsFormatException,
      );
      expect(controller.computerAddressOf('fixture-peer'), '192.168.31.222');
      expect(
        calls.where((call) => call['method'] == 'device_link_lan_address_set'),
        hasLength(2),
      );
    },
  );

  test(
    'child window reloads local IP and discovery error after a failed refresh',
    () async {
      const channels = MethodChannel('mixin.one/desktop_multi_window/channels');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channels, (call) async {
        final method = (call.arguments as Map)['method'];
        if (method == 'device_link_lan_refresh') {
          throw PlatformException(code: 'discovery_failed');
        }
        if (method == deviceLinkManagerSnapshotMethod) {
          return {
            'localDevice': {
              'id': 'fixture-local',
              'name': 'Fixture host',
              'platform': 'macos',
            },
            'localComputerAddresses': ['192.168.31.180'],
            'computerDiscoveryError': 'address_in_use',
          };
        }
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channels, null));
      final controller = RemoteDeviceLinkManagement(
        parentController: WindowController.fromWindowId('fixture-main'),
      );
      addTearDown(controller.dispose);

      await expectLater(
        controller.refreshComputers(),
        throwsA(isA<WindowChannelException>()),
      );

      expect(controller.localComputerAddresses, ['192.168.31.180']);
      expect(controller.computerDiscoveryError, 'address_in_use');
    },
  );

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
    final List<String> ownerMethods = [];
    messenger.setMockMethodCallHandler(registry, (MethodCall call) async {
      if (call.method == 'getWindowDefinition') {
        return <String, String>{'windowId': windowId, 'windowArgument': ''};
      }
      return null;
    });
    messenger.setMockMethodCallHandler(channels, (call) async {
      final method = (call.arguments as Map)['method'];
      if (method is String) ownerMethods.add(method);
      return null;
    });
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
    expect(
      ownerMethods,
      contains('device_link_lan_refresh'),
      reason:
          'Opening the manager must load local IPs even when every saved computer is disconnected.',
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
