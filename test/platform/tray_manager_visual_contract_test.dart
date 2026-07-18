import 'dart:async';
import 'dart:io';

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
    expect(gateway, contains('DesktopShellCommand.clearClipboardHistory'));
    expect(gateway, contains('DesktopShellCommand.showSettings'));
    expect(gateway, contains('DesktopShellCommand.quit'));
  });

  test('Windows tray bridge samples the real taskbar and refreshes safely', () {
    final String source = File(
      'packages/tray_manager/windows/tray_manager_plugin.cpp',
    ).readAsStringSync();
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
