import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:flutter/material.dart';

/// Search and primary commands for the resource workspace.
class ResourceFilterBar extends StatelessWidget {
  const ResourceFilterBar({
    required this.viewModel,
    this.onImport,
    this.onImportJson,
    this.onExport,
    this.onDeleteSelection,
    super.key,
  });

  final LibraryViewModel viewModel;
  final VoidCallback? onImport;
  final VoidCallback? onImportJson;
  final VoidCallback? onExport;
  final VoidCallback? onDeleteSelection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              if (constraints.maxWidth < 520) {
                return Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        context.localized('Resources', '资源'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    PopupMenuButton<_LibraryAction>(
                      key: const Key('library-actions'),
                      tooltip: context.localized('Resource actions', '资源操作'),
                      onSelected: (_LibraryAction action) {
                        switch (action) {
                          case _LibraryAction.create:
                            viewModel.startCreating();
                          case _LibraryAction.import:
                            onImport?.call();
                          case _LibraryAction.importJson:
                            onImportJson?.call();
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
                            if (onImportJson != null)
                              PopupMenuItem<_LibraryAction>(
                                value: _LibraryAction.importJson,
                                child: Text(
                                  context.localized(
                                    'Import shared JSON',
                                    '导入分享 JSON',
                                  ),
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
                  Text(
                    context.localized('Resources', '资源'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Text(
                    '${viewModel.visibleResources.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  _TransferActionButton(
                    actionKey: const Key('library-import'),
                    tooltip: context.localized('Import folder', '导入文件夹'),
                    onPressed: onImport,
                    icon: Icons.drive_folder_upload_outlined,
                  ),
                  const SizedBox(width: 5),
                  _TransferActionButton(
                    actionKey: const Key('library-import-json'),
                    tooltip: context.localized(
                      'Import shared JSON',
                      '导入分享 JSON',
                    ),
                    onPressed: onImportJson,
                    icon: Icons.upload_file_outlined,
                  ),
                  const SizedBox(width: 5),
                  _TransferActionButton(
                    actionKey: const Key('library-export'),
                    tooltip: context.localized('Export JSON', '导出 JSON'),
                    onPressed: onExport,
                    icon: Icons.download_outlined,
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
          const SizedBox(height: 16),
          TextField(
            key: const Key('resource-search'),
            onChanged: viewModel.setQuery,
            decoration: InputDecoration(
              hintText: context.localized('Search name or content', '搜索名称或内容'),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              prefixIconConstraints: const BoxConstraints(minWidth: 38),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _TypeTab(
                        label: context.localized('All', '全部'),
                        selected:
                            viewModel.selectedType == null &&
                            !viewModel.pinnedOnly,
                        onTap: () => viewModel.setTypeFilter(null),
                      ),
                      for (final ResourceType type in ResourceType.values.where(
                        (ResourceType value) =>
                            value.isConfigurableAgentResource,
                      )) ...<Widget>[
                        const SizedBox(width: 3),
                        _TypeTab(
                          key: Key('resource-filter-${type.name}'),
                          label: _typeLabel(context, type),
                          selected: viewModel.selectedType == type,
                          onTap: () => viewModel.setTypeFilter(type),
                        ),
                      ],
                      const SizedBox(width: 3),
                      _TypeTab(
                        label: context.localized('Pinned', '已置顶'),
                        selected: viewModel.pinnedOnly,
                        onTap: () =>
                            viewModel.setPinnedOnly(!viewModel.pinnedOnly),
                      ),
                      const SizedBox(width: 14),
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
              ),
              const SizedBox(width: 10),
              if (viewModel.selectionCount > 0) ...<Widget>[
                Text(
                  context.localized(
                    '${viewModel.selectionCount} selected',
                    '已选 ${viewModel.selectionCount} 项',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(width: 3),
                IconButton(
                  key: const Key('resource-delete-selection'),
                  tooltip: context.localized('Delete selected', '删除所选'),
                  onPressed: onDeleteSelection,
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                ),
                IconButton(
                  tooltip: context.localized('Clear selection', '清除选择'),
                  onPressed: viewModel.clearSelection,
                  icon: const Icon(Icons.close_rounded, size: 16),
                ),
              ],
              TextButton(
                key: const Key('resource-select-all'),
                onPressed: viewModel.toggleAllVisible,
                child: Text(
                  viewModel.allVisibleSelected
                      ? context.localized('Clear all', '取消全选')
                      : context.localized('Select all', '全选'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _LibraryAction { create, import, importJson, export }

class _TransferActionButton extends StatelessWidget {
  const _TransferActionButton({
    required this.actionKey,
    required this.tooltip,
    required this.onPressed,
    required this.icon,
  });

  final Key actionKey;
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return IconButton(
      key: actionKey,
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(34),
        minimumSize: const Size.square(34),
        maximumSize: const Size.square(34),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: colors.onSurfaceVariant,
        backgroundColor: colors.surface,
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.78)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      ),
      icon: SizedBox.square(
        dimension: 18,
        child: Center(child: Icon(icon, size: 18)),
      ),
    );
  }
}

String _typeLabel(BuildContext context, ResourceType type) {
  return switch (type) {
    ResourceType.prompt => context.localized('Prompts', '提示词'),
    ResourceType.skill => context.localized('Skills', '技能'),
    ResourceType.mcp => 'MCP',
    ResourceType.knowledge => context.localized('Knowledge', '知识库'),
    ResourceType.clipboard => context.localized('Clipboard', '剪贴板'),
  };
}

class _TypeTab extends StatelessWidget {
  const _TypeTab({
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 6, 9, 7),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? colors.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: selected ? colors.onSurface : colors.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
