import 'dart:async';
import 'dart:io';

import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/platform/plugin_desktop_shell_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unread tray title requests the native capsule treatment', () async {
    MethodCall? receivedCall;
    const MethodChannel channel = MethodChannel('tray_manager');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          receivedCall = call;
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await trayManager.setTitle(' 1', style: TrayTitleStyle.unreadBadge);

    expect(receivedCall?.method, 'setTitle');
    expect(receivedCall?.arguments, <String, Object>{
      'title': ' 1',
      'style': 'unreadBadge',
    });
  });

  test('tray title forwards the selected badge color', () async {
    MethodCall? receivedCall;
    const MethodChannel channel = MethodChannel('tray_manager');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          receivedCall = call;
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await trayManager.setTitle(
      ' 1',
      style: TrayTitleStyle.unreadBadge,
      badgeColorRgb: TrayNotificationColor.purple.rgbValue,
    );

    expect(receivedCall?.method, 'setTitle');
    expect(receivedCall?.arguments, <String, Object>{
      'title': ' 1',
      'style': 'unreadBadge',
      'badgeColorRgb': TrayNotificationColor.purple.rgbValue,
    });
  });

  test(
    'tray badge background is enabled only while a notification is unread',
    () {
      expect(macOSTrayTitleStyle(hot: false), TrayTitleStyle.plain);
      expect(macOSTrayTitleStyle(hot: true), TrayTitleStyle.unreadBadge);
    },
  );

  test('tray icon shake requests the native status item animation', () async {
    MethodCall? receivedCall;
    const MethodChannel channel = MethodChannel('tray_manager');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          receivedCall = call;
          return true;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    await trayManager.shakeIcon();

    expect(receivedCall?.method, 'shakeIcon');
  });

  test(
    'Windows tray icons carry an alternate attention icon and count',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      MethodCall? receivedCall;
      const MethodChannel channel = MethodChannel('tray_manager');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            receivedCall = call;
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      await trayManager.setIcon(
        'windows/runner/resources/tray_icon_on_dark.ico',
        attentionIconPath:
            'windows/runner/resources/tray_icon_on_dark_unread.ico',
        unreadCount: 3,
      );

      expect(receivedCall?.method, 'setIcon');
      final Map<Object?, Object?> arguments =
          receivedCall?.arguments as Map<Object?, Object?>;
      expect(arguments['unreadCount'], 3);
      expect(
        arguments['attentionIconPath'],
        endsWith('tray_icon_on_dark_unread.ico'),
      );
      expect(arguments, isNot(contains('requestAttention')));
      expect(arguments, isNot(contains('taskbarIsLight')));
    },
  );

  test('Windows tray renderer enlarges bundled source art without a badge', () {
    final String header = File(
      'packages/tray_manager/windows/tray_visual.h',
    ).readAsStringSync();
    final String source = File(
      'packages/tray_manager/windows/tray_visual.cpp',
    ).readAsStringSync();
    final String cmake = File(
      'packages/tray_manager/windows/CMakeLists.txt',
    ).readAsStringSync();

    expect(header, contains('kTrayArtOccupancy = 1.0f'));
    expect(header, contains('CreateTrayIcon'));
    expect(source, contains('kTrayArtOccupancy'));
    expect(source, contains('GetPixel'));
    expect(source, contains('DrawImage'));
    expect(source, isNot(contains('FillEllipse')));
    expect(source, isNot(contains('DrawString')));
    expect(source, isNot(contains('GraphicsPath')));
    expect(source, contains('GetHICON'));
    expect(cmake, contains('tray_visual.cpp'));
    expect(cmake, contains('gdiplus'));
    expect(cmake, contains('NOMINMAX'));
    expect(source, contains('#pragma warning(disable : 4458)'));
    expect(source, contains('static_cast<Gdiplus::REAL>'));
    expect(source, contains('using std::min;'));
    expect(source, contains('using std::max;'));
  });

  test(
    'taskbar surface brightness is exposed through the tray channel',
    () async {
      MethodCall? receivedCall;
      const MethodChannel channel = MethodChannel('tray_manager');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            receivedCall = call;
            return true;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      expect(await trayManager.getTaskbarSurfaceIsLight(), isTrue);
      expect(receivedCall?.method, 'getTaskbarSurfaceIsLight');
    },
  );

  test(
    'window focus reapplies the saved opacity after a Space switch',
    () async {
      final List<MethodCall> calls = <MethodCall>[];
      const MethodChannel channel = MethodChannel('window_manager');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final PluginDesktopShellGateway gateway = PluginDesktopShellGateway();

      await gateway.setOpacity(0.96);
      calls.clear();
      gateway.onWindowFocus();
      await Future<void>.delayed(Duration.zero);

      expect(
        calls,
        contains(
          isA<MethodCall>()
              .having((MethodCall call) => call.method, 'method', 'setOpacity')
              .having(
                (MethodCall call) =>
                    (call.arguments! as Map<Object?, Object?>)['opacity'],
                'opacity',
                0.96,
              ),
        ),
      );
    },
  );

  test('taskbar appearance events reach tray listeners', () async {
    final _RecordingTrayListener listener = _RecordingTrayListener();
    trayManager.addListener(listener);
    addTearDown(() => trayManager.removeListener(listener));
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final Completer<void> handled = Completer<void>();

    await messenger.handlePlatformMessage(
      'tray_manager',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('onTaskbarAppearanceChanged', true),
      ),
      (_) => handled.complete(),
    );
    await handled.future;

    expect(listener.taskbarIsLight, isTrue);
  });

  test('desktop tray restores a native right-click utility menu', () {
    final String gateway = File(
      'lib/platform/plugin_desktop_shell_gateway.dart',
    ).readAsStringSync();

    expect(gateway, contains('void onTrayIconRightMouseDown()'));
    expect(gateway, contains('trayManager.popUpContextMenu()'));
    expect(gateway, contains('DesktopShellCommand.showClipboard'));
    expect(gateway, isNot(contains("'清空剪贴板历史'")));
    expect(gateway, isNot(contains("'Clear Clipboard History'")));
    expect(gateway, contains("label: chinese ? '资源管理' : 'Resource Manager'"));
    expect(gateway, contains("label: chinese ? '设置' : 'Settings'"));
    expect(gateway, isNot(contains("'资源管理…'")));
    expect(gateway, isNot(contains("'设置…'")));
    final int resourceManagerIndex = gateway.indexOf(
      'DesktopShellCommand.showResourceManager',
    );
    final int settingsIndex = gateway.indexOf(
      'DesktopShellCommand.showSettings',
    );
    expect(resourceManagerIndex, greaterThan(-1));
    expect(resourceManagerIndex, lessThan(settingsIndex));
    expect(gateway, contains('DesktopShellCommand.showSettings'));
    expect(gateway, contains('DesktopShellCommand.quit'));
  });

  test('macOS tray persists the user-arranged status item position', () {
    final String source = File(
      'packages/tray_manager/macos/tray_manager/Classes/TrayIcon.swift',
    ).readAsStringSync();

    expect(source, contains('statusItem?.autosaveName ='));
    expect(source, contains('Bundle.main.bundleIdentifier'));
    expect(source, contains('.primary-status-item'));
  });

  test('macOS copy feedback shakes the complete status bar button', () {
    final String trayIcon = File(
      'packages/tray_manager/macos/tray_manager/Classes/TrayIcon.swift',
    ).readAsStringSync();
    final String plugin = File(
      'packages/tray_manager/macos/tray_manager/Classes/TrayManagerPlugin.swift',
    ).readAsStringSync();
    final String main = File('lib/main.dart').readAsStringSync();

    expect(trayIcon, contains('public func shake()'));
    expect(
      trayIcon,
      contains('CAKeyframeAnimation(keyPath: "transform.rotation.z")'),
    );
    expect(trayIcon, contains('button.layer?.add(animation'));
    expect(plugin, contains('case "shakeIcon":'));
    expect(
      main,
      contains(
        'onCopyDetected: () => unawaited(shellGateway.shakeTrayIcon()),',
      ),
    );
    expect(
      main,
      isNot(contains('onCopyDetected: shellController.requestMascotShake')),
    );
  });

  test('macOS unread tray uses the selected RGB capsule color', () {
    final String gateway = File(
      'lib/platform/plugin_desktop_shell_gateway.dart',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final String plugin = File(
      'packages/tray_manager/macos/tray_manager/Classes/TrayManagerPlugin.swift',
    ).readAsStringSync();
    final String source = File(
      'packages/tray_manager/macos/tray_manager/Classes/TrayIcon.swift',
    ).readAsStringSync();

    expect(gateway, contains('badgeColorRgb: _trayNotificationColor.rgbValue'));
    expect(gateway, isNot(contains('hot || macDevelopment')));
    expect(gateway, contains('await trayManager.setTitle(\n        title,'));
    expect(plugin, contains('args["badgeColorRgb"] as? NSNumber'));
    expect(source, contains('style == "unreadBadge" && !countText.isEmpty'));
    expect(source, contains('let value = rgb ?? 0xDB7333'));
    expect(source, contains('let red = CGFloat((value >> 16) & 0xFF) / 255'));
    expect(source, contains('button.layer?.backgroundColor = nil'));
  });

  test('Windows tray bridge samples the real taskbar and refreshes safely', () {
    final String source = File(
      'packages/tray_manager/windows/tray_manager_plugin.cpp',
    ).readAsStringSync().replaceAll('\r\n', '\n');
    final String gateway = File(
      'lib/platform/plugin_desktop_shell_gateway.dart',
    ).readAsStringSync();

    expect(gateway, contains('required int unreadCount'));
    expect(gateway, contains('unreadCount: windows ? unreadCount : 0'));
    expect(gateway, contains('attentionIconPath: windows'));
    expect(gateway, contains('windowsTrayTooltip('));
    expect(source, contains('Shell_NotifyIconGetRect(&niif, &icon_rect)'));
    expect(source, contains('GetPixel(desktop_dc'));
    expect(source, contains('RelativeLuminance'));
    expect(source, contains('0.55'));
    expect(source, contains('SystemUsesLightTheme'));
    expect(source, contains('onTaskbarAppearanceChanged'));
    expect(source, contains('WM_DWMCOLORIZATIONCOLORCHANGED'));
    expect(source, contains('HICON replacement_icon'));
    expect(source, contains('if (replacement_icon == nullptr)'));
    expect(source, contains('ValueOrNull(args, "unreadCount")'));
    expect(source, contains('ValueOrNull(args, "attentionIconPath")'));
    expect(source, contains('kAttentionFlashIntervalMs = 550'));
    expect(source, contains('StartAttentionFlash'));
    expect(source, contains('AdvanceAttentionFlash'));
    expect(source, contains('CancelAttentionFlash'));
    expect(
      source,
      contains('''  } else {
    CancelAttentionFlash();
    ApplyIconFrame(false);
  }'''),
    );
    expect(
      source,
      isNot(
        contains('''    CancelAttentionFlash();
    if (!tray_icon_setted) {
      ApplyIconFrame(false);
    }'''),
      ),
    );
    expect(source, contains('WM_TIMER'));
    expect(source, contains('SetTimer'));
    expect(source, contains('KillTimer'));
    expect(source, contains('tray_manager::CreateTrayIcon'));
  });
}

final class _RecordingTrayListener with TrayListener {
  bool? taskbarIsLight;

  @override
  void onTaskbarAppearanceChanged(bool taskbarIsLight) {
    this.taskbarIsLight = taskbarIsLight;
  }
}
