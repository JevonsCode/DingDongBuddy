part of 'clipboard_screen.dart';

int? _numberShortcutIndex(LogicalKeyboardKey key) {
  final int index = const <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ].indexOf(key);
  return index < 0 ? null : index;
}

class _CompactClipboardToolbar extends StatelessWidget {
  const _CompactClipboardToolbar({
    required this.viewModel,
    required this.searchFocusNode,
    required this.settingsViewModel,
    required this.filtersExpanded,
    required this.showShortcutHint,
    required this.contextMenuGateway,
    required this.onToggleFilters,
  });

  final ClipboardViewModel viewModel;
  final FocusNode searchFocusNode;
  final ClipboardSettingsController? settingsViewModel;
  final bool filtersExpanded;
  final bool showShortcutHint;
  final DesktopContextMenuGateway? contextMenuGateway;
  final VoidCallback onToggleFilters;

  @override
  Widget build(BuildContext context) {
    final ClipboardSettingsController? settings = settingsViewModel;
    final bool clipboardMonitoring = settings?.clipboardMonitoring ?? true;
    final bool filtersActive =
        viewModel.selectedCategoryId != null || viewModel.selectedGroup != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, filtersExpanded ? 12 : 20),
      child: Column(
        children: <Widget>[
          Container(
            height: 54,
            padding: const EdgeInsets.fromLTRB(10, 9, 9, 9),
            decoration: PopupStyle.card(radius: 10),
            child: Row(
              children: <Widget>[
                _ClipboardMonitoringToggle(
                  value: clipboardMonitoring,
                  onChanged: settings?.setClipboardMonitoring,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    key: const Key('clipboard-search'),
                    focusNode: searchFocusNode,
                    onChanged: viewModel.setQuery,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: context.localized('Search clipboard', '搜索剪贴板'),
                      hintStyle: const TextStyle(
                        color: PopupStyle.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      prefixIcon: const SizedBox(
                        width: 40,
                        child: Center(
                          child: PopupSymbolIcon(
                            'search',
                            color: PopupStyle.textSecondary,
                            size: 19,
                          ),
                        ),
                      ),
                      prefixIconConstraints: const BoxConstraints.tightFor(
                        width: 40,
                      ),
                      fillColor: PopupStyle.field,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: filtersExpanded
                      ? context.localized(
                          'Hide categories and groups',
                          '收起分类与分组',
                        )
                      : filtersActive
                      ? context.localized(
                          'Show categories and groups (filters active)',
                          '展开分类与分组（筛选已启用）',
                        )
                      : context.localized(
                          'Show categories and groups',
                          '展开分类与分组',
                        ),
                  child: _FilterToggleButton(
                    filtersExpanded: filtersExpanded,
                    filtersActive: filtersActive,
                    showShortcutHint: showShortcutHint,
                    onPressed: onToggleFilters,
                  ),
                ),
              ],
            ),
          ),
          if (filtersExpanded) ...<Widget>[
            const SizedBox(height: 10),
            _ClipboardKindFilters(viewModel: viewModel),
            if (viewModel.groups.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _ClipboardGroupFilters(
                viewModel: viewModel,
                contextMenuGateway: contextMenuGateway,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ClipboardMonitoringToggle extends StatelessWidget {
  const _ClipboardMonitoringToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onChanged != null;
    return Tooltip(
      message: value
          ? context.localized('Pause clipboard monitoring', '暂停剪贴板监听')
          : context.localized('Turn on clipboard monitoring', '开启剪贴板监听'),
      child: MouseRegion(
        key: const Key('clipboard-monitoring-toggle'),
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: CompactSwitch(
          key: const Key('clipboard-monitoring-switch'),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _FilterToggleButton extends StatefulWidget {
  const _FilterToggleButton({
    required this.filtersExpanded,
    required this.filtersActive,
    required this.showShortcutHint,
    required this.onPressed,
  });

  final bool filtersExpanded;
  final bool filtersActive;
  final bool showShortcutHint;
  final VoidCallback onPressed;

  @override
  State<_FilterToggleButton> createState() => _FilterToggleButtonState();
}

class _FilterToggleButtonState extends State<_FilterToggleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  late final Animation<double> _scale =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 1,
            end: 0.88,
          ).chain(CurveTween(curve: Curves.easeOut)),
          weight: 45,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(
            begin: 0.88,
            end: 1,
          ).chain(CurveTween(curve: Curves.easeOutBack)),
          weight: 55,
        ),
      ]).animate(_controller);

  @override
  void didUpdateWidget(covariant _FilterToggleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filtersExpanded != widget.filtersExpanded ||
        oldWidget.filtersActive != widget.filtersActive) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool highlighted = widget.filtersExpanded || widget.filtersActive;
    final Color foreground = highlighted
        ? PopupStyle.accent
        : PopupStyle.textSecondary;
    final Color background = highlighted
        ? PopupStyle.accentSoft
        : PopupStyle.surface;
    return ScaleTransition(
      key: const Key('clipboard-filter-transition'),
      scale: _scale,
      child: OutlinedButton(
        key: const Key('clipboard-toggle-filters'),
        onPressed: widget.onPressed,
        style: OutlinedButton.styleFrom(
          fixedSize: const Size(35, 36),
          minimumSize: const Size(35, 36),
          padding: EdgeInsets.zero,
          foregroundColor: foreground,
          backgroundColor: background,
          side: BorderSide(
            color: highlighted
                ? PopupStyle.accent.withValues(alpha: 0.32)
                : PopupStyle.border,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          animationDuration: const Duration(milliseconds: 160),
        ),
        child: SizedBox(
          width: 35,
          height: 36,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              if (widget.showShortcutHint)
                const Text(
                  'R',
                  key: Key('clipboard-filter-shortcut'),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                )
              else
                PopupSymbolIcon(
                  widget.filtersExpanded ? 'collapse' : 'filter',
                  key: Key(
                    widget.filtersExpanded
                        ? 'clipboard-collapse-filters-icon'
                        : 'clipboard-filter-icon',
                  ),
                  size: 17,
                  color: foreground,
                ),
              if (widget.filtersActive)
                Positioned(
                  top: 5,
                  right: 5,
                  child: Container(
                    key: const Key('clipboard-filter-active-indicator'),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: PopupStyle.accent,
                      border: Border.all(color: background),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClipboardKindFilters extends StatelessWidget {
  const _ClipboardKindFilters({required this.viewModel});

  final ClipboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final List<ClipboardCategoryRule> categories =
        viewModel.availableCategories;
    return SizedBox(
      height: 30,
      child: Row(
        children: <Widget>[
          _categoryChip(context, null),
          if (categories.isNotEmpty) const SizedBox(width: 6),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (BuildContext context, int index) =>
                  _categoryChip(context, categories[index]),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            key: const Key('clipboard-manage-categories'),
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
    );
  }

  Widget _categoryChip(BuildContext context, ClipboardCategoryRule? category) {
    final String label = switch (category?.id) {
      null => context.localized('All', '全部'),
      'text' => context.localized('Text', '文本'),
      'links' => context.localized('Links', '链接'),
      'images' => context.localized('Images', '图片'),
      'files' => context.localized('Files', '文件'),
      _ => category!.name,
    };
    return FilterChip(
      key: Key('clipboard-category-${category?.id ?? 'all'}'),
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
      selected: viewModel.selectedCategoryId == category?.id,
      onSelected: (_) => viewModel.setCategory(category?.id),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _ClipboardGroupFilters extends StatelessWidget {
  const _ClipboardGroupFilters({
    required this.viewModel,
    required this.contextMenuGateway,
  });

  final ClipboardViewModel viewModel;
  final DesktopContextMenuGateway? contextMenuGateway;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ReorderableListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: viewModel.groups.length,
        onReorderItem: viewModel.reorderGroups,
        buildDefaultDragHandles: false,
        itemBuilder: (BuildContext context, int index) {
          final String group = viewModel.groups[index];
          return Padding(
            key: ValueKey<String>('clipboard-group-$group'),
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTapUp: (TapUpDetails details) => unawaited(
                showClipboardGroupContextMenu(
                  context,
                  globalPosition: details.globalPosition,
                  group: group,
                  viewModel: viewModel,
                  gateway: contextMenuGateway,
                ),
              ),
              child: ReorderableDragStartListener(
                index: index,
                child: FilterChip(
                  avatar: const Icon(Icons.folder_outlined, size: 13),
                  label: Text(
                    group,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  selected: viewModel.selectedGroup == group,
                  onSelected: (bool selected) =>
                      viewModel.setGroup(selected ? group : null),
                  showCheckmark: false,
                  backgroundColor: Colors.transparent,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
