import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_category_rule.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_context_menu.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_source.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_category_rules_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_group_context_menu.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_group_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_timestamp_label.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter/material.dart';

const double _managerSearchControlHeight = 40;
const double _sourceFilterMenuWidth = 280;

/// Large-window clipboard history manager with bounded lazy rows and bulk actions.
class ClipboardManagerScreen extends StatefulWidget {
  const ClipboardManagerScreen({
    required this.viewModel,
    this.contextMenuGateway,
    super.key,
  });

  final ClipboardViewModel viewModel;
  final DesktopContextMenuGateway? contextMenuGateway;

  @override
  State<ClipboardManagerScreen> createState() => _ClipboardManagerScreenState();
}

class _ClipboardManagerScreenState extends State<ClipboardManagerScreen> {
  final Set<String> _selectedIds = <String>{};

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: AnimatedBuilder(
        animation: widget.viewModel,
        builder: (BuildContext context, Widget? child) {
          final List<ClipboardRecord> records = widget.viewModel.visibleRecords;
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
                        TextButton(
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
                          child: Text(
                            _selectedIds.length == records.length &&
                                    records.isNotEmpty
                                ? context.localized('Clear selection', '取消全选')
                                : context.localized('Select all', '全选'),
                          ),
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
                      ],
                    ),
                    const SizedBox(height: 10),
                    _ManagerFilters(
                      viewModel: widget.viewModel,
                      contextMenuGateway: widget.contextMenuGateway,
                    ),
                  ],
                ),
              ),
              if (_selectedIds.isNotEmpty)
                _BulkToolbar(
                  count: _selectedIds.length,
                  onAssignGroup: _assignGroup,
                  onEnable: () =>
                      widget.viewModel.setEnabledMany(_selectedIds, true),
                  onDisable: () =>
                      widget.viewModel.setEnabledMany(_selectedIds, false),
                  onDelete: _deleteSelected,
                ),
              Expanded(
                child: ListView.builder(
                  key: const Key('clipboard-manager-list'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  itemExtent: 60,
                  itemCount: records.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ClipboardRecord record = records[index];
                    return _ManagerRow(
                      record: record,
                      categoryLabel:
                          widget.viewModel.categoryFor(record)?.name ??
                          context.localized('Uncategorized', '未分类'),
                      selected: _selectedIds.contains(record.id),
                      onChanged: (bool selected) => setState(() {
                        selected
                            ? _selectedIds.add(record.id)
                            : _selectedIds.remove(record.id);
                      }),
                      onSecondaryTapUp: (TapUpDetails details) =>
                          _showItemMenu(record, details.globalPosition),
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
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.localized('Cancel', '取消')),
          ),
          FilledButton(
            style: DesktopDialogStyle.destructiveButtonStyle(context),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.localized('Delete', '删除')),
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
                items: clipboardContextMenuItems(
                  includeShare: false,
                  enabled: record.enabled,
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
        await widget.viewModel.promoteSelected(ResourceType.prompt);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.localized('Saved as prompt', '已保存为提示词')),
            ),
          );
        }
      case _ManagerAction.toggleEnabled:
        widget.viewModel.setEnabledMany(<String>{record.id}, !record.enabled);
      case _ManagerAction.delete:
        if (await _confirmSingleDelete()) {
          widget.viewModel.deleteMany(<String>{record.id});
          setState(() => _selectedIds.remove(record.id));
        }
    }
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
      const DesktopMenuDivider<_ManagerAction>(),
      _managerMenuItem(
        context,
        _ManagerAction.addTitle,
        'add_title',
        'Add title',
        '添加标题',
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
      _managerMenuItem(
        context,
        _ManagerAction.toggleEnabled,
        record.enabled ? 'paused' : 'enabled',
        record.enabled ? 'Disable' : 'Enable',
        record.enabled ? '停用' : '启用',
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
      builder: (BuildContext context) => DesktopAlertDialog(
        maxWidth: 600,
        title: Text(record.title),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: <Widget>[
                  _MetaChip(
                    label:
                        widget.viewModel.categoryFor(record)?.name ??
                        context.localized('Uncategorized', '未分类'),
                  ),
                  _MetaChip(label: record.kind.name),
                  for (final String group in record.groupNames)
                    _MetaChip(label: group),
                ],
              ),
              if (record.source?.isNotEmpty ?? false) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  context.localized(
                    'Source: ${record.source}',
                    '来源：${record.source}',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 14),
              SelectableText(record.content),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.localized('Close', '关闭')),
          ),
        ],
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
              ? context.localized('Add title', '添加标题')
              : context.localized('Edit text', '编辑文本'),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: titleOnly ? 1 : 6,
          maxLines: titleOnly ? 1 : 12,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.localized('Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.localized('Save', '保存')),
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
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.localized('Cancel', '取消')),
              ),
              FilledButton(
                style: DesktopDialogStyle.destructiveButtonStyle(context),
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.localized('Delete', '删除')),
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
  addTitle,
  editText,
  archiveTo,
  savePrompt,
  toggleEnabled,
  delete,
}

_ManagerAction? _managerActionFromNative(ClipboardContextAction? action) =>
    switch (action) {
      ClipboardContextAction.paste ||
      ClipboardContextAction.pastePlainText => null,
      ClipboardContextAction.details => _ManagerAction.details,
      ClipboardContextAction.copy => _ManagerAction.copy,
      ClipboardContextAction.addTitle => _ManagerAction.addTitle,
      ClipboardContextAction.editText => _ManagerAction.editText,
      ClipboardContextAction.saveAsPrompt => _ManagerAction.savePrompt,
      ClipboardContextAction.archiveTo => _ManagerAction.archiveTo,
      ClipboardContextAction.toggleEnabled => _ManagerAction.toggleEnabled,
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

class _ManagerSearchField extends StatefulWidget {
  const _ManagerSearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_ManagerSearchField> createState() => _ManagerSearchFieldState();
}

class _ManagerSearchFieldState extends State<_ManagerSearchField> {
  final FocusNode _focusNode = FocusNode(
    debugLabel: 'clipboard-manager-search',
  );

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _focusNode,
      builder: (BuildContext context, Widget? child) => AnimatedContainer(
        key: const Key('clipboard-manager-search-surface'),
        height: _managerSearchControlHeight,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        clipBehavior: Clip.antiAlias,
        decoration: _managerControlDecoration(
          colors,
          emphasized: _focusNode.hasFocus,
        ),
        child: child,
      ),
      child: _CenteredSearchInput(
        textFieldKey: const Key('clipboard-manager-search'),
        iconKey: const Key('clipboard-manager-search-icon'),
        height: _managerSearchControlHeight,
        leadingWidth: 38,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        hintText: context.localized('Search clipboard history', '搜索剪贴板历史'),
      ),
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
  borderRadius: BorderRadius.circular(5),
);

class _CenteredSearchInput extends StatelessWidget {
  const _CenteredSearchInput({
    required this.textFieldKey,
    required this.iconKey,
    required this.height,
    required this.leadingWidth,
    required this.focusNode,
    required this.onChanged,
    required this.hintText,
    this.controller,
    this.onClear,
  });

  final Key textFieldKey;
  final Key iconKey;
  final double height;
  final double leadingWidth;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final String hintText;
  final TextEditingController? controller;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final TextStyle? textStyle = theme.textTheme.bodyMedium?.copyWith(
      height: 1.05,
      fontWeight: FontWeight.w400,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox(
          key: iconKey,
          width: leadingWidth,
          height: height,
          child: Center(
            child: Icon(
              Icons.search_rounded,
              size: height <= 32 ? 16 : 17,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: TextField(
              key: textFieldKey,
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              maxLines: 1,
              cursorColor: colors.onSurfaceVariant,
              cursorHeight: height <= 32 ? 16 : 17,
              cursorWidth: 1.5,
              style: textStyle,
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                hintText: hintText,
                hintStyle: textStyle?.copyWith(color: colors.onSurfaceVariant),
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
        if (onClear != null)
          Semantics(
            button: true,
            label: context.localized('Clear search', '清除搜索'),
            child: GestureDetector(
              key: const Key('clipboard-manager-source-search-clear'),
              behavior: HitTestBehavior.opaque,
              onTap: onClear,
              child: SizedBox(
                width: 28,
                height: height,
                child: Center(
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          )
        else
          const SizedBox(width: 8),
      ],
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
                Container(
                  key: const Key('clipboard-manager-source-search-surface'),
                  height: 34,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _CenteredSearchInput(
                    textFieldKey: const Key('clipboard-manager-source-search'),
                    iconKey: const Key('clipboard-manager-source-search-icon'),
                    height: 32,
                    leadingWidth: 34,
                    controller: _searchController,
                    focusNode: _searchFocusNode,
                    onChanged: (String value) => setState(() => _query = value),
                    hintText: context.localized('Search sources', '搜索来源'),
                    onClear: _query.isEmpty ? null : _clearSearch,
                  ),
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
                      borderRadius: BorderRadius.circular(5),
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

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
    _searchFocusNode.requestFocus();
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
  });

  final ClipboardViewModel viewModel;
  final DesktopContextMenuGateway? contextMenuGateway;

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
              IconButton(
                key: const Key('clipboard-manager-categories'),
                tooltip: context.localized('Manage categories', '管理分类'),
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (BuildContext context) =>
                      ClipboardCategoryRulesDialog(viewModel: viewModel),
                ),
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
    required this.onEnable,
    required this.onDisable,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onAssignGroup;
  final VoidCallback onEnable;
  final VoidCallback onDisable;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('clipboard-bulk-toolbar'),
    padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
    child: Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        Text(context.localized('$count selected', '已选择 $count 项')),
        FilledButton.tonal(
          key: const Key('clipboard-bulk-archive-to'),
          onPressed: onAssignGroup,
          child: Text(context.localized('Archive to…', '归档到…')),
        ),
        TextButton(
          onPressed: onEnable,
          child: Text(context.localized('Enable', '启用')),
        ),
        TextButton(
          onPressed: onDisable,
          child: Text(context.localized('Disable', '停用')),
        ),
        TextButton(
          onPressed: onDelete,
          child: Text(context.localized('Delete', '删除')),
        ),
      ],
    ),
  );
}

class _ManagerRow extends StatelessWidget {
  const _ManagerRow({
    required this.record,
    required this.categoryLabel,
    required this.selected,
    required this.onChanged,
    required this.onSecondaryTapUp,
  });

  final ClipboardRecord record;
  final String categoryLabel;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final GestureTapUpCallback onSecondaryTapUp;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        key: ValueKey<String>('clipboard-manager-row-${record.id}'),
        color: selected
            ? colors.primary.withValues(alpha: 0.075)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapUp: onSecondaryTapUp,
          child: InkWell(
            borderRadius: BorderRadius.circular(5),
            onTap: () => onChanged(!selected),
            child: Row(
              children: <Widget>[
                const SizedBox(width: 5),
                Semantics(
                  selected: selected,
                  button: true,
                  child: SizedBox.square(
                    key: Key('clipboard-manager-select-${record.id}'),
                    dimension: 32,
                    child: Center(child: SelectionMark(selected: selected)),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        record.content.replaceAll('\n', ' '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (record.groupNames.isNotEmpty)
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
                      record.groupNames.join(' · '),
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
                    categoryLabel,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  record.kind.name,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  clipboardTimestampLabel(context, record.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
