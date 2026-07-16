import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_category_rule.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_context_menu.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_settings_controller.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_category_rules_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_group_context_menu.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_group_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_list_tile.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_organize_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
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
    this.compact = false,
    this.settingsViewModel,
    this.showShortcutHints = false,
    this.onPreview,
    this.onDismissPreview,
    this.onShare,
    this.contextMenuGateway,
    this.filtersExpanded,
    this.onToggleFilters,
    this.searchFocusRevision = 0,
    super.key,
  });

  final ClipboardViewModel viewModel;
  final bool compact;
  final ClipboardSettingsController? settingsViewModel;
  final bool showShortcutHints;
  final Future<void> Function(ClipboardRecord record)? onPreview;
  final Future<void> Function()? onDismissPreview;
  final Future<void> Function(ClipboardRecord record)? onShare;
  final DesktopContextMenuGateway? contextMenuGateway;
  final bool? filtersExpanded;
  final VoidCallback? onToggleFilters;
  final int searchFocusRevision;

  @override
  State<ClipboardScreen> createState() => _ClipboardScreenState();
}

class _ClipboardScreenState extends State<ClipboardScreen>
    with WidgetsBindingObserver {
  bool _showFilters = false;
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'clipboard-search');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.settingsViewModel?.refreshQuickPastePermission());
    if (widget.searchFocusRevision > 0) {
      _scheduleSearchFocus();
    }
  }

  @override
  void didUpdateWidget(covariant ClipboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchFocusRevision != oldWidget.searchFocusRevision) {
      _scheduleSearchFocus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
  bool get compact => widget.compact;
  ClipboardSettingsController? get settingsViewModel =>
      widget.settingsViewModel;
  bool get showShortcutHints => widget.showShortcutHints;
  Future<void> Function(ClipboardRecord record)? get onPreview =>
      widget.onPreview;
  Future<void> Function()? get onDismissPreview => widget.onDismissPreview;
  Future<void> Function(ClipboardRecord record)? get onShare => widget.onShare;
  DesktopContextMenuGateway? get contextMenuGateway =>
      widget.contextMenuGateway;
  bool get filtersExpanded => widget.filtersExpanded ?? _showFilters;

  void _toggleFilters() {
    final VoidCallback? externalToggle = widget.onToggleFilters;
    if (externalToggle != null) {
      externalToggle();
    } else {
      setState(() => _showFilters = !_showFilters);
    }
  }

  void _scheduleSearchFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _focusSearch() => _searchFocusNode.requestFocus();

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
                _toggleFilters();
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
                unawaited(viewModel.restoreVisibleAt(shortcutIndex));
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
                      settingsViewModel: settingsViewModel,
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
                                child: TextField(
                                  key: const Key('clipboard-search'),
                                  focusNode: _searchFocusNode,
                                  onChanged: viewModel.setQuery,
                                  decoration: InputDecoration(
                                    hintText: context.localized(
                                      'Search clipboard history',
                                      '搜索剪贴板历史',
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.search_rounded,
                                      size: 20,
                                    ),
                                    border: const OutlineInputBorder(),
                                    isDense: true,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton.icon(
                                onPressed: viewModel.captureNow,
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: Text(
                                  context.localized('Capture now', '立即捕获'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _ClipboardKindFilters(viewModel: viewModel),
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
                              compact: compact,
                              showShortcutHints: showShortcutHints,
                              onPreview: onPreview,
                              onDismissPreview: onDismissPreview,
                              contextMenuGateway: contextMenuGateway,
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
                                    onRestore: viewModel.restoreSelected,
                                    onTogglePinned: viewModel.togglePinned,
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
