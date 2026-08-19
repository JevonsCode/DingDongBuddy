import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_choice_chip.dart';
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
    super.key,
  });

  final LibraryViewModel viewModel;
  final VoidCallback? onImportJson;
  final VoidCallback? onImportLink;
  final VoidCallback? onImportHistory;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
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
                        context.l10n.resourceManager,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ),
                    DesktopMenuButton<_LibraryAction>(
                      key: const Key('library-actions'),
                      tooltip: context.l10n.resourceActions,
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
                          label: context.l10n.newResource,
                          symbol: 'add_title',
                        ),
                        if (onImportJson != null)
                          DesktopMenuItem<_LibraryAction>(
                            value: _LibraryAction.importJson,
                            label: context.l10n.importJSONFile,
                            symbol: 'archive',
                          ),
                        if (onImportLink != null)
                          DesktopMenuItem<_LibraryAction>(
                            value: _LibraryAction.importLink,
                            label: context.l10n.importFromLink,
                            symbol: 'link',
                          ),
                        if (onImportHistory != null)
                          DesktopMenuItem<_LibraryAction>(
                            value: _LibraryAction.importHistory,
                            label: context.l10n.importHistory,
                            symbol: 'details',
                          ),
                        if (onExport != null)
                          DesktopMenuItem<_LibraryAction>(
                            value: _LibraryAction.export,
                            label: context.l10n.exportJSON,
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
                    context.l10n.resourceManager,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.25,
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
                        tooltip: context.l10n.importJSONFile,
                        onPressed: onImportJson,
                        icon: Icons.download_outlined,
                      ),
                      _TransferActionButton(
                        actionKey: const Key('library-import-link'),
                        tooltip: context.l10n.importFromLink,
                        onPressed: onImportLink,
                        icon: Icons.link_rounded,
                      ),
                      _TransferActionButton(
                        actionKey: const Key('library-import-history'),
                        tooltip: context.l10n.importHistory,
                        onPressed: onImportHistory,
                        icon: Icons.history_rounded,
                      ),
                      _TransferActionButton(
                        actionKey: const Key('library-export'),
                        tooltip: context.l10n.exportJSON,
                        onPressed: onExport,
                        icon: Icons.upload_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  DesktopActionButton(
                    onPressed: viewModel.startCreating,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: context.l10n.newResource,
                    tone: DesktopActionTone.primary,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget search = DesktopSearchField(
                key: const Key('resource-search'),
                onChanged: viewModel.setQuery,
                height: 36,
                hintText: context.l10n.searchNameOrContent,
                clearTooltip: context.l10n.clearSearch,
                searchIcon: const Icon(Icons.search_rounded, size: 17),
                borderRadius: 7,
              );
              final Widget filters = SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: _TypeFilters(viewModel: viewModel),
              );
              if (constraints.maxWidth < 680) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    search,
                    const SizedBox(height: 10),
                    filters,
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(flex: 5, child: search),
                  const SizedBox(width: 12),
                  Expanded(flex: 6, child: filters),
                ],
              );
            },
          ),
          const SizedBox(height: 9),
          Row(
            children: <Widget>[
              Text(
                viewModel.selectionCount > 0
                    ? context.l10n.selectioncountSelected(
                        viewModel.selectionCount,
                      )
                    : context.l10n.lengthResults(
                        viewModel.visibleResources.length,
                      ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              DesktopActionButton(
                key: const Key('resource-select-all'),
                onPressed: viewModel.toggleAllVisible,
                label: viewModel.allVisibleSelected
                    ? context.l10n.clearAll
                    : context.l10n.selectAll,
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

class _TypeFilters extends StatelessWidget {
  const _TypeFilters({required this.viewModel});

  final LibraryViewModel viewModel;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      _TypeTab(
        key: const Key('resource-filter-all'),
        label: context.l10n.all,
        selected: viewModel.selectedType == null && !viewModel.pinnedOnly,
        onTap: () => viewModel.setTypeFilter(null),
      ),
      for (final ResourceType type in ResourceType.values.where(
        (ResourceType value) => value.isConfigurableAgentResource,
      )) ...<Widget>[
        const SizedBox(width: 5),
        _TypeTab(
          key: Key('resource-filter-${type.name}'),
          label: _typeLabel(context, type),
          selected: viewModel.selectedType == type,
          onTap: () => viewModel.setTypeFilter(type),
        ),
      ],
      const SizedBox(width: 5),
      _TypeTab(
        key: const Key('resource-filter-pinned'),
        label: context.l10n.pinned,
        selected: viewModel.pinnedOnly,
        onTap: () => viewModel.setPinnedOnly(!viewModel.pinnedOnly),
      ),
    ],
  );
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
    ResourceType.prompt => context.l10n.prompts,
    ResourceType.skill => context.l10n.skills,
    ResourceType.mcp => 'MCP',
    ResourceType.knowledge => context.l10n.knowledge,
    ResourceType.clipboard => context.l10n.clipboard,
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
    return DesktopChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      borderRadius: 6,
      backgroundColor: colors.surfaceContainerLowest,
      selectedBackgroundColor: colors.primary.withValues(alpha: 0.08),
      borderColor: colors.outlineVariant.withValues(alpha: 0.72),
      selectedBorderColor: colors.primary.withValues(alpha: 0.46),
      foregroundColor: colors.onSurfaceVariant,
      selectedForegroundColor: colors.primary,
      textStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontSize: 11,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      label: Text(label),
    );
  }
}
