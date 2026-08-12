import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_category_rule.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_context_menu.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_source.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_category_rules_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_copy_count.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_group_context_menu.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_group_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_pinned_indicator.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_timestamp_label.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _managerSearchControlHeight = 40;
const double _sourceFilterMenuWidth = 280;

/// Large-window clipboard history manager with bounded lazy rows and bulk actions.
class ClipboardManagerScreen extends StatefulWidget {
  const ClipboardManagerScreen({
    required this.viewModel,
    this.contextMenuGateway,
    this.resourceManagerLauncher,
    this.categoryManagementRequestRevision = 0,
    super.key,
  });

  final ClipboardViewModel viewModel;
  final DesktopContextMenuGateway? contextMenuGateway;
  final ResourceManagerLauncher? resourceManagerLauncher;
  final int categoryManagementRequestRevision;

  @override
  State<ClipboardManagerScreen> createState() => _ClipboardManagerScreenState();
}

class _ClipboardManagerScreenState extends State<ClipboardManagerScreen> {
  final Set<String> _selectedIds = <String>{};
  bool _categoryDialogOpen = false;

  @override
  void initState() {
    super.initState();
    if (widget.categoryManagementRequestRevision > 0) {
      _scheduleCategoryManagement();
    }
  }

  @override
  void didUpdateWidget(covariant ClipboardManagerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.categoryManagementRequestRevision >
        oldWidget.categoryManagementRequestRevision) {
      _scheduleCategoryManagement();
    }
  }

  void _scheduleCategoryManagement() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_showCategoryManagement());
      }
    });
  }

  Future<void> _showCategoryManagement() async {
    if (_categoryDialogOpen) {
      return;
    }
    _categoryDialogOpen = true;
    try {
      await showDialog<void>(
        context: context,
        builder: (BuildContext context) =>
            ClipboardCategoryRulesDialog(viewModel: widget.viewModel),
      );
    } finally {
      _categoryDialogOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: AnimatedBuilder(
        animation: widget.viewModel,
        builder: (BuildContext context, Widget? child) {
          final List<ClipboardRecord> records = widget.viewModel.visibleRecords;
          final bool archiveWorkspace = widget.viewModel.showingArchivedRecords;
          final bool canReorder =
              widget.viewModel.canReorderVisibleRecords && records.length > 1;
          _selectedIds.removeWhere(
            (String id) =>
                !records.any((ClipboardRecord item) => item.id == id),
          );
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 13),
                child: Column(
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          context.localized('Clipboard', '剪贴板'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          '${records.length}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                        const Spacer(),
                        DesktopActionButton(
                          key: const Key('clipboard-manager-select-all'),
                          onPressed: () => setState(() {
                            if (_selectedIds.length == records.length) {
                              _selectedIds.clear();
                            } else {
                              _selectedIds
                                ..clear()
                                ..addAll(
                                  records.map(
                                    (ClipboardRecord item) => item.id,
                                  ),
                                );
                            }
                          }),
                          label:
                              _selectedIds.length == records.length &&
                                  records.isNotEmpty
                              ? context.localized('Clear selection', '取消全选')
                              : context.localized('Select all', '全选'),
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _ManagerSearchField(
                            onChanged: widget.viewModel.setQuery,
                          ),
                        ),
                        if (widget
                            .viewModel
                            .sourceOptions
                            .isNotEmpty) ...<Widget>[
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 220,
                            height: _managerSearchControlHeight,
                            child: _SourceFilterDropdown(
                              viewModel: widget.viewModel,
                            ),
                          ),
                        ],
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 170,
                          height: _managerSearchControlHeight,
                          child: _ClipboardSortDropdown(
                            viewModel: widget.viewModel,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ManagerFilters(
                      viewModel: widget.viewModel,
                      contextMenuGateway: widget.contextMenuGateway,
                      onManageCategories: () =>
                          unawaited(_showCategoryManagement()),
                    ),
                  ],
                ),
              ),
              if (_selectedIds.isNotEmpty)
                _BulkToolbar(
                  count: _selectedIds.length,
                  onAssignGroup: _assignGroup,
                  onDelete: _deleteSelected,
                ),
              Expanded(
                child: Builder(
                  builder: (BuildContext context) {
                    Widget buildRow(BuildContext context, int index) {
                      final ClipboardRecord record = records[index];
                      return _ManagerRow(
                        key: ValueKey<String>(
                          'clipboard-manager-row-${record.id}',
                        ),
                        record: record,
                        categoryLabel:
                            widget.viewModel.categoryFor(record)?.name ??
                            context.localized('Uncategorized', '未分类'),
                        selected: _selectedIds.contains(record.id),
                        showReorderHandle: canReorder,
                        showPinnedIndicator: archiveWorkspace,
                        reorderIndex: index,
                        onChanged: (bool selected) => setState(() {
                          selected
                              ? _selectedIds.add(record.id)
                              : _selectedIds.remove(record.id);
                        }),
                        onOpenDetails: () {
                          widget.viewModel.select(record);
                          unawaited(_showDetails(record));
                        },
                        onSecondaryTapUp: (TapUpDetails details) =>
                            _showItemMenu(record, details.globalPosition),
                      );
                    }

                    if (canReorder) {
                      return ReorderableListView.builder(
                        key: const Key('clipboard-manager-list'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        itemExtent: 60,
                        itemCount: records.length,
                        buildDefaultDragHandles: false,
                        onReorderItem: (int oldIndex, int newIndex) =>
                            widget.viewModel.reorderVisibleRecords(
                              oldIndex,
                              newIndex,
                              newIndexAlreadyAdjusted: true,
                            ),
                        itemBuilder: buildRow,
                      );
                    }
                    return ListView.builder(
                      key: const Key('clipboard-manager-list'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      itemExtent: 60,
                      itemCount: records.length,
                      itemBuilder: buildRow,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _assignGroup() async {
    final Set<String>? groups = await showDialog<Set<String>>(
      context: context,
      builder: (BuildContext context) =>
          ClipboardGroupDialog(availableGroups: widget.viewModel.groups),
    );
    if (groups == null || groups.isEmpty) return;
    widget.viewModel.addManyToGroups(_selectedIds, groups);
    setState(_selectedIds.clear);
  }

  Future<void> _deleteSelected() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => DesktopAlertDialog(
        title: Text(context.localized('Delete selected items?', '删除所选条目？')),
        actions: <Widget>[
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, false),
            label: context.localized('Cancel', '取消'),
            compact: true,
          ),
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, true),
            label: context.localized('Delete', '删除'),
            tone: DesktopActionTone.danger,
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      widget.viewModel.deleteMany(_selectedIds);
      setState(_selectedIds.clear);
    }
  }

  Future<void> _showItemMenu(ClipboardRecord record, Offset position) async {
    widget.viewModel.select(record);
    final _ManagerAction? action = widget.contextMenuGateway == null
        ? await _showMaterialItemMenu(record, position)
        : _managerActionFromNative(
            clipboardActionFromId(
              await widget.contextMenuGateway!.show(
                x: position.dx,
                y: position.dy,
                useChinese:
                    Localizations.localeOf(context).languageCode == 'zh',
                isDark: Theme.of(context).brightness == Brightness.dark,
                items: clipboardContextMenuItems(
                  includeShare: false,
                  includePin: widget.viewModel.showingArchivedRecords,
                  pinned: record.pinned,
                  hasTitle: record.title.trim().isNotEmpty,
                ),
              ),
            ),
          );
    if (action == null || !mounted) {
      return;
    }
    switch (action) {
      case _ManagerAction.details:
        await _showDetails(record);
      case _ManagerAction.copy:
        await widget.viewModel.copySelected();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localized('Copied', '已复制'))),
          );
        }
      case _ManagerAction.togglePinned:
        widget.viewModel.togglePinned();
      case _ManagerAction.addTitle:
        await _editRecord(record, titleOnly: true);
      case _ManagerAction.editText:
        await _editRecord(record, titleOnly: false);
      case _ManagerAction.archiveTo:
        final Set<String>? groups = await showDialog<Set<String>>(
          context: context,
          builder: (BuildContext context) => ClipboardGroupDialog(
            availableGroups: widget.viewModel.groups,
            selectedGroups: record.groupNames.toSet(),
          ),
        );
        if (groups != null && groups.isNotEmpty) {
          widget.viewModel.addSelectedToGroups(groups);
        }
      case _ManagerAction.savePrompt:
        await _openPromptCreation(record);
      case _ManagerAction.delete:
        if (await _confirmSingleDelete()) {
          widget.viewModel.deleteMany(<String>{record.id});
          setState(() => _selectedIds.remove(record.id));
        }
    }
  }

  Future<void> _openPromptCreation(ClipboardRecord record) async {
    final ResourceManagerLauncher? launcher = widget.resourceManagerLauncher;
    if (launcher == null) {
      return;
    }
    await launcher.show(
      createRequest: ResourceManagerCreateRequest(
        type: ResourceType.prompt,
        title: record.title.trim().isEmpty ? null : record.title,
        content: record.content,
      ),
    );
  }

  Future<_ManagerAction?> _showMaterialItemMenu(
    ClipboardRecord record,
    Offset position,
  ) => showDesktopContextMenu<_ManagerAction>(
    context: context,
    globalPosition: position,
    entries: <DesktopMenuEntry<_ManagerAction>>[
      _managerMenuItem(
        context,
        _ManagerAction.details,
        'details',
        'Details',
        '查看详情',
      ),
      _managerMenuItem(context, _ManagerAction.copy, 'copy', 'Copy', '复制'),
      if (widget.viewModel.showingArchivedRecords)
        _managerMenuItem(
          context,
          _ManagerAction.togglePinned,
          'archive',
          record.pinned ? 'Unpin' : 'Pin',
          record.pinned ? '取消置顶' : '置顶',
        ),
      const DesktopMenuDivider<_ManagerAction>(),
      _managerMenuItem(
        context,
        _ManagerAction.addTitle,
        'add_title',
        record.title.trim().isEmpty ? 'Add title' : 'Edit title',
        record.title.trim().isEmpty ? '添加标题' : '修改标题',
      ),
      _managerMenuItem(
        context,
        _ManagerAction.editText,
        'edit',
        'Edit text',
        '编辑文本',
      ),
      _managerMenuItem(
        context,
        _ManagerAction.archiveTo,
        'archive_to',
        'Archive to…',
        '归档到…',
      ),
      _managerMenuItem(
        context,
        _ManagerAction.savePrompt,
        'prompt',
        'Save as prompt',
        '保存为提示词',
      ),
      const DesktopMenuDivider<_ManagerAction>(),
      _managerMenuItem(
        context,
        _ManagerAction.delete,
        'delete',
        'Delete',
        '删除',
        destructive: true,
      ),
    ],
  );

  Future<void> _showDetails(ClipboardRecord record) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => _ClipboardDetailsDialog(
        record: record,
        categoryLabel:
            widget.viewModel.categoryFor(record)?.name ??
            context.localized('Uncategorized', '未分类'),
        onClose: () => Navigator.pop(context),
        onCopy: () async {
          await widget.viewModel.copySelected();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localized('Copied', '已复制'))),
          );
        },
      ),
    );
  }

  Future<void> _editRecord(
    ClipboardRecord record, {
    required bool titleOnly,
  }) async {
    final TextEditingController controller = TextEditingController(
      text: titleOnly ? record.title : record.content,
    );
    final String? value = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => DesktopAlertDialog(
        title: Text(
          titleOnly
              ? context.localized(
                  record.title.trim().isEmpty ? 'Add title' : 'Edit title',
                  record.title.trim().isEmpty ? '添加标题' : '修改标题',
                )
              : context.localized('Edit text', '编辑文本'),
        ),
        content: DesktopTextField(
          controller: controller,
          autofocus: true,
          minLines: titleOnly ? 1 : 6,
          maxLines: titleOnly ? 1 : 12,
        ),
        actions: <Widget>[
          DesktopActionButton(
            onPressed: () => Navigator.pop(context),
            label: context.localized('Cancel', '取消'),
            compact: true,
          ),
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, controller.text),
            label: context.localized('Save', '保存'),
            tone: DesktopActionTone.primary,
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty) {
      return;
    }
    widget.viewModel.organizeSelected(
      title: titleOnly ? value : record.title,
      content: titleOnly ? record.content : value,
      group: record.group,
      tags: record.tags,
    );
  }

  Future<bool> _confirmSingleDelete() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => DesktopAlertDialog(
            title: Text(
              context.localized('Delete this clipboard item?', '删除此剪贴板条目？'),
            ),
            actions: <Widget>[
              DesktopActionButton(
                onPressed: () => Navigator.pop(context, false),
                label: context.localized('Cancel', '取消'),
                compact: true,
              ),
              DesktopActionButton(
                onPressed: () => Navigator.pop(context, true),
                label: context.localized('Delete', '删除'),
                tone: DesktopActionTone.danger,
              ),
            ],
          ),
        ) ??
        false;
  }
}

enum _ManagerAction {
  details,
  copy,
  togglePinned,
  addTitle,
  editText,
  archiveTo,
  savePrompt,
  delete,
}

_ManagerAction? _managerActionFromNative(ClipboardContextAction? action) =>
    switch (action) {
      ClipboardContextAction.paste ||
      ClipboardContextAction.pastePlainText => null,
      ClipboardContextAction.details => _ManagerAction.details,
      ClipboardContextAction.copy => _ManagerAction.copy,
      ClipboardContextAction.togglePinned => _ManagerAction.togglePinned,
      ClipboardContextAction.addTitle => _ManagerAction.addTitle,
      ClipboardContextAction.editText => _ManagerAction.editText,
      ClipboardContextAction.saveAsPrompt => _ManagerAction.savePrompt,
      ClipboardContextAction.archiveTo => _ManagerAction.archiveTo,
      ClipboardContextAction.delete => _ManagerAction.delete,
      ClipboardContextAction.share || null => null,
    };

DesktopMenuItem<_ManagerAction> _managerMenuItem(
  BuildContext context,
  _ManagerAction action,
  String symbol,
  String english,
  String chinese, {
  bool destructive = false,
}) => DesktopMenuItem<_ManagerAction>(
  key: Key('clipboard-manager-action-${action.name}'),
  value: action,
  symbol: symbol,
  label: context.localized(english, chinese),
  destructive: destructive,
);

class _ManagerSearchField extends StatelessWidget {
  const _ManagerSearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DesktopSearchField(
      key: const Key('clipboard-manager-search'),
      surfaceKey: const Key('clipboard-manager-search-surface'),
      searchIconKey: const Key('clipboard-manager-search-icon'),
      height: _managerSearchControlHeight,
      onChanged: onChanged,
      hintText: context.localized('Search clipboard history', '搜索剪贴板历史'),
      clearTooltip: context.localized('Clear search', '清除搜索'),
      backgroundColor: colors.surface,
      borderColor: colors.outlineVariant,
      focusBorderColor: colors.outline,
      borderRadius: 8,
    );
  }
}

BoxDecoration _managerControlDecoration(
  ColorScheme colors, {
  required bool emphasized,
}) => BoxDecoration(
  color: colors.surface,
  border: Border.all(
    color: emphasized ? colors.outline : colors.outlineVariant,
  ),
  borderRadius: BorderRadius.circular(8),
);

class _ClipboardSortDropdown extends StatelessWidget {
  const _ClipboardSortDropdown({required this.viewModel});

  final ClipboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final ClipboardSortMode selected = viewModel.sortMode;
    final String label = switch (selected) {
      ClipboardSortMode.defaultOrder => context.localized(
        'Default order',
        '默认排序',
      ),
      ClipboardSortMode.copyCount => context.localized('Copy count', '按次数排序'),
    };
    return MenuAnchor(
      menuChildren: <Widget>[
        MenuItemButton(
          key: const Key('clipboard-manager-sort-default'),
          leadingIcon: SelectionMark(
            selected: selected == ClipboardSortMode.defaultOrder,
          ),
          onPressed: () =>
              viewModel.setSortMode(ClipboardSortMode.defaultOrder),
          child: Text(context.localized('Default order', '默认排序')),
        ),
        MenuItemButton(
          key: const Key('clipboard-manager-sort-copy-count'),
          leadingIcon: SelectionMark(
            selected: selected == ClipboardSortMode.copyCount,
          ),
          onPressed: () => viewModel.setSortMode(ClipboardSortMode.copyCount),
          child: Text(context.localized('Copy count', '按次数排序')),
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) =>
              Semantics(
                button: true,
                label: context.localized(
                  'Clipboard sort: $label',
                  '剪贴板排序：$label',
                ),
                child: Container(
                  key: const Key('clipboard-manager-sort'),
                  decoration: _managerControlDecoration(
                    colors,
                    emphasized: selected == ClipboardSortMode.copyCount,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: colors.onSurface.withValues(alpha: 0.035),
                      focusColor: colors.onSurface.withValues(alpha: 0.035),
                      onTap: () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.sort_rounded,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 17,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
    );
  }
}

class _SourceFilterDropdown extends StatefulWidget {
  const _SourceFilterDropdown({required this.viewModel});

  final ClipboardViewModel viewModel;

  @override
  State<_SourceFilterDropdown> createState() => _SourceFilterDropdownState();
}

class _SourceFilterDropdownState extends State<_SourceFilterDropdown> {
  final MenuController _menuController = MenuController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'clipboard-manager-source-search',
  );
  String _query = '';
  bool _menuOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<ClipboardSourceOption> sources = widget.viewModel.sourceOptions;
    final String needle = _query.trim().toLowerCase();
    final List<ClipboardSourceOption> filteredSources = sources
        .where(
          (ClipboardSourceOption source) =>
              needle.isEmpty ||
              source.label.toLowerCase().contains(needle) ||
              source.id.toLowerCase().contains(needle),
        )
        .toList(growable: false);
    final double resultsHeight = filteredSources.isEmpty
        ? 42
        : (filteredSources.length * 30.0).clamp(30.0, 150.0);
    final bool hasSelection = widget.viewModel.selectedSourceIds.isNotEmpty;
    final String summary = _summaryLabel(context, sources);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(-_sourceFilterMenuWidth, 6),
      clipBehavior: Clip.antiAlias,
      animated: !reduceMotion,
      onOpen: _handleOpen,
      onClose: _handleClose,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(colors.surface),
        shadowColor: WidgetStatePropertyAll<Color>(
          Colors.black.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.28 : 0.12,
          ),
        ),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        elevation: const WidgetStatePropertyAll<double>(4),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.zero,
        ),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(
            color: colors.outline.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.82 : 0.72,
            ),
          ),
        ),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        alignment: AlignmentDirectional.bottomEnd,
      ),
      menuChildren: <Widget>[
        SizedBox(
          key: const Key('clipboard-manager-source-menu'),
          width: _sourceFilterMenuWidth,
          height: 89 + resultsHeight,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DesktopSearchField(
                  key: const Key('clipboard-manager-source-search'),
                  surfaceKey: const Key(
                    'clipboard-manager-source-search-surface',
                  ),
                  searchIconKey: const Key(
                    'clipboard-manager-source-search-icon',
                  ),
                  clearButtonKey: const Key(
                    'clipboard-manager-source-search-clear',
                  ),
                  height: 34,
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (String value) => setState(() => _query = value),
                  hintText: context.localized('Search sources', '搜索来源'),
                  clearTooltip: context.localized('Clear search', '清除搜索'),
                  backgroundColor: colors.surfaceContainerLow,
                  borderColor: colors.outlineVariant.withValues(alpha: 0.72),
                  focusBorderColor: colors.outline,
                  borderRadius: 6,
                ),
                const SizedBox(height: 6),
                _SourceFilterOption(
                  key: const Key('clipboard-manager-source-all'),
                  label: context.localized('All sources', '全部来源'),
                  selected: !hasSelection,
                  onTap: widget.viewModel.clearSources,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Divider(
                    height: 7,
                    thickness: 1,
                    color: colors.outlineVariant,
                  ),
                ),
                SizedBox(
                  height: resultsHeight,
                  child: filteredSources.isEmpty
                      ? SizedBox(
                          height: 42,
                          child: Center(
                            child: Text(
                              context.localized(
                                'No matching sources',
                                '没有匹配的来源',
                              ),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ),
                        )
                      : ListView.builder(
                          primary: false,
                          itemExtent: 30,
                          itemCount: filteredSources.length,
                          itemBuilder: (BuildContext context, int index) {
                            final ClipboardSourceOption source =
                                filteredSources[index];
                            return _SourceFilterOption(
                              key: Key('clipboard-manager-source-${source.id}'),
                              label: source.label,
                              selected: widget.viewModel.selectedSourceIds
                                  .contains(source.id),
                              onTap: () =>
                                  widget.viewModel.toggleSource(source.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) =>
              Semantics(
                button: true,
                selected: hasSelection,
                expanded: _menuOpen,
                label: context.localized(
                  'Source filter: $summary',
                  '来源筛选：$summary',
                ),
                child: AnimatedContainer(
                  key: const Key('clipboard-manager-source-filter'),
                  height: _managerSearchControlHeight,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                  clipBehavior: Clip.antiAlias,
                  decoration: _managerControlDecoration(
                    colors,
                    emphasized: _menuOpen,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: colors.onSurface.withValues(alpha: 0.035),
                      focusColor: colors.onSurface.withValues(alpha: 0.035),
                      onTap: () {
                        controller.isOpen
                            ? controller.close()
                            : controller.open();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.filter_list_rounded,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                summary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: hasSelection
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Icon(
                              _menuOpen
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 17,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
    );
  }

  String _summaryLabel(
    BuildContext context,
    List<ClipboardSourceOption> sources,
  ) {
    final Set<String> selected = widget.viewModel.selectedSourceIds;
    if (selected.isEmpty) {
      return context.localized('All sources', '全部来源');
    }
    if (selected.length == 1) {
      for (final ClipboardSourceOption source in sources) {
        if (selected.contains(source.id)) {
          return source.label;
        }
      }
    }
    return context.localized(
      '${selected.length} sources',
      '已选 ${selected.length} 个来源',
    );
  }

  void _handleOpen() {
    if (mounted) {
      setState(() => _menuOpen = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _menuController.isOpen) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _handleClose() {
    _searchFocusNode.unfocus();
    if (!mounted) {
      return;
    }
    setState(() {
      _menuOpen = false;
      _query = '';
      _searchController.clear();
    });
  }
}

class _SourceFilterOption extends StatelessWidget {
  const _SourceFilterOption({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.surfaceContainerLow : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: colors.onSurface.withValues(alpha: 0.04),
          focusColor: colors.onSurface.withValues(alpha: 0.04),
          child: SizedBox(
            height: 30,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      height: 1.05,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 17,
                  height: 30,
                  child: selected
                      ? Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: colors.onSurface,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagerFilters extends StatelessWidget {
  const _ManagerFilters({
    required this.viewModel,
    required this.contextMenuGateway,
    required this.onManageCategories,
  });

  final ClipboardViewModel viewModel;
  final DesktopContextMenuGateway? contextMenuGateway;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 30,
          child: Row(
            children: <Widget>[
              _CompactFilterButton(
                key: const Key('clipboard-manager-category-all'),
                label: Text(context.localized('All', '全部')),
                selected: viewModel.selectedCategoryId == null,
                onPressed: () => viewModel.setCategory(null),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: viewModel.availableCategories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (BuildContext context, int index) {
                    final ClipboardCategoryRule rule =
                        viewModel.availableCategories[index];
                    return _CompactFilterButton(
                      key: Key('clipboard-manager-category-${rule.id}'),
                      label: Text(_categoryLabel(context, rule)),
                      selected: viewModel.selectedCategoryId == rule.id,
                      onPressed: () => viewModel.setCategory(rule.id),
                    );
                  },
                ),
              ),
              DesktopIconButton(
                key: const Key('clipboard-manager-categories'),
                tooltip: context.localized('Manage categories', '管理分类'),
                onPressed: onManageCategories,
                icon: const Icon(Icons.tune_rounded, size: 16),
              ),
            ],
          ),
        ),
        if (viewModel.groups.isNotEmpty) ...<Widget>[
          const SizedBox(height: 7),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: viewModel.groups.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (BuildContext context, int index) {
                final String group = viewModel.groups[index];
                return GestureDetector(
                  key: Key('clipboard-manager-group-$group'),
                  behavior: HitTestBehavior.opaque,
                  onSecondaryTapUp: (TapUpDetails details) =>
                      showClipboardGroupContextMenu(
                        context,
                        globalPosition: details.globalPosition,
                        group: group,
                        viewModel: viewModel,
                        gateway: contextMenuGateway,
                      ),
                  child: _CompactFilterButton(
                    icon: Icons.folder_outlined,
                    label: Text(group),
                    selected: viewModel.selectedGroup == group,
                    onPressed: () => viewModel.setGroup(
                      viewModel.selectedGroup == group ? null : group,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactFilterButton extends StatelessWidget {
  const _CompactFilterButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final Widget label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color foreground = selected
        ? colors.primary
        : colors.onSurfaceVariant;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.11)
          : colors.surfaceContainerLow.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(5),
        hoverColor: selected
            ? colors.primary.withValues(alpha: 0.05)
            : colors.onSurface.withValues(alpha: 0.045),
        child: Container(
          height: 28,
          padding: EdgeInsets.symmetric(horizontal: icon == null ? 10 : 9),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 13, color: foreground),
                const SizedBox(width: 6),
              ],
              DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                child: label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _categoryLabel(BuildContext context, ClipboardCategoryRule rule) =>
    switch (rule.id) {
      'text' => context.localized('Text', '文本'),
      'links' => context.localized('Links', '链接'),
      'images' => context.localized('Images', '图片'),
      'files' => context.localized('Files', '文件'),
      _ => rule.name,
    };

class _ClipboardDetailsDialog extends StatelessWidget {
  const _ClipboardDetailsDialog({
    required this.record,
    required this.categoryLabel,
    required this.onClose,
    required this.onCopy,
  });

  final ClipboardRecord record;
  final String categoryLabel;
  final VoidCallback onClose;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String title = record.title.trim().isEmpty
        ? context.localized('Untitled clipboard item', '未命名剪贴板条目')
        : record.title;
    final List<_DetailDatum> overview = <_DetailDatum>[
      _DetailDatum(
        label: context.localized('Category', '分类'),
        value: categoryLabel,
      ),
      _DetailDatum(
        label: context.localized('Content type', '内容类型'),
        value: _clipboardKindLabel(context, record.kind),
      ),
      _DetailDatum(
        label: context.localized('Copy count', '复制次数'),
        value: '${record.copyCount}',
      ),
      _DetailDatum(
        label: context.localized('Updated', '更新时间'),
        value: MaterialLocalizations.of(
          context,
        ).formatMediumDate(record.updatedAt.toLocal()),
      ),
    ];
    return DesktopDialogFrame(
      dialogKey: const Key('clipboard-details-dialog'),
      width: 660,
      maxHeight: (MediaQuery.sizeOf(context).height - 48).clamp(360, 700),
      density: DesktopDialogDensity.editor,
      header: DesktopDialogHeader(
        density: DesktopDialogDensity.editor,
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _clipboardKindIcon(record.kind),
            size: 17,
            color: colors.primary,
          ),
        ),
        title: Text(title),
        subtitle: Text(
          context.localized(
            'Clipboard details and complete content',
            '剪贴板详情与完整内容',
          ),
        ),
        onClose: onClose,
        closeTooltip: context.localized('Close', '关闭'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 52,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: overview.length,
              itemBuilder: (BuildContext context, int index) =>
                  _DetailDatumView(datum: overview[index]),
            ),
            if (record.groupNames.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              _DetailSectionLabel(label: context.localized('Groups', '分组')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: record.groupNames
                    .map((String value) => _MetaChip(label: value))
                    .toList(growable: false),
              ),
            ],
            if (record.sources.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              _DetailSectionLabel(label: context.localized('Sources', '来源')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: record.sources
                    .map((String value) => _MetaChip(label: value))
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 18),
            _DetailSectionLabel(label: context.localized('Content', '内容')),
            const SizedBox(height: 8),
            Container(
              key: const Key('clipboard-details-content'),
              constraints: const BoxConstraints(minHeight: 130),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.72),
                ),
              ),
              child: SelectableText(
                record.sensitive
                    ? context.localized('Sensitive content hidden', '敏感内容已隐藏')
                    : record.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  fontFamily: _clipboardKindIsCodeLike(record.kind)
                      ? 'monospace'
                      : null,
                  color: record.sensitive
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
      footer: DesktopDialogFooter(
        density: DesktopDialogDensity.editor,
        showDivider: true,
        actions: <Widget>[
          DesktopActionButton(
            onPressed: onClose,
            label: context.localized('Close', '关闭'),
            compact: true,
          ),
          DesktopActionButton(
            key: const Key('clipboard-details-copy'),
            onPressed: record.sensitive ? null : () => onCopy(),
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: context.localized('Copy content', '复制内容'),
            tone: DesktopActionTone.primary,
          ),
        ],
      ),
    );
  }
}

final class _DetailDatum {
  const _DetailDatum({required this.label, required this.value});

  final String label;
  final String value;
}

class _DetailDatumView extends StatelessWidget {
  const _DetailDatumView({required this.datum});

  final _DetailDatum datum;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            datum.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            datum.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSectionLabel extends StatelessWidget {
  const _DetailSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    ),
  );
}

String _clipboardKindLabel(BuildContext context, ClipboardKind kind) =>
    switch (kind) {
      ClipboardKind.text => context.localized('Text', '文本'),
      ClipboardKind.url => context.localized('Link', '链接'),
      ClipboardKind.command => context.localized('Command', '命令'),
      ClipboardKind.code => context.localized('Code', '代码'),
      ClipboardKind.json => 'JSON',
      ClipboardKind.path => context.localized('Path', '路径'),
      ClipboardKind.email => context.localized('Email', '邮箱'),
      ClipboardKind.file => context.localized('File', '文件'),
      ClipboardKind.image => context.localized('Image', '图片'),
    };

IconData _clipboardKindIcon(ClipboardKind kind) => switch (kind) {
  ClipboardKind.image => Icons.image_outlined,
  ClipboardKind.file => Icons.description_outlined,
  ClipboardKind.command => Icons.terminal_rounded,
  ClipboardKind.url => Icons.link_rounded,
  ClipboardKind.code || ClipboardKind.json => Icons.code_rounded,
  ClipboardKind.path => Icons.folder_outlined,
  ClipboardKind.email => Icons.mail_outline_rounded,
  ClipboardKind.text => Icons.notes_rounded,
};

bool _clipboardKindIsCodeLike(ClipboardKind kind) =>
    kind == ClipboardKind.command ||
    kind == ClipboardKind.code ||
    kind == ClipboardKind.json;

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}

class _BulkToolbar extends StatelessWidget {
  const _BulkToolbar({
    required this.count,
    required this.onAssignGroup,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onAssignGroup;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('clipboard-bulk-toolbar'),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.symmetric(
          horizontal: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(context.localized('$count selected', '已选择 $count 项')),
          const SizedBox(width: 12),
          DesktopActionButton(
            key: const Key('clipboard-bulk-archive-to'),
            onPressed: onAssignGroup,
            label: context.localized('Archive to…', '归档到…'),
            tone: DesktopActionTone.soft,
          ),
          const Spacer(),
          Container(height: 24, width: 1, color: colors.outlineVariant),
          const SizedBox(width: 12),
          DesktopActionButton(
            key: const Key('clipboard-bulk-delete'),
            onPressed: onDelete,
            label: context.localized('Delete', '删除'),
            tone: DesktopActionTone.danger,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _ManagerRow extends StatefulWidget {
  const _ManagerRow({
    required this.record,
    required this.categoryLabel,
    required this.selected,
    required this.onChanged,
    required this.onOpenDetails,
    required this.onSecondaryTapUp,
    required this.showReorderHandle,
    required this.showPinnedIndicator,
    required this.reorderIndex,
    super.key,
  });

  final ClipboardRecord record;
  final String categoryLabel;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenDetails;
  final GestureTapUpCallback onSecondaryTapUp;
  final bool showReorderHandle;
  final bool showPinnedIndicator;
  final int reorderIndex;

  @override
  State<_ManagerRow> createState() => _ManagerRowState();
}

class _ManagerRowState extends State<_ManagerRow> {
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: <Widget>[
          Material(
            color: widget.selected
                ? colors.primary.withValues(alpha: 0.075)
                : _hovered || _focused
                ? colors.onSurface.withValues(alpha: 0.035)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: FocusableActionDetector(
                key: Key('clipboard-manager-open-${widget.record.id}'),
                focusNode: _focusNode,
                mouseCursor: SystemMouseCursors.click,
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                },
                actions: <Type, Action<Intent>>{
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      widget.onOpenDetails();
                      return null;
                    },
                  ),
                },
                onShowFocusHighlight: (bool value) {
                  if (_focused != value) setState(() => _focused = value);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onOpenDetails,
                  onSecondaryTapUp: widget.onSecondaryTapUp,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _focused
                            ? colors.primary.withValues(alpha: 0.58)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        const SizedBox(width: 5),
                        Semantics(
                          selected: widget.selected,
                          button: true,
                          label: context.localized('Select item', '选择条目'),
                          child: DesktopIconButton(
                            key: Key(
                              'clipboard-manager-select-${widget.record.id}',
                            ),
                            tooltip: context.localized('Select item', '选择条目'),
                            semanticLabel: context.localized(
                              'Select item',
                              '选择条目',
                            ),
                            selected: widget.selected,
                            size: 32,
                            onPressed: () => widget.onChanged(!widget.selected),
                            icon: SelectionMark(selected: widget.selected),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (widget.showReorderHandle)
                          ReorderableDragStartListener(
                            index: widget.reorderIndex,
                            child: Tooltip(
                              message: context.localized('Reorder', '调整顺序'),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  size: 17,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.record.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.record.content.replaceAll('\n', ' '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (widget.record.groupNames.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              widget.record.groupNames.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          color: colors.surfaceContainerLow,
                          child: Text(
                            widget.categoryLabel,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.record.kind.name,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(width: 8),
                        if (widget.record.copyCount > 1) ...<Widget>[
                          ClipboardCopyCount(
                            recordId: widget.record.id,
                            count: widget.record.copyCount,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          clipboardTimestampLabel(
                            context,
                            widget.record.updatedAt,
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(width: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.showPinnedIndicator && widget.record.pinned)
            Positioned(
              top: -7,
              right: -2,
              child: ClipboardPinnedIndicator(
                recordId: widget.record.id,
                keyPrefix: 'clipboard-manager-pinned-indicator',
                color: colors.primary,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}
