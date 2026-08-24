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

// Keep the screen state small while private filters, dialogs, and row widgets
// remain implementation details of ClipboardManagerScreen.
part 'clipboard_details_dialog.dart';
part 'clipboard_manager_actions.dart';
part 'clipboard_manager_filters.dart';
part 'clipboard_manager_rows.dart';

const double _managerSearchControlHeight = 40;
const double _sourceFilterMenuWidth = 280;

/// Large-window clipboard history manager with bounded lazy rows and bulk actions.
class ClipboardManagerScreen extends StatefulWidget {
  const ClipboardManagerScreen({
    required this.viewModel,
    this.contextMenuGateway,
    this.resourceManagerLauncher,
    this.categoryManagementRequestRevision = 0,
    this.onCategoryManagementRequestHandled,
    super.key,
  });

  final ClipboardViewModel viewModel;
  final DesktopContextMenuGateway? contextMenuGateway;
  final ResourceManagerLauncher? resourceManagerLauncher;
  final int categoryManagementRequestRevision;
  final ValueChanged<int>? onCategoryManagementRequestHandled;

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
    final int requestRevision = widget.categoryManagementRequestRevision;
    if (requestRevision <= 0) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onCategoryManagementRequestHandled?.call(requestRevision);
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
                          context.l10n.clipboard,
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
                              ? context.l10n.clearSelection
                              : context.l10n.selectAll,
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
                            context.l10n.uncategorized,
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
        title: Text(context.l10n.deleteSelectedItems),
        actions: <Widget>[
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, false),
            label: context.l10n.cancel,
            compact: true,
          ),
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, true),
            label: context.l10n.delete,
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
                isDark: Theme.of(context).brightness == Brightness.dark,
                items: clipboardContextMenuItems(
                  strings: context.l10n,
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.copied)));
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
        context.l10n.details,
      ),
      _managerMenuItem(context, _ManagerAction.copy, 'copy', context.l10n.copy),
      if (widget.viewModel.showingArchivedRecords)
        _managerMenuItem(
          context,
          _ManagerAction.togglePinned,
          'archive',
          record.pinned ? context.l10n.unpin : context.l10n.pin,
        ),
      const DesktopMenuDivider<_ManagerAction>(),
      _managerMenuItem(
        context,
        _ManagerAction.addTitle,
        'add_title',
        record.title.trim().isEmpty
            ? context.l10n.addTitle
            : context.l10n.editTitle,
      ),
      _managerMenuItem(
        context,
        _ManagerAction.editText,
        'edit',
        context.l10n.editText,
      ),
      _managerMenuItem(
        context,
        _ManagerAction.archiveTo,
        'archive_to',
        context.l10n.archiveTo,
      ),
      _managerMenuItem(
        context,
        _ManagerAction.savePrompt,
        'prompt',
        context.l10n.saveAsPrompt,
      ),
      const DesktopMenuDivider<_ManagerAction>(),
      _managerMenuItem(
        context,
        _ManagerAction.delete,
        'delete',
        context.l10n.delete,
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
            context.l10n.uncategorized,
        onClose: () => Navigator.pop(context),
        onCopy: () async {
          await widget.viewModel.copySelected();
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.l10n.copied)));
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
              ? record.title.trim().isEmpty
                    ? context.l10n.addTitle
                    : context.l10n.editTitle
              : context.l10n.editText,
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
            label: context.l10n.cancel,
            compact: true,
          ),
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, controller.text),
            label: context.l10n.save,
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
            title: Text(context.l10n.deleteThisClipboardItem),
            actions: <Widget>[
              DesktopActionButton(
                onPressed: () => Navigator.pop(context, false),
                label: context.l10n.cancel,
                compact: true,
              ),
              DesktopActionButton(
                onPressed: () => Navigator.pop(context, true),
                label: context.l10n.delete,
                tone: DesktopActionTone.danger,
              ),
            ],
          ),
        ) ??
        false;
  }
}
