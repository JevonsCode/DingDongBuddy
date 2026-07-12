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
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.localized('Delete this resource?', '删除这个资源？')),
        content: Text(resource.title),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.localized('Cancel', '取消')),
          ),
          FilledButton(
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
    final Color background = switch (resource.type) {
      ResourceType.prompt => PopupStyle.warmSurface,
      ResourceType.skill => PopupStyle.skillSurface,
      _ => PopupStyle.surfaceSoft,
    };
    return Opacity(
      opacity: resource.enabled ? 1 : 0.58,
      child: Container(
        decoration: PopupStyle.card(color: background, radius: 9),
        padding: const EdgeInsets.fromLTRB(14, 12, 11, 10),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 32,
              child: PopupSymbolIcon(
                _resourceSymbol(resource.type),
                size: 20,
                color: _resourceColor(resource.type),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    resource.title,
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
                    resource.content.replaceAll('\n', ' '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PopupStyle.textSecondary,
                      fontSize: 10,
                      height: 1.25,
                    ),
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 39,
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 3,
                        children: <Widget>[
                          for (final (int index, String tag) in <String>[
                            if (resource.group.isNotEmpty) resource.group,
                            ...resource.tags,
                          ].indexed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: index == 0
                                    ? const Color(0xFFECE4CF)
                                    : PopupStyle.accentSoft,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(color: PopupStyle.border),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(
                                  color: index == 0
                                      ? const Color(0xFF6E6246)
                                      : PopupStyle.accent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 94,
              child: Wrap(
                spacing: 2,
                runSpacing: 4,
                children: <Widget>[
                  _CardAction(
                    symbol: resource.enabled ? 'enabled' : 'paused',
                    tooltip: resource.enabled
                        ? context.localized('Disable', '停用')
                        : context.localized('Enable', '启用'),
                    color: resource.enabled
                        ? PopupStyle.success
                        : PopupStyle.textTertiary,
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
    this.onPressed,
  });

  final String symbol;
  final String tooltip;
  final Color? color;
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
        backgroundColor: PopupStyle.surface,
        foregroundColor: color ?? PopupStyle.textSecondary,
        disabledForegroundColor: PopupStyle.textTertiary,
        side: const BorderSide(color: PopupStyle.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
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
    ResourceType.mcp => PopupStyle.textTertiary,
    ResourceType.knowledge => PopupStyle.accent,
    ResourceType.clipboard => PopupStyle.textSecondary,
  };
}
