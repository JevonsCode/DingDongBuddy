import 'dart:async';
import 'dart:io';

import 'package:dingdong/core/platform/desktop_window_policy.dart';
import 'package:dingdong/core/platform/windows_tray_icon_selector.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:dingdong/features/shell/domain/desktop_shell_gateway.dart';
import 'package:dingdong/features/shell/domain/popup_window_policy.dart';
import 'package:dingdong/features/shell/domain/tray_unread_controller.dart';
import 'package:dingdong/features/shell/domain/tray_unread_store.dart';
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
    this.unreadStore,
    bool Function()? clipboardMonitoringState,
    bool Function()? useChineseLabels,
    bool? developmentBuild,
    TrayNotificationColor? trayNotificationColor,
  }) : _clipboardMonitoringState = clipboardMonitoringState ?? (() => false),
       _useChineseLabels = useChineseLabels ?? (() => false),
       _developmentBuild = developmentBuild ?? kDebugMode,
       _trayNotificationColor =
           trayNotificationColor ??
           ((developmentBuild ?? kDebugMode)
               ? TrayNotificationColor.pink
               : TrayNotificationColor.orange);

  final Future<void> Function()? onHideAuxiliaryWindows;
  final TrayUnreadStore? unreadStore;
  final bool Function() _clipboardMonitoringState;
  final bool Function() _useChineseLabels;
  final bool _developmentBuild;
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
    store: unreadStore,
  );
  Timer? _unreadAcknowledgementTimer;
  bool _started = false;
  bool _methodHandlersInstalled = false;
  bool _taskbarIsLight = false;
  bool _hideDockIcon = false;
  double _windowOpacity = 0.90;
  TrayNotificationColor _trayNotificationColor;
  GlobalHotKey _globalHotKey = GlobalHotKey.defaultValue;
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
    await windowManager.setSkipTaskbar(
      desktopWindowSkipsTaskbar(
        defaultTargetPlatform,
        hideDockIcon: _hideDockIcon,
        fallback: true,
      ),
    );
    await windowManager.setBackgroundColor(
      desktopWindowBackground(
        defaultTargetPlatform,
        opaqueColor: PopupStyle.background,
      ),
    );
    await _applyWindowOpacity();
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);
    trayManager.addListener(this);
    await _unreadController.restore();
    if (Platform.isWindows) {
      _taskbarIsLight = await trayManager.getTaskbarSurfaceIsLight();
      await _unreadController.refresh();
    }
    await _rebuildContextMenu();
    _installMethodHandlers();
    await windowManager.hide();
    await _registerGlobalHotKey(_globalHotKey);
    _started = true;
  }

  void _installMethodHandlers() {
    if (_methodHandlersInstalled) {
      return;
    }
    _hotKeyChannel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'openApplication') {
        _commands.add(DesktopShellCommand.openApplication);
      } else if (call.method == 'hideDockIcon') {
        _commands.add(DesktopShellCommand.hideDockIcon);
      } else if (call.method == 'pressed') {
        _commands.add(DesktopShellCommand.toggleClipboard);
      } else if (call.method == 'pastePermissionGranted') {
        _commands.add(DesktopShellCommand.quickPastePermissionGranted);
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
    _methodHandlersInstalled = true;
  }

  @override
  Future<void> showAndFocus({bool acknowledgeUnread = false}) async {
    if (_placementSession.shouldUseDefaultPosition) {
      await _positionPopup();
    }
    await windowManager.show();
    await windowManager.restore();
    await windowManager.focus();
    await _applyWindowOpacity();
    if (acknowledgeUnread) {
      _scheduleUnreadAcknowledgement();
    }
  }

  Future<void> setOpacity(double value) async {
    _windowOpacity = value.clamp(0.82, 0.96);
    await _applyWindowOpacity();
  }

  Future<void> _applyWindowOpacity() =>
      windowManager.setOpacity(_windowOpacity);

  Future<void> setDockIconHidden(bool value) async {
    _hideDockIcon = value;
    if (_started && Platform.isMacOS) {
      await windowManager.setSkipTaskbar(value);
    }
  }

  Future<void> setTrayNotificationColor(TrayNotificationColor value) async {
    if (_trayNotificationColor == value) {
      return;
    }
    _trayNotificationColor = value;
    if (_started && Platform.isMacOS) {
      await _unreadController.refresh();
    }
  }

  Future<bool> setGlobalHotKey(GlobalHotKey value) async {
    final GlobalHotKey candidate = value.sanitized();
    _installMethodHandlers();
    final bool registered = await _registerGlobalHotKey(candidate);
    if (registered) {
      _globalHotKey = candidate;
    }
    return registered;
  }

  Future<bool> _registerGlobalHotKey(GlobalHotKey value) async {
    return await _hotKeyChannel.invokeMethod<bool>(
          'register',
          value.toPlatformArguments(),
        ) ??
        false;
  }

  Future<void> startDragging() {
    _placementSession.markUserMoved();
    return windowManager.startDragging();
  }

  Future<void> markUnread() => _unreadController.markUnread();

  Future<void> shakeTrayIcon() async {
    if (!Platform.isMacOS) {
      return;
    }
    await trayManager.shakeIcon();
  }

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
          MenuItem.separator(),
          MenuItem(
            label: chinese ? '资源管理' : 'Resource Manager',
            onClick: (_) =>
                _commands.add(DesktopShellCommand.showResourceManager),
          ),
          MenuItem(
            label: chinese ? '设置' : 'Settings',
            onClick: (_) => _commands.add(DesktopShellCommand.showSettings),
          ),
          MenuItem.separator(),
          MenuItem(
            label: chinese
                ? _developmentBuild
                      ? '退出 DingDong DEV'
                      : '退出 DingDong'
                : _developmentBuild
                ? 'Quit DingDong DEV'
                : 'Quit DingDong',
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
    required int unreadCount,
  }) async {
    final bool windows = Platform.isWindows;
    await trayManager.setIcon(
      windows
          ? windowsTrayIconPath(taskbarIsLight: _taskbarIsLight, unread: false)
          : hot
          ? 'Assets/AgentToolMenuBarHotIcon.png'
          : 'Assets/AgentToolMenuBarIcon.png',
      isTemplate: Platform.isMacOS && !hot,
      iconSize: iconSize,
      attentionIconPath: windows
          ? windowsTrayIconPath(taskbarIsLight: _taskbarIsLight, unread: true)
          : null,
      unreadCount: windows ? unreadCount : 0,
    );
    if (windows) {
      await trayManager.setToolTip(
        windowsTrayTooltip(
          unreadCount: unreadCount,
          useChineseLabels: _useChineseLabels(),
        ),
      );
    }
    if (Platform.isMacOS) {
      await trayManager.setTitle(
        title,
        style: macOSTrayTitleStyle(hot: hot),
        badgeColorRgb: _trayNotificationColor.rgbValue,
      );
    }
  }

  Future<void> hide() async {
    _unreadAcknowledgementTimer?.cancel();
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
  Future<void> toggleAndFocus({bool acknowledgeUnread = false}) async {
    if (await windowManager.isVisible()) {
      await hide();
      return;
    }
    await showAndFocus(acknowledgeUnread: acknowledgeUnread);
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
    _unreadAcknowledgementTimer?.cancel();
    await _hotKeyChannel.invokeMethod<void>('unregister');
    _hotKeyChannel.setMethodCallHandler(null);
    _modifierChannel.setMethodCallHandler(null);
    _methodHandlersInstalled = false;
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

  @override
  void onTaskbarAppearanceChanged(bool taskbarIsLight) {
    if (_taskbarIsLight == taskbarIsLight) {
      return;
    }
    _taskbarIsLight = taskbarIsLight;
    unawaited(_unreadController.refresh());
  }

  Future<void> _showContextMenu() async {
    await _rebuildContextMenu();
    await trayManager.popUpContextMenu();
  }

  void _scheduleUnreadAcknowledgement() {
    _unreadAcknowledgementTimer?.cancel();
    if (_unreadController.count == 0) {
      return;
    }
    final TrayUnreadSnapshot snapshot = _unreadController.snapshot();
    _unreadAcknowledgementTimer = Timer(
      PopupWindowPolicy.unreadAcknowledgementDelay,
      () => unawaited(_acknowledgeUnreadIfVisible(snapshot)),
    );
  }

  Future<void> _acknowledgeUnreadIfVisible(TrayUnreadSnapshot snapshot) async {
    if (await windowManager.isVisible()) {
      await _unreadController.acknowledge(snapshot);
    }
  }

  @override
  void onWindowClose() {
    unawaited(hide());
  }

  @override
  void onWindowBlur() {
    unawaited(_handleWindowBlur());
  }

  @override
  void onWindowFocus() {
    unawaited(_applyWindowOpacity());
  }

  @override
  void onWindowMoved() {
    unawaited(_applyWindowOpacity());
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

@visibleForTesting
TrayTitleStyle macOSTrayTitleStyle({required bool hot}) =>
    hot ? TrayTitleStyle.unreadBadge : TrayTitleStyle.plain;
