import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:flutter/material.dart';

/// Search and primary commands for the resource workspace.
class ResourceFilterBar extends StatelessWidget {
  const ResourceFilterBar({
    required this.viewModel,
    this.onImportJson,
    this.onImportLink,
    this.onImportHistory,
    this.onExport,
    this.onDeleteSelection,
    super.key,
  });

  final LibraryViewModel viewModel;
  final VoidCallback? onImportJson;
  final VoidCallback? onImportLink;
  final VoidCallback? onImportHistory;
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
                    DesktopMenuButton<_LibraryAction>(
                      key: const Key('library-actions'),
                      tooltip: context.localized('Resource actions', '资源操作'),
                      onSelected: (_LibraryAction action) {
                        switch (action) {
                          case _LibraryAction.create:
                            viewModel.startCreating();
                          case _LibraryAction.importJson:
                            onImportJson?.call();
                          case _LibraryAction.importLink:
                            onImportLink?.call();
                          case _LibraryAction.importHistory:
                            onImportHistory?.call();
                          case _LibraryAction.export:
                            onExport?.call();
                        }
                      },
                      entries: <DesktopMenuEntry<_LibraryAction>>[
                        DesktopMenuItem<_LibraryAction>(
                          value: _LibraryAction.create,
                          label: context.localized('New resource', '新建资源'),
                          symbol: 'add_title',
                        ),
                        if (onImportJson != null)
                          DesktopMenuItem<_LibraryAction>(
                            value: _LibraryAction.importJson,
                            label: context.localized(
                              'Import JSON file',
                              '导入 JSON 文件',
                            ),
                            symbol: 'archive',
                          ),
                        if (onImportLink != null)
                          DesktopMenuItem<_LibraryAction>(
                            value: _LibraryAction.importLink,
                            label: context.localized(
                              'Import from link',
                              '从链接导入',
                            ),
                            symbol: 'link',
                          ),
                        if (onImportHistory != null)
                          DesktopMenuItem<_LibraryAction>(
                            value: _LibraryAction.importHistory,
                            label: context.localized('Import history', '导入历史'),
                            symbol: 'details',
                          ),
                        if (onExport != null)
                          DesktopMenuItem<_LibraryAction>(
                            value: _LibraryAction.export,
                            label: context.localized('Export JSON', '导出 JSON'),
                            symbol: 'share',
                          ),
                      ],
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
                  _TransferActionGroup(
                    children: <Widget>[
                      _TransferActionButton(
                        actionKey: const Key('library-import-json'),
                        tooltip: context.localized(
                          'Import JSON file',
                          '导入 JSON 文件',
                        ),
                        onPressed: onImportJson,
                        icon: Icons.download_outlined,
                      ),
                      _TransferActionButton(
                        actionKey: const Key('library-import-link'),
                        tooltip: context.localized('Import from link', '从链接导入'),
                        onPressed: onImportLink,
                        icon: Icons.link_rounded,
                      ),
                      _TransferActionButton(
                        actionKey: const Key('library-import-history'),
                        tooltip: context.localized('Import history', '导入历史'),
                        onPressed: onImportHistory,
                        icon: Icons.history_rounded,
                      ),
                      _TransferActionButton(
                        actionKey: const Key('library-export'),
                        tooltip: context.localized('Export JSON', '导出 JSON'),
                        onPressed: onExport,
                        icon: Icons.upload_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  DesktopActionButton(
                    onPressed: viewModel.startCreating,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: context.localized('New resource', '新建资源'),
                    tone: DesktopActionTone.primary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          DesktopSearchField(
            key: const Key('resource-search'),
            onChanged: viewModel.setQuery,
            height: 40,
            hintText: context.localized('Search name or content', '搜索名称或内容'),
            clearTooltip: context.localized('Clear search', '清除搜索'),
            searchIcon: const Icon(Icons.search_rounded, size: 18),
            borderRadius: 9,
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
                const SizedBox(width: 8),
                DesktopIconButton(
                  key: const Key('resource-delete-selection'),
                  tooltip: context.localized('Delete selected', '删除所选'),
                  onPressed: onDeleteSelection,
                  size: 32,
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.07),
                  foregroundColor: Theme.of(context).colorScheme.error,
                  borderColor: Theme.of(
                    context,
                  ).colorScheme.error.withValues(alpha: 0.22),
                  icon: const Icon(Icons.delete_outline_rounded, size: 17),
                ),
                const SizedBox(width: 6),
                DesktopActionButton(
                  key: const Key('resource-clear-selection'),
                  onPressed: viewModel.clearSelection,
                  icon: const Icon(Icons.close_rounded, size: 14),
                  label: context.localized('Clear selection', '清除选择'),
                  compact: true,
                  tone: DesktopActionTone.neutral,
                ),
                const SizedBox(width: 8),
              ],
              DesktopActionButton(
                key: const Key('resource-select-all'),
                onPressed: viewModel.toggleAllVisible,
                label: viewModel.allVisibleSelected
                    ? context.localized('Clear all', '取消全选')
                    : context.localized('Select all', '全选'),
                compact: true,
                tone: DesktopActionTone.soft,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _LibraryAction { create, importJson, importLink, importHistory, export }

class _TransferActionGroup extends StatelessWidget {
  const _TransferActionGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('library-transfer-actions'),
      height: 34,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.76),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (int index = 0; index < children.length; index++) ...<Widget>[
            if (index > 0)
              Container(
                width: 1,
                height: 18,
                color: colors.outlineVariant.withValues(alpha: 0.72),
              ),
            children[index],
          ],
        ],
      ),
    );
  }
}

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
    return DesktopIconButton(
      key: actionKey,
      tooltip: tooltip,
      onPressed: onPressed,
      size: 34,
      iconSize: 18,
      foregroundColor: colors.onSurfaceVariant,
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
