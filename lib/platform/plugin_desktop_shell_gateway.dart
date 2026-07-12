import 'dart:async';
import 'dart:io';

import 'package:dingdong/features/shell/domain/desktop_shell_gateway.dart';
import 'package:dingdong/features/shell/domain/popup_window_policy.dart';
import 'package:dingdong/features/shell/domain/tray_unread_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Production tray, window, and global-hotkey adapter for macOS and Windows.
final class PluginDesktopShellGateway
    with TrayListener, WindowListener
    implements DesktopShellGateway {
  PluginDesktopShellGateway({this.onHideAuxiliaryWindows});

  final Future<void> Function()? onHideAuxiliaryWindows;
  static const MethodChannel _hotKeyChannel = MethodChannel(
    'dingdong/global_hotkey',
  );
  static const MethodChannel _modifierChannel = MethodChannel(
    'dingdong/modifier_keys',
  );

  final StreamController<DesktopShellCommand> _commands =
      StreamController<DesktopShellCommand>.broadcast();
  final PopupPlacementSession _placementSession = PopupPlacementSession();
  late final TrayUnreadController _unreadController = TrayUnreadController(
    apply: _applyUnreadAppearance,
  );
  bool _started = false;
  final ValueNotifier<bool> shortcutHints = ValueNotifier<bool>(false);

  @override
  Stream<DesktopShellCommand> get commands => _commands.stream;

  @override
  Future<void> start() async {
    if (_started) {
      return;
    }
    await windowManager.ensureInitialized();
    await windowManager.setAsFrameless();
    await windowManager.setSize(PopupWindowPolicy.initialSize);
    await windowManager.setMinimumSize(PopupWindowPolicy.minimumSize);
    await windowManager.setMaximumSize(PopupWindowPolicy.maximumSize);
    await windowManager.setResizable(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setBackgroundColor(Colors.transparent);
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    trayManager.addListener(this);
    await _unreadController.clear();
    await trayManager.setToolTip('DingDong');
    await trayManager.setContextMenu(
      Menu(
        items: <MenuItem>[
          MenuItem(
            label: 'Open DingDong',
            onClick: (_) => _commands.add(DesktopShellCommand.showToday),
          ),
          MenuItem(
            label: 'Clipboard',
            onClick: (_) => _commands.add(DesktopShellCommand.showClipboard),
          ),
          MenuItem.separator(),
          MenuItem(
            label: 'Quit DingDong',
            onClick: (_) => _commands.add(DesktopShellCommand.quit),
          ),
        ],
      ),
    );
    _hotKeyChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'pressed') {
        _commands.add(DesktopShellCommand.toggleClipboard);
      } else if (call.method == 'workspaceShortcut' &&
          call.arguments == 'today') {
        _commands.add(DesktopShellCommand.showToday);
      } else if (call.method == 'workspaceShortcut' &&
          call.arguments == 'filters') {
        _commands.add(DesktopShellCommand.toggleClipboardFilters);
      }
    });
    _modifierChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'commandChanged') {
        shortcutHints.value = call.arguments == true;
      }
    });
    await _hotKeyChannel.invokeMethod<void>('register');
    await windowManager.hide();
    _started = true;
  }

  @override
  Future<void> showAndFocus() async {
    await _unreadController.clear();
    if (_placementSession.shouldUseDefaultPosition) {
      await _positionPopup();
    }
    await windowManager.show();
    await windowManager.restore();
    await windowManager.focus();
  }

  Future<void> setOpacity(double value) {
    return windowManager.setOpacity(value.clamp(0.82, 0.96));
  }

  Future<void> startDragging() {
    _placementSession.markUserMoved();
    return windowManager.startDragging();
  }

  Future<void> markUnread() => _unreadController.markUnread();

  Future<void> _applyUnreadAppearance({
    required bool hot,
    required String title,
    required int iconSize,
  }) async {
    await trayManager.setIcon(
      Platform.isWindows
          ? 'windows/runner/resources/app_icon.ico'
          : hot
          ? 'Assets/AgentToolMenuBarHotIcon.png'
          : 'Assets/AgentToolMenuBarIcon.png',
      isTemplate: Platform.isMacOS && !hot,
      iconSize: iconSize,
    );
    if (Platform.isMacOS) {
      await trayManager.setTitle(
        title,
        style: hot ? TrayTitleStyle.unreadBadge : TrayTitleStyle.plain,
      );
    }
  }

  Future<void> hide() async {
    await onHideAuxiliaryWindows?.call();
    await windowManager.hide();
  }

  Future<void> _positionPopup() async {
    final Rect? trayBounds = await trayManager.getBounds();
    final List<Display> displays = await screenRetriever.getAllDisplays();
    if (displays.isEmpty) {
      return;
    }
    final Display display = trayBounds == null
        ? await screenRetriever.getPrimaryDisplay()
        : displays.firstWhere((Display candidate) {
            final Offset position = candidate.visiblePosition ?? Offset.zero;
            final Size size = candidate.visibleSize ?? candidate.size;
            return (position & size).contains(trayBounds.center);
          }, orElse: () => displays.first);
    final Offset displayPosition = display.visiblePosition ?? Offset.zero;
    final Size displaySize = display.visibleSize ?? display.size;
    final Rect visibleDisplay = displayPosition & displaySize;
    final Rect anchor =
        trayBounds ??
        Rect.fromLTWH(visibleDisplay.right - 24, visibleDisplay.top, 24, 24);
    final bool taskbarIsBelow = anchor.center.dy > visibleDisplay.center.dy;
    final Offset position = taskbarIsBelow
        ? PopupWindowPolicy.positionAboveTray(
            trayBounds: anchor,
            visibleDisplay: visibleDisplay,
            popupSize: PopupWindowPolicy.initialSize,
          )
        : PopupWindowPolicy.positionBelowTray(
            trayBounds: anchor,
            visibleDisplay: visibleDisplay,
            popupSize: PopupWindowPolicy.initialSize,
          );
    await windowManager.setPosition(position);
  }

  @override
  Future<void> toggleAndFocus() async {
    if (await windowManager.isVisible()) {
      await hide();
      return;
    }
    await showAndFocus();
  }

  @override
  Future<void> quit() async {
    await stop();
    await windowManager.destroy();
  }

  @override
  Future<void> stop() async {
    if (!_started) {
      return;
    }
    await _hotKeyChannel.invokeMethod<void>('unregister');
    _hotKeyChannel.setMethodCallHandler(null);
    _modifierChannel.setMethodCallHandler(null);
    shortcutHints.value = false;
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await trayManager.destroy();
    _started = false;
  }

  @override
  void onTrayIconMouseDown() {
    _commands.add(DesktopShellCommand.openTray);
  }

  @override
  void onWindowClose() {
    unawaited(hide());
  }

  @override
  void onWindowBlur() {
    unawaited(_handleWindowBlur());
  }

  Future<void> _handleWindowBlur() async {
    await Future<void>.delayed(const Duration(milliseconds: 30));
    final bool applicationIsActive =
        await _hotKeyChannel.invokeMethod<bool>('isApplicationActive') ?? false;
    if (PopupWindowPolicy.shouldHideOnBlur(
      applicationIsActive: applicationIsActive,
    )) {
      await hide();
    }
  }
}
