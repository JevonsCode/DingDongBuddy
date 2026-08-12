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
        final Size viewport = MediaQuery.sizeOf(context);
        final double maximumHeight = (viewport.height - 48).clamp(0.0, 540.0);
        final int visibleRuleCount = widget.viewModel.categoryRules.length
            .clamp(0, 6);
        final double availableBodyHeight = (maximumHeight - 106).clamp(
          0.0,
          434.0,
        );
        final double naturalListHeight = 46 + (visibleRuleCount * 54.0);
        final double bodyHeight = _editing == null
            ? availableBodyHeight < 216
                  ? availableBodyHeight
                  : naturalListHeight.clamp(216.0, availableBodyHeight)
            : availableBodyHeight;
        final bool compact = viewport.width < 480;
        return DesktopDialogFrame(
          dialogKey: const Key('clipboard-category-rules-dialog'),
          width: 620,
          maxHeight: maximumHeight,
          bodyPadding: EdgeInsets.fromLTRB(
            compact ? 12 : 18,
            10,
            compact ? 12 : 18,
            14,
          ),
          header: _DialogHeader(
            editing: _editing != null,
            onBack: () => setState(() => _editing = null),
            onClose: () => Navigator.pop(context),
          ),
          body: SizedBox(
            height: bodyHeight,
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
    return DesktopDialogHeader(
      onBack: editing ? onBack : null,
      backTooltip: context.localized('Back to categories', '返回分类列表'),
      onClose: onClose,
      closeTooltip: context.localized('Close', '关闭'),
      title: Text(
        editing
            ? context.localized('Category rule', '分类规则')
            : context.localized('Clipboard categories', '剪贴板分类'),
      ),
      subtitle: Text(
        editing
            ? context.localized(
                'Define what content belongs in this category.',
                '设置进入这个分类的内容条件。',
              )
            : context.localized(
                'Rules run from top to bottom; the first match wins.',
                '规则从上到下匹配，首个命中分类生效。',
              ),
      ),
      showDivider: false,
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
          height: 38,
          padding: const EdgeInsets.only(left: 6),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.low_priority_rounded,
                size: 15,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  context.localized(
                    'Priority · first match wins',
                    '匹配顺序 · 上方优先',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 10.75,
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              DesktopActionButton(
                key: const Key('clipboard-category-add'),
                onPressed: onCreate,
                height: 30,
                compact: true,
                icon: const Icon(Icons.add_rounded, size: 14),
                label: context.localized('New category', '新建分类'),
                tone: DesktopActionTone.soft,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            key: const Key('clipboard-category-list-surface'),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow.withValues(
                alpha: Theme.of(context).brightness == Brightness.dark
                    ? 0.32
                    : 0.46,
              ),
              borderRadius: BorderRadius.circular(8),
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
                              borderRadius: BorderRadius.circular(7),
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
                        onEdit: () => onEdit(rule),
                        onEnabledChanged: (bool value) => viewModel
                            .saveCategoryRule(rule.copyWith(enabled: value)),
                        onDelete: () => _confirmDeleteRule(
                          context,
                          rule,
                          () => viewModel.deleteCategoryRule(rule.id),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

Future<void> _confirmDeleteRule(
  BuildContext context,
  ClipboardCategoryRule rule,
  VoidCallback onConfirmed,
) async {
  final bool confirmed =
      await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => DesktopAlertDialog(
          title: Text(context.localized('Delete this category?', '删除这个分类？')),
          content: Text(
            context.localized(
              '“${_ruleName(context, rule)}” and its matching conditions will be removed. Clipboard items are not deleted.',
              '“${_ruleName(context, rule)}”及其匹配条件将被移除，剪贴板条目不会被删除。',
            ),
          ),
          actions: <Widget>[
            DesktopActionButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              label: context.localized('Cancel', '取消'),
              compact: true,
            ),
            DesktopActionButton(
              key: const Key('clipboard-category-delete-confirm'),
              onPressed: () => Navigator.pop(dialogContext, true),
              label: context.localized('Delete category', '删除分类'),
              tone: DesktopActionTone.danger,
            ),
          ],
        ),
      ) ??
      false;
  if (confirmed) onConfirmed();
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
            Icons.filter_alt_off_outlined,
            size: 20,
            color: colors.onSurfaceVariant.withValues(alpha: 0.62),
          ),
          const SizedBox(height: 6),
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
          const SizedBox(height: 9),
          DesktopActionButton(
            onPressed: onCreate,
            height: 30,
            compact: true,
            icon: const Icon(Icons.add_rounded, size: 13),
            label: context.localized('New category', '新建分类'),
            tone: DesktopActionTone.soft,
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
    required this.onEdit,
    required this.onEnabledChanged,
    required this.onDelete,
    super.key,
  });

  final ClipboardCategoryRule rule;
  final int index;
  final VoidCallback onEdit;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color accent = _ruleAccent(colors, rule);
    return Material(
      color: rule.enabled
          ? Colors.transparent
          : colors.surfaceContainerHigh.withValues(alpha: 0.28),
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
          height: 54,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: <Widget>[
                Tooltip(
                  message: context.localized(
                    'Priority ${index + 1} · drag to reorder',
                    '优先级 ${index + 1} · 拖动排序',
                  ),
                  child: ReorderableDragStartListener(
                    index: index,
                    child: SizedBox(
                      width: 24,
                      height: 42,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            '${index + 1}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 9.5,
                                  height: 1,
                                  fontWeight: FontWeight.w600,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                          const SizedBox(height: 2),
                          Icon(
                            Icons.drag_indicator_rounded,
                            size: 13,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.62,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  key: Key('clipboard-category-icon-${rule.id}'),
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent.withValues(
                      alpha: Theme.of(context).brightness == Brightness.dark
                          ? 0.18
                          : 0.09,
                    ),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: PopupSymbolIcon(
                    _ruleSymbol(rule),
                    size: 14,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Container(
                    key: Key('clipboard-category-copy-${rule.id}'),
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
                                  fontSize: 12.75,
                                  height: 1.1,
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
                                  fontSize: 10.25,
                                  height: 1.05,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  key: Key('clipboard-category-actions-${rule.id}'),
                  width: 104,
                  height: 30,
                  child: Row(
                    children: <Widget>[
                      SizedBox(
                        width: 42,
                        child: Center(
                          child: Tooltip(
                            message: rule.enabled
                                ? context.localized('Disable category', '停用分类')
                                : context.localized('Enable category', '启用分类'),
                            child: CompactSwitch(
                              value: rule.enabled,
                              onChanged: onEnabledChanged,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 2),
                      DesktopIconButton(
                        key: Key('clipboard-category-edit-${rule.id}'),
                        tooltip: context.localized('Edit', '编辑'),
                        onPressed: onEdit,
                        size: 28,
                        iconSize: 13,
                        icon: PopupSymbolIcon(
                          'edit',
                          size: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 2),
                      DesktopIconButton(
                        key: Key('clipboard-category-delete-${rule.id}'),
                        tooltip: context.localized('Delete', '删除'),
                        onPressed: onDelete,
                        size: 28,
                        iconSize: 13,
                        icon: PopupSymbolIcon(
                          'delete',
                          size: 13,
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
  bool _showAdvanced = false;
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
      padding: const EdgeInsets.only(bottom: 2),
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
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              for (final ClipboardKind kind in ClipboardKind.values)
                DesktopChoiceChip(
                  leading: Icon(_kindIcon(kind), size: 14),
                  label: Text(_kindLabel(context, kind)),
                  selected: _kinds.contains(kind),
                  onSelected: (bool selected) => setState(() {
                    selected ? _kinds.add(kind) : _kinds.remove(kind);
                  }),
                  height: 30,
                  borderRadius: 8,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        context.localized('Advanced matching', '高级匹配'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.localized(
                          'Use regular expressions only when type and length are not enough.',
                          '仅在类型和长度条件不足时使用正则表达式。',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                DesktopActionButton(
                  key: const Key('clipboard-category-advanced-toggle'),
                  onPressed: () =>
                      setState(() => _showAdvanced = !_showAdvanced),
                  icon: Icon(
                    _showAdvanced
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 15,
                  ),
                  label: _showAdvanced
                      ? context.localized('Hide', '收起')
                      : context.localized('Show', '展开'),
                  compact: true,
                ),
              ],
            ),
          ),
          if (_showAdvanced ||
              _contentPattern.text.isNotEmpty ||
              _sourcePattern.text.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
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
          ],
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
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 140,
              child: DesktopActionButton(
                key: const Key('clipboard-category-save'),
                onPressed: _save,
                height: 36,
                label: context.localized('Save category', '保存分类'),
                tone: DesktopActionTone.primary,
              ),
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
      setState(() => _error = _localizedValidationError(context, error));
      return;
    }
    widget.onSave(rule);
  }
}

String _localizedValidationError(BuildContext context, String error) =>
    switch (error) {
      'Category name is required.' => context.localized(
        'Category name is required.',
        '请输入分类名称。',
      ),
      'Minimum length cannot be negative.' => context.localized(
        'Minimum length cannot be negative.',
        '最少字符数不能为负数。',
      ),
      'Maximum length cannot be negative.' => context.localized(
        'Maximum length cannot be negative.',
        '最多字符数不能为负数。',
      ),
      'Minimum length cannot exceed maximum length.' => context.localized(
        'Minimum length cannot exceed maximum length.',
        '最少字符数不能大于最多字符数。',
      ),
      'Regular expression is invalid.' => context.localized(
        'Regular expression is invalid.',
        '正则表达式格式不正确。',
      ),
      _ => error,
    };

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
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
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
      color: colors.surfaceContainerLow.withValues(alpha: 0.86),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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
          height: 42,
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

IconData _kindIcon(ClipboardKind kind) => switch (kind) {
  ClipboardKind.text => Icons.notes_rounded,
  ClipboardKind.url => Icons.link_rounded,
  ClipboardKind.command => Icons.terminal_rounded,
  ClipboardKind.code => Icons.code_rounded,
  ClipboardKind.json => Icons.data_object_rounded,
  ClipboardKind.path => Icons.folder_outlined,
  ClipboardKind.email => Icons.mail_outline_rounded,
  ClipboardKind.file => Icons.insert_drive_file_outlined,
  ClipboardKind.image => Icons.image_outlined,
};

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
