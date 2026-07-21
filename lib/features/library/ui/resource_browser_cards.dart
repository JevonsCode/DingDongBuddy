part of 'resource_browser_screen.dart';

class _ResourceCards extends StatelessWidget {
  const _ResourceCards({
    required this.viewModel,
    required this.clipboardGateway,
    required this.launcher,
  });

  final LibraryViewModel viewModel;
  final ClipboardGateway? clipboardGateway;
  final ResourceManagerLauncher? launcher;

  @override
  Widget build(BuildContext context) {
    final List<Resource> resources = viewModel.visibleResources;
    if (resources.isEmpty) {
      return Center(
        child: Text(
          context.localized('No matching resources', '没有匹配的资源'),
          style: const TextStyle(color: PopupStyle.textSecondary),
        ),
      );
    }
    return ListView.builder(
      key: const Key('resource-list'),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      itemCount: resources.length,
      itemExtent: 124,
      itemBuilder: (BuildContext context, int index) {
        final Resource resource = resources[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ResourceCard(
            resource: resource,
            onToggleEnabled: () => unawaited(
              viewModel.save(resource.copyWith(enabled: !resource.enabled)),
            ),
            onCopy: clipboardGateway == null
                ? null
                : () => clipboardGateway!.writeText(resource.content),
            onEdit: launcher == null
                ? null
                : () => launcher!.show(editingResourceId: resource.id),
            onDelete: () => _confirmDelete(context, resource),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Resource resource) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => DesktopAlertDialog(
        title: Text(context.localized('Delete this resource?', '删除这个资源？')),
        content: Text(resource.title),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.localized('Cancel', '取消')),
          ),
          FilledButton(
            style: DesktopDialogStyle.destructiveButtonStyle(context),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.localized('Delete', '删除')),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      viewModel.selectResource(resource);
      await viewModel.deleteSelected();
    }
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.resource,
    required this.onToggleEnabled,
    required this.onCopy,
    required this.onEdit,
    required this.onDelete,
  });

  final Resource resource;
  final VoidCallback onToggleEnabled;
  final Future<void> Function()? onCopy;
  final Future<void> Function()? onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ResourceCardPresentation display =
        ResourceCardPresentation.fromResource(resource);
    final List<String> tags = _resourceCardTags(context, resource, display);
    final List<String> visibleTags = tags.take(4).toList(growable: false);
    final int hiddenTagCount = tags.length - visibleTags.length;
    final Color background = switch (resource.type) {
      ResourceType.prompt => PopupStyle.warmSurface,
      ResourceType.skill => PopupStyle.skillSurface,
      ResourceType.mcp => PopupStyle.mcpSoft,
      _ => PopupStyle.surfaceSoft,
    };
    return Opacity(
      opacity: resource.enabled ? 1 : 0.58,
      child: Container(
        key: Key('resource-card-${resource.id}'),
        decoration: PopupStyle.card(color: background, radius: 9),
        padding: const EdgeInsets.fromLTRB(14, 12, 11, 10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 32,
              child: PopupSymbolIcon(
                _resourceSymbol(resource.type),
                key: Key('resource-card-type-${resource.id}'),
                size: 20,
                color: _resourceColor(resource.type),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  key: Key('resource-card-content-${resource.id}'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      display.title,
                      key: Key('resource-card-title-${resource.id}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PopupStyle.textPrimary,
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      display.summary,
                      key: Key('resource-card-summary-${resource.id}'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: PopupStyle.textSecondary,
                        fontSize: 10,
                        height: 1.25,
                      ),
                    ),
                    if (tags.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 8),
                      ConstrainedBox(
                        key: Key('resource-card-tags-${resource.id}'),
                        constraints: const BoxConstraints(maxHeight: 39),
                        child: ClipRect(
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: <Widget>[
                              for (final (int index, String tag)
                                  in visibleTags.indexed)
                                _ResourceTag(
                                  label: tag,
                                  prominent:
                                      index == 0 && resource.group.isNotEmpty,
                                  type: resource.type,
                                ),
                              if (hiddenTagCount > 0)
                                _ResourceTag(label: '+$hiddenTagCount'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              key: Key('resource-card-actions-${resource.id}'),
              width: 64,
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: <Widget>[
                  _CardAction(
                    key: Key('resource-card-status-${resource.id}'),
                    symbol: resource.enabled ? 'enabled' : 'paused',
                    tooltip: resource.enabled
                        ? context.localized('Disable', '停用')
                        : context.localized('Enable', '启用'),
                    color: resource.enabled
                        ? PopupStyle.success
                        : PopupStyle.textTertiary,
                    backgroundColor: resource.enabled
                        ? PopupStyle.success.withValues(alpha: 0.13)
                        : PopupStyle.field,
                    onPressed: onToggleEnabled,
                  ),
                  _CardAction(
                    symbol: 'copy',
                    tooltip: context.localized('Copy', '复制'),
                    onPressed: onCopy == null ? null : () => onCopy!(),
                  ),
                  _CardAction(
                    symbol: 'edit',
                    tooltip: context.localized('Edit', '编辑'),
                    onPressed: onEdit == null ? null : () => onEdit!(),
                  ),
                  _CardAction(
                    symbol: 'delete',
                    tooltip: context.localized('Delete', '删除'),
                    color: const Color(0xFF9B625C),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardAction extends StatelessWidget {
  const _CardAction({
    required this.symbol,
    required this.tooltip,
    this.color,
    this.backgroundColor,
    this.onPressed,
    super.key,
  });

  final String symbol;
  final String tooltip;
  final Color? color;
  final Color? backgroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(30),
        minimumSize: const Size.square(30),
        maximumSize: const Size.square(30),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor:
            backgroundColor ?? PopupStyle.field.withValues(alpha: 0.72),
        foregroundColor: color ?? PopupStyle.textSecondary,
        disabledForegroundColor: PopupStyle.textTertiary,
        disabledBackgroundColor: PopupStyle.field.withValues(alpha: 0.45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      icon: symbol == 'enabled' || symbol == 'paused'
          ? EnabledStatusIcon(enabled: symbol == 'enabled', size: 16)
          : PopupSymbolIcon(
              symbol,
              size: 16,
              color: color ?? PopupStyle.textSecondary,
            ),
    );
  }
}

class _ResourceTag extends StatelessWidget {
  const _ResourceTag({required this.label, this.prominent = false, this.type});

  final String label;
  final bool prominent;
  final ResourceType? type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: prominent
            ? switch (type) {
                ResourceType.mcp => PopupStyle.mcpSoft,
                ResourceType.skill => const Color(0xFFE9EBF7),
                _ => const Color(0xFFF0EBDD),
              }
            : PopupStyle.field,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: prominent
              ? switch (type) {
                  ResourceType.mcp => PopupStyle.mcp,
                  ResourceType.skill => const Color(0xFF4C63A1),
                  _ => const Color(0xFF75684F),
                }
              : PopupStyle.textSecondary,
          fontSize: 9,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

List<String> _resourceCardTags(
  BuildContext context,
  Resource resource,
  ResourceCardPresentation display,
) {
  final List<String> values = switch (resource.type) {
    ResourceType.prompt => <String>[
      if (resource.group.isNotEmpty &&
          resource.group != resource.type.defaultGroup)
        resource.group,
      ...resource.tags,
    ],
    ResourceType.skill => <String>[
      context.localized('Skill', '技能'),
      context.localized(
        display.variant == ResourceCardVariant.skillOnline ? 'Online' : 'Local',
        display.variant == ResourceCardVariant.skillOnline ? '在线' : '本地',
      ),
      ...resource.tags,
    ],
    ResourceType.mcp => <String>['MCP', display.variantLabel, ...resource.tags],
    ResourceType.knowledge || ResourceType.clipboard => <String>[
      if (resource.group.isNotEmpty &&
          resource.group != resource.type.defaultGroup)
        resource.group,
      ...resource.tags,
    ],
  };
  final Set<String> seen = <String>{};
  final List<String> result = <String>[];
  for (final String value in values) {
    final String tag = value.trim();
    if (tag.isEmpty || !seen.add(tag.toLowerCase())) continue;
    result.add(tag);
  }
  return result;
}

String _typeLabel(BuildContext context, ResourceType? type) {
  return switch (type) {
    null => context.localized('All', '全部'),
    ResourceType.prompt => context.localized('Prompts', '提示词'),
    ResourceType.skill => context.localized('Skills', '技能'),
    ResourceType.mcp => 'MCP',
    ResourceType.knowledge => context.localized('Knowledge', '知识库'),
    ResourceType.clipboard => context.localized('Clipboard', '剪贴板'),
  };
}

String _resourceSymbol(ResourceType type) {
  return switch (type) {
    ResourceType.prompt => 'prompt',
    ResourceType.skill => 'skill',
    ResourceType.mcp => 'mcp',
    ResourceType.knowledge => 'knowledge',
    ResourceType.clipboard => 'clipboard',
  };
}

Color _resourceColor(ResourceType type) {
  return switch (type) {
    ResourceType.prompt => const Color(0xFFA97822),
    ResourceType.skill => const Color(0xFF4C63A1),
    ResourceType.mcp => PopupStyle.mcp,
    ResourceType.knowledge => PopupStyle.accent,
    ResourceType.clipboard => PopupStyle.textSecondary,
  };
}
