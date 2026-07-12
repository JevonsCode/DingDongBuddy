import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter/material.dart';

/// Large-window clipboard history manager with bounded lazy rows and bulk actions.
class ClipboardManagerScreen extends StatefulWidget {
  const ClipboardManagerScreen({required this.viewModel, super.key});

  final ClipboardViewModel viewModel;

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
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        key: const Key('clipboard-manager-search'),
                        onChanged: widget.viewModel.setQuery,
                        decoration: InputDecoration(
                          hintText: context.localized(
                            'Search clipboard history',
                            '搜索剪贴板历史',
                          ),
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      key: const Key('clipboard-manager-select-all'),
                      onPressed: () => setState(() {
                        if (_selectedIds.length == records.length) {
                          _selectedIds.clear();
                        } else {
                          _selectedIds
                            ..clear()
                            ..addAll(
                              records.map((ClipboardRecord item) => item.id),
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
              ),
              if (_selectedIds.isNotEmpty)
                _BulkToolbar(
                  count: _selectedIds.length,
                  onArchive: () {
                    widget.viewModel.archiveMany(_selectedIds);
                    setState(_selectedIds.clear);
                  },
                  onAssignGroup: _assignGroup,
                  onEnable: () =>
                      widget.viewModel.setEnabledMany(_selectedIds, true),
                  onDisable: () =>
                      widget.viewModel.setEnabledMany(_selectedIds, false),
                  onDelete: _deleteSelected,
                ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  key: const Key('clipboard-manager-list'),
                  itemExtent: 64,
                  itemCount: records.length,
                  itemBuilder: (BuildContext context, int index) {
                    final ClipboardRecord record = records[index];
                    return _ManagerRow(
                      record: record,
                      selected: _selectedIds.contains(record.id),
                      onChanged: (bool selected) => setState(() {
                        selected
                            ? _selectedIds.add(record.id)
                            : _selectedIds.remove(record.id);
                      }),
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
    final TextEditingController controller = TextEditingController();
    final String? group = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.localized('Assign group', '分配分组')),
        content: TextField(controller: controller, autofocus: true),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.localized('Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(context.localized('Save', '保存')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (group == null) return;
    widget.viewModel.archiveMany(_selectedIds, group: group);
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
}

class _BulkToolbar extends StatelessWidget {
  const _BulkToolbar({
    required this.count,
    required this.onArchive,
    required this.onAssignGroup,
    required this.onEnable,
    required this.onDisable,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onArchive;
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
        OutlinedButton(
          key: const Key('clipboard-bulk-archive'),
          onPressed: onArchive,
          child: Text(context.localized('Archive', '归档')),
        ),
        OutlinedButton(
          onPressed: onAssignGroup,
          child: Text(context.localized('Assign group', '分配分组')),
        ),
        OutlinedButton(onPressed: onEnable, child: const Text('Enable')),
        OutlinedButton(onPressed: onDisable, child: const Text('Disable')),
        TextButton(onPressed: onDelete, child: const Text('Delete')),
      ],
    ),
  );
}

class _ManagerRow extends StatelessWidget {
  const _ManagerRow({
    required this.record,
    required this.selected,
    required this.onChanged,
  });

  final ClipboardRecord record;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: selected
          ? Theme.of(context).colorScheme.secondaryContainer
          : Colors.transparent,
      border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
    ),
    child: Row(
      children: <Widget>[
        Checkbox(
          key: Key('clipboard-manager-select-${record.id}'),
          value: selected,
          onChanged: (bool? value) => onChanged(value ?? false),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(record.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(
                record.content.replaceAll('\n', ' '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (record.group.isNotEmpty) Chip(label: Text(record.group)),
        const SizedBox(width: 12),
        Text(
          TimeOfDay.fromDateTime(record.createdAt.toLocal()).format(context),
        ),
        const SizedBox(width: 20),
      ],
    ),
  );
}
