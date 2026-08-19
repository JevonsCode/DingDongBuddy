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
          context.l10n.noMatchingResources,
          style: TextStyle(color: PopupStyle.of(context).textSecondary),
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
            onToggleEnabled: () => unawaited(_toggleEnabled(resource)),
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

  Future<void> _toggleEnabled(Resource resource) async {
    try {
      await viewModel.save(resource.copyWith(enabled: !resource.enabled));
    } on Object {
      // The synchronized store publishes the actionable problem to the shared
      // issue center and rolls the resource state back transactionally.
    }
  }

  Future<void> _confirmDelete(BuildContext context, Resource resource) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => DesktopAlertDialog(
        title: Text(context.l10n.deleteThisResource2),
        content: Text(resource.title),
        actions: <Widget>[
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, false),
            label: context.l10n.cancel,
            compact: true,
          ),
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, true),
            label: context.l10n.delete,
            tone: DesktopActionTone.danger,
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isMcp = resource.type == ResourceType.mcp;
    final Color background = switch (resource.type) {
      ResourceType.prompt => PopupStyle.of(context).warmSurface,
      ResourceType.skill => PopupStyle.of(context).skillSurface,
      ResourceType.mcp => PopupStyle.mcpSurface(Theme.of(context).brightness),
      _ => PopupStyle.of(context).surfaceSoft,
    };
    final BoxDecoration decoration = isMcp
        ? BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: PopupStyle.mcpBorder(Theme.of(context).brightness),
            ),
          )
        : PopupStyle.of(context).card(color: background, radius: 9);
    return Opacity(
      opacity: resource.enabled ? 1 : 0.58,
      child: Container(
        key: Key('resource-card-${resource.id}'),
        decoration: decoration,
        padding: const EdgeInsets.fromLTRB(14, 12, 11, 10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 32,
              child: PopupSymbolIcon(
                _resourceSymbol(resource.type),
                key: Key('resource-card-type-${resource.id}'),
                size: 20,
                color: _resourceColor(resource.type, isDark: isDark),
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PopupStyle.of(context).textPrimary,
                        fontSize: 13,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      display.summary,
                      key: Key('resource-card-summary-${resource.id}'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: PopupStyle.of(context).textSecondary,
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
                                  key:
                                      resource.isScopedSkill &&
                                          tag == context.l10n.scoped
                                      ? Key(
                                          'resource-card-scope-${resource.id}',
                                        )
                                      : null,
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
                        ? context.l10n.disable
                        : context.l10n.enable,
                    color: resource.enabled
                        ? PopupStyle.of(context).success
                        : PopupStyle.of(context).textTertiary,
                    backgroundColor: resource.enabled
                        ? PopupStyle.of(context).success.withValues(alpha: 0.13)
                        : PopupStyle.of(context).field,
                    onPressed: onToggleEnabled,
                  ),
                  _CardAction(
                    symbol: 'copy',
                    tooltip: context.l10n.copy,
                    onPressed: onCopy == null ? null : () => onCopy!(),
                  ),
                  _CardAction(
                    symbol: 'edit',
                    tooltip: context.l10n.edit,
                    onPressed: onEdit == null ? null : () => onEdit!(),
                  ),
                  _CardAction(
                    symbol: 'delete',
                    tooltip: context.l10n.delete,
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
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      child: ExcludeSemantics(
        child: DesktopIconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          size: 30,
          iconSize: 16,
          backgroundColor:
              backgroundColor ??
              PopupStyle.of(context).field.withValues(alpha: 0.72),
          foregroundColor: color ?? PopupStyle.of(context).textSecondary,
          icon: symbol == 'enabled' || symbol == 'paused'
              ? EnabledStatusIcon(enabled: symbol == 'enabled', size: 16)
              : PopupSymbolIcon(
                  symbol,
                  size: 16,
                  color: color ?? PopupStyle.of(context).textSecondary,
                ),
        ),
      ),
    );
  }
}

class _ResourceTag extends StatelessWidget {
  const _ResourceTag({
    required this.label,
    this.prominent = false,
    this.type,
    super.key,
  });

  final String label;
  final bool prominent;
  final ResourceType? type;

  @override
  Widget build(BuildContext context) {
    final bool usesMcpAccent = type == ResourceType.mcp;
    final bool emphasized = prominent || usesMcpAccent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: emphasized
            ? switch (type) {
                ResourceType.mcp => PopupStyle.mcpSurface(
                  Theme.of(context).brightness,
                  opacity: 0.16,
                ),
                ResourceType.skill => PopupStyle.of(context).skillTagSurface,
                _ => PopupStyle.of(context).warmTagSurface,
              }
            : PopupStyle.of(context).field,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: emphasized
              ? switch (type) {
                  ResourceType.mcp => PopupStyle.mcpAccent(
                    Theme.of(context).brightness,
                  ),
                  ResourceType.skill => PopupStyle.of(context).skillAccent,
                  _ => PopupStyle.of(context).warmAccent,
                }
              : PopupStyle.of(context).textSecondary,
          fontSize: 10,
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
      context.l10n.skill2,
      display.variant == ResourceCardVariant.skillOnline
          ? context.l10n.online
          : context.l10n.local,
      if (resource.isScopedSkill) context.l10n.scoped,
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
    null => context.l10n.all,
    ResourceType.prompt => context.l10n.prompts,
    ResourceType.skill => context.l10n.skills,
    ResourceType.mcp => 'MCP',
    ResourceType.knowledge => context.l10n.knowledge,
    ResourceType.clipboard => context.l10n.clipboard,
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

Color _resourceColor(ResourceType type, {bool isDark = false}) {
  final Brightness brightness = isDark ? Brightness.dark : Brightness.light;
  final PopupPalette popup = PopupStyle.forBrightness(brightness);
  return switch (type) {
    ResourceType.prompt => popup.warmAccent,
    ResourceType.skill => popup.skillAccent,
    ResourceType.mcp => PopupStyle.mcpAccent(brightness),
    ResourceType.knowledge => popup.accent,
    ResourceType.clipboard => popup.textSecondary,
  };
}
