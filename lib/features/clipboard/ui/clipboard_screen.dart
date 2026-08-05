import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/platform/desktop_platform_policy.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_choice_chip.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_category_rule.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_content_launcher.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_context_menu.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_settings_controller.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_category_rules_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_group_context_menu.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_group_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_list_tile.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_organize_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'clipboard_actions.dart';
part 'clipboard_filter_bar.dart';
part 'clipboard_permission_banner.dart';
part 'clipboard_preview_pane.dart';
part 'clipboard_record_list.dart';

/// Searchable lazy clipboard history with an adaptive preview pane.
class ClipboardScreen extends StatefulWidget {
  const ClipboardScreen({
    required this.viewModel,
    this.settingsViewModel,
    this.showShortcutHints = false,
    this.showPlainTextShortcutHints = false,
    this.onPreview,
    this.onOpenContent,
    this.onDismissPreview,
    this.onShare,
    this.contextMenuGateway,
    this.resourceManagerLauncher,
    this.filtersExpanded,
    this.onToggleFilters,
    this.onShortcutStartIndexChanged,
    this.searchFocusRevision = 0,
    this.now,
    super.key,
  });

  final ClipboardViewModel viewModel;
  final ClipboardSettingsController? settingsViewModel;
  final bool showShortcutHints;
  final bool showPlainTextShortcutHints;
  final Future<void> Function(ClipboardRecord record)? onPreview;
  final Future<void> Function(ClipboardRecord record)? onOpenContent;
  final Future<void> Function()? onDismissPreview;
  final Future<void> Function(ClipboardRecord record)? onShare;
  final DesktopContextMenuGateway? contextMenuGateway;
  final ResourceManagerLauncher? resourceManagerLauncher;
  final bool? filtersExpanded;
  final VoidCallback? onToggleFilters;
  final ValueChanged<int>? onShortcutStartIndexChanged;
  final int searchFocusRevision;
  final DateTime Function()? now;

  @override
  State<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends State<ClipboardScreen>
    with WidgetsBindingObserver {
  bool _showFilters = false;
  int _shortcutStartIndex = 0;
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'clipboard-search');
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController = TextEditingController(text: viewModel.query);
    viewModel.addListener(_syncSearchController);
    unawaited(widget.settingsViewModel?.refreshQuickPastePermission());
    if (widget.searchFocusRevision > 0) {
      _scheduleSearchFocus();
    }
  }

  @override
  void didUpdateWidget(covariant ClipboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      oldWidget.viewModel.removeListener(_syncSearchController);
      widget.viewModel.addListener(_syncSearchController);
      _syncSearchController();
    }
    if (widget.searchFocusRevision != oldWidget.searchFocusRevision) {
      _scheduleSearchFocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    viewModel.removeListener(_syncSearchController);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.settingsViewModel?.refreshQuickPastePermission());
    }
  }

  ClipboardViewModel get viewModel => widget.viewModel;
  ClipboardSettingsController? get settingsViewModel =>
      widget.settingsViewModel;
  bool get showShortcutHints => widget.showShortcutHints;
  bool get showPlainTextShortcutHints => widget.showPlainTextShortcutHints;
  Future<void> Function(ClipboardRecord record)? get onPreview =>
      widget.onPreview;
  Future<void> Function(ClipboardRecord record)? get onOpenContent =>
      widget.onOpenContent;
  Future<void> Function()? get onDismissPreview => widget.onDismissPreview;
  Future<void> Function(ClipboardRecord record)? get onShare => widget.onShare;
  DesktopContextMenuGateway? get contextMenuGateway =>
      widget.contextMenuGateway;
  ResourceManagerLauncher? get resourceManagerLauncher =>
      widget.resourceManagerLauncher;
  bool get filtersExpanded => widget.filtersExpanded ?? _showFilters;

  void _toggleFilters() {
    final VoidCallback? externalToggle = widget.onToggleFilters;
    if (externalToggle != null) {
      externalToggle();
    } else {
      setState(() => _showFilters = !_showFilters);
    }
  }

  void _handleFilterShortcut() {
    if (!filtersExpanded) {
      _toggleFilters();
      return;
    }
    if (viewModel.hasActiveFilters) {
      viewModel.clearFilters();
      return;
    }
    _toggleFilters();
  }

  void _scheduleSearchFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _focusSearch() => _searchFocusNode.requestFocus();

  void _syncSearchController() {
    final String query = viewModel.query;
    if (_searchController.text == query) {
      return;
    }
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
  }

  void _handleShortcutStartIndexChanged(int index) {
    _shortcutStartIndex = index;
    widget.onShortcutStartIndexChanged?.call(index);
  }

  Future<void> _openContent(
    BuildContext context,
    ClipboardRecord record,
  ) async {
    try {
      await onOpenContent?.call(record);
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.localized(
              'This content is no longer available or could not be opened.',
              '该内容已不存在或无法打开。',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (BuildContext context, Widget? child) {
        final bool callout = MediaQuery.sizeOf(context).width < 600;
        return CallbackShortcuts(
          bindings: <ShortcutActivator, VoidCallback>{
            const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
                _focusSearch,
            const SingleActivator(LogicalKeyboardKey.keyF, control: true):
                _focusSearch,
          },
          child: Focus(
            autofocus: true,
            onKeyEvent: (FocusNode node, KeyEvent event) {
              if (event is! KeyDownEvent) {
                return KeyEventResult.ignored;
              }
              final HardwareKeyboard keyboard = HardwareKeyboard.instance;
              if (event.logicalKey == LogicalKeyboardKey.keyR &&
                  (keyboard.isMetaPressed || keyboard.isControlPressed)) {
                _handleFilterShortcut();
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                viewModel.moveSelection(1);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                viewModel.moveSelection(-1);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.space) {
                final ClipboardRecord? selected =
                    viewModel.selectedRecord ??
                    (viewModel.visibleRecords.isEmpty
                        ? null
                        : viewModel.visibleRecords.first);
                if (selected != null) {
                  viewModel.select(selected);
                  unawaited(onPreview?.call(selected));
                }
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.enter) {
                unawaited(_useSelectedClipboardItem());
                return KeyEventResult.handled;
              }
              final int? shortcutIndex = _numberShortcutIndex(event.logicalKey);
              if (shortcutIndex != null &&
                  (keyboard.isMetaPressed || keyboard.isControlPressed)) {
                unawaited(
                  viewModel.restoreVisibleAt(
                    _shortcutStartIndex + shortcutIndex,
                    mode:
                        defaultTargetPlatform == TargetPlatform.macOS &&
                            keyboard.isAltPressed
                        ? ClipboardPasteMode.plainText
                        : ClipboardPasteMode.original,
                  ),
                );
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              child: Column(
                children: <Widget>[
                  if (settingsViewModel != null)
                    _ClipboardPermissionBanner(viewModel: settingsViewModel!),
                  if (callout)
                    _CompactClipboardToolbar(
                      viewModel: viewModel,
                      searchFocusNode: _searchFocusNode,
                      searchController: _searchController,
                      filtersExpanded: filtersExpanded,
                      showShortcutHint: showShortcutHints,
                      contextMenuGateway: contextMenuGateway,
                      onToggleFilters: _toggleFilters,
                    )
                  else ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: DesktopSearchField(
                                  key: const Key('clipboard-search'),
                                  focusNode: _searchFocusNode,
                                  controller: _searchController,
                                  onChanged: viewModel.setQuery,
                                  height: 40,
                                  hintText: context.localized(
                                    'Search clipboard history',
                                    '搜索剪贴板历史',
                                  ),
                                  clearTooltip: context.localized(
                                    'Clear search',
                                    '清除搜索',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              DesktopActionButton(
                                onPressed: viewModel.captureNow,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: context.localized('Capture now', '立即捕获'),
                                tone: DesktopActionTone.primary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _ClipboardKindFilters(
                            viewModel: viewModel,
                            showResetShortcutHint: false,
                          ),
                          if (viewModel.groups.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 8),
                            _ClipboardGroupFilters(
                              viewModel: viewModel,
                              contextMenuGateway: contextMenuGateway,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                  ],
                  Expanded(
                    child: LayoutBuilder(
                      builder:
                          (BuildContext context, BoxConstraints constraints) {
                            final Widget list = _ClipboardList(
                              viewModel: viewModel,
                              includeShare: onShare != null,
                              showShortcutHints: showShortcutHints,
                              showPlainTextShortcutHints:
                                  showPlainTextShortcutHints,
                              onShortcutStartIndexChanged:
                                  _handleShortcutStartIndexChanged,
                              onPreview: onPreview,
                              onOpenContent: onOpenContent,
                              onDismissPreview: onDismissPreview,
                              contextMenuGateway: contextMenuGateway,
                              now: widget.now?.call() ?? DateTime.now(),
                              onAction: (_ClipboardAction action) =>
                                  _handleAction(context, action),
                            );
                            if (constraints.maxWidth < 900) {
                              return list;
                            }
                            return Row(
                              children: <Widget>[
                                SizedBox(
                                  width: constraints.maxWidth * 0.55,
                                  child: list,
                                ),
                                const VerticalDivider(width: 1),
                                Expanded(
                                  child: _ClipboardPreview(
                                    record: viewModel.selectedRecord,
                                    onRestore: () async {
                                      await viewModel.restoreSelected();
                                    },
                                    onTogglePinned: viewModel.togglePinned,
                                    onOpen: onOpenContent == null
                                        ? null
                                        : (ClipboardRecord record) =>
                                              _openContent(context, record),
                                    onAction: (_ClipboardAction action) =>
                                        _handleAction(context, action),
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _useSelectedClipboardItem() async {
    final ClipboardRecord? selected =
        viewModel.selectedRecord ??
        (viewModel.visibleRecords.isEmpty
            ? null
            : viewModel.visibleRecords.first);
    if (selected == null) {
      return;
    }
    viewModel.select(selected);
    await onDismissPreview?.call();
    await viewModel.restoreSelected();
  }
}
