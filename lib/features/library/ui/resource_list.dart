import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:flutter/material.dart';

/// Lazy, keyboard-ready resource result list.
class ResourceList extends StatelessWidget {
  const ResourceList({
    required this.viewModel,
    this.compact = false,
    super.key,
  });

  final LibraryViewModel viewModel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final List<Resource> resources = viewModel.visibleResources;
    if (resources.isEmpty) {
      return Center(
        child: Text(context.localized('No matching resources', '没有匹配的资源')),
      );
    }
    return ListView.builder(
      key: const Key('resource-list'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      itemCount: resources.length,
      itemExtent: compact ? 64 : 78,
      itemBuilder: (BuildContext context, int index) {
        final Resource resource = resources[index];
        final bool selected = viewModel.selectedResource?.id == resource.id;
        return Padding(
          key: ValueKey<String>('resource-row-${resource.id}'),
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Material(
            color: selected
                ? Theme.of(context).colorScheme.secondaryContainer
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => viewModel.selectResource(resource),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(_iconFor(resource.type), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            resource.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            resource.content.replaceAll('\n', ' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    if (resource.pinned)
                      const Icon(Icons.push_pin_outlined, size: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
