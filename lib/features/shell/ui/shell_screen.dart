import 'dart:async';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/platform/desktop_platform_policy.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/activity/ui/activity_screen.dart';
import 'package:dingdong/features/agent_api/ui/agent_api_screen.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_preview_launcher.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_share_gateway.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_screen.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/library/domain/library_transfer_gateway.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/resource_browser_screen.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/settings/domain/sound_file_gateway.dart';
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
    required this.clipboardViewModel,
    required this.libraryViewModel,
    required this.settingsViewModel,
    required this.controller,
    this.agentBaseUri,
    this.clipboardGateway,
    this.desktopContextMenuGateway,
    this.clipboardPreviewLauncher,
    this.clipboardShareGateway,
    this.libraryTransferGateway,
    this.resourceManagerLauncher,
    this.settingsWindowLauncher,
    this.soundFileGateway,
    this.onStartDragging,
    this.onHideWindow,
    this.shortcutHints,
    this.now,
    super.key,
  });

  final ActivityController activityController;
  final ClipboardViewModel clipboardViewModel;
  final LibraryViewModel libraryViewModel;
  final SettingsViewModel settingsViewModel;
  final ShellController controller;
  final Uri? agentBaseUri;
  final ClipboardGateway? clipboardGateway;
  final DesktopContextMenuGateway? desktopContextMenuGateway;
  final ClipboardPreviewLauncher? clipboardPreviewLauncher;
  final ClipboardShareGateway? clipboardShareGateway;
  final LibraryTransferGateway? libraryTransferGateway;
  final ResourceManagerLauncher? resourceManagerLauncher;
  final SettingsWindowLauncher? settingsWindowLauncher;
  final SoundFileGateway? soundFileGateway;
  final Future<void> Function()? onStartDragging;
  final Future<void> Function()? onHideWindow;
  final ValueListenable<bool>? shortcutHints;
  final DateTime Function()? now;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  bool _showShortcutHints = false;
  bool _clipboardFiltersExpanded = false;
  bool _clipboardPreviewOpen = false;
  bool _focusMcpOnOpen = false;
  late int _lastClipboardFilterToggleRevision;
  late int _lastClipboardRefreshRevision;
  late int _lastSelectedIndex;
  int? _loadingIndex;

  @override
  void initState() {
    super.initState();
    _lastClipboardFilterToggleRevision =
        widget.controller.clipboardFilterToggleRevision;
    _lastClipboardRefreshRevision = widget.controller.clipboardRefreshRevision;
    _lastSelectedIndex = widget.controller.selectedIndex;
    widget.controller.addListener(_handleNavigationChanged);
    widget.shortcutHints?.addListener(_handleExternalShortcutHints);
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
      _lastSelectedIndex = widget.controller.selectedIndex;
    }
    if (oldWidget.shortcutHints != widget.shortcutHints) {
      oldWidget.shortcutHints?.removeListener(_handleExternalShortcutHints);
      widget.shortcutHints?.addListener(_handleExternalShortcutHints);
      _handleExternalShortcutHints();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleNavigationChanged);
    widget.shortcutHints?.removeListener(_handleExternalShortcutHints);
    super.dispose();
  }

  void _handleNavigationChanged() {
    final int selectedIndex = widget.controller.selectedIndex;
    if (selectedIndex == 2 && _lastSelectedIndex != 2) {
      unawaited(widget.clipboardViewModel.captureNow());
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
      }
    });
  }

  void _handleExternalShortcutHints() {
    final bool show = widget.shortcutHints?.value ?? false;
    if (show != _showShortcutHints && mounted) {
      setState(() => _showShortcutHints = show);
    }
  }

  Future<void> _refreshContent() async {
    if (_loadingIndex != null) {
      return;
    }
    final int workspace = widget.controller.selectedIndex.clamp(0, 2);
    setState(() => _loadingIndex = workspace);
    widget.clipboardViewModel.load();
    await widget.libraryViewModel.load();
    await Future<void>.delayed(const Duration(milliseconds: 720));
    if (mounted) {
      setState(() => _loadingIndex = null);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    final TargetPlatform platform = defaultTargetPlatform;
    final bool isModifierKey = isPrimaryModifierKey(event.logicalKey, platform);
    final bool show = isModifierKey
        ? event is! KeyUpEvent
        : isPrimaryModifierPressed(HardwareKeyboard.instance, platform);
    if (show != _showShortcutHints) {
      setState(() => _showShortcutHints = show);
    }
    if (event is KeyDownEvent && widget.controller.selectedIndex == 2) {
      final int? shortcutIndex = _clipboardShortcutIndex(event.logicalKey);
      if (shortcutIndex != null &&
          isPrimaryModifierPressed(HardwareKeyboard.instance, platform)) {
        unawaited(_useClipboardRecordAt(shortcutIndex));
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        widget.clipboardViewModel.moveSelection(1);
        return KeyEventResult.handled;
      }
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        widget.clipboardViewModel.moveSelection(-1);
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

  Future<void> _useClipboardRecordAt(int index) async {
    await _hideClipboardPreview();
    await widget.clipboardViewModel.restoreVisibleAt(index);
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

  Future<void> _openSettings() async {
    final SettingsWindowLauncher? launcher = widget.settingsWindowLauncher;
    if (launcher == null) {
      return;
    }
    await widget.onHideWindow?.call();
    await launcher.show();
  }

  Future<void> _openAgentApi() async {
    final bool firstOpen = !widget.settingsViewModel.settings.mcpAccessSeen;
    if (firstOpen) {
      await widget.settingsViewModel.markMcpAccessSeen();
    }
    if (!mounted) {
      return;
    }
    setState(() => _focusMcpOnOpen = firstOpen);
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

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          _handleEscape();
        },
        const SingleActivator(LogicalKeyboardKey.keyQ, meta: true): () =>
            widget.controller.open(0),
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true): () =>
            widget.controller.open(1),
        const SingleActivator(LogicalKeyboardKey.keyE, meta: true): () =>
            widget.controller.open(2),
        const SingleActivator(LogicalKeyboardKey.keyQ, control: true): () =>
            widget.controller.open(0),
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): () =>
            widget.controller.open(1),
        const SingleActivator(LogicalKeyboardKey.keyE, control: true): () =>
            widget.controller.open(2),
        const SingleActivator(LogicalKeyboardKey.keyR, meta: true): () {
          if (widget.controller.selectedIndex == 2) {
            setState(
              () => _clipboardFiltersExpanded = !_clipboardFiltersExpanded,
            );
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyR, control: true): () {
          if (widget.controller.selectedIndex == 2) {
            setState(
              () => _clipboardFiltersExpanded = !_clipboardFiltersExpanded,
            );
          }
        },
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
          if (!focused && _showShortcutHints) {
            setState(() => _showShortcutHints = false);
          }
        },
        child: RepaintBoundary(
          key: const Key('desktop-shell-golden'),
          child: Material(
            key: const Key('popup-shell'),
            color: PopupStyle.background,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(PopupStyle.radius),
              side: const BorderSide(color: PopupStyle.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: <Widget>[
                PopupHeader(
                  selectedIndex: widget.controller.selectedIndex,
                  loadingIndex: _loadingIndex,
                  showShortcutHints: _showShortcutHints,
                  onSelected: widget.controller.open,
                  onRefresh: () => unawaited(_refreshContent()),
                  onSettings: () {
                    unawaited(_openSettings());
                  },
                  onStartDragging: widget.onStartDragging,
                  onHide: widget.onHideWindow,
                ),
                Expanded(child: _selectedWorkspace()),
                PopupFooter(apiPort: widget.settingsViewModel.settings.apiPort),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedWorkspace() {
    final bool compact =
        widget.settingsViewModel.settings.density ==
        PanelDensityPreference.compact;
    return switch (widget.controller.selectedIndex) {
      0 => ActivityScreen(
        activityController: widget.activityController,
        clipboardViewModel: widget.clipboardViewModel,
        libraryViewModel: widget.libraryViewModel,
        settingsViewModel: widget.settingsViewModel,
        onOpenWorkspace: widget.controller.open,
        onOpenAgentApi: () => unawaited(_openAgentApi()),
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
        compact: compact,
        settingsViewModel: widget.settingsViewModel,
        showShortcutHints: _showShortcutHints,
        onPreview: _showClipboardPreview,
        onDismissPreview: _hideClipboardPreview,
        onShare: widget.clipboardShareGateway?.share,
        contextMenuGateway: widget.desktopContextMenuGateway,
        filtersExpanded: _clipboardFiltersExpanded,
        onToggleFilters: () {
          setState(
            () => _clipboardFiltersExpanded = !_clipboardFiltersExpanded,
          );
        },
        searchFocusRevision: widget.controller.clipboardSearchFocusRevision,
      ),
      3 => AgentApiScreen(
        settingsViewModel: widget.settingsViewModel,
        baseUri: widget.agentBaseUri,
        clipboardGateway: widget.clipboardGateway,
        focusMcpOnOpen: _focusMcpOnOpen,
        onMcpFocusHandled: _handleMcpFocusHandled,
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

final class _CalloutHidingResourceManagerLauncher
    implements ResourceManagerLauncher {
  const _CalloutHidingResourceManagerLauncher({
    required this.launcher,
    required this.onHideWindow,
  });

  final ResourceManagerLauncher launcher;
  final Future<void> Function()? onHideWindow;

  @override
  Future<void> show({String? editingResourceId}) async {
    await onHideWindow?.call();
    await launcher.show(editingResourceId: editingResourceId);
  }
}
