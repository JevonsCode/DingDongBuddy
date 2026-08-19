import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/device_link/domain/device_link_management.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:dingdong/features/device_link/ui/device_link_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a connecting device can be stopped from the manager window', (
    WidgetTester tester,
  ) async {
    final _FakeManagement controller = _FakeManagement();

    await _pumpManager(
      tester,
      controller: controller,
      locale: const Locale('zh'),
    );

    expect(find.byKey(const Key('device-link-manager-screen')), findsOneWidget);
    expect(find.text('连接设备'), findsOneWidget);
    expect(find.text('只在你信任的设备之间传递内容。'), findsNothing);
    expect(find.text('1 台设备'), findsNothing);
    expect(find.text('已连接设备'), findsOneWidget);
    expect(
      find.byKey(const Key('device-connection-mode-note')),
      findsOneWidget,
    );
    expect(find.textContaining('优先使用 WebRTC 直连'), findsOneWidget);
    expect(find.textContaining('端到端加密中继'), findsOneWidget);
    expect(find.text('停止连接'), findsOneWidget);
    await tester.tap(find.text('停止连接'));
    await tester.pump();

    expect(controller.disconnectedDeviceId, 'phone-one');
  });

  testWidgets('pairing stays first and actionable at the minimum window size', (
    WidgetTester tester,
  ) async {
    final _FakeManagement controller = _FakeManagement(includeDevice: false);

    await _pumpManager(
      tester,
      controller: controller,
      size: const Size(620, 580),
      locale: const Locale('zh'),
    );

    final Finder pairingPanel = find.byKey(const Key('device-pairing-panel'));
    final Finder localDevice = find.byKey(const Key('device-local-device'));
    final Finder beginPairing = find.byKey(const Key('device-begin-pairing'));
    expect(pairingPanel, findsOneWidget);
    expect(localDevice, findsOneWidget);
    expect(
      tester.getTopLeft(pairingPanel).dy,
      lessThan(tester.getTopLeft(localDevice).dy),
    );
    expect(tester.getBottomRight(beginPairing).dy, lessThanOrEqualTo(580));
    expect(tester.takeException(), isNull);

    await tester.tap(beginPairing);
    await tester.pump();
    expect(controller.beganPairing, isTrue);
  });

  testWidgets('active pairing QR is visible and has one security explanation', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _FakeManagement controller = _FakeManagement(
      includeDevice: false,
      pendingPairing: _pendingPairing(),
    );

    await _pumpManager(
      tester,
      controller: controller,
      size: const Size(620, 580),
    );

    final Finder qr = find.byKey(const Key('device-pairing-qr'));
    expect(qr, findsOneWidget);
    expect(tester.getBottomRight(qr).dy, lessThanOrEqualTo(580));
    expect(tester.getSemantics(qr).label, contains('Pairing QR code for 测试电脑'));
    expect(
      find.byKey(const Key('device-connection-mode-note')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('device-pairing-connection-mode-note')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('device setting rows support keyboard activation', (
    WidgetTester tester,
  ) async {
    final _FakeManagement controller = _FakeManagement();
    await _pumpManager(tester, controller: controller);

    final Finder setting = find.byKey(const Key('device-auto-send-phone-one'));
    final Finder focusable = find
        .descendant(of: setting, matching: find.byType(FocusableActionDetector))
        .first;
    final FocusableActionDetector detector = tester.widget(focusable);
    detector.focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(controller.autoSendDeviceId, 'phone-one');
    expect(controller.autoSendValue, isTrue);
  });

  testWidgets('error status uses the active dark theme color scheme', (
    WidgetTester tester,
  ) async {
    const Color seed = Color(0xFF6B7A4D);
    final ThemeData theme = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seed,
        brightness: Brightness.dark,
      ),
    );
    final _FakeManagement controller = _FakeManagement(
      connectionStatus: DeviceConnectionStatus.error,
    );

    await _pumpManager(tester, controller: controller, theme: theme);

    final Container badge = tester.widget<Container>(
      find.byKey(const Key('device-status-phone-one')),
    );
    final BoxDecoration decoration = badge.decoration! as BoxDecoration;
    expect(decoration.color, theme.colorScheme.errorContainer);
    expect(find.text('Connection error'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpManager(
  WidgetTester tester, {
  required _FakeManagement controller,
  Size size = const Size(820, 720),
  Locale locale = const Locale('en'),
  ThemeData? theme,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: theme,
      locale: locale,
      supportedLocales: DingDongLocalizations.supportedLocales,
      localizationsDelegates: DingDongLocalizations.localizationsDelegates,
      home: DeviceLinkManagerScreen(controller: controller),
    ),
  );
  await tester.pump();
}

PendingDevicePairing _pendingPairing() {
  return PendingDevicePairing(
    payload: DevicePairingPayload(
      room: 'abcdefghijklmnopqrstuvwx',
      secret: 'BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc',
      hostId: 'host-one',
      hostName: 'Test computer',
      relayUrl: Uri.parse('wss://relay.example.test'),
    ),
    url: Uri.parse('https://device.example.test/pair#payload'),
    createdAt: DateTime.utc(2026, 8, 8),
  );
}

final class _FakeManagement extends ChangeNotifier
    implements DeviceLinkManagement {
  _FakeManagement({
    this.includeDevice = true,
    this.pendingPairing,
    this.connectionStatus = DeviceConnectionStatus.connecting,
  });

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

  final bool includeDevice;
  final DeviceConnectionStatus connectionStatus;

  @override
  final PendingDevicePairing? pendingPairing;

  String? disconnectedDeviceId;
  String? autoSendDeviceId;
  bool? autoSendValue;
  bool beganPairing = false;

  @override
  bool get canPair => true;

  @override
  List<LinkedDevice> get devices =>
      includeDevice ? <LinkedDevice>[device] : const <LinkedDevice>[];

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
  Future<PendingDevicePairing?> beginPairing() async {
    beganPairing = true;
    return pendingPairing;
  }

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
  Future<void> setAutoSendClipboard(String deviceId, bool value) async {
    autoSendDeviceId = deviceId;
    autoSendValue = value;
  }

  @override
  DeviceConnectionStatus statusOf(String deviceId) => connectionStatus;
}
