import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:flutter/material.dart';

typedef CreateTriggerGroup =
    Future<TriggerGroup> Function({
      required String name,
      required List<TriggerRule> rules,
    });

/// Searchable multi-select picker with inline trigger-group management.
final class TriggerGroupPickerDialog extends StatefulWidget {
  const TriggerGroupPickerDialog({
    required this.groups,
    required this.selectedIds,
    required this.onCreate,
    required this.onUpdate,
    required this.onDelete,
    super.key,
  });

  final List<TriggerGroup> groups;
  final Set<String> selectedIds;
  final CreateTriggerGroup onCreate;
  final Future<void> Function(TriggerGroup group) onUpdate;
  final Future<void> Function(String id) onDelete;

  @override
  State<TriggerGroupPickerDialog> createState() =>
      _TriggerGroupPickerDialogState();
}

final class _TriggerGroupPickerDialogState
    extends State<TriggerGroupPickerDialog> {
  late List<TriggerGroup> _groups;
  late final Set<String> _selectedIds;
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _groups = List<TriggerGroup>.of(widget.groups);
    _selectedIds = <String>{...widget.selectedIds};
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String needle = _query.trim().toLowerCase();
    final List<TriggerGroup> visible =
        _groups
            .where(
              (TriggerGroup group) =>
                  needle.isEmpty ||
                  group.name.toLowerCase().contains(needle) ||
                  group.rules.any(
                    (TriggerRule rule) =>
                        rule.value.toLowerCase().contains(needle),
                  ),
            )
            .toList()
          ..sort(
            (TriggerGroup left, TriggerGroup right) =>
                left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          );
    return DesktopDialogTheme(
      child: Dialog(
        key: const Key('trigger-group-picker'),
        elevation: 3,
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        insetPadding: DesktopDialogStyle.insetPadding,
        clipBehavior: Clip.antiAlias,
        shape: DesktopDialogStyle.shape(colors),
        child: SizedBox(
          width: 520,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  context.localized('Trigger groups', '选择触发组'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  context.localized(
                    'Resources are available only when at least one selected group matches the current project.',
                    '只有当前项目命中至少一个所选触发组时，资源才会生效。',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (_groups.length > 5) ...<Widget>[
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('trigger-group-search'),
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (String value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: context.localized(
                        'Search names or rules',
                        '搜索名称或规则',
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, size: 17),
                      prefixIconConstraints: const BoxConstraints(minWidth: 36),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: visible.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Text(
                            _groups.isEmpty
                                ? context.localized(
                                    'No trigger groups yet',
                                    '还没有触发组',
                                  )
                                : context.localized(
                                    'No matching trigger groups',
                                    '没有匹配的触发组',
                                  ),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: visible.length,
                          itemBuilder: (BuildContext context, int index) {
                            final TriggerGroup group = visible[index];
                            final bool selected = _selectedIds.contains(
                              group.id,
                            );
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == visible.length - 1 ? 0 : 4,
                              ),
                              child: Material(
                                key: ValueKey<String>(
                                  'trigger-group-row-${group.id}',
                                ),
                                color: selected
                                    ? colors.primary.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(5),
                                  onTap: () => setState(() {
                                    selected
                                        ? _selectedIds.remove(group.id)
                                        : _selectedIds.add(group.id);
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      10,
                                      8,
                                      5,
                                      8,
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.filter_alt_outlined,
                                          size: 16,
                                          color: selected
                                              ? colors.primary
                                              : colors.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              Text(
                                                group.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium
                                                    ?.copyWith(
                                                      fontWeight: selected
                                                          ? FontWeight.w600
                                                          : FontWeight.w500,
                                                    ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                _ruleSummary(context, group),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: colors
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          key: ValueKey<String>(
                                            'edit-trigger-group-${group.id}',
                                          ),
                                          tooltip: context.localized(
                                            'Edit rules',
                                            '编辑规则',
                                          ),
                                          onPressed: () => _edit(group),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 2),
                                        SelectionMark(
                                          selected: selected,
                                          size: 17,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[
                    TextButton.icon(
                      key: const Key('create-trigger-group'),
                      onPressed: _create,
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: Text(
                        context.localized('New trigger group', '新建触发组'),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.localized('Cancel', '取消')),
                    ),
                    FilledButton(
                      key: const Key('apply-trigger-groups'),
                      onPressed: () => Navigator.pop(
                        context,
                        Set<String>.unmodifiable(_selectedIds),
                      ),
                      child: Text(context.localized('Apply', '应用')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    final TriggerGroupEditResult? result =
        await showDialog<TriggerGroupEditResult>(
          context: context,
          builder: (BuildContext context) => const TriggerGroupEditorDialog(),
        );
    if (result == null || result.delete) {
      return;
    }
    final TriggerGroup created = await widget.onCreate(
      name: result.name,
      rules: result.rules,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _groups = <TriggerGroup>[..._groups, created];
      _selectedIds.add(created.id);
    });
  }

  Future<void> _edit(TriggerGroup group) async {
    final TriggerGroupEditResult? result =
        await showDialog<TriggerGroupEditResult>(
          context: context,
          builder: (BuildContext context) =>
              TriggerGroupEditorDialog(group: group),
        );
    if (result == null) {
      return;
    }
    if (result.delete) {
      final bool confirmed = await _confirmDelete(group);
      if (!confirmed) {
        return;
      }
      await widget.onDelete(group.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _groups = _groups
            .where((TriggerGroup item) => item.id != group.id)
            .toList(growable: false);
        _selectedIds.remove(group.id);
      });
      return;
    }
    final TriggerGroup updated = group.copyWith(
      name: result.name,
      rules: result.rules,
    );
    await widget.onUpdate(updated);
    if (!mounted) {
      return;
    }
    setState(() {
      _groups = <TriggerGroup>[
        ..._groups.where((TriggerGroup item) => item.id != group.id),
        updated,
      ];
    });
  }

  Future<bool> _confirmDelete(TriggerGroup group) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => DesktopAlertDialog(
            title: Text(
              context.localized(
                'Delete “${group.name}”?',
                '删除「${group.name}」？',
              ),
            ),
            content: Text(
              context.localized(
                'Resources using this group will become unrestricted.',
                '使用此触发组的资源将变为不限制项目。',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.localized('Cancel', '取消')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: DesktopDialogStyle.destructiveButtonStyle(context),
                child: Text(context.localized('Delete', '删除')),
              ),
            ],
          ),
        ) ??
        false;
  }
}

final class TriggerGroupEditResult {
  const TriggerGroupEditResult({
    this.name = '',
    this.rules = const <TriggerRule>[],
    this.delete = false,
  });

  final String name;
  final List<TriggerRule> rules;
  final bool delete;
}

final class TriggerGroupEditorDialog extends StatefulWidget {
  const TriggerGroupEditorDialog({this.group, super.key});

  final TriggerGroup? group;

  @override
  State<TriggerGroupEditorDialog> createState() =>
      _TriggerGroupEditorDialogState();
}

final class _TriggerGroupEditorDialogState
    extends State<TriggerGroupEditorDialog> {
  late final TextEditingController _nameController;
  late final List<_EditableTriggerRule> _rules;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    final List<TriggerRule> rules =
        widget.group?.rules ??
        <TriggerRule>[
          TriggerRule(
            field: TriggerRuleField.projectPath,
            operator: TriggerRuleOperator.contains,
            value: '',
          ),
        ];
    _rules = rules
        .map((TriggerRule rule) => _EditableTriggerRule.fromRule(rule))
        .toList(growable: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (final _EditableTriggerRule rule in _rules) {
      rule.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DesktopDialogTheme(
      child: Dialog(
        key: const Key('trigger-group-editor'),
        elevation: 3,
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        insetPadding: DesktopDialogStyle.insetPadding,
        clipBehavior: Clip.antiAlias,
        shape: DesktopDialogStyle.shape(colors),
        child: SizedBox(
          width: 650,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  widget.group == null
                      ? context.localized('New trigger group', '新建触发组')
                      : context.localized('Edit trigger group', '编辑触发组'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                _DialogLabel(text: context.localized('Group name', '触发组名称')),
                const SizedBox(height: 7),
                TextField(
                  key: const Key('trigger-group-name'),
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: context.localized(
                      'e.g. DingDong projects',
                      '例如：DingDong 项目',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _DialogLabel(
                        text: context.localized(
                          'Match any of these rules',
                          '满足任一规则时触发',
                        ),
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('add-trigger-rule'),
                      onPressed: _addRule,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: Text(context.localized('Add rule', '添加规则')),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Column(
                      children: <Widget>[
                        for (final (int index, _EditableTriggerRule rule)
                            in _rules.indexed)
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: index == _rules.length - 1 ? 0 : 7,
                            ),
                            child: _TriggerRuleRow(
                              key: ValueKey<_EditableTriggerRule>(rule),
                              rule: rule,
                              canDelete: _rules.length > 1,
                              onChanged: () => setState(() => _error = null),
                              onDelete: () => _removeRule(rule),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    key: const Key('trigger-group-error'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.error),
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    if (widget.group != null)
                      TextButton.icon(
                        key: const Key('delete-trigger-group'),
                        onPressed: () => Navigator.pop(
                          context,
                          const TriggerGroupEditResult(delete: true),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: colors.error,
                        ),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 17,
                        ),
                        label: Text(context.localized('Delete', '删除')),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.localized('Cancel', '取消')),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const Key('save-trigger-group'),
                      onPressed: _save,
                      child: Text(context.localized('Save group', '保存触发组')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _addRule() {
    setState(() {
      _rules.add(
        _EditableTriggerRule(
          field: TriggerRuleField.projectPath,
          operator: TriggerRuleOperator.contains,
        ),
      );
    });
  }

  void _removeRule(_EditableTriggerRule rule) {
    if (_rules.length <= 1) {
      return;
    }
    setState(() {
      _rules.remove(rule);
      rule.dispose();
    });
  }

  void _save() {
    final String name = _nameController.text.trim();
    final List<TriggerRule> rules = _rules
        .map((_EditableTriggerRule rule) => rule.toRule())
        .where((TriggerRule rule) => rule.value.isNotEmpty)
        .toList(growable: false);
    if (name.isEmpty) {
      setState(
        () => _error = context.localized(
          'Enter a trigger-group name.',
          '请输入触发组名称。',
        ),
      );
      return;
    }
    if (rules.isEmpty) {
      setState(
        () => _error = context.localized(
          'Add at least one complete rule.',
          '请至少填写一条完整规则。',
        ),
      );
      return;
    }
    Navigator.pop(context, TriggerGroupEditResult(name: name, rules: rules));
  }
}

final class _EditableTriggerRule {
  _EditableTriggerRule({required this.field, required this.operator})
    : controller = TextEditingController();

  factory _EditableTriggerRule.fromRule(TriggerRule rule) {
    return _EditableTriggerRule(field: rule.field, operator: rule.operator)
      ..controller.text = rule.value;
  }

  TriggerRuleField field;
  TriggerRuleOperator operator;
  final TextEditingController controller;

  TriggerRule toRule() =>
      TriggerRule(field: field, operator: operator, value: controller.text);

  void dispose() => controller.dispose();
}

final class _TriggerRuleRow extends StatelessWidget {
  const _TriggerRuleRow({
    required this.rule,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
    super.key,
  });

  final _EditableTriggerRule rule;
  final bool canDelete;
  final VoidCallback onChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 4,
            child: DesktopSelectField<TriggerRuleField>(
              value: rule.field,
              items: <DesktopSelectItem<TriggerRuleField>>[
                DesktopSelectItem<TriggerRuleField>(
                  value: TriggerRuleField.projectPath,
                  label: context.localized('Project directory', '项目目录'),
                ),
                DesktopSelectItem<TriggerRuleField>(
                  value: TriggerRuleField.repositoryUrl,
                  label: context.localized('Repository address', '仓库地址'),
                ),
              ],
              onChanged: (TriggerRuleField value) {
                rule.field = value;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            flex: 3,
            child: DesktopSelectField<TriggerRuleOperator>(
              value: rule.operator,
              items: <DesktopSelectItem<TriggerRuleOperator>>[
                DesktopSelectItem<TriggerRuleOperator>(
                  value: TriggerRuleOperator.equals,
                  label: context.localized('Equals', '等于'),
                ),
                DesktopSelectItem<TriggerRuleOperator>(
                  value: TriggerRuleOperator.contains,
                  label: context.localized('Contains', '包含'),
                ),
              ],
              onChanged: (TriggerRuleOperator value) {
                rule.operator = value;
                onChanged();
              },
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            flex: 6,
            child: TextField(
              controller: rule.controller,
              onChanged: (_) => onChanged(),
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: rule.field == TriggerRuleField.projectPath
                    ? '/workspace/dingdong'
                    : 'github.com/team/dingdong',
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: context.localized('Remove rule', '删除规则'),
            onPressed: canDelete ? onDelete : null,
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

final class _DialogLabel extends StatelessWidget {
  const _DialogLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    ),
  );
}

String _ruleSummary(BuildContext context, TriggerGroup group) {
  return group.rules
      .map((TriggerRule rule) {
        final String field = switch (rule.field) {
          TriggerRuleField.projectPath => context.localized(
            'Project directory',
            '项目目录',
          ),
          TriggerRuleField.repositoryUrl => context.localized(
            'Repository address',
            '仓库地址',
          ),
        };
        final String operator = switch (rule.operator) {
          TriggerRuleOperator.equals => context.localized('equals', '等于'),
          TriggerRuleOperator.contains => context.localized('contains', '包含'),
        };
        return '$field $operator ${rule.value}';
      })
      .join(' · ');
}
