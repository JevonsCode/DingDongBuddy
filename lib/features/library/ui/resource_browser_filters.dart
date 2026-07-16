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
      height: 33,
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
      height: 30,
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
            label: group ?? context.localized('All', '全部'),
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
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 33),
        padding: EdgeInsets.zero,
        backgroundColor: selected ? PopupStyle.accentSoft : PopupStyle.surface,
        foregroundColor: selected
            ? PopupStyle.accent
            : PopupStyle.textSecondary,
        side: BorderSide(
          color: selected
              ? PopupStyle.accent.withValues(alpha: 0.25)
              : PopupStyle.border,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
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
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 9),
        backgroundColor: selected ? PopupStyle.accentSoft : PopupStyle.surface,
        foregroundColor: selected
            ? PopupStyle.accent
            : PopupStyle.textSecondary,
        side: BorderSide(
          color: selected
              ? PopupStyle.accent.withValues(alpha: 0.25)
              : PopupStyle.border,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Row(
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
              color: selected ? PopupStyle.accent : PopupStyle.textSecondary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
