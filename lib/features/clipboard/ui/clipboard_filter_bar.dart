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
    required this.onToggleFilters,
  });

  final ClipboardViewModel viewModel;
  final FocusNode searchFocusNode;
  final ClipboardSettingsController? settingsViewModel;
  final bool filtersExpanded;
  final bool showShortcutHint;
  final VoidCallback onToggleFilters;

  @override
  Widget build(BuildContext context) {
    final ClipboardSettingsController? settings = settingsViewModel;
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
                CompactSwitch(
                  value: settings?.clipboardMonitoring ?? true,
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
                      : context.localized(
                          'Show categories and groups',
                          '展开分类与分组',
                        ),
                  child: OutlinedButton(
                    key: const Key('clipboard-toggle-filters'),
                    onPressed: onToggleFilters,
                    style: OutlinedButton.styleFrom(
                      fixedSize: const Size(35, 36),
                      minimumSize: const Size(35, 36),
                      padding: EdgeInsets.zero,
                      foregroundColor: PopupStyle.textSecondary,
                      backgroundColor: PopupStyle.surface,
                      side: const BorderSide(color: PopupStyle.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: showShortcutHint
                        ? const Text(
                            'R',
                            key: Key('clipboard-filter-shortcut'),
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : PopupSymbolIcon(
                            filtersExpanded ? 'collapse' : 'filter',
                            key: Key(
                              filtersExpanded
                                  ? 'clipboard-collapse-filters-icon'
                                  : 'clipboard-filter-icon',
                            ),
                            size: 17,
                            color: PopupStyle.textSecondary,
                          ),
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
              _ClipboardGroupFilters(viewModel: viewModel),
            ],
          ],
        ],
      ),
    );
  }
}

class _ClipboardKindFilters extends StatelessWidget {
  const _ClipboardKindFilters({required this.viewModel});

  final ClipboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final List<ClipboardCategory> categories = viewModel.availableCategories;
    return SizedBox(
      height: 30,
      child: Row(
        children: <Widget>[
          _categoryChip(context, null),
          if (categories.isNotEmpty) const SizedBox(width: 6),
          Expanded(
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              buildDefaultDragHandles: false,
              itemCount: categories.length,
              onReorderItem: viewModel.reorderCategories,
              proxyDecorator: (Widget child, _, _) => Material(
                color: Colors.transparent,
                elevation: 3,
                borderRadius: BorderRadius.circular(8),
                child: child,
              ),
              itemBuilder: (BuildContext context, int index) => Padding(
                key: ValueKey<String>('category-${categories[index].name}'),
                padding: const EdgeInsets.only(right: 6),
                child: ReorderableDragStartListener(
                  index: index,
                  child: GestureDetector(
                    onSecondaryTapUp: (TapUpDetails details) =>
                        _showCategoryOrderMenu(
                          context,
                          details.globalPosition,
                          index,
                          categories.length,
                        ),
                    child: _categoryChip(context, categories[index]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryChip(BuildContext context, ClipboardCategory? category) {
    final String label = switch (category) {
      null => context.localized('All', '全部'),
      ClipboardCategory.text => context.localized('Text', '文本'),
      ClipboardCategory.link => context.localized('Links', '链接'),
      ClipboardCategory.image => context.localized('Images', '图片'),
      ClipboardCategory.file => context.localized('Files', '文件'),
    };
    return FilterChip(
      key: Key('clipboard-category-${category?.name ?? 'all'}'),
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
      selected: viewModel.selectedCategory == category,
      onSelected: (_) => viewModel.setCategory(category),
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Future<void> _showCategoryOrderMenu(
    BuildContext context,
    Offset position,
    int index,
    int length,
  ) async {
    final _FilterMove? move = await showMenu<_FilterMove>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, 0, 0),
      popUpAnimationStyle: AnimationStyle.noAnimation,
      items: <PopupMenuEntry<_FilterMove>>[
        PopupMenuItem(
          value: _FilterMove.earlier,
          enabled: index > 0,
          child: Text(context.localized('Move earlier', '往前一位')),
        ),
        PopupMenuItem(
          value: _FilterMove.first,
          enabled: index > 0,
          child: Text(context.localized('Move to first', '放到最前')),
        ),
        PopupMenuItem(
          value: _FilterMove.last,
          enabled: index < length - 1,
          child: Text(context.localized('Move to last', '放到最后')),
        ),
      ],
    );
    if (move == null) return;
    final int target = switch (move) {
      _FilterMove.earlier => index - 1,
      _FilterMove.first => 0,
      _FilterMove.last => length,
    };
    viewModel.reorderCategories(index, target);
  }
}

class _ClipboardGroupFilters extends StatelessWidget {
  const _ClipboardGroupFilters({required this.viewModel});

  final ClipboardViewModel viewModel;

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
          );
        },
      ),
    );
  }
}

enum _FilterMove { earlier, first, last }
