import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:dingdong/features/library/domain/resource_card_presentation.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:flutter/material.dart';

/// Lazy, keyboard-ready resource result list.
class ResourceList extends StatelessWidget {
  const ResourceList({
    required this.viewModel,
    required this.onDeleteResource,
    this.contextMenuGateway,
    this.compact = false,
    super.key,
  });

  final LibraryViewModel viewModel;
  final ValueChanged<Resource> onDeleteResource;
  final DesktopContextMenuGateway? contextMenuGateway;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final List<Resource> resources = viewModel.visibleResources;
    if (resources.isEmpty) {
      return Center(
        key: const Key('resource-list'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.search_off_rounded,
              size: 22,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 9),
            Text(
              context.localized('No matching resources', '没有匹配的资源'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      key: const Key('resource-list'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      itemCount: resources.length,
      itemExtent: compact ? 56 : 64,
      itemBuilder: (BuildContext context, int index) {
        final Resource resource = resources[index];
        final bool selected = viewModel.selectedResource?.id == resource.id;
        final bool selectedForAction = viewModel.isSelected(resource.id);
        final ColorScheme colors = Theme.of(context).colorScheme;
        final ResourceCardPresentation display =
            ResourceCardPresentation.fromResource(resource);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Material(
            key: ValueKey<String>('resource-row-${resource.id}'),
            color: selected
                ? colors.primary.withValues(alpha: 0.075)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onSecondaryTapUp: (TapUpDetails details) =>
                  _showContextMenu(context, details.globalPosition, resource),
              child: InkWell(
                borderRadius: BorderRadius.circular(5),
                onTap: () => viewModel.selectResource(resource),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(9, 7, 7, 7),
                  child: Row(
                    children: <Widget>[
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 140),
                        width: 2,
                        height: selected ? 30 : 16,
                        decoration: BoxDecoration(
                          color: selected ? colors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? colors.primary.withValues(alpha: 0.1)
                              : colors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Icon(
                          _iconFor(resource.type),
                          size: 15,
                          color: selected
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              display.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              display.summary,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        context.localized(
                          '${resource.usageCount} uses',
                          '${resource.usageCount} 次',
                        ),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (resource.pinned) ...<Widget>[
                        const SizedBox(width: 6),
                        Icon(
                          Icons.push_pin_outlined,
                          size: 13,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                      _SelectionButton(
                        key: ValueKey<String>('resource-select-${resource.id}'),
                        selected: selectedForAction,
                        onPressed: () => viewModel.toggleSelection(resource.id),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showContextMenu(
    BuildContext context,
    Offset position,
    Resource resource,
  ) async {
    final _ResourceRowAction? action = contextMenuGateway == null
        ? await showMenu<_ResourceRowAction>(
            context: context,
            position: desktopContextMenuPosition(context, position),
            popUpAnimationStyle: AnimationStyle.noAnimation,
            items: <PopupMenuEntry<_ResourceRowAction>>[
              PopupMenuItem<_ResourceRowAction>(
                value: _ResourceRowAction.delete,
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.delete_outline_rounded, size: 17),
                    const SizedBox(width: 9),
                    Text(context.localized('Delete', '删除')),
                  ],
                ),
              ),
            ],
          )
        : switch (await contextMenuGateway!.show(
            x: position.dx,
            y: position.dy,
            useChinese: Localizations.localeOf(context).languageCode == 'zh',
            items: const <DesktopContextMenuItem>[
              DesktopContextMenuItem(
                id: 'delete',
                englishLabel: 'Delete',
                chineseLabel: '删除',
              ),
            ],
          )) {
            'delete' => _ResourceRowAction.delete,
            _ => null,
          };
    if (action == _ResourceRowAction.delete) {
      onDeleteResource(resource);
    }
  }
}

enum _ResourceRowAction { delete }

class _SelectionButton extends StatelessWidget {
  const _SelectionButton({
    required this.selected,
    required this.onPressed,
    super.key,
  });

  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: selected
          ? context.localized('Remove from selection', '取消选择')
          : context.localized('Select item', '选择此项'),
      child: SizedBox.square(
        dimension: 28,
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll<Size>(Size.square(28)),
            maximumSize: const WidgetStatePropertyAll<Size>(Size.square(28)),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: WidgetStatePropertyAll<OutlinedBorder>(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
            foregroundColor: WidgetStatePropertyAll<Color>(
              selected ? colors.primary : colors.onSurfaceVariant,
            ),
            backgroundColor: WidgetStateProperty.resolveWith<Color?>((
              Set<WidgetState> states,
            ) {
              if (states.contains(WidgetState.hovered)) {
                return selected
                    ? colors.primary.withValues(alpha: 0.12)
                    : colors.surfaceContainerHigh;
              }
              return Colors.transparent;
            }),
            overlayColor: const WidgetStatePropertyAll<Color>(
              Colors.transparent,
            ),
            splashFactory: NoSplash.splashFactory,
          ),
          icon: SelectionMark(selected: selected, size: 16),
        ),
      ),
    );
  }
}

IconData _iconFor(ResourceType type) {
  return switch (type) {
    ResourceType.prompt => Icons.format_quote_rounded,
    ResourceType.skill => Icons.auto_awesome_outlined,
    ResourceType.mcp => Icons.dns_outlined,
    ResourceType.knowledge => Icons.folder_outlined,
    ResourceType.clipboard => Icons.content_paste_outlined,
  };
}
