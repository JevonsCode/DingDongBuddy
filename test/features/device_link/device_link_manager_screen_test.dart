import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/device_link/domain/device_link_management.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:dingdong/features/device_link/ui/device_link_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a connecting device can be stopped from the manager window', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(820, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _FakeManagement controller = _FakeManagement();

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: const <Locale>[Locale('zh')],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          DingDongLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: DeviceLinkManagerScreen(controller: controller),
      ),
    );

    expect(find.byKey(const Key('device-link-manager-screen')), findsOneWidget);
    expect(find.text('连接设备'), findsNothing);
    expect(find.text('只在你信任的设备之间传递内容。'), findsNothing);
    expect(find.text('1 台设备'), findsNothing);
    expect(find.text('已连接设备'), findsOneWidget);
    expect(
      find.byKey(const Key('device-connection-mode-note')),
      findsOneWidget,
    );
    expect(find.textContaining('优先使用局域网 WebRTC 直连'), findsOneWidget);
    expect(find.textContaining('端到端加密中继'), findsOneWidget);
    expect(find.text('停止连接'), findsOneWidget);
    await tester.tap(find.text('停止连接'));
    await tester.pump();

    expect(controller.disconnectedDeviceId, 'phone-one');
  });
}

final class _FakeManagement extends ChangeNotifier
    implements DeviceLinkManagement {
  final LinkedDevice device = LinkedDevice(
    id: 'phone-one',
    name: '我的手机',
    kind: LinkedDeviceKind.phone,
    platform: 'ios-pwa',
    room: 'abcdefghijklmnopqrstuvwx',
    secret: 'BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc',
    autoSendClipboard: false,
    receiveAgentNotifications: false,
    vibrationEnabled: true,
    manuallyDisconnected: false,
    pairedAt: DateTime.utc(2026, 8, 8),
  );

  String? disconnectedDeviceId;

  @override
  bool get canPair => true;

  @override
  List<LinkedDevice> get devices => <LinkedDevice>[device];

  @override
  LocalDeviceIdentity get localDevice => const LocalDeviceIdentity(
    id: 'host-one',
    name: '测试电脑',
    platform: 'macos',
  );

  @override
  DeviceConnectionStatus get pairingStatus =>
      DeviceConnectionStatus.disconnected;

  @override
  PendingDevicePairing? get pendingPairing => null;

  @override
  Future<PendingDevicePairing?> beginPairing() async => null;

  @override
  Future<void> cancelPairing() async {}

  @override
  Future<void> deleteDevice(String deviceId) async {}

  @override
  Future<void> disconnect(String deviceId) async {
    disconnectedDeviceId = deviceId;
  }

  @override
  bool isConnected(String deviceId) => false;

  @override
  Future<void> reconnect(String deviceId) async {}

  @override
  Future<void> setAgentNotifications(String deviceId, bool value) async {}

  @override
  Future<void> setAutoSendClipboard(String deviceId, bool value) async {}

  @override
  DeviceConnectionStatus statusOf(String deviceId) =>
      DeviceConnectionStatus.connecting;
}
