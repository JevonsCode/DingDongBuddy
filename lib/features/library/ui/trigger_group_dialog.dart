import 'dart:io';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

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
    this.exactProjectOnly = false,
    super.key,
  });

  final List<TriggerGroup> groups;
  final Set<String> selectedIds;
  final CreateTriggerGroup onCreate;
  final Future<void> Function(TriggerGroup group) onUpdate;
  final Future<void> Function(String id) onDelete;
  final bool exactProjectOnly;

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
    if (widget.exactProjectOnly) {
      final Set<String> eligibleIds = _groups
          .where(_isExactProjectGroup)
          .map((TriggerGroup group) => group.id)
          .toSet();
      _selectedIds.removeWhere((String id) => !eligibleIds.contains(id));
    }
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
                  (!widget.exactProjectOnly || _isExactProjectGroup(group)) &&
                  (needle.isEmpty ||
                      group.name.toLowerCase().contains(needle) ||
                      group.rules.any(
                        (TriggerRule rule) =>
                            rule.value.toLowerCase().contains(needle),
                      )),
            )
            .toList()
          ..sort(
            (TriggerGroup left, TriggerGroup right) =>
                left.name.toLowerCase().compareTo(right.name.toLowerCase()),
          );
    return DesktopDialogFrame(
      dialogKey: const Key('trigger-group-picker'),
      width: 540,
      maxHeight: 620,
      header: DesktopDialogHeader(
        title: Text(
          widget.exactProjectOnly
              ? context.l10n.projectInstallationScope
              : context.l10n.triggerGroups,
        ),
        subtitle: Text(
          widget.exactProjectOnly
              ? context
                    .l10n
                    .onlyExactExistingProjectDirectoriesCanReceiveANative_7c3d0f93
              : context
                    .l10n
                    .resourcesBecomeAvailableWhenASelectedGroupMatchesThis_ae977468,
        ),
        onClose: () => Navigator.pop(context),
        closeTooltip: context.l10n.close,
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_groups.length > 5) ...<Widget>[
            DesktopSearchField(
              key: const Key('trigger-group-search'),
              controller: _searchController,
              autofocus: true,
              onChanged: (String value) => setState(() => _query = value),
              hintText: context.l10n.searchNamesOrRules,
              clearTooltip: context.l10n.clearSearch,
            ),
          ],
          if (_groups.length > 5) const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: visible.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Text(
                      _groups.isEmpty
                          ? widget.exactProjectOnly
                                ? context.l10n.noProjectGroupsYet
                                : context.l10n.noTriggerGroupsYet
                          : context.l10n.noMatchingTriggerGroups,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: visible.length,
                    itemBuilder: (BuildContext context, int index) {
                      final TriggerGroup group = visible[index];
                      final bool selected = _selectedIds.contains(group.id);
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
                              padding: const EdgeInsets.fromLTRB(10, 8, 5, 8),
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
                                                color: colors.onSurfaceVariant,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DesktopIconButton(
                                    key: ValueKey<String>(
                                      'edit-trigger-group-${group.id}',
                                    ),
                                    tooltip: context.l10n.editRules,
                                    onPressed: () => _edit(group),
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  SelectionMark(selected: selected, size: 17),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      footer: DesktopDialogFooter(
        actions: <Widget>[
          DesktopActionButton(
            key: const Key('create-trigger-group'),
            onPressed: _create,
            icon: const Icon(Icons.add_rounded, size: 17),
            label: widget.exactProjectOnly
                ? context.l10n.newProjectGroup
                : context.l10n.newTriggerGroup,
            tone: DesktopActionTone.soft,
            compact: true,
          ),
          DesktopActionButton(
            onPressed: () => Navigator.pop(context),
            label: context.l10n.cancel,
            compact: true,
          ),
          DesktopActionButton(
            key: const Key('apply-trigger-groups'),
            onPressed: () =>
                Navigator.pop(context, Set<String>.unmodifiable(_selectedIds)),
            label: context.l10n.apply,
            tone: DesktopActionTone.primary,
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final TriggerGroupEditResult? result =
        await showDialog<TriggerGroupEditResult>(
          context: context,
          builder: (BuildContext context) => TriggerGroupEditorDialog(
            exactProjectOnly: widget.exactProjectOnly,
          ),
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
          builder: (BuildContext context) => TriggerGroupEditorDialog(
            group: group,
            exactProjectOnly: widget.exactProjectOnly,
          ),
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
            title: Text(context.l10n.deleteName(group.name)),
            content: Text(
              context.l10n.resourcesUsingThisGroupWillBecomeUnrestricted,
            ),
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
  const TriggerGroupEditorDialog({
    this.group,
    this.exactProjectOnly = false,
    super.key,
  });

  final TriggerGroup? group;
  final bool exactProjectOnly;

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
            operator: widget.exactProjectOnly
                ? TriggerRuleOperator.equals
                : TriggerRuleOperator.contains,
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
    return DesktopDialogFrame(
      dialogKey: const Key('trigger-group-editor'),
      width: 650,
      maxHeight: 680,
      header: DesktopDialogHeader(
        title: Text(
          widget.exactProjectOnly
              ? widget.group == null
                    ? context.l10n.newProjectGroup
                    : context.l10n.editProjectGroup
              : widget.group == null
              ? context.l10n.newTriggerGroup
              : context.l10n.editTriggerGroup,
        ),
        subtitle: Text(
          widget.exactProjectOnly
              ? context.l10n.addOneOrMoreExistingAbsoluteProjectDirectories
              : context.l10n.matchAProjectPathRepositoryOrAgentSource,
        ),
        onClose: () => Navigator.pop(context),
        closeTooltip: context.l10n.close,
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _DialogLabel(text: context.l10n.groupName),
          const SizedBox(height: 7),
          DesktopTextField(
            key: const Key('trigger-group-name'),
            controller: _nameController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: context.l10n.eGDingDongProjects,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _DialogLabel(
                  text: widget.exactProjectOnly
                      ? context.l10n.installInAnyOfTheseProjects
                      : context.l10n.matchAnyOfTheseRules,
                ),
              ),
              DesktopActionButton(
                key: const Key('add-trigger-rule'),
                onPressed: _addRule,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: widget.exactProjectOnly
                    ? context.l10n.addProject
                    : context.l10n.addRule,
                tone: DesktopActionTone.soft,
                compact: true,
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
                        exactProjectOnly: widget.exactProjectOnly,
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
        ],
      ),
      footer: DesktopDialogFooter(
        actions: <Widget>[
          if (widget.group != null)
            DesktopActionButton(
              key: const Key('delete-trigger-group'),
              onPressed: () => Navigator.pop(
                context,
                const TriggerGroupEditResult(delete: true),
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 17),
              label: context.l10n.delete,
              tone: DesktopActionTone.danger,
              compact: true,
            ),
          DesktopActionButton(
            onPressed: () => Navigator.pop(context),
            label: context.l10n.cancel,
            compact: true,
          ),
          DesktopActionButton(
            key: const Key('save-trigger-group'),
            onPressed: _save,
            label: context.l10n.saveGroup,
            tone: DesktopActionTone.primary,
          ),
        ],
      ),
    );
  }

  void _addRule() {
    setState(() {
      _rules.add(
        _EditableTriggerRule(
          field: TriggerRuleField.projectPath,
          operator: widget.exactProjectOnly
              ? TriggerRuleOperator.equals
              : TriggerRuleOperator.contains,
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
      setState(() => _error = context.l10n.enterATriggerGroupName);
      return;
    }
    if (rules.isEmpty) {
      setState(() => _error = context.l10n.addAtLeastOneCompleteRule);
      return;
    }
    if (widget.exactProjectOnly &&
        rules.any(
          (TriggerRule rule) =>
              rule.field != TriggerRuleField.projectPath ||
              rule.operator != TriggerRuleOperator.equals ||
              !path.isAbsolute(path.normalize(rule.value)) ||
              !Directory(path.normalize(rule.value)).existsSync(),
        )) {
      setState(
        () =>
            _error = context.l10n.eachProjectMustBeAnExistingAbsoluteDirectory,
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
    required this.exactProjectOnly,
    required this.canDelete,
    required this.onChanged,
    required this.onDelete,
    super.key,
  });

  final _EditableTriggerRule rule;
  final bool exactProjectOnly;
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
          if (exactProjectOnly)
            SizedBox(
              width: 150,
              child: Text(
                context.l10n.projectDirectoryEquals,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else ...<Widget>[
            Expanded(
              flex: 4,
              child: DesktopSelectField<TriggerRuleField>(
                value: rule.field,
                items: <DesktopSelectItem<TriggerRuleField>>[
                  DesktopSelectItem<TriggerRuleField>(
                    value: TriggerRuleField.projectPath,
                    label: context.l10n.projectDirectory,
                  ),
                  DesktopSelectItem<TriggerRuleField>(
                    value: TriggerRuleField.repositoryUrl,
                    label: context.l10n.repositoryAddress,
                  ),
                  DesktopSelectItem<TriggerRuleField>(
                    value: TriggerRuleField.source,
                    label: context.l10n.agentSource,
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
                    label: context.l10n.equals,
                  ),
                  DesktopSelectItem<TriggerRuleOperator>(
                    value: TriggerRuleOperator.contains,
                    label: context.l10n.contains,
                  ),
                ],
                onChanged: (TriggerRuleOperator value) {
                  rule.operator = value;
                  onChanged();
                },
              ),
            ),
          ],
          const SizedBox(width: 7),
          Expanded(
            flex: 6,
            child: DesktopTextField(
              controller: rule.controller,
              onChanged: (_) => onChanged(),
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: switch (rule.field) {
                  TriggerRuleField.projectPath => '/workspace/dingdong',
                  TriggerRuleField.repositoryUrl => 'github.com/team/dingdong',
                  TriggerRuleField.source => 'Codex, Claude Code, Cursor',
                },
              ),
            ),
          ),
          const SizedBox(width: 4),
          DesktopIconButton(
            tooltip: context.l10n.removeRule,
            onPressed: canDelete ? onDelete : null,
            icon: const Icon(Icons.close_rounded, size: 17),
          ),
        ],
      ),
    );
  }
}

bool _isExactProjectGroup(TriggerGroup group) =>
    group.rules.isNotEmpty &&
    group.rules.every(
      (TriggerRule rule) =>
          rule.field == TriggerRuleField.projectPath &&
          rule.operator == TriggerRuleOperator.equals &&
          path.isAbsolute(path.normalize(rule.value)) &&
          Directory(path.normalize(rule.value)).existsSync(),
    );

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
          TriggerRuleField.projectPath => context.l10n.projectDirectory,
          TriggerRuleField.repositoryUrl => context.l10n.repositoryAddress,
          TriggerRuleField.source => context.l10n.agentSource,
        };
        final String operator = switch (rule.operator) {
          TriggerRuleOperator.equals => context.l10n.equals2,
          TriggerRuleOperator.contains => context.l10n.contains2,
        };
        return '$field $operator ${rule.value}';
      })
      .join(' · ');
}
