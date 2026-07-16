import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_category_rule.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter/material.dart';

/// Manages ordered clipboard categories and their matching conditions.
class ClipboardCategoryRulesDialog extends StatefulWidget {
  const ClipboardCategoryRulesDialog({required this.viewModel, super.key});

  final ClipboardViewModel viewModel;

  @override
  State<ClipboardCategoryRulesDialog> createState() =>
      _ClipboardCategoryRulesDialogState();
}

class _ClipboardCategoryRulesDialogState
    extends State<ClipboardCategoryRulesDialog> {
  ClipboardCategoryRule? _editing;

  @override
  Widget build(BuildContext context) {
    final double height = (MediaQuery.sizeOf(context).height - 64).clamp(
      360,
      500,
    );
    return Dialog(
      insetPadding: const EdgeInsets.all(32),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        key: const Key('clipboard-category-rules-dialog'),
        width: 580,
        height: height,
        child: Column(
          children: <Widget>[
            SizedBox(
              height: 50,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 5, 10, 5),
                child: Row(
                  children: <Widget>[
                    if (_editing != null)
                      IconButton(
                        key: const Key('clipboard-category-back'),
                        tooltip: context.localized(
                          'Back to categories',
                          '返回分类列表',
                        ),
                        onPressed: () => setState(() => _editing = null),
                        icon: const Icon(Icons.arrow_back_rounded, size: 17),
                      )
                    else
                      const SizedBox(width: 8),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _editing == null
                            ? context.localized('Clipboard categories', '剪贴板分类')
                            : context.localized('Category rule', '分类规则'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: context.localized('Close', '关闭'),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 17),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                child: ListenableBuilder(
                  listenable: widget.viewModel,
                  builder: (BuildContext context, Widget? child) =>
                      _editing == null
                      ? _RuleList(
                          viewModel: widget.viewModel,
                          onEdit: (ClipboardCategoryRule rule) =>
                              setState(() => _editing = rule),
                          onCreate: () => setState(
                            () => _editing = ClipboardCategoryRule(
                              id: 'category-${DateTime.now().microsecondsSinceEpoch}',
                              name: '',
                            ),
                          ),
                        )
                      : _RuleEditor(
                          key: ValueKey<String>(_editing!.id),
                          rule: _editing!,
                          onSave: (ClipboardCategoryRule rule) {
                            widget.viewModel.saveCategoryRule(rule);
                            setState(() => _editing = null);
                          },
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleList extends StatelessWidget {
  const _RuleList({
    required this.viewModel,
    required this.onEdit,
    required this.onCreate,
  });

  final ClipboardViewModel viewModel;
  final ValueChanged<ClipboardCategoryRule> onEdit;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final List<ClipboardCategoryRule> rules = viewModel.categoryRules;
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                context.localized(
                  'Rules run from top to bottom; the first match wins.',
                  '规则从上到下匹配，一个条目只进入第一个命中的分类。',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton.icon(
              key: const Key('clipboard-category-add'),
              onPressed: onCreate,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: Text(context.localized('New category', '新建分类')),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: ReorderableListView.builder(
            itemCount: rules.length,
            onReorderItem: viewModel.reorderCategories,
            itemBuilder: (BuildContext context, int index) {
              final ClipboardCategoryRule rule = rules[index];
              return Material(
                key: ValueKey<String>('clipboard-category-rule-${rule.id}'),
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onEdit(rule),
                  child: Container(
                    height: 54,
                    padding: const EdgeInsets.only(left: 2, right: 2),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        ReorderableDragStartListener(
                          index: index,
                          child: SizedBox.square(
                            dimension: 28,
                            child: Icon(
                              Icons.drag_indicator_rounded,
                              size: 16,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                rule.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _ruleSummary(context, rule),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        CompactSwitch(
                          value: rule.enabled,
                          onChanged: (bool value) => viewModel.saveCategoryRule(
                            rule.copyWith(enabled: value),
                          ),
                        ),
                        const SizedBox(width: 5),
                        IconButton(
                          tooltip: context.localized('Edit', '编辑'),
                          onPressed: () => onEdit(rule),
                          icon: const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                          ),
                        ),
                        IconButton(
                          tooltip: context.localized('Delete', '删除'),
                          onPressed: () =>
                              viewModel.deleteCategoryRule(rule.id),
                          icon: const Icon(
                            Icons.delete_outline_rounded,
                            size: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RuleEditor extends StatefulWidget {
  const _RuleEditor({required this.rule, required this.onSave, super.key});

  final ClipboardCategoryRule rule;
  final ValueChanged<ClipboardCategoryRule> onSave;

  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  late final TextEditingController _name;
  late final TextEditingController _contentPattern;
  late final TextEditingController _sourcePattern;
  late final TextEditingController _minLength;
  late final TextEditingController _maxLength;
  late Set<ClipboardKind> _kinds;
  late bool _enabled;
  late bool _caseSensitive;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.rule.name);
    _contentPattern = TextEditingController(text: widget.rule.contentPattern);
    _sourcePattern = TextEditingController(text: widget.rule.sourcePattern);
    _minLength = TextEditingController(
      text: widget.rule.minCharacters?.toString() ?? '',
    );
    _maxLength = TextEditingController(
      text: widget.rule.maxCharacters?.toString() ?? '',
    );
    _kinds = Set<ClipboardKind>.of(widget.rule.kinds);
    _enabled = widget.rule.enabled;
    _caseSensitive = widget.rule.caseSensitive;
  }

  @override
  void dispose() {
    _name.dispose();
    _contentPattern.dispose();
    _sourcePattern.dispose();
    _minLength.dispose();
    _maxLength.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _RuleField(
            label: context.localized('Category name', '分类名称'),
            child: TextField(
              key: const Key('clipboard-category-name'),
              controller: _name,
              decoration: InputDecoration(
                hintText: context.localized(
                  'For example: Project links',
                  '例如：项目链接',
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            context.localized('Content types', '内容类型'),
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: <Widget>[
              for (final ClipboardKind kind in ClipboardKind.values)
                _KindChoice(
                  label: Text(_kindLabel(context, kind)),
                  selected: _kinds.contains(kind),
                  onPressed: () => setState(() {
                    final bool selected = !_kinds.contains(kind);
                    selected ? _kinds.add(kind) : _kinds.remove(kind);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _RuleField(
            label: context.localized('Content regular expression', '内容正则'),
            child: TextField(
              key: const Key('clipboard-category-content-regex'),
              controller: _contentPattern,
              decoration: const InputDecoration(
                hintText: r'github\.com|dingdong',
              ),
            ),
          ),
          const SizedBox(height: 10),
          _RuleField(
            label: context.localized(
              'Source application regular expression',
              '来源应用正则',
            ),
            child: TextField(
              key: const Key('clipboard-category-source-regex'),
              controller: _sourcePattern,
              decoration: const InputDecoration(
                hintText: r'Chrome|Cursor|Terminal',
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _RuleField(
                  label: context.localized('Minimum characters', '最少字符数'),
                  child: TextField(
                    controller: _minLength,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RuleField(
                  label: context.localized('Maximum characters', '最多字符数'),
                  child: TextField(
                    controller: _maxLength,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _RuleToggle(
                  label: context.localized('Case sensitive', '区分大小写'),
                  value: _caseSensitive,
                  onChanged: (bool value) =>
                      setState(() => _caseSensitive = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RuleToggle(
                  label: context.localized('Enabled', '启用'),
                  value: _enabled,
                  onChanged: (bool value) => setState(() => _enabled = value),
                ),
              ),
            ],
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 9),
              child: Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const Key('clipboard-category-save'),
              onPressed: _save,
              child: Text(context.localized('Save category', '保存分类')),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    final ClipboardCategoryRule rule = widget.rule.copyWith(
      name: _name.text.trim(),
      enabled: _enabled,
      kinds: _kinds,
      contentPattern: _contentPattern.text.trim(),
      sourcePattern: _sourcePattern.text.trim(),
      minCharacters: int.tryParse(_minLength.text.trim()),
      maxCharacters: int.tryParse(_maxLength.text.trim()),
      clearMinCharacters: _minLength.text.trim().isEmpty,
      clearMaxCharacters: _maxLength.text.trim().isEmpty,
      caseSensitive: _caseSensitive,
    );
    final String? error = rule.validationError;
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    widget.onSave(rule);
  }
}

class _RuleField extends StatelessWidget {
  const _RuleField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 5),
      child,
    ],
  );
}

class _KindChoice extends StatelessWidget {
  const _KindChoice({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Widget label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.11)
          : colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          height: 29,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          child: DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected ? colors.primary : colors.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
            child: label,
          ),
        ),
      ),
    );
  }
}

class _RuleToggle extends StatelessWidget {
  const _RuleToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLow,
    borderRadius: BorderRadius.circular(5),
    child: InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(5),
      child: SizedBox(
        height: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              CompactSwitch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    ),
  );
}

String _ruleSummary(BuildContext context, ClipboardCategoryRule rule) {
  final List<String> parts = <String>[
    if (rule.kinds.isNotEmpty)
      rule.kinds
          .map((ClipboardKind kind) => _kindLabel(context, kind))
          .join(' · '),
    if (rule.contentPattern.isNotEmpty)
      context.localized('Content regex', '内容正则'),
    if (rule.sourcePattern.isNotEmpty)
      context.localized('Source regex', '来源正则'),
    if (rule.minCharacters != null || rule.maxCharacters != null)
      context.localized('Length range', '长度范围'),
  ];
  return parts.isEmpty
      ? context.localized('Matches everything', '匹配全部内容')
      : parts.join(' · ');
}

String _kindLabel(BuildContext context, ClipboardKind kind) => switch (kind) {
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
