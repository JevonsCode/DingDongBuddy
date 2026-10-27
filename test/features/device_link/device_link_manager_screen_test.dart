import 'dart:io';
import 'dart:ui' as ui;

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/features/device_link/domain/device_link_management.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:dingdong/features/device_link/domain/file_transfer.dart';
import 'package:dingdong/features/device_link/domain/lan_computer_management.dart';
import 'package:dingdong/features/device_link/ui/device_link_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'LAN address input keeps this computer IP visible and distinct from peer input',
    (tester) async {
      final controller = _FakeManagement(includeDevice: false)
        ..localAddresses = [];
      await _pumpManager(
        tester,
        controller: controller,
        size: const Size(620, 700),
        locale: const Locale('zh'),
      );
      await tester.tap(find.byKey(const Key('device-join-computer')));
      await tester.pumpAndSettle();
      final local = find.byKey(const Key('device-computer-local-addresses'));
      final input = find.byKey(const Key('device-computer-find-address'));
      expect(local, findsOneWidget);
      expect(find.text('本机 IP · 暂未获取，点击刷新重试'), findsOneWidget);
      controller.localAddresses = ['192.168.31.180', '10.0.0.20'];
      controller.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.text('本机 IP · 192.168.31.180 · 10.0.0.20'), findsWidgets);
      final field = tester.widget<TextField>(input);
      expect(field.controller!.text, isEmpty);
      expect(field.decoration!.labelText, '另一台电脑的局域网 IP');
      expect(
        tester.getRect(local).bottom,
        lessThanOrEqualTo(tester.getRect(input).top),
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final route in [
    DeviceLinkActiveTransport.localNetwork,
    DeviceLinkActiveTransport.serviceRelay,
  ]) {
    testWidgets(
      'LAN permission failures show actionable help without blaming the pairing code',
      (tester) async {
        final controller = _FakeManagement(includeDevice: false)
          ..discoveryError = 'access_denied';
        await _pumpManager(
          tester,
          controller: controller,
          locale: const Locale('en'),
        );
        await tester.tap(find.byKey(const Key('device-join-computer')));
        await tester.pumpAndSettle();
        expect(
          find.textContaining('Local network access was denied.'),
          findsOneWidget,
        );
        final input = tester.widget<TextField>(
          find.byKey(const Key('device-computer-pairing-input')),
        );
        expect(input.decoration?.errorText, isNull);
      },
    );
    testWidgets('phone shows the active $route route', (tester) async {
      final controller = _FakeManagement(
        connectionStatus: DeviceConnectionStatus.connected,
        activeTransport: route,
      );
      await _pumpManager(
        tester,
        controller: controller,
        locale: const Locale('zh'),
      );
      expect(
        find.text(
          route == DeviceLinkActiveTransport.localNetwork ? '直连' : '加密服务',
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('device-address-edit-phone-one')),
        findsNothing,
      );
    });
  }

  testWidgets('offline computers show saved IP and allow correction', (
    tester,
  ) async {
    final controller = _FakeManagement(
      deviceKind: LinkedDeviceKind.computer,
      connectionStatus: DeviceConnectionStatus.disconnected,
    );
    await _pumpManager(
      tester,
      controller: controller,
      size: const Size(620, 640),
      locale: const Locale('zh'),
    );
    expect(find.textContaining('192.168.31.180'), findsOneWidget);
    expect(find.textContaining('192.168.31.153'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('device-settings-toggle-computer-one')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('device-address-edit-computer-one')));
    await tester.pumpAndSettle();
    final field = find.byKey(const Key('device-address-input'));
    await tester.enterText(field, 'wrong-ip');
    await tester.tap(find.byKey(const Key('device-address-save')));
    await tester.pumpAndSettle();
    expect(controller.editedAddress, isNull);
    expect(find.text('请输入与这台电脑同一局域网的 IPv4 地址。'), findsOneWidget);
    await tester.enterText(field, '192.168.31.222');
    await tester.tap(find.byKey(const Key('device-address-save')));
    await tester.pumpAndSettle();
    expect(controller.editedAddress, '192.168.31.222');
    expect(find.byKey(const Key('device-address-dialog')), findsNothing);
    expect(find.textContaining('192.168.31.222'), findsWidgets);
  });

  testWidgets(
    'manager and history remain readable in light and dark compact windows',
    (tester) async {
      final preview = Platform.environment['DEVICE_MANAGER_PREVIEW'] == '1';
      if (preview) {
        await tester.runAsync(() async {
          for (final name in ['.AppleSystemUIFont', 'Roboto', 'Ahem']) {
            await (FontLoader(name)..addFont(
                  Future.value(
                    ByteData.sublistView(
                      File(
                        '/System/Library/Fonts/STHeiti Light.ttc',
                      ).readAsBytesSync(),
                    ),
                  ),
                ))
                .load();
          }
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
        });
      }
      final controller = _FakeManagement(
        deviceKind: LinkedDeviceKind.computer,
        connectionStatus: DeviceConnectionStatus.connected,
        additionalDevices: [
          LinkedDevice(
            id: 'offline-phone',
            name: 'Xiaomi17u',
            kind: LinkedDeviceKind.phone,
            platform: 'web',
            room: 'offline-room',
            secret: 'test',
            autoSendClipboard: false,
            receiveAgentNotifications: true,
            vibrationEnabled: true,
            manuallyDisconnected: true,
            pairedAt: DateTime.utc(2026, 10, 22),
          ),
        ],
        statuses: {'offline-phone': DeviceConnectionStatus.disconnected},
        fileTransfers: [
          FileTransfer(
            id: 'active',
            deviceId: 'computer-one',
            name: '项目素材（演示）.zip',
            size: 10000000,
            bytes: 4200000,
            sending: true,
            status: 'transferring',
          ),
          FileTransfer(
            id: 'done',
            deviceId: 'offline-phone',
            name: '会议资料（演示）.pdf',
            size: 1000000,
            bytes: 1000000,
            sending: false,
            status: 'completed',
          ),
        ],
      );
      for (final dark in [false, true]) {
        await _pumpManager(
          tester,
          controller: controller,
          size: const Size(620, 580),
          locale: const Locale('zh'),
          theme: dark
              ? AppTheme.desktopPanelDark()
              : AppTheme.desktopPanelLight(),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const Key('device-auto-send-offline-phone')),
          findsNothing,
        );
        if (preview) {
          await _capture(tester, 'manager-${dark ? 'dark' : 'light'}');
          await tester.tap(
            find.byKey(const Key('device-address-edit-computer-one')),
          );
          await tester.pumpAndSettle();
          await _capture(tester, 'address-${dark ? 'dark' : 'light'}');
          Navigator.of(
            tester.element(find.byKey(const Key('device-address-dialog'))),
          ).pop();
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('device-transfer-history-open')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('42%'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
        if (preview) {
          await _capture(tester, 'history-${dark ? 'dark' : 'light'}');
        }
        Navigator.of(
          tester.element(
            find.byKey(const Key('device-transfer-history-dialog')),
          ),
        ).pop();
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'online devices appear before history and pairing on a compact window',
    (tester) async {
      final jarvis = LinkedDevice(
        id: 'jarvis',
        name: 'JARVIS',
        kind: LinkedDeviceKind.computer,
        platform: 'windows',
        room: 'jarvis-room',
        secret: 'test',
        autoSendClipboard: true,
        receiveAgentNotifications: false,
        vibrationEnabled: false,
        manuallyDisconnected: false,
        pairedAt: DateTime.utc(2026, 10, 22),
      );
      final controller = _FakeManagement(
        additionalDevices: [jarvis],
        statuses: {'jarvis': DeviceConnectionStatus.connected},
      );
      await _pumpManager(
        tester,
        controller: controller,
        size: const Size(620, 580),
        locale: const Locale('zh'),
      );
      final online = find.byKey(const Key('linked-device-jarvis'));
      final history = find.byKey(const Key('linked-device-phone-one'));
      expect(
        tester.getTopLeft(online).dy,
        lessThan(tester.getTopLeft(history).dy),
      );
      expect(tester.getTopLeft(online).dy, lessThan(200));
      expect(find.text('历史连接'), findsOneWidget);
      expect(
        tester.getTopLeft(online).dy,
        lessThan(
          tester.getTopLeft(find.byKey(const Key('device-pairing-panel'))).dy,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offline settings stay collapsed while reconnect remains accessible',
    (tester) async {
      final controller = _FakeManagement(
        connectionStatus: DeviceConnectionStatus.disconnected,
      );
      await _pumpManager(tester, controller: controller);
      expect(find.byKey(const Key('device-auto-send-phone-one')), findsNothing);
      expect(
        find.byKey(const Key('device-connection-phone-one')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('device-settings-toggle-phone-one')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('device-auto-send-phone-one')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const Key('device-settings-toggle-phone-one')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('device-auto-send-phone-one')), findsNothing);
    },
  );

  testWidgets(
    'transfer history opens on demand without occupying the manager',
    (tester) async {
      final controller = _FakeManagement(
        fileTransfers: [
          FileTransfer(
            id: 'done',
            deviceId: 'phone-one',
            name: 'report.pdf',
            size: 80,
            bytes: 80,
            sending: true,
            status: 'completed',
          ),
          FileTransfer(
            id: 'done',
            deviceId: 'another-device',
            name: 'another-report.pdf',
            size: 80,
            bytes: 80,
            sending: false,
            status: 'completed',
          ),
        ],
      );
      await _pumpManager(tester, controller: controller);
      expect(find.text('report.pdf'), findsNothing);
      await tester.tap(find.byKey(const Key('device-transfer-history-open')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('device-transfer-history-dialog')),
        findsOneWidget,
      );
      expect(find.text('report.pdf'), findsOneWidget);
      expect(find.text('another-report.pdf'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    },
  );

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
    expect(find.text('历史连接'), findsOneWidget);
    expect(
      find.byKey(const Key('device-connection-mode-note')),
      findsOneWidget,
    );
    expect(find.textContaining('优先使用 WebRTC 直连'), findsOneWidget);
    expect(find.textContaining('端到端加密中继'), findsOneWidget);
    expect(find.byTooltip('停止连接'), findsOneWidget);
    await tester.tap(find.byKey(const Key('device-connection-phone-one')));
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

  testWidgets(
    'another computer can be joined using six digits and nearby discovery',
    (WidgetTester tester) async {
      final _FakeManagement controller = _FakeManagement(includeDevice: false);
      await _pumpManager(
        tester,
        controller: controller,
        locale: const Locale('zh'),
      );

      expect(find.textContaining('电脑设备默认关闭提醒'), findsNothing);
      await tester.tap(find.byKey(const Key('device-join-computer')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('device-computer-pairing-dialog')),
        findsOneWidget,
      );
      expect(find.textContaining('电脑设备默认关闭提醒'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('device-computer-pairing-dialog')),
          matching: find.byType(Wrap),
        ),
        findsWidgets,
      );

      await tester.enterText(
        find.byKey(const Key('device-computer-find-address')),
        '192.168.31.153',
      );
      await tester.tap(
        find.byKey(const Key('device-computer-find-address-submit')),
      );
      await tester.pumpAndSettle();
      expect(controller.discoveredAddress, '192.168.31.153');

      await tester.tap(find.byKey(const Key('device-computer-generate-code')));
      await tester.pumpAndSettle();
      expect(find.text('012 345'), findsOneWidget);
      await tester.tap(find.byKey(const Key('nearby-computer-nearby')));
      await tester.pump();
      const String pairingLink = '012345';
      await tester.enterText(
        find.byKey(const Key('device-computer-pairing-input')),
        pairingLink,
      );
      await tester.tap(find.byKey(const Key('device-computer-pairing-submit')));
      await tester.pumpAndSettle();

      expect(controller.joinedComputerLink, pairingLink);
      expect(
        find.byKey(const Key('device-computer-pairing-dialog')),
        findsNothing,
      );
    },
  );

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
    final _FakeManagement controller = _FakeManagement(
      connectionStatus: DeviceConnectionStatus.connected,
    );
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

  testWidgets('computer route is fixed to LAN with no relay selector', (
    tester,
  ) async {
    final controller = _FakeManagement(
      deviceKind: LinkedDeviceKind.computer,
      connectionStatus: DeviceConnectionStatus.connected,
    );
    await _pumpManager(tester, controller: controller);
    expect(
      find.byKey(const Key('device-transport-computer-one')),
      findsOneWidget,
    );
    expect(
      find.text('LAN only · Reconnects automatically after pairing'),
      findsOneWidget,
    );
    expect(find.text('Automatic (recommended)'), findsNothing);
    expect(find.text('Encrypted service'), findsNothing);
    expect(
      find.text('工作电脑  macOS', findRichText: true),
      findsOneWidget,
      reason: 'Paired computers show which operating system they run.',
    );
    expect(tester.takeException(), isNull);
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
    RepaintBoundary(
      key: const Key('device-manager-preview'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        locale: locale,
        supportedLocales: DingDongLocalizations.supportedLocales,
        localizationsDelegates: DingDongLocalizations.localizationsDelegates,
        home: DeviceLinkManagerScreen(controller: controller),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('device-manager-preview')),
    );
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/device-manager-preview')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
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
    implements
        DeviceLinkManagement,
        LanComputerManagement,
        FileTransferManagement {
  _FakeManagement({
    this.includeDevice = true,
    this.pendingPairing,
    this.connectionStatus = DeviceConnectionStatus.connecting,
    this.additionalDevices = const [],
    this.statuses = const {},
    this.activeTransport = DeviceLinkActiveTransport.none,
    this.fileTransfers = const [],
    LinkedDeviceKind deviceKind = LinkedDeviceKind.phone,
  }) : device = LinkedDevice(
         id: deviceKind == LinkedDeviceKind.computer
             ? 'computer-one'
             : 'phone-one',
         name: deviceKind == LinkedDeviceKind.computer ? '工作电脑' : '我的手机',
         kind: deviceKind,
         platform: deviceKind == LinkedDeviceKind.computer
             ? 'macos'
             : 'ios-pwa',
         room: 'abcdefghijklmnopqrstuvwx',
         secret: 'BwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwcHBwc',
         autoSendClipboard: false,
         receiveAgentNotifications: false,
         vibrationEnabled: deviceKind == LinkedDeviceKind.phone,
         manuallyDisconnected: false,
         pairedAt: DateTime.utc(2026, 8, 8),
       );

  @override
  List<NearbyComputer> get nearbyComputers => const [
    NearbyComputer(id: 'nearby', name: '另一台电脑', pairing: true),
  ];
  @override
  String? computerPairingCode;
  String? discoveryError;
  @override
  String? get computerDiscoveryError => discoveryError;
  @override
  Future<void> refreshComputers() async {}
  String? discoveredAddress;
  @override
  Future<void> discoverComputerAddress(String address) async {
    discoveredAddress = address;
  }

  @override
  Future<void> beginComputerPairing() async {
    computerPairingCode = '012345';
    notifyListeners();
  }

  @override
  Future<void> cancelComputerPairing() async {
    computerPairingCode = null;
  }

  @override
  Future<void> joinNearbyComputer(String deviceId, String code) async {
    joinedComputerLink = code;
  }

  String address = '192.168.31.153';
  String? editedAddress;
  List<String> localAddresses = const ['192.168.31.180'];
  @override
  List<String> get localComputerAddresses => localAddresses;
  @override
  String? computerAddressOf(String deviceId) => address;
  @override
  Future<void> setComputerAddress(String deviceId, String value) async {
    editedAddress = value;
    address = value;
    notifyListeners();
  }

  final LinkedDevice device;
  final List<LinkedDevice> additionalDevices;
  final Map<String, DeviceConnectionStatus> statuses;
  final DeviceLinkActiveTransport activeTransport;
  @override
  final List<FileTransfer> fileTransfers;
  @override
  Future<void> controlFileTransfer(
    String id,
    String deviceId,
    String action,
  ) async {}

  final bool includeDevice;
  final DeviceConnectionStatus connectionStatus;

  @override
  final PendingDevicePairing? pendingPairing;

  String? disconnectedDeviceId;
  String? autoSendDeviceId;
  bool? autoSendValue;
  bool beganPairing = false;
  String? joinedComputerLink;

  @override
  bool get canPair => true;

  @override
  List<LinkedDevice> get devices => includeDevice
      ? <LinkedDevice>[device, ...additionalDevices]
      : additionalDevices;

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
  Future<void> joinComputer(String pairingLink) async {
    joinedComputerLink = pairingLink;
  }

  @override
  Future<void> deleteDevice(String deviceId) async {}

  @override
  Future<void> disconnect(String deviceId) async {
    disconnectedDeviceId = deviceId;
  }

  @override
  bool isConnected(String deviceId) =>
      statusOf(deviceId) == DeviceConnectionStatus.connected;

  @override
  Future<void> reconnect(String deviceId) async {}

  @override
  Future<void> setAgentNotifications(String deviceId, bool value) async {}

  @override
  Future<void> setTransportPreference(
    String deviceId,
    DeviceLinkTransportPreference value,
  ) async {}

  @override
  Future<void> setAutoSendClipboard(String deviceId, bool value) async {
    autoSendDeviceId = deviceId;
    autoSendValue = value;
  }

  @override
  DeviceConnectionStatus statusOf(String deviceId) =>
      statuses[deviceId] ?? connectionStatus;

  @override
  DeviceLinkActiveTransport transportOf(String deviceId) => activeTransport;
}
