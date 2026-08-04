import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_choice_chip.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
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
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (BuildContext context, Widget? child) {
        final ColorScheme colors = Theme.of(context).colorScheme;
        final double maximumHeight = (MediaQuery.sizeOf(context).height - 48)
            .clamp(320.0, 520.0);
        final int visibleRuleCount = widget.viewModel.categoryRules.length
            .clamp(0, 6);
        final double listHeight = (158.0 + (visibleRuleCount * 62.0)).clamp(
          320.0,
          maximumHeight,
        );
        return DesktopDialogTheme(
          child: Dialog(
            insetPadding: DesktopDialogStyle.insetPadding,
            backgroundColor: colors.surfaceContainerLowest,
            surfaceTintColor: Colors.transparent,
            elevation: 5,
            shadowColor: Colors.black.withValues(alpha: 0.18),
            clipBehavior: Clip.antiAlias,
            shape: DesktopDialogStyle.shape(colors),
            child: SizedBox(
              key: const Key('clipboard-category-rules-dialog'),
              width: 600,
              height: _editing == null ? listHeight : maximumHeight,
              child: Column(
                children: <Widget>[
                  _DialogHeader(
                    editing: _editing != null,
                    onBack: () => setState(() => _editing = null),
                    onClose: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                      child: _editing == null
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
    required this.editing,
    required this.onBack,
    required this.onClose,
  });

  final bool editing;
  final VoidCallback onBack;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color controlBackground = colors.surfaceContainerLow.withValues(
      alpha: 0.82,
    );
    return Container(
      height: 72,
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          if (editing)
            DesktopIconButton(
              key: const Key('clipboard-category-back'),
              tooltip: context.localized('Back to categories', '返回分类列表'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              size: 32,
              backgroundColor: controlBackground,
              borderColor: colors.outlineVariant,
            )
          else
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Icon(
                Icons.category_outlined,
                size: 17,
                color: colors.primary,
              ),
            ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  editing
                      ? context.localized('Category rule', '分类规则')
                      : context.localized('Clipboard categories', '剪贴板分类'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 17,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  editing
                      ? context.localized(
                          'Define what content belongs in this category.',
                          '设置进入这个分类的内容条件。',
                        )
                      : context.localized(
                          'Rules run from top to bottom; the first match wins.',
                          '规则从上到下匹配，首个命中分类生效。',
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          DesktopIconButton(
            tooltip: context.localized('Close', '关闭'),
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 16),
            size: 32,
            backgroundColor: controlBackground,
            borderColor: colors.outlineVariant,
          ),
        ],
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
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        Container(
          key: const Key('clipboard-category-priority-toolbar'),
          height: 46,
          padding: const EdgeInsets.fromLTRB(8, 6, 7, 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colors.outlineVariant.withValues(alpha: 0.76),
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: colors.outlineVariant.withValues(alpha: 0.8),
                  ),
                ),
                child: Icon(
                  Icons.sort_rounded,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.localized('Matching priority', '匹配优先级'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurface,
                        fontSize: 11.5,
                        height: 1.15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.localized(
                        'Drag rows to put the first match on top',
                        '拖动排序，优先命中的规则放在上方',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontSize: 9.5,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              DesktopActionButton(
                key: const Key('clipboard-category-add'),
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 15),
                label: context.localized('New category', '新建分类'),
                tone: DesktopActionTone.soft,
                compact: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Container(
            key: const Key('clipboard-category-list-surface'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                color: colors.outlineVariant.withValues(alpha: 0.88),
              ),
            ),
            child: rules.isEmpty
                ? _EmptyRuleList(onCreate: onCreate)
                : ReorderableListView.builder(
                    padding: EdgeInsets.zero,
                    buildDefaultDragHandles: false,
                    itemCount: rules.length,
                    onReorderItem: viewModel.reorderCategories,
                    proxyDecorator:
                        (
                          Widget child,
                          int index,
                          Animation<double> animation,
                        ) => AnimatedBuilder(
                          animation: animation,
                          builder: (BuildContext context, Widget? proxy) {
                            final double elevation = 5 * animation.value;
                            return Material(
                              color: colors.surfaceContainerLowest,
                              elevation: elevation,
                              shadowColor: Colors.black.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(10),
                              clipBehavior: Clip.antiAlias,
                              child: proxy,
                            );
                          },
                          child: child,
                        ),
                    itemBuilder: (BuildContext context, int index) {
                      final ClipboardCategoryRule rule = rules[index];
                      return _RuleRow(
                        key: ValueKey<String>(
                          'clipboard-category-rule-${rule.id}',
                        ),
                        rule: rule,
                        index: index,
                        showDivider: index != rules.length - 1,
                        onEdit: () => onEdit(rule),
                        onEnabledChanged: (bool value) => viewModel
                            .saveCategoryRule(rule.copyWith(enabled: value)),
                        onDelete: () => viewModel.deleteCategoryRule(rule.id),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _EmptyRuleList extends StatelessWidget {
  const _EmptyRuleList({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.inbox_outlined,
            size: 24,
            color: colors.onSurfaceVariant.withValues(alpha: 0.62),
          ),
          const SizedBox(height: 8),
          Text(
            context.localized('No categories yet', '还没有分类'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            context.localized(
              'Create one to start organizing clipboard items.',
              '新建分类后即可开始自动整理剪贴板。',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 10),
          DesktopActionButton(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded, size: 14),
            label: context.localized('New category', '新建分类'),
            tone: DesktopActionTone.soft,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.rule,
    required this.index,
    required this.showDivider,
    required this.onEdit,
    required this.onEnabledChanged,
    required this.onDelete,
    super.key,
  });

  final ClipboardCategoryRule rule;
  final int index;
  final bool showDivider;
  final VoidCallback onEdit;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color accent = _ruleAccent(colors, rule);
    return Column(
      children: <Widget>[
        Material(
          color: rule.enabled
              ? Colors.transparent
              : colors.surfaceContainerLow.withValues(alpha: 0.46),
          child: InkWell(
            onTap: onEdit,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.hovered) ||
                  states.contains(WidgetState.focused)) {
                return colors.primary.withValues(alpha: 0.045);
              }
              if (states.contains(WidgetState.pressed)) {
                return colors.primary.withValues(alpha: 0.07);
              }
              return Colors.transparent;
            }),
            child: SizedBox(
              height: 61,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Row(
                  children: <Widget>[
                    Tooltip(
                      message: context.localized('Reorder', '拖动排序'),
                      child: ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: colors.surfaceContainerLow.withValues(
                              alpha: 0.76,
                            ),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: colors.outlineVariant.withValues(
                                alpha: 0.66,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            size: 15,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      key: Key('clipboard-category-icon-${rule.id}'),
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: Theme.of(context).brightness == Brightness.dark
                              ? 0.18
                              : 0.09,
                        ),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.12),
                        ),
                      ),
                      child: PopupSymbolIcon(
                        _ruleSymbol(rule),
                        size: 16,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Opacity(
                        opacity: rule.enabled ? 1 : 0.58,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _ruleName(context, rule),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontSize: 13,
                                    height: 1.15,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: -0.05,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _ruleSummary(context, rule),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 10.5,
                                    height: 1.1,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Container(
                      key: Key('clipboard-category-actions-${rule.id}'),
                      width: 122,
                      height: 34,
                      padding: const EdgeInsets.fromLTRB(7, 3, 3, 3),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow.withValues(
                          alpha: 0.78,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.72),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Tooltip(
                            message: context.localized('Enabled', '启用'),
                            child: CompactSwitch(
                              value: rule.enabled,
                              onChanged: onEnabledChanged,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 1,
                            height: 18,
                            color: colors.outlineVariant,
                          ),
                          const SizedBox(width: 3),
                          DesktopIconButton(
                            key: Key('clipboard-category-edit-${rule.id}'),
                            tooltip: context.localized('Edit', '编辑'),
                            onPressed: onEdit,
                            size: 27,
                            icon: PopupSymbolIcon(
                              'edit',
                              size: 13.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 1),
                          DesktopIconButton(
                            key: Key('clipboard-category-delete-${rule.id}'),
                            tooltip: context.localized('Delete', '删除'),
                            onPressed: onDelete,
                            size: 27,
                            icon: PopupSymbolIcon(
                              'delete',
                              size: 13.5,
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.78,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 12,
            endIndent: 12,
            color: colors.outlineVariant.withValues(alpha: 0.72),
          ),
      ],
    );
  }
}

String _ruleSymbol(ClipboardCategoryRule rule) => switch (rule.id) {
  'links' => 'link',
  'images' => 'image',
  'files' => 'file',
  'text' => 'text',
  _ => 'filter',
};

Color _ruleAccent(ColorScheme colors, ClipboardCategoryRule rule) =>
    switch (rule.id) {
      'links' => colors.primary,
      'images' => colors.tertiary,
      'files' => colors.secondary,
      'text' => colors.onSurfaceVariant,
      _ => colors.primary,
    };

String _ruleName(BuildContext context, ClipboardCategoryRule rule) =>
    switch (rule.id) {
      'links' => context.localized('Links', '链接'),
      'images' => context.localized('Images', '图片'),
      'files' => context.localized('Files', '文件'),
      'text' => context.localized('Text', '文本'),
      _ => rule.name,
    };

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
            child: DesktopTextField(
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
                DesktopChoiceChip(
                  label: Text(_kindLabel(context, kind)),
                  selected: _kinds.contains(kind),
                  onSelected: (bool selected) => setState(() {
                    selected ? _kinds.add(kind) : _kinds.remove(kind);
                  }),
                  height: 29,
                  borderRadius: 7,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _RuleField(
            label: context.localized('Content regular expression', '内容正则'),
            child: DesktopTextField(
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
            child: DesktopTextField(
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
                  child: DesktopTextField(
                    controller: _minLength,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RuleField(
                  label: context.localized('Maximum characters', '最多字符数'),
                  child: DesktopTextField(
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
            child: DesktopActionButton(
              key: const Key('clipboard-category-save'),
              onPressed: _save,
              label: context.localized('Save category', '保存分类'),
              tone: DesktopActionTone.primary,
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
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colors.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onChanged(!value),
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return colors.primary.withValues(alpha: 0.045);
          }
          return Colors.transparent;
        }),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
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
