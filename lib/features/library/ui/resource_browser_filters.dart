part of 'resource_browser_screen.dart';

class _TypeFilters extends StatelessWidget {
  const _TypeFilters({required this.viewModel});

  final LibraryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final List<ResourceType?> types = <ResourceType?>[
      null,
      ResourceType.prompt,
      ResourceType.skill,
      ResourceType.mcp,
    ];
    return SizedBox(
      height: 35,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            for (int index = 0; index < types.length; index += 1) ...<Widget>[
              if (index > 0) const SizedBox(width: 6),
              Expanded(
                child: _FilterButton(
                  label: _typeLabel(context, types[index]),
                  selected:
                      viewModel.selectedType == types[index] &&
                      viewModel.selectedGroup == null,
                  onPressed: () => viewModel.setTypeFilter(types[index]),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupFilters extends StatelessWidget {
  const _GroupFilters({required this.viewModel});

  final LibraryViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final List<String?> groups = <String?>[null, ...viewModel.groups];
    return SizedBox(
      height: 32,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: groups.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int index) {
          final String? group = groups[index];
          final int count = group == null
              ? viewModel.allResources
                    .where(
                      (Resource item) => item.type.isConfigurableAgentResource,
                    )
                    .length
              : viewModel.allResources
                    .where(
                      (Resource item) =>
                          item.type.isConfigurableAgentResource &&
                          item.group == group,
                    )
                    .length;
          return _GroupButton(
            label: group ?? context.l10n.all,
            count: count,
            selected:
                viewModel.selectedGroup == group &&
                (group != null || viewModel.selectedType == null),
            onPressed: () => viewModel.setGroupFilter(group),
          );
        },
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DesktopChoiceChip(
      label: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
      selected: selected,
      onSelected: (_) => onPressed(),
      height: 35,
      padding: EdgeInsets.zero,
      foregroundColor: PopupStyle.of(context).textSecondary,
      selectedForegroundColor: PopupStyle.of(context).accent,
      backgroundColor: PopupStyle.of(context).surface,
      selectedBackgroundColor: PopupStyle.of(context).accentSoft,
      borderColor: PopupStyle.of(context).border,
      selectedBorderColor: PopupStyle.of(
        context,
      ).accent.withValues(alpha: 0.25),
      borderRadius: 8,
    );
  }
}

class _GroupButton extends StatelessWidget {
  const _GroupButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DesktopChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: selected
                  ? PopupStyle.of(context).accent
                  : PopupStyle.of(context).textSecondary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: PopupStyle.of(context).background,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      selected: selected,
      onSelected: (_) => onPressed(),
      height: 32,
      foregroundColor: PopupStyle.of(context).textSecondary,
      selectedForegroundColor: PopupStyle.of(context).accent,
      backgroundColor: PopupStyle.of(context).surface,
      selectedBackgroundColor: PopupStyle.of(context).accentSoft,
      borderColor: PopupStyle.of(context).border,
      selectedBorderColor: PopupStyle.of(
        context,
      ).accent.withValues(alpha: 0.25),
      borderRadius: 8,
    );
  }
}
