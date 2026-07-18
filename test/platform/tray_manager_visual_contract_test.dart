import 'dart:async';
import 'dart:io';

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

    expect(source, contains('Shell_NotifyIconGetRect(&niif, &icon_rect)'));
    expect(source, contains('GetPixel(desktop_dc'));
    expect(source, contains('RelativeLuminance'));
    expect(source, contains('0.55'));
    expect(source, contains('SystemUsesLightTheme'));
    expect(source, contains('onTaskbarAppearanceChanged'));
    expect(source, contains('WM_DWMCOLORIZATIONCOLORCHANGED'));
    expect(source, contains('HICON replacement_icon'));
    expect(source, contains('if (replacement_icon == nullptr)'));
  });
}

final class _RecordingTrayListener with TrayListener {
  bool? taskbarIsLight;

  @override
  void onTaskbarAppearanceChanged(bool taskbarIsLight) {
    this.taskbarIsLight = taskbarIsLight;
  }
}
