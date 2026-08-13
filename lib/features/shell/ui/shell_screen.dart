import 'dart:async';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/platform/desktop_platform_policy.dart';
import 'package:dingdong/core/platform/desktop_window_policy.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/activity/ui/activity_screen.dart';
import 'package:dingdong/features/agent_api/ui/agent_api_screen.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_content_launcher.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_preview_launcher.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_share_gateway.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_screen.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/device_link/domain/device_link_management.dart';
import 'package:dingdong/features/device_link/ui/device_link_controller.dart';
import 'package:dingdong/features/device_link/ui/device_link_dialog.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/library/domain/library_transfer_gateway.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/resource_browser_screen.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/settings/domain/sound_file_gateway.dart';
import 'package:dingdong/features/settings/domain/sound_preview_gateway.dart';
import 'package:dingdong/features/settings/domain/workspace_shortcuts.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:dingdong/features/shell/ui/popup_footer.dart';
import 'package:dingdong/features/shell/ui/popup_header.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Main desktop navigation shell shared by macOS and Windows.
class ShellScreen extends StatefulWidget {
  const ShellScreen({
    required this.activityController,
    required this.agentConversationLauncher,
    required this.clipboardViewModel,
    required this.libraryViewModel,
    required this.issueCenterController,
    required this.settingsViewModel,
    required this.controller,
    this.agentBaseUri,
    this.developmentBuild = false,
    this.clipboardGateway,
    this.desktopContextMenuGateway,
    this.clipboardContentLauncher,
    this.clipboardPreviewLauncher,
    this.clipboardShareGateway,
    this.deviceLinkController,
    this.deviceLinkManagerLauncher,
    this.libraryTransferGateway,
    this.resourceManagerLauncher,
    this.settingsWindowLauncher,
    this.soundFileGateway,
    this.soundPreviewGateway,
    this.onStartDragging,
    this.onHideWindow,
    this.shortcutHints,
    this.windowVisible,
    this.now,
    super.key,
  });

  final ActivityController activityController;
  final AgentConversationLauncher agentConversationLauncher;
  final ClipboardViewModel clipboardViewModel;
  final LibraryViewModel libraryViewModel;
  final IssueCenterController issueCenterController;
  final SettingsViewModel settingsViewModel;
  final ShellController controller;
  final Uri? agentBaseUri;
  final bool developmentBuild;
  final ClipboardGateway? clipboardGateway;
  final DesktopContextMenuGateway? desktopContextMenuGateway;
  final ClipboardContentLauncher? clipboardContentLauncher;
  final ClipboardPreviewLauncher? clipboardPreviewLauncher;
  final ClipboardShareGateway? clipboardShareGateway;
  final DeviceLinkController? deviceLinkController;
  final DeviceLinkManagerLauncher? deviceLinkManagerLauncher;
  final LibraryTransferGateway? libraryTransferGateway;
  final ResourceManagerLauncher? resourceManagerLauncher;
  final SettingsWindowLauncher? settingsWindowLauncher;
  final SoundFileGateway? soundFileGateway;
  final SoundPreviewGateway? soundPreviewGateway;
  final Future<void> Function()? onStartDragging;
  final Future<void> Function()? onHideWindow;
  final ValueListenable<bool>? shortcutHints;
  final ValueListenable<bool>? windowVisible;
  final DateTime Function()? now;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  bool _showShortcutHints = false;
  bool _showWorkspaceShortcutHints = false;
  bool _showPlainTextShortcutHints = false;
  bool _showGroupShortcutHints = false;
  bool _clipboardFiltersExpanded = false;
  bool _clipboardPreviewOpen = false;
  bool _focusMcpOnOpen = false;
  int _clipboardShortcutStartIndex = 0;
  int _clipboardGroupShortcutStartIndex = 0;
  late int _lastClipboardFilterToggleRevision;
  late int _lastClipboardRefreshRevision;
  late int _lastLibraryRefreshRevision;
  late int _lastSelectedIndex;
  int _lastDeviceShareRevision = 0;
  bool _deviceShareDialogOpen = false;

  @override
  void initState() {
    super.initState();
    _lastClipboardFilterToggleRevision =
        widget.controller.clipboardFilterToggleRevision;
    _lastClipboardRefreshRevision = widget.controller.clipboardRefreshRevision;
    _lastLibraryRefreshRevision = widget.controller.libraryRefreshRevision;
    _lastSelectedIndex = widget.controller.selectedIndex;
    widget.controller.addListener(_handleNavigationChanged);
    widget.shortcutHints?.addListener(_handleExternalShortcutHints);
    _lastDeviceShareRevision =
        widget.deviceLinkController?.shareRequestRevision ?? 0;
    widget.deviceLinkController?.addListener(_handleDeviceLinkChanged);
    widget.clipboardViewModel.load();
    widget.libraryViewModel.load();
  }

  @override
  void didUpdateWidget(covariant ShellScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleNavigationChanged);
      widget.controller.addListener(_handleNavigationChanged);
      _lastClipboardFilterToggleRevision =
          widget.controller.clipboardFilterToggleRevision;
      _lastClipboardRefreshRevision =
          widget.controller.clipboardRefreshRevision;
      _lastLibraryRefreshRevision = widget.controller.libraryRefreshRevision;
      _lastSelectedIndex = widget.controller.selectedIndex;
    }
    if (oldWidget.shortcutHints != widget.shortcutHints) {
      oldWidget.shortcutHints?.removeListener(_handleExternalShortcutHints);
      widget.shortcutHints?.addListener(_handleExternalShortcutHints);
      _handleExternalShortcutHints();
    }
    if (oldWidget.deviceLinkController != widget.deviceLinkController) {
      oldWidget.deviceLinkController?.removeListener(_handleDeviceLinkChanged);
      _lastDeviceShareRevision =
          widget.deviceLinkController?.shareRequestRevision ?? 0;
      widget.deviceLinkController?.addListener(_handleDeviceLinkChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleNavigationChanged);
    widget.shortcutHints?.removeListener(_handleExternalShortcutHints);
    widget.deviceLinkController?.removeListener(_handleDeviceLinkChanged);
    super.dispose();
  }

  void _handleNavigationChanged() {
    final int selectedIndex = widget.controller.selectedIndex;
    if (selectedIndex == 1 && _lastSelectedIndex != 1) {
      widget.libraryViewModel.load();
    }
    if (selectedIndex == 2 && _lastSelectedIndex != 2) {
      widget.clipboardViewModel.load();
    }
    _lastSelectedIndex = selectedIndex;
    final ClipboardPreviewLauncher? launcher = widget.clipboardPreviewLauncher;
    if (selectedIndex != 2 && launcher != null) {
      unawaited(launcher.hide());
      _clipboardPreviewOpen = false;
    }
    final int refreshRevision = widget.controller.clipboardRefreshRevision;
    if (refreshRevision != _lastClipboardRefreshRevision) {
      _lastClipboardRefreshRevision = refreshRevision;
      widget.clipboardViewModel.load();
    }
    final int libraryRefreshRevision = widget.controller.libraryRefreshRevision;
    if (libraryRefreshRevision != _lastLibraryRefreshRevision) {
      _lastLibraryRefreshRevision = libraryRefreshRevision;
      widget.libraryViewModel.load();
    }
    setState(() {
      final int revision = widget.controller.clipboardFilterToggleRevision;
      if (revision != _lastClipboardFilterToggleRevision) {
        _lastClipboardFilterToggleRevision = revision;
        if (widget.controller.selectedIndex == 2) {
          _clipboardFiltersExpanded = !_clipboardFiltersExpanded;
        }
      }
      if (widget.controller.selectedIndex != 2) {
        _clipboardFiltersExpanded = false;
        _clipboardShortcutStartIndex = 0;
        _clipboardGroupShortcutStartIndex = 0;
      }
    });
  }

  void _handleExternalShortcutHints() {
    final bool show = widget.shortcutHints?.value ?? false;
    if ((show != _showShortcutHints ||
            (!show && _showPlainTextShortcutHints)) &&
        mounted) {
      setState(() {
        _showShortcutHints = show;
        if (!show) {
          _showPlainTextShortcutHints = false;
        }
      });
    }
  }

  void _handleDeviceLinkChanged() {
    final DeviceLinkController? controller = widget.deviceLinkController;
    if (controller == null ||
        controller.shareRequestRevision == _lastDeviceShareRevision) {
      return;
    }
    _lastDeviceShareRevision = controller.shareRequestRevision;
    if (controller.pendingShare == null || _deviceShareDialogOpen) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_openPendingDeviceShare());
    });
  }

  Future<void> _openDeviceLinks() async {
    final DeviceLinkManagerLauncher? launcher =
        widget.deviceLinkManagerLauncher;
    if (launcher == null) return;
    await widget.onHideWindow?.call();
    await launcher.show();
  }

  Future<void> _openPendingDeviceShare() async {
    final DeviceLinkController? controller = widget.deviceLinkController;
    final ClipboardRecord? record = controller?.pendingShare;
    if (controller == null || record == null || _deviceShareDialogOpen) return;
    _deviceShareDialogOpen = true;
    try {
      await showDialog<bool>(
        context: context,
        builder: (BuildContext context) =>
            DeviceShareDialog(controller: controller, record: record),
      );
    } finally {
      controller.clearPendingShare();
      _deviceShareDialogOpen = false;
    }
  }

  void _openIssueCenter() {
    final ResourceManagerLauncher? launcher = widget.resourceManagerLauncher;
    if (launcher != null) {
      unawaited(launcher.show(destination: ResourceManagerDestination.issues));
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final TargetPlatform platform = defaultTargetPlatform;
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool isPrimaryKey = isPrimaryModifierKey(event.logicalKey, platform);
    final bool showPrimary = isPrimaryKey
        ? event is! KeyUpEvent
        : isPrimaryModifierPressed(keyboard, platform);
    final bool showWorkspace = widget
        .settingsViewModel
        .settings
        .workspaceShortcuts
        .values
        .any(
          (WorkspaceShortcut shortcut) =>
              shortcut.modifierStateMatches(keyboard, platform),
        );
    final bool showPlainText =
        showPrimary &&
        usesMetaAsPrimaryModifier(platform) &&
        keyboard.isAltPressed;
    final bool showGroups = _groupNavigationModifierPressed(keyboard, platform);
    if (showPrimary != _showShortcutHints ||
        showWorkspace != _showWorkspaceShortcutHints ||
        showPlainText != _showPlainTextShortcutHints ||
        showGroups != _showGroupShortcutHints) {
      setState(() {
        _showShortcutHints = showPrimary;
        _showWorkspaceShortcutHints = showWorkspace;
        _showPlainTextShortcutHints = showPlainText;
        _showGroupShortcutHints = showGroups;
        if (showGroups &&
            widget.controller.selectedIndex == 2 &&
            widget.clipboardViewModel.groups.isNotEmpty) {
          _clipboardFiltersExpanded = true;
        }
      });
    }
    if (event is KeyDownEvent && widget.controller.selectedIndex == 2) {
      final int? shortcutIndex = _clipboardShortcutIndex(event.logicalKey);
      if (shortcutIndex != null &&
          shortcutIndex < 5 &&
          showGroups &&
          widget.clipboardViewModel.groups.isNotEmpty) {
        setState(() => _clipboardFiltersExpanded = true);
        widget.clipboardViewModel.selectGroupAt(
          _clipboardGroupShortcutStartIndex + shortcutIndex,
        );
        return KeyEventResult.handled;
      }
      if (shortcutIndex != null &&
          isPrimaryModifierPressed(keyboard, platform)) {
        unawaited(
          _useClipboardRecordAt(
            shortcutIndex,
            mode: showPlainText
                ? ClipboardPasteMode.plainText
                : ClipboardPasteMode.original,
          ),
        );
        return KeyEventResult.handled;
      }
      if (!_isEditingText() &&
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        widget.clipboardViewModel.moveSelection(1);
        return KeyEventResult.handled;
      }
      if (!_isEditingText() && event.logicalKey == LogicalKeyboardKey.arrowUp) {
        widget.clipboardViewModel.moveSelection(-1);
        return KeyEventResult.handled;
      }
      if (!_isEditingText() &&
          event.logicalKey == LogicalKeyboardKey.arrowRight) {
        setState(() => _clipboardFiltersExpanded = true);
        widget.clipboardViewModel.moveGroupSelection(1);
        return KeyEventResult.handled;
      }
      if (!_isEditingText() &&
          event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        setState(() => _clipboardFiltersExpanded = true);
        widget.clipboardViewModel.moveGroupSelection(-1);
        return KeyEventResult.handled;
      }
      if (!_isEditingText()) {
        if (event.logicalKey == LogicalKeyboardKey.space) {
          final record = _selectedOrFirstClipboardRecord();
          if (record != null) {
            widget.clipboardViewModel.select(record);
            unawaited(_showClipboardPreview(record));
          }
          return KeyEventResult.handled;
        }
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter) {
          unawaited(_useSelectedClipboardRecord());
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  bool _isEditingText() {
    final BuildContext? focusContext =
        FocusManager.instance.primaryFocus?.context;
    return focusContext?.widget is EditableText ||
        focusContext?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  ClipboardRecord? _selectedOrFirstClipboardRecord() {
    final ClipboardRecord? selected = widget.clipboardViewModel.selectedRecord;
    if (selected != null) {
      return selected;
    }
    final records = widget.clipboardViewModel.visibleRecords;
    return records.isEmpty ? null : records.first;
  }

  Future<void> _useSelectedClipboardRecord() async {
    final ClipboardRecord? record = _selectedOrFirstClipboardRecord();
    if (record == null) {
      return;
    }
    widget.clipboardViewModel.select(record);
    await _hideClipboardPreview();
    await widget.clipboardViewModel.restoreSelected();
  }

  Future<void> _useClipboardRecordAt(
    int index, {
    ClipboardPasteMode mode = ClipboardPasteMode.original,
  }) async {
    await _hideClipboardPreview();
    await widget.clipboardViewModel.restoreVisibleAt(
      _clipboardShortcutStartIndex + index,
      mode: mode,
    );
  }

  Future<void> _showClipboardPreview(ClipboardRecord record) async {
    final ClipboardPreviewLauncher? launcher = widget.clipboardPreviewLauncher;
    if (launcher == null) {
      return;
    }
    _clipboardPreviewOpen = true;
    await launcher.show(record);
  }

  Future<void> _hideClipboardPreview() async {
    _clipboardPreviewOpen = false;
    await widget.clipboardPreviewLauncher?.hide();
  }

  Future<void> _openClipboardContent(ClipboardRecord record) async {
    await _hideClipboardPreview();
    await widget.clipboardContentLauncher?.open(record);
  }

  Future<void> _openSettings({
    SettingsWindowDestination destination = SettingsWindowDestination.top,
  }) async {
    final SettingsWindowLauncher? launcher = widget.settingsWindowLauncher;
    if (launcher == null) {
      return;
    }
    await widget.onHideWindow?.call();
    await launcher.show(destination: destination);
  }

  Future<void> _previewConfiguredSound() async {
    final SoundPreviewGateway? gateway = widget.soundPreviewGateway;
    final AppSettings settings = widget.settingsViewModel.settings;
    if (gateway == null || settings.selectedSound == 'muted') {
      return;
    }
    await gateway.preview(
      sound: settings.selectedSound,
      customSoundPath: settings.customSoundPath,
    );
  }

  Future<void> _openAgentApi() async {
    final bool firstOpen = !widget.settingsViewModel.settings.mcpAccessSeen;
    final bool requiresSetupUpdate =
        widget.settingsViewModel.settings.requiresAgentSetupUpdate;
    if (firstOpen) {
      await widget.settingsViewModel.markMcpAccessSeen();
    }
    if (!mounted) {
      return;
    }
    setState(() => _focusMcpOnOpen = firstOpen || requiresSetupUpdate);
    widget.controller.open(3);
  }

  void _handleMcpFocusHandled() {
    if (_focusMcpOnOpen && mounted) {
      setState(() => _focusMcpOnOpen = false);
    }
  }

  void _handleEscape() {
    if (_clipboardPreviewOpen) {
      unawaited(_hideClipboardPreview());
      return;
    }
    unawaited(widget.onHideWindow?.call());
  }

  void _handleClipboardFilterShortcut() {
    if (widget.controller.selectedIndex != 2) {
      return;
    }
    if (!_clipboardFiltersExpanded) {
      setState(() => _clipboardFiltersExpanded = true);
      return;
    }
    if (widget.clipboardViewModel.hasActiveFilters) {
      widget.clipboardViewModel.clearFilters();
      return;
    }
    setState(() => _clipboardFiltersExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final TargetPlatform platform = defaultTargetPlatform;
    final WorkspaceShortcuts workspaceShortcuts =
        widget.settingsViewModel.settings.workspaceShortcuts;
    final bool systemOwnsCorners = usesSystemWindowCorners(platform);
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _handleEscape();
        },
        workspaceShortcuts.today.activator(platform): () =>
            widget.controller.open(0),
        workspaceShortcuts.library.activator(platform): () =>
            widget.controller.open(1),
        workspaceShortcuts.clipboard.activator(platform): () =>
            widget.controller.open(2),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true):
            _handleClipboardFilterShortcut,
        const SingleActivator(LogicalKeyboardKey.keyR, control: true):
            _handleClipboardFilterShortcut,
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): () {
          if (widget.controller.selectedIndex == 2) {
            widget.controller.requestClipboardSearchFocus();
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          if (widget.controller.selectedIndex == 2) {
            widget.controller.requestClipboardSearchFocus();
          }
        },
      },
      child: Focus(
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        onFocusChange: (bool focused) {
          if (!focused &&
              (_showShortcutHints ||
                  _showWorkspaceShortcutHints ||
                  _showPlainTextShortcutHints ||
                  _showGroupShortcutHints)) {
            setState(() {
              _showShortcutHints = false;
              _showWorkspaceShortcutHints = false;
              _showPlainTextShortcutHints = false;
              _showGroupShortcutHints = false;
            });
          }
        },
        child: RepaintBoundary(
          key: const Key('desktop-shell-golden'),
          child: Material(
            key: const Key('popup-shell'),
            color: PopupStyle.of(context).background,
            shape: systemOwnsCorners
                ? null
                : RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(PopupStyle.radius),
                    side: BorderSide(color: PopupStyle.of(context).border),
                  ),
            clipBehavior: systemOwnsCorners ? Clip.none : Clip.antiAlias,
            child: Column(
              children: <Widget>[
                AnimatedBuilder(
                  animation: Listenable.merge(<Listenable>[
                    widget.issueCenterController,
                    widget.settingsViewModel,
                  ]),
                  builder: (BuildContext context, _) => PopupHeader(
                    selectedIndex: widget.controller.selectedIndex,
                    issueCount: widget.issueCenterController.count,
                    developmentBuild: widget.developmentBuild,
                    updateAvailable:
                        widget
                            .settingsViewModel
                            .releaseStatus
                            .isUpdateAvailable ==
                        true,
                    showShortcutHints: _showWorkspaceShortcutHints,
                    workspaceShortcuts: workspaceShortcuts,
                    mascotShakeRevision: widget.controller.mascotShakeRevision,
                    mascotState: widget.controller.mascotState,
                    onSelected: widget.controller.open,
                    onIssues: _openIssueCenter,
                    onBrand: () => unawaited(_previewConfiguredSound()),
                    onConnections: widget.deviceLinkManagerLauncher == null
                        ? null
                        : () => unawaited(_openDeviceLinks()),
                    onSettings: () {
                      unawaited(_openSettings());
                    },
                    onVersion: () {
                      unawaited(
                        _openSettings(
                          destination: SettingsWindowDestination.version,
                        ),
                      );
                    },
                    onStartDragging: widget.onStartDragging,
                    onHide: widget.onHideWindow,
                  ),
                ),
                Expanded(child: _selectedWorkspace()),
                PopupFooter(
                  agentBaseUri: widget.agentBaseUri,
                  globalHotKey: widget.settingsViewModel.settings.globalHotKey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedWorkspace() {
    return switch (widget.controller.selectedIndex) {
      0 => ActivityScreen(
        activityController: widget.activityController,
        agentConversationLauncher: widget.agentConversationLauncher,
        clipboardViewModel: widget.clipboardViewModel,
        libraryViewModel: widget.libraryViewModel,
        settingsViewModel: widget.settingsViewModel,
        onOpenWorkspace: widget.controller.open,
        onOpenAgentApi: () => unawaited(_openAgentApi()),
        agentBaseUri: widget.agentBaseUri,
        onHideWindow: widget.onHideWindow,
        windowVisible: widget.windowVisible,
        resourceManagerLauncher: _resourceManagerLauncher(),
        contextMenuGateway: widget.desktopContextMenuGateway,
        now: widget.now,
      ),
      1 => ResourceBrowserScreen(
        viewModel: widget.libraryViewModel,
        clipboardGateway: widget.clipboardGateway,
        resourceManagerLauncher: _resourceManagerLauncher(),
      ),
      2 => ClipboardScreen(
        viewModel: widget.clipboardViewModel,
        settingsViewModel: widget.settingsViewModel,
        showShortcutHints: _showShortcutHints,
        showPlainTextShortcutHints: _showPlainTextShortcutHints,
        showGroupShortcutHints: _showGroupShortcutHints,
        onPreview: _showClipboardPreview,
        onOpenContent: widget.clipboardContentLauncher == null
            ? null
            : _openClipboardContent,
        onDismissPreview: _hideClipboardPreview,
        onShare: widget.clipboardShareGateway?.share,
        contextMenuGateway: widget.desktopContextMenuGateway,
        resourceManagerLauncher: _resourceManagerLauncher(),
        filtersExpanded: _clipboardFiltersExpanded,
        onToggleFilters: () {
          setState(
            () => _clipboardFiltersExpanded = !_clipboardFiltersExpanded,
          );
        },
        onShortcutStartIndexChanged: (int index) {
          _clipboardShortcutStartIndex = index;
        },
        onGroupShortcutStartIndexChanged: (int index) {
          _clipboardGroupShortcutStartIndex = index;
        },
        searchFocusRevision: widget.controller.clipboardSearchFocusRevision,
        now: widget.now,
      ),
      3 => AgentApiScreen(
        settingsViewModel: widget.settingsViewModel,
        baseUri: widget.agentBaseUri,
        clipboardGateway: widget.clipboardGateway,
        activityController: widget.activityController,
        issueCenterController: widget.issueCenterController,
        resourceManagerLauncher: _resourceManagerLauncher(),
        focusMcpOnOpen: _focusMcpOnOpen,
        onMcpFocusHandled: _handleMcpFocusHandled,
        onBack: () => widget.controller.open(0),
      ),
      _ => const SizedBox.shrink(),
    };
  }

  ResourceManagerLauncher? _resourceManagerLauncher() {
    final ResourceManagerLauncher? launcher = widget.resourceManagerLauncher;
    if (launcher == null) {
      return null;
    }
    return _CalloutHidingResourceManagerLauncher(
      launcher: launcher,
      onHideWindow: widget.onHideWindow,
    );
  }
}

int? _clipboardShortcutIndex(LogicalKeyboardKey key) {
  final int index = const <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ].indexOf(key);
  return index < 0 ? null : index;
}

bool _groupNavigationModifierPressed(
  HardwareKeyboard keyboard,
  TargetPlatform platform,
) => usesMetaAsPrimaryModifier(platform)
    ? keyboard.isControlPressed
    : keyboard.isAltPressed;

final class _CalloutHidingResourceManagerLauncher
    implements ResourceManagerLauncher, ClipboardCategoryManagerLauncher {
  const _CalloutHidingResourceManagerLauncher({
    required this.launcher,
    required this.onHideWindow,
  });

  final ResourceManagerLauncher launcher;
  final Future<void> Function()? onHideWindow;

  @override
  Future<void> show({
    String? editingResourceId,
    ResourceManagerCreateRequest? createRequest,
    ResourceManagerDestination destination =
        ResourceManagerDestination.resources,
  }) async {
    await onHideWindow?.call();
    await launcher.show(
      editingResourceId: editingResourceId,
      createRequest: createRequest,
      destination: destination,
    );
  }

  @override
  Future<void> showClipboardCategories() async {
    await onHideWindow?.call();
    await showClipboardCategoryManager(launcher);
  }
}
