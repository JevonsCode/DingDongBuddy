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
    required this.searchController,
    required this.filtersExpanded,
    required this.showShortcutHint,
    required this.showGroupShortcutHints,
    required this.contextMenuGateway,
    required this.onGroupShortcutStartIndexChanged,
    required this.onToggleFilters,
  });

  final ClipboardViewModel viewModel;
  final FocusNode searchFocusNode;
  final TextEditingController searchController;
  final bool filtersExpanded;
  final bool showShortcutHint;
  final bool showGroupShortcutHints;
  final DesktopContextMenuGateway? contextMenuGateway;
  final ValueChanged<int> onGroupShortcutStartIndexChanged;
  final VoidCallback onToggleFilters;

  @override
  Widget build(BuildContext context) {
    final bool filtersActive = viewModel.hasActiveFilters;
    final bool showResetShortcutHint =
        showShortcutHint && filtersExpanded && filtersActive;
    final bool showFilterToggleShortcutHint =
        showShortcutHint && !showResetShortcutHint;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 14, 16, filtersExpanded ? 12 : 20),
      child: Column(
        children: <Widget>[
          Container(
            height: 58,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: PopupStyle.card(radius: 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: DesktopSearchField(
                    key: const Key('clipboard-search'),
                    focusNode: searchFocusNode,
                    controller: searchController,
                    onChanged: viewModel.setQuery,
                    height: 38,
                    hintText: context.localized('Search clipboard', '搜索剪贴板'),
                    clearTooltip: context.localized('Clear search', '清除搜索'),
                    style: const TextStyle(fontSize: 12),
                    hintStyle: const TextStyle(
                      color: PopupStyle.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    searchIcon: const PopupSymbolIcon(
                      'search',
                      color: PopupStyle.textSecondary,
                      size: 19,
                    ),
                    backgroundColor: PopupStyle.field,
                    borderColor: PopupStyle.border,
                    focusBorderColor: PopupStyle.accent,
                    foregroundColor: PopupStyle.textSecondary,
                    borderRadius: 8,
                  ),
                ),
                const SizedBox(width: 8),
                _FilterToggleButton(
                  filtersExpanded: filtersExpanded,
                  filtersActive: filtersActive,
                  showShortcutHint: showFilterToggleShortcutHint,
                  onPressed: onToggleFilters,
                ),
              ],
            ),
          ),
          if (filtersExpanded) ...<Widget>[
            const SizedBox(height: 10),
            _ClipboardKindFilters(
              viewModel: viewModel,
              showResetShortcutHint: showResetShortcutHint,
            ),
            if (viewModel.groups.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _ClipboardGroupFilters(
                viewModel: viewModel,
                contextMenuGateway: contextMenuGateway,
                showShortcutHints: showGroupShortcutHints,
                onShortcutStartIndexChanged: onGroupShortcutStartIndexChanged,
              ),
            ],
          ],
        ],
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
    final String label = widget.filtersExpanded
        ? context.localized('Hide categories and groups', '收起分类与分组')
        : widget.filtersActive
        ? context.localized(
            'Show categories and groups (filters active)',
            '展开分类与分组（筛选已启用）',
          )
        : context.localized('Show categories and groups', '展开分类与分组');
    return Semantics(
      button: true,
      expanded: widget.filtersExpanded,
      label: label,
      child: ExcludeSemantics(
        child: Tooltip(
          message: label,
          excludeFromSemantics: true,
          child: ScaleTransition(
            key: const Key('clipboard-filter-transition'),
            scale: _scale,
            child: DesktopIconButton(
              key: const Key('clipboard-toggle-filters'),
              onPressed: widget.onPressed,
              size: 38,
              iconSize: 17,
              foregroundColor: foreground,
              backgroundColor: background,
              borderColor: highlighted
                  ? PopupStyle.accent.withValues(alpha: 0.32)
                  : PopupStyle.border,
              icon: SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    if (widget.showShortcutHint)
                      Text(
                        primaryShortcutLabel('R', defaultTargetPlatform),
                        key: Key('clipboard-filter-shortcut'),
                        style: const TextStyle(
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
          ),
        ),
      ),
    );
  }
}

class _ClipboardKindFilters extends StatelessWidget {
  const _ClipboardKindFilters({
    required this.viewModel,
    required this.showResetShortcutHint,
  });

  final ClipboardViewModel viewModel;
  final bool showResetShortcutHint;

  @override
  Widget build(BuildContext context) {
    final List<ClipboardCategoryRule> categories =
        viewModel.availableCategories;
    return SizedBox(
      height: 32,
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
          DesktopIconButton(
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
    final bool showShortcut = category == null && showResetShortcutHint;
    final Widget labelWidget = Text(
      showShortcut ? primaryShortcutLabel('R', defaultTargetPlatform) : label,
      key: showShortcut
          ? const Key('clipboard-filter-reset-shortcut')
          : Key('clipboard-category-${category?.id ?? 'all'}-label'),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
    );
    return DesktopChoiceChip(
      key: Key('clipboard-category-${category?.id ?? 'all'}'),
      label: category == null
          ? SizedBox(
              width: 24,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 140),
                switchInCurve: Curves.easeOutBack,
                switchOutCurve: Curves.easeOut,
                transitionBuilder:
                    (Widget child, Animation<double> animation) =>
                        FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.88,
                              end: 1,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                child: labelWidget,
              ),
            )
          : labelWidget,
      selected: category == null
          ? !viewModel.hasActiveFilters
          : viewModel.selectedCategoryId == category.id,
      onSelected: (_) => category == null
          ? viewModel.clearFilters()
          : viewModel.setCategory(category.id),
      height: 32,
      foregroundColor: PopupStyle.textSecondary,
      selectedForegroundColor: PopupStyle.accent,
      backgroundColor: PopupStyle.surface,
      selectedBackgroundColor: PopupStyle.accentSoft,
      borderColor: PopupStyle.border,
      selectedBorderColor: PopupStyle.accent.withValues(alpha: 0.28),
    );
  }
}

class _ClipboardGroupFilters extends StatefulWidget {
  const _ClipboardGroupFilters({
    required this.viewModel,
    required this.contextMenuGateway,
    required this.showShortcutHints,
    required this.onShortcutStartIndexChanged,
  });

  final ClipboardViewModel viewModel;
  final DesktopContextMenuGateway? contextMenuGateway;
  final bool showShortcutHints;
  final ValueChanged<int> onShortcutStartIndexChanged;

  @override
  State<_ClipboardGroupFilters> createState() => _ClipboardGroupFiltersState();
}

class _ClipboardGroupFiltersState extends State<_ClipboardGroupFilters> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _viewportKey = GlobalKey();
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};
  int _shortcutStartIndex = 0;
  String? _lastSelectedGroup;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scheduleVisibleRangeUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onShortcutStartIndexChanged(0);
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_scheduleVisibleRangeUpdate)
      ..dispose();
    super.dispose();
  }

  void _scheduleVisibleRangeUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateVisibleRange();
    });
  }

  void _updateVisibleRange() {
    final RenderBox? viewport =
        _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) return;
    final Offset viewportOrigin = viewport.localToGlobal(Offset.zero);
    final Rect viewportRect = viewportOrigin & viewport.size;
    final List<String> groups = widget.viewModel.groups;
    var next = 0;
    for (int index = 0; index < groups.length; index++) {
      final RenderBox? item =
          _itemKeys[groups[index]]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (item == null || !item.hasSize) continue;
      final Rect itemRect = item.localToGlobal(Offset.zero) & item.size;
      if (itemRect.right > viewportRect.left + 1 &&
          itemRect.left < viewportRect.right - 1) {
        next = index;
        break;
      }
    }
    if (next == _shortcutStartIndex) return;
    setState(() => _shortcutStartIndex = next);
    widget.onShortcutStartIndexChanged(next);
  }

  void _ensureSelectedVisible(String group) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final BuildContext? itemContext = _itemKeys[group]?.currentContext;
      if (itemContext == null) return;
      unawaited(
        Scrollable.ensureVisible(
          itemContext,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ).then((_) => _updateVisibleRange()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> groups = widget.viewModel.groups;
    _itemKeys.removeWhere((String group, _) => !groups.contains(group));
    final String? selectedGroup = widget.viewModel.selectedGroup;
    if (selectedGroup != null && selectedGroup != _lastSelectedGroup) {
      _lastSelectedGroup = selectedGroup;
      _ensureSelectedVisible(selectedGroup);
    } else if (selectedGroup == null) {
      _lastSelectedGroup = null;
    }
    return SizedBox(
      key: _viewportKey,
      height: 32,
      child: ReorderableListView.builder(
        scrollController: _scrollController,
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        onReorderItem: widget.viewModel.reorderGroups,
        buildDefaultDragHandles: false,
        proxyDecorator: _clipboardGroupDragProxy,
        itemBuilder: (BuildContext context, int index) {
          final String group = groups[index];
          final int shortcutIndex = index - _shortcutStartIndex + 1;
          final bool showShortcut =
              widget.showShortcutHints &&
              shortcutIndex >= 1 &&
              shortcutIndex <= 5;
          return Padding(
            key: ValueKey<String>('clipboard-group-$group'),
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(
              key: _itemKeys.putIfAbsent(group, GlobalKey.new),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onSecondaryTapUp: (TapUpDetails details) => unawaited(
                  showClipboardGroupContextMenu(
                    context,
                    globalPosition: details.globalPosition,
                    group: group,
                    viewModel: widget.viewModel,
                    gateway: widget.contextMenuGateway,
                  ),
                ),
                child: ReorderableDragStartListener(
                  index: index,
                  child: DesktopChoiceChip(
                    leading: showShortcut
                        ? Container(
                            key: Key('clipboard-group-shortcut-$shortcutIndex'),
                            width: 18,
                            height: 18,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: PopupStyle.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$shortcutIndex',
                              style: const TextStyle(
                                color: PopupStyle.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          )
                        : const Icon(Icons.folder_outlined, size: 13),
                    label: Text(
                      group,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    selected: widget.viewModel.selectedGroup == group,
                    onSelected: (bool selected) =>
                        widget.viewModel.setGroup(selected ? group : null),
                    height: 32,
                    foregroundColor: PopupStyle.textSecondary,
                    selectedForegroundColor: PopupStyle.accent,
                    backgroundColor: PopupStyle.surface,
                    selectedBackgroundColor: PopupStyle.accentSoft,
                    borderColor: PopupStyle.border,
                    selectedBorderColor: PopupStyle.accent.withValues(
                      alpha: 0.28,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Widget _clipboardGroupDragProxy(
  Widget child,
  int index,
  Animation<double> animation,
) {
  final Animation<double> transition = CurvedAnimation(
    parent: animation,
    curve: Curves.easeOutCubic,
  );
  return AnimatedBuilder(
    animation: transition,
    child: Material(type: MaterialType.transparency, child: child),
    builder: (BuildContext context, Widget? child) => Transform.scale(
      key: const Key('clipboard-group-drag-proxy'),
      scale: 1 + (transition.value * 0.015),
      child: Opacity(opacity: 1 - (transition.value * 0.02), child: child),
    ),
  );
}
