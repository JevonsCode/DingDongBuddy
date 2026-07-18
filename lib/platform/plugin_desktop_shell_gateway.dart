import 'dart:async';
import 'dart:io';

import 'package:dingdong/features/shell/domain/desktop_shell_gateway.dart';
import 'package:dingdong/features/shell/domain/popup_window_policy.dart';
import 'package:dingdong/features/shell/domain/tray_unread_controller.dart';
import 'package:dingdong/core/platform/desktop_window_policy.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Production tray, window, and global-hotkey adapter for macOS and Windows.
final class PluginDesktopShellGateway
    with TrayListener, WindowListener
    implements DesktopShellGateway {
  PluginDesktopShellGateway({
    this.onHideAuxiliaryWindows,
    bool Function()? clipboardMonitoringState,
    bool Function()? useChineseLabels,
  }) : _clipboardMonitoringState = clipboardMonitoringState ?? (() => false),
       _useChineseLabels = useChineseLabels ?? (() => false);

  final Future<void> Function()? onHideAuxiliaryWindows;
  final bool Function() _clipboardMonitoringState;
  final bool Function() _useChineseLabels;
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
    // MainFlutterWindow is already borderless. window_manager's macOS
    // setAsFrameless implementation force-unwraps title-bar buttons and
    // crashes when those buttons do not exist on an already borderless window.
    await windowManager.setSize(PopupWindowPolicy.initialSize);
    await windowManager.setMinimumSize(PopupWindowPolicy.minimumSize);
    await windowManager.setMaximumSize(PopupWindowPolicy.maximumSize);
    await windowManager.setResizable(true);
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setSkipTaskbar(true);
    await windowManager.setBackgroundColor(
      desktopWindowBackground(
        defaultTargetPlatform,
        opaqueColor: PopupStyle.background,
      ),
    );
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    trayManager.addListener(this);
    await _unreadController.clear();
    await trayManager.setToolTip('DingDong');
    await _rebuildContextMenu();
    _hotKeyChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'pressed') {
        _commands.add(DesktopShellCommand.toggleClipboard);
      } else if (call.method == 'workspaceShortcut' &&
          call.arguments == 'today') {
        _commands.add(DesktopShellCommand.showToday);
      } else if (call.method == 'workspaceShortcut' &&
          call.arguments == 'filters') {
        _commands.add(DesktopShellCommand.toggleClipboardFilters);
      } else if (call.method == 'workspaceShortcut' &&
          call.arguments == 'search') {
        _commands.add(DesktopShellCommand.focusClipboardSearch);
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

  Future<void> _rebuildContextMenu() async {
    final bool monitoring = _clipboardMonitoringState();
    final bool chinese = _useChineseLabels();
    await trayManager.setContextMenu(
      Menu(
        items: <MenuItem>[
          MenuItem(
            label: chinese ? '打开剪贴板' : 'Open Clipboard',
            onClick: (_) => _commands.add(DesktopShellCommand.showClipboard),
          ),
          MenuItem.separator(),
          MenuItem.checkbox(
            label: chinese
                ? monitoring
                      ? '正在监听剪贴板'
                      : '剪贴板监听已暂停'
                : monitoring
                ? 'Clipboard Monitoring On'
                : 'Clipboard Monitoring Paused',
            checked: monitoring,
            disabled: true,
          ),
          MenuItem(
            label: chinese
                ? monitoring
                      ? '停止监听'
                      : '开始监听'
                : monitoring
                ? 'Stop Monitoring'
                : 'Start Monitoring',
            onClick: (_) => _commands.add(
              monitoring
                  ? DesktopShellCommand.stopClipboardMonitoring
                  : DesktopShellCommand.startClipboardMonitoring,
            ),
          ),
          MenuItem(
            label: chinese ? '清空剪贴板历史' : 'Clear Clipboard History',
            onClick: (_) =>
                _commands.add(DesktopShellCommand.clearClipboardHistory),
          ),
          MenuItem.separator(),
          MenuItem(
            label: chinese ? '设置…' : 'Settings…',
            onClick: (_) => _commands.add(DesktopShellCommand.showSettings),
          ),
          MenuItem.separator(),
          MenuItem(
            label: chinese ? '退出 DingDong' : 'Quit DingDong',
            onClick: (_) => _commands.add(DesktopShellCommand.quit),
          ),
        ],
      ),
    );
  }

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
    final Display primaryDisplay = await screenRetriever.getPrimaryDisplay();
    final Display display = trayBounds == null
        ? primaryDisplay
        : displays.firstWhere((Display candidate) {
            final Offset position = candidate.visiblePosition ?? Offset.zero;
            final Size size = candidate.visibleSize ?? candidate.size;
            return (position & size).contains(trayBounds.center);
          }, orElse: () => primaryDisplay);
    final Offset displayPosition = display.visiblePosition ?? Offset.zero;
    final Size displaySize = display.visibleSize ?? display.size;
    final Rect visibleDisplay = displayPosition & displaySize;
    final Size popupSize = PopupWindowPolicy.sizeForVisibleDisplay(
      visibleDisplay,
    );
    await windowManager.setSize(popupSize);
    final Rect anchor =
        trayBounds ??
        Rect.fromLTWH(visibleDisplay.right - 24, visibleDisplay.top, 24, 24);
    final bool taskbarIsBelow = anchor.center.dy > visibleDisplay.center.dy;
    final Offset position = taskbarIsBelow
        ? PopupWindowPolicy.positionAboveTray(
            trayBounds: anchor,
            visibleDisplay: visibleDisplay,
            popupSize: popupSize,
          )
        : PopupWindowPolicy.positionBelowTray(
            trayBounds: anchor,
            visibleDisplay: visibleDisplay,
            popupSize: popupSize,
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
    exit(0);
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
  void onTrayIconRightMouseDown() {
    unawaited(_showContextMenu());
  }

  Future<void> _showContextMenu() async {
    await _rebuildContextMenu();
    await trayManager.popUpContextMenu();
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
