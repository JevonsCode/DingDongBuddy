part of 'clipboard_manager_screen.dart';

// Search, sort, source, category, and compact filter controls.
class _ManagerSearchField extends StatelessWidget {
  const _ManagerSearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DesktopSearchField(
      key: const Key('clipboard-manager-search'),
      surfaceKey: const Key('clipboard-manager-search-surface'),
      searchIconKey: const Key('clipboard-manager-search-icon'),
      height: _managerSearchControlHeight,
      onChanged: onChanged,
      hintText: context.l10n.searchClipboardHistory,
      clearTooltip: context.l10n.clearSearch,
      backgroundColor: colors.surface,
      borderColor: colors.outlineVariant,
      focusBorderColor: colors.outline,
      borderRadius: 8,
    );
  }
}

BoxDecoration _managerControlDecoration(
  ColorScheme colors, {
  required bool emphasized,
}) => BoxDecoration(
  color: colors.surface,
  border: Border.all(
    color: emphasized ? colors.outline : colors.outlineVariant,
  ),
  borderRadius: BorderRadius.circular(8),
);

class _ClipboardSortDropdown extends StatelessWidget {
  const _ClipboardSortDropdown({required this.viewModel});

  final ClipboardViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final ClipboardSortMode selected = viewModel.sortMode;
    final String label = switch (selected) {
      ClipboardSortMode.defaultOrder => context.l10n.defaultOrder,
      ClipboardSortMode.copyCount => context.l10n.copyCount2,
    };
    return MenuAnchor(
      menuChildren: <Widget>[
        MenuItemButton(
          key: const Key('clipboard-manager-sort-default'),
          leadingIcon: SelectionMark(
            selected: selected == ClipboardSortMode.defaultOrder,
          ),
          onPressed: () =>
              viewModel.setSortMode(ClipboardSortMode.defaultOrder),
          child: Text(context.l10n.defaultOrder),
        ),
        MenuItemButton(
          key: const Key('clipboard-manager-sort-copy-count'),
          leadingIcon: SelectionMark(
            selected: selected == ClipboardSortMode.copyCount,
          ),
          onPressed: () => viewModel.setSortMode(ClipboardSortMode.copyCount),
          child: Text(context.l10n.copyCount2),
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) =>
              Semantics(
                button: true,
                label: context.l10n.clipboardSortLabel(label),
                child: Container(
                  key: const Key('clipboard-manager-sort'),
                  decoration: _managerControlDecoration(
                    colors,
                    emphasized: selected == ClipboardSortMode.copyCount,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: colors.onSurface.withValues(alpha: 0.035),
                      focusColor: colors.onSurface.withValues(alpha: 0.035),
                      onTap: () => controller.isOpen
                          ? controller.close()
                          : controller.open(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.sort_rounded,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.keyboard_arrow_down_rounded,
                              size: 17,
                              color: colors.onSurfaceVariant,
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

class _SourceFilterDropdown extends StatefulWidget {
  const _SourceFilterDropdown({required this.viewModel});

  final ClipboardViewModel viewModel;

  @override
  State<_SourceFilterDropdown> createState() => _SourceFilterDropdownState();
}

class _SourceFilterDropdownState extends State<_SourceFilterDropdown> {
  final MenuController _menuController = MenuController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'clipboard-manager-source-search',
  );
  String _query = '';
  bool _menuOpen = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<ClipboardSourceOption> sources = widget.viewModel.sourceOptions;
    final String needle = _query.trim().toLowerCase();
    final List<ClipboardSourceOption> filteredSources = sources
        .where(
          (ClipboardSourceOption source) =>
              needle.isEmpty ||
              source.label.toLowerCase().contains(needle) ||
              source.id.toLowerCase().contains(needle),
        )
        .toList(growable: false);
    final double resultsHeight = filteredSources.isEmpty
        ? 42
        : (filteredSources.length * 30.0).clamp(30.0, 150.0);
    final bool hasSelection = widget.viewModel.selectedSourceIds.isNotEmpty;
    final String summary = _summaryLabel(context, sources);
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return MenuAnchor(
      controller: _menuController,
      alignmentOffset: const Offset(-_sourceFilterMenuWidth, 6),
      clipBehavior: Clip.antiAlias,
      animated: !reduceMotion,
      onOpen: _handleOpen,
      onClose: _handleClose,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(colors.surface),
        shadowColor: WidgetStatePropertyAll<Color>(
          Colors.black.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.28 : 0.12,
          ),
        ),
        surfaceTintColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
        elevation: const WidgetStatePropertyAll<double>(4),
        padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
          EdgeInsets.zero,
        ),
        side: WidgetStatePropertyAll<BorderSide>(
          BorderSide(
            color: colors.outline.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.82 : 0.72,
            ),
          ),
        ),
        shape: const WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
          ),
        ),
        alignment: AlignmentDirectional.bottomEnd,
      ),
      menuChildren: <Widget>[
        SizedBox(
          key: const Key('clipboard-manager-source-menu'),
          width: _sourceFilterMenuWidth,
          height: 89 + resultsHeight,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                DesktopSearchField(
                  key: const Key('clipboard-manager-source-search'),
                  surfaceKey: const Key(
                    'clipboard-manager-source-search-surface',
                  ),
                  searchIconKey: const Key(
                    'clipboard-manager-source-search-icon',
                  ),
                  clearButtonKey: const Key(
                    'clipboard-manager-source-search-clear',
                  ),
                  height: 34,
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (String value) => setState(() => _query = value),
                  hintText: context.l10n.searchSources,
                  clearTooltip: context.l10n.clearSearch,
                  backgroundColor: colors.surfaceContainerLow,
                  borderColor: colors.outlineVariant.withValues(alpha: 0.72),
                  focusBorderColor: colors.outline,
                  borderRadius: 6,
                ),
                const SizedBox(height: 6),
                _SourceFilterOption(
                  key: const Key('clipboard-manager-source-all'),
                  label: context.l10n.allSources,
                  selected: !hasSelection,
                  onTap: widget.viewModel.clearSources,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Divider(
                    height: 7,
                    thickness: 1,
                    color: colors.outlineVariant,
                  ),
                ),
                SizedBox(
                  height: resultsHeight,
                  child: filteredSources.isEmpty
                      ? SizedBox(
                          height: 42,
                          child: Center(
                            child: Text(
                              context.l10n.noMatchingSources,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ),
                        )
                      : ListView.builder(
                          primary: false,
                          itemExtent: 30,
                          itemCount: filteredSources.length,
                          itemBuilder: (BuildContext context, int index) {
                            final ClipboardSourceOption source =
                                filteredSources[index];
                            return _SourceFilterOption(
                              key: Key('clipboard-manager-source-${source.id}'),
                              label: source.label,
                              selected: widget.viewModel.selectedSourceIds
                                  .contains(source.id),
                              onTap: () =>
                                  widget.viewModel.toggleSource(source.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
      builder:
          (BuildContext context, MenuController controller, Widget? child) =>
              Semantics(
                button: true,
                selected: hasSelection,
                expanded: _menuOpen,
                label: context.l10n.sourceFilterSummary(summary),
                child: AnimatedContainer(
                  key: const Key('clipboard-manager-source-filter'),
                  height: _managerSearchControlHeight,
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOutCubic,
                  clipBehavior: Clip.antiAlias,
                  decoration: _managerControlDecoration(
                    colors,
                    emphasized: _menuOpen,
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      hoverColor: colors.onSurface.withValues(alpha: 0.035),
                      focusColor: colors.onSurface.withValues(alpha: 0.035),
                      onTap: () {
                        controller.isOpen
                            ? controller.close()
                            : controller.open();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              Icons.filter_list_rounded,
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                summary,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: hasSelection
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 7),
                            Icon(
                              _menuOpen
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 17,
                              color: colors.onSurfaceVariant,
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

  String _summaryLabel(
    BuildContext context,
    List<ClipboardSourceOption> sources,
  ) {
    final Set<String> selected = widget.viewModel.selectedSourceIds;
    if (selected.isEmpty) {
      return context.l10n.allSources;
    }
    if (selected.length == 1) {
      for (final ClipboardSourceOption source in sources) {
        if (selected.contains(source.id)) {
          return source.label;
        }
      }
    }
    return context.l10n.lengthSources(selected.length);
  }

  void _handleOpen() {
    if (mounted) {
      setState(() => _menuOpen = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _menuController.isOpen) {
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _handleClose() {
    _searchFocusNode.unfocus();
    if (!mounted) {
      return;
    }
    setState(() {
      _menuOpen = false;
      _query = '';
      _searchController.clear();
    });
  }
}

class _SourceFilterOption extends StatelessWidget {
  const _SourceFilterOption({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? colors.surfaceContainerLow : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: colors.onSurface.withValues(alpha: 0.04),
          focusColor: colors.onSurface.withValues(alpha: 0.04),
          child: SizedBox(
            height: 30,
            child: Row(
              children: <Widget>[
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      height: 1.05,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 17,
                  height: 30,
                  child: selected
                      ? Center(
                          child: Icon(
                            Icons.check_rounded,
                            size: 15,
                            color: colors.onSurface,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManagerFilters extends StatelessWidget {
  const _ManagerFilters({
    required this.viewModel,
    required this.contextMenuGateway,
    required this.onManageCategories,
  });

  final ClipboardViewModel viewModel;
  final DesktopContextMenuGateway? contextMenuGateway;
  final VoidCallback onManageCategories;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: 30,
          child: Row(
            children: <Widget>[
              _CompactFilterButton(
                key: const Key('clipboard-manager-category-all'),
                label: Text(context.l10n.all),
                selected: viewModel.selectedCategoryId == null,
                onPressed: () => viewModel.setCategory(null),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: viewModel.availableCategories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 6),
                  itemBuilder: (BuildContext context, int index) {
                    final ClipboardCategoryRule rule =
                        viewModel.availableCategories[index];
                    return _CompactFilterButton(
                      key: Key('clipboard-manager-category-${rule.id}'),
                      label: Text(_categoryLabel(context, rule)),
                      selected: viewModel.selectedCategoryId == rule.id,
                      onPressed: () => viewModel.setCategory(rule.id),
                    );
                  },
                ),
              ),
              DesktopIconButton(
                key: const Key('clipboard-manager-categories'),
                tooltip: context.l10n.manageCategories,
                onPressed: onManageCategories,
                icon: const Icon(Icons.tune_rounded, size: 16),
              ),
            ],
          ),
        ),
        if (viewModel.groups.isNotEmpty) ...<Widget>[
          const SizedBox(height: 7),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: viewModel.groups.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (BuildContext context, int index) {
                final String group = viewModel.groups[index];
                return GestureDetector(
                  key: Key('clipboard-manager-group-$group'),
                  behavior: HitTestBehavior.opaque,
                  onSecondaryTapUp: (TapUpDetails details) =>
                      showClipboardGroupContextMenu(
                        context,
                        globalPosition: details.globalPosition,
                        group: group,
                        viewModel: viewModel,
                        gateway: contextMenuGateway,
                      ),
                  child: _CompactFilterButton(
                    icon: Icons.folder_outlined,
                    label: Text(group),
                    selected: viewModel.selectedGroup == group,
                    onPressed: () => viewModel.setGroup(
                      viewModel.selectedGroup == group ? null : group,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactFilterButton extends StatelessWidget {
  const _CompactFilterButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    this.icon,
    super.key,
  });

  final Widget label;
  final bool selected;
  final VoidCallback onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color foreground = selected
        ? colors.primary
        : colors.onSurfaceVariant;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.11)
          : colors.surfaceContainerLow.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(5),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(5),
        hoverColor: selected
            ? colors.primary.withValues(alpha: 0.05)
            : colors.onSurface.withValues(alpha: 0.045),
        child: Container(
          height: 28,
          padding: EdgeInsets.symmetric(horizontal: icon == null ? 10 : 9),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 13, color: foreground),
                const SizedBox(width: 6),
              ],
              DefaultTextStyle.merge(
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
                child: label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _categoryLabel(BuildContext context, ClipboardCategoryRule rule) =>
    switch (rule.id) {
      'text' => context.l10n.text,
      'links' => context.l10n.links,
      'images' => context.l10n.images,
      'files' => context.l10n.files,
      _ => rule.name,
    };
