import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:flutter/material.dart';

/// Search and primary commands for the resource workspace.
class ResourceFilterBar extends StatelessWidget {
  const ResourceFilterBar({
    required this.viewModel,
    this.onImport,
    this.onExport,
    super.key,
  });

  final LibraryViewModel viewModel;
  final VoidCallback? onImport;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget search = TextField(
                key: const Key('resource-search'),
                onChanged: viewModel.setQuery,
                decoration: InputDecoration(
                  hintText: context.localized(
                    'Search title, tags, group, or content',
                    '搜索标题、标签、分组或内容',
                  ),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              );
              if (constraints.maxWidth < 520) {
                return Row(
                  children: <Widget>[
                    Expanded(child: search),
                    const SizedBox(width: 8),
                    PopupMenuButton<_LibraryAction>(
                      key: const Key('library-actions'),
                      tooltip: context.localized('Resource actions', '资源操作'),
                      onSelected: (_LibraryAction action) {
                        switch (action) {
                          case _LibraryAction.create:
                            viewModel.startCreating();
                          case _LibraryAction.import:
                            onImport?.call();
                          case _LibraryAction.export:
                            onExport?.call();
                        }
                      },
                      itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<_LibraryAction>>[
                            PopupMenuItem<_LibraryAction>(
                              value: _LibraryAction.create,
                              child: Text(
                                context.localized('New resource', '新建资源'),
                              ),
                            ),
                            if (onImport != null)
                              PopupMenuItem<_LibraryAction>(
                                value: _LibraryAction.import,
                                child: Text(
                                  context.localized('Import folder', '导入文件夹'),
                                ),
                              ),
                            if (onExport != null)
                              PopupMenuItem<_LibraryAction>(
                                value: _LibraryAction.export,
                                child: Text(
                                  context.localized('Export JSON', '导出 JSON'),
                                ),
                              ),
                          ],
                      icon: const Icon(Icons.more_horiz_rounded),
                    ),
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: search),
                  const SizedBox(width: 12),
                  IconButton.outlined(
                    key: const Key('library-import'),
                    tooltip: context.localized('Import folder', '导入文件夹'),
                    onPressed: onImport,
                    icon: const Icon(
                      Icons.drive_folder_upload_outlined,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.outlined(
                    key: const Key('library-export'),
                    tooltip: context.localized('Export JSON', '导出 JSON'),
                    onPressed: onExport,
                    icon: const Icon(Icons.download_outlined, size: 19),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: viewModel.startCreating,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(context.localized('New resource', '新建资源')),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                _TypeChip(
                  label: context.localized('All', '全部'),
                  selected:
                      viewModel.selectedType == null && !viewModel.pinnedOnly,
                  onSelected: (_) => viewModel.setTypeFilter(null),
                ),
                for (final ResourceType type in ResourceType.values.where(
                  (ResourceType value) => value.isLibraryResource,
                )) ...<Widget>[
                  const SizedBox(width: 7),
                  _TypeChip(
                    key: Key('resource-filter-${type.name}'),
                    label: _typeLabel(context, type),
                    selected: viewModel.selectedType == type,
                    onSelected: (_) => viewModel.setTypeFilter(type),
                  ),
                ],
                const SizedBox(width: 7),
                _TypeChip(
                  label: context.localized('Pinned', '已置顶'),
                  selected: viewModel.pinnedOnly,
                  onSelected: viewModel.setPinnedOnly,
                ),
                const SizedBox(width: 12),
                Text(
                  context.localized(
                    '${viewModel.visibleResources.length} results',
                    '${viewModel.visibleResources.length} 个结果',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _LibraryAction { create, import, export }

String _typeLabel(BuildContext context, ResourceType type) {
  return switch (type) {
    ResourceType.prompt => context.localized('Prompts', '提示词'),
    ResourceType.skill => context.localized('Skills', '技能'),
    ResourceType.mcp => 'MCP',
    ResourceType.knowledge => context.localized('Knowledge', '知识库'),
    ResourceType.clipboard => context.localized('Clipboard', '剪贴板'),
  };
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    super.key,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: false,
      visualDensity: VisualDensity.compact,
    );
  }
}
