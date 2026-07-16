import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_category_rule.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_context_menu.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_category_rules_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_group_context_menu.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_group_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter/material.dart';

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
                    TextField(
                      key: const Key('clipboard-manager-search'),
                      onChanged: widget.viewModel.setQuery,
                      decoration: InputDecoration(
                        hintText: context.localized(
                          'Search clipboard history',
                          '搜索剪贴板历史',
                        ),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 38,
                        ),
                      ),
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
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.localized('Delete selected items?', '删除所选条目？')),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.localized('Cancel', '取消')),
          ),
          FilledButton(
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
  ) => showMenu<_ManagerAction>(
    context: context,
    position: desktopContextMenuPosition(context, position),
    popUpAnimationStyle: AnimationStyle.noAnimation,
    items: <PopupMenuEntry<_ManagerAction>>[
      _managerMenuItem(
        context,
        _ManagerAction.details,
        Icons.info_outline_rounded,
        'Details',
        '查看详情',
      ),
      _managerMenuItem(
        context,
        _ManagerAction.copy,
        Icons.copy_rounded,
        'Copy',
        '复制',
      ),
      const PopupMenuDivider(),
      _managerMenuItem(
        context,
        _ManagerAction.addTitle,
        Icons.title_rounded,
        'Add title',
        '添加标题',
      ),
      _managerMenuItem(
        context,
        _ManagerAction.editText,
        Icons.edit_outlined,
        'Edit text',
        '编辑文本',
      ),
      _managerMenuItem(
        context,
        _ManagerAction.archiveTo,
        Icons.create_new_folder_outlined,
        'Archive to…',
        '归档到…',
      ),
      _managerMenuItem(
        context,
        _ManagerAction.savePrompt,
        Icons.format_quote_rounded,
        'Save as prompt',
        '保存为提示词',
      ),
      _managerMenuItem(
        context,
        _ManagerAction.toggleEnabled,
        record.enabled
            ? Icons.pause_circle_outline_rounded
            : Icons.play_circle_outline_rounded,
        record.enabled ? 'Disable' : 'Enable',
        record.enabled ? '停用' : '启用',
      ),
      const PopupMenuDivider(),
      _managerMenuItem(
        context,
        _ManagerAction.delete,
        Icons.delete_outline_rounded,
        'Delete',
        '删除',
      ),
    ],
  );

  Future<void> _showDetails(ClipboardRecord record) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
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
      builder: (BuildContext context) => AlertDialog(
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
          builder: (BuildContext context) => AlertDialog(
            title: Text(
              context.localized('Delete this clipboard item?', '删除此剪贴板条目？'),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.localized('Cancel', '取消')),
              ),
              FilledButton(
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

PopupMenuItem<_ManagerAction> _managerMenuItem(
  BuildContext context,
  _ManagerAction action,
  IconData icon,
  String english,
  String chinese,
) => PopupMenuItem<_ManagerAction>(
  key: Key('clipboard-manager-action-${action.name}'),
  value: action,
  child: Row(
    children: <Widget>[
      Icon(icon, size: 17),
      const SizedBox(width: 9),
      Flexible(
        child: Text(
          context.localized(english, chinese),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  ),
);

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
                  TimeOfDay.fromDateTime(
                    record.createdAt.toLocal(),
                  ).format(context),
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
