import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:dingdong/features/library/domain/resource_card_presentation.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double _statusColumnWidth = 56;
const double _updatedColumnWidth = 116;
const double _statusUpdatedGap = 16;

/// Lazy, keyboard-ready resource result list.
class ResourceList extends StatelessWidget {
  const ResourceList({
    required this.viewModel,
    required this.onDeleteResource,
    this.contextMenuGateway,
    super.key,
  });

  final LibraryViewModel viewModel;
  final ValueChanged<Resource> onDeleteResource;
  final DesktopContextMenuGateway? contextMenuGateway;

  @override
  Widget build(BuildContext context) {
    final List<Resource> resources = viewModel.visibleResources;
    return LayoutBuilder(
      key: const Key('resource-list'),
      builder: (BuildContext context, BoxConstraints constraints) {
        final _VisibleColumns columns = _VisibleColumns.fromWidth(
          constraints.maxWidth,
        );
        return Column(
          children: <Widget>[
            _ResourceListHeader(columns: columns),
            const Divider(height: 1),
            Expanded(
              child: resources.isEmpty
                  ? _EmptyResourceList()
                  : Scrollbar(
                      child: ListView.builder(
                        padding: EdgeInsets.only(
                          bottom: viewModel.selectionCount > 0 ? 74 : 8,
                        ),
                        itemCount: resources.length,
                        itemExtent: 58,
                        itemBuilder: (BuildContext context, int index) {
                          final Resource resource = resources[index];
                          return _ResourceRow(
                            key: ValueKey<String>(
                              'resource-row-${resource.id}',
                            ),
                            resource: resource,
                            display: ResourceCardPresentation.fromResource(
                              resource,
                            ),
                            columns: columns,
                            selectedForAction: viewModel.isSelected(
                              resource.id,
                            ),
                            onOpen: () => viewModel.selectResource(resource),
                            onToggleSelection: () =>
                                viewModel.toggleSelection(resource.id),
                            onToggleEnabled: () => viewModel.save(
                              resource.copyWith(enabled: !resource.enabled),
                              select: false,
                            ),
                            onSecondaryTapUp: (TapUpDetails details) =>
                                _showContextMenu(
                                  context,
                                  details.globalPosition,
                                  resource,
                                ),
                          );
                        },
                      ),
                    ),
            ),
          ],
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
        ? await showDesktopContextMenu<_ResourceRowAction>(
            context: context,
            globalPosition: position,
            entries: <DesktopMenuEntry<_ResourceRowAction>>[
              DesktopMenuItem<_ResourceRowAction>(
                value: _ResourceRowAction.delete,
                symbol: 'delete',
                label: context.localized('Delete', '删除'),
                destructive: true,
              ),
            ],
          )
        : switch (await contextMenuGateway!.show(
            x: position.dx,
            y: position.dy,
            useChinese: Localizations.localeOf(context).languageCode == 'zh',
            isDark: Theme.of(context).brightness == Brightness.dark,
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

final class _VisibleColumns {
  const _VisibleColumns({
    required this.scope,
    required this.source,
    required this.status,
    required this.updated,
  });

  factory _VisibleColumns.fromWidth(double width) => _VisibleColumns(
    scope: width >= 650,
    source: width >= 760,
    status: width >= 560,
    updated: width >= 860,
  );

  final bool scope;
  final bool source;
  final bool status;
  final bool updated;
}

class _ResourceListHeader extends StatelessWidget {
  const _ResourceListHeader({required this.columns});

  final _VisibleColumns columns;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextStyle? style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colors.onSurfaceVariant,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.15,
    );
    return Semantics(
      header: true,
      child: Container(
        key: const Key('resource-list-header'),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        color: colors.surfaceContainerLowest,
        child: Row(
          children: <Widget>[
            const SizedBox(width: 28),
            const SizedBox(width: 8),
            _ColumnLabel(
              width: 94,
              label: context.localized('Type', '类型'),
              style: style,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.localized('Resource', '资源'),
                maxLines: 1,
                style: style,
              ),
            ),
            if (columns.scope)
              _ColumnLabel(
                width: 90,
                label: context.localized('Scope', '作用域'),
                style: style,
              ),
            if (columns.source)
              _ColumnLabel(
                width: 96,
                label: context.localized('Source', '来源'),
                style: style,
              ),
            if (columns.status)
              _ColumnLabel(
                width: _statusColumnWidth,
                label: context.localized('Status', '状态'),
                style: style,
              ),
            if (columns.updated) ...<Widget>[
              const SizedBox(width: _statusUpdatedGap),
              _ColumnLabel(
                width: _updatedColumnWidth,
                label: context.localized('Updated', '更新'),
                style: style,
              ),
            ],
            const SizedBox(width: 28),
          ],
        ),
      ),
    );
  }
}

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel({
    required this.width,
    required this.label,
    required this.style,
  });

  final double width;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    ),
  );
}

class _EmptyResourceList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final Color foreground = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.search_off_rounded, size: 22, color: foreground),
          const SizedBox(height: 9),
          Text(
            context.localized('No matching resources', '没有匹配的资源'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _ResourceRow extends StatefulWidget {
  const _ResourceRow({
    required this.resource,
    required this.display,
    required this.columns,
    required this.selectedForAction,
    required this.onOpen,
    required this.onToggleSelection,
    required this.onToggleEnabled,
    required this.onSecondaryTapUp,
    super.key,
  });

  final Resource resource;
  final ResourceCardPresentation display;
  final _VisibleColumns columns;
  final bool selectedForAction;
  final VoidCallback onOpen;
  final VoidCallback onToggleSelection;
  final Future<void> Function() onToggleEnabled;
  final GestureTapUpCallback onSecondaryTapUp;

  @override
  State<_ResourceRow> createState() => _ResourceRowState();
}

class _ResourceRowState extends State<_ResourceRow> {
  bool _hovered = false;
  bool _focused = false;

  void _open() => widget.onOpen();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color fill = widget.selectedForAction
        ? colors.primary.withValues(alpha: 0.055)
        : (_hovered || _focused)
        ? colors.onSurface.withValues(alpha: 0.032)
        : Colors.transparent;
    final BorderSide quietDivider = BorderSide(
      color: colors.outlineVariant.withValues(alpha: 0.52),
    );
    final BorderSide focusSide = BorderSide(
      color: colors.primary.withValues(alpha: 0.55),
    );
    return Semantics(
      button: true,
      selected: widget.selectedForAction,
      label: context.localized(
        'Open ${widget.display.title}',
        '打开 ${widget.display.title}',
      ),
      onTap: _open,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _open();
                return null;
              },
            ),
          },
          onShowFocusHighlight: (bool value) {
            if (_focused != value) setState(() => _focused = value);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _open,
            onSecondaryTapUp: widget.onSecondaryTapUp,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: fill,
                border: Border(
                  left: _focused ? focusSide : BorderSide.none,
                  top: _focused ? focusSide : BorderSide.none,
                  right: _focused ? focusSide : BorderSide.none,
                  bottom: _focused ? focusSide : quietDivider,
                ),
              ),
              child: Row(
                children: <Widget>[
                  _SelectionButton(
                    key: ValueKey<String>(
                      'resource-select-${widget.resource.id}',
                    ),
                    selected: widget.selectedForAction,
                    onPressed: widget.onToggleSelection,
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 94,
                    child: _ResourceTypeIdentity(type: widget.resource.type),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          widget.display.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.display.summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  if (widget.columns.scope)
                    SizedBox(
                      width: 90,
                      child: widget.resource.isScopedSkill
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: _TriggerScopeBadge(
                                key: Key(
                                  'resource-scope-${widget.resource.id}',
                                ),
                              ),
                            )
                          : _QuietCell(
                              label: _activationLabel(
                                context,
                                widget.resource.activation,
                              ),
                            ),
                    ),
                  if (widget.columns.source)
                    SizedBox(
                      width: 96,
                      child: _QuietCell(
                        label: _sourceLabel(context, widget.resource),
                      ),
                    ),
                  if (widget.columns.status)
                    SizedBox(
                      key: ValueKey<String>(
                        'resource-status-${widget.resource.id}',
                      ),
                      width: _statusColumnWidth,
                      child: _ResourceStatus(
                        enabled: widget.resource.enabled,
                        onChanged: () => widget.onToggleEnabled(),
                      ),
                    ),
                  if (widget.columns.updated) ...<Widget>[
                    const SizedBox(width: _statusUpdatedGap),
                    SizedBox(
                      key: ValueKey<String>(
                        'resource-updated-${widget.resource.id}',
                      ),
                      width: _updatedColumnWidth,
                      child: _QuietCell(
                        label: MaterialLocalizations.of(
                          context,
                        ).formatShortDate(widget.resource.updatedAt.toLocal()),
                      ),
                    ),
                  ],
                  SizedBox(
                    width: 28,
                    child: widget.resource.pinned
                        ? Tooltip(
                            message: context.localized('Pinned', '已置顶'),
                            child: Icon(
                              Icons.push_pin_outlined,
                              size: 14,
                              color: colors.onSurfaceVariant,
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResourceTypeIdentity extends StatelessWidget {
  const _ResourceTypeIdentity({required this.type});

  final ResourceType type;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color accent = _typeColor(colors, type);
    return Row(
      children: <Widget>[
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.085),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: accent.withValues(alpha: 0.16)),
          ),
          child: PopupSymbolIcon(_symbolFor(type), size: 14, color: accent),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            _typeName(context, type),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuietCell extends StatelessWidget {
  const _QuietCell({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    ),
  );
}

class _ResourceStatus extends StatelessWidget {
  const _ResourceStatus({required this.enabled, required this.onChanged});

  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final String label = enabled
        ? context.localized('Disable resource', '停用资源')
        : context.localized('Enable resource', '启用资源');
    return Semantics(
      container: true,
      toggled: enabled,
      enabled: true,
      label: label,
      onTap: onChanged,
      child: ExcludeSemantics(
        child: Align(
          alignment: Alignment.centerLeft,
          child: Tooltip(
            message: label,
            child: CompactSwitch(value: enabled, onChanged: (_) => onChanged()),
          ),
        ),
      ),
    );
  }
}

class _TriggerScopeBadge extends StatelessWidget {
  const _TriggerScopeBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.localized(
        'Only active in its configured trigger scope',
        '仅在已配置的触发范围内生效',
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: colors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.filter_alt_outlined, size: 11, color: colors.primary),
            const SizedBox(width: 3),
            Text(
              context.localized('Scoped', '有触发范围'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.primary,
                fontSize: 9,
                height: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
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
        child: DesktopIconButton(
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

String _symbolFor(ResourceType type) {
  return switch (type) {
    ResourceType.prompt => 'prompt',
    ResourceType.skill => 'skill',
    ResourceType.mcp => 'mcp',
    ResourceType.knowledge => 'folder',
    ResourceType.clipboard => 'clipboard',
  };
}

String _typeName(BuildContext context, ResourceType type) {
  return switch (type) {
    ResourceType.prompt => context.localized('Prompt', '提示词'),
    ResourceType.skill => context.localized('Skill', '技能'),
    ResourceType.mcp => 'MCP',
    ResourceType.knowledge => context.localized('Knowledge', '知识库'),
    ResourceType.clipboard => context.localized('Clipboard', '剪贴板'),
  };
}

String _activationLabel(BuildContext context, ResourceActivation activation) {
  return switch (activation) {
    ResourceActivation.always => context.localized('Always', '始终'),
    ResourceActivation.taskMatch => context.localized('Task match', '任务匹配'),
    ResourceActivation.manual => context.localized('Manual', '手动'),
  };
}

String _sourceLabel(BuildContext context, Resource resource) {
  final String? source = resource.source;
  if (source != null) {
    return source;
  }
  return resource.group == resource.type.defaultGroup
      ? _typeName(context, resource.type)
      : resource.group;
}

Color _typeColor(ColorScheme colors, ResourceType type) {
  return switch (type) {
    ResourceType.prompt => colors.tertiary,
    ResourceType.skill => colors.primary,
    ResourceType.mcp => colors.secondary,
    ResourceType.knowledge => colors.primary,
    ResourceType.clipboard => colors.secondary,
  };
}
