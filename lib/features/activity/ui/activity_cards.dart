part of 'activity_screen.dart';

class _RecentAgentCount extends StatelessWidget {
  const _RecentAgentCount({required this.count, required this.hours});

  final int count;
  final int hours;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const Key('recent-agent-count'),
      decoration: BoxDecoration(
        color: PopupStyle.surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: PopupStyle.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.schedule_rounded,
              size: 9,
              color: PopupStyle.textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              context.localized('$hours h · $count', '$hours 小时 · $count'),
              style: const TextStyle(
                color: PopupStyle.textSecondary,
                fontSize: 8,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentAgentMoreButton extends StatelessWidget {
  const _RecentAgentMoreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.localized('View all recent agents', '查看全部最近 Agent'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('recent-agent-more'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          hoverColor: PopupStyle.accentSoft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 4, 4, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  context.localized('More', '更多'),
                  style: const TextStyle(
                    color: PopupStyle.accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 13,
                  color: PopupStyle.accent,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AgentActivityCard extends StatefulWidget {
  const _AgentActivityCard({
    required this.activity,
    required this.animate,
    this.onTap,
  });

  final AgentActivity activity;
  final bool animate;
  final VoidCallback? onTap;

  @override
  State<_AgentActivityCard> createState() => _AgentActivityCardState();
}

class _AgentActivityCardState extends State<_AgentActivityCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
  );

  @override
  void initState() {
    super.initState();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(covariant _AgentActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.animate && widget.animate) {
      _startIfNeeded();
    }
  }

  void _startIfNeeded() {
    if (widget.animate) {
      _controller.repeat(reverse: true, count: 4);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double pulse = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: 1 + pulse * 0.012,
          child: MouseRegion(
            cursor: widget.onTap == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: Container(
                key: Key('activity-${widget.activity.id}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Color.lerp(
                    PopupStyle.surface,
                    PopupStyle.accentSoft,
                    pulse * 0.72,
                  ),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: Color.lerp(
                      PopupStyle.border,
                      PopupStyle.accent,
                      pulse * 0.42,
                    )!,
                  ),
                  boxShadow: pulse == 0
                      ? const <BoxShadow>[]
                      : <BoxShadow>[
                          BoxShadow(
                            color: PopupStyle.accent.withValues(
                              alpha: 0.14 * pulse,
                            ),
                            blurRadius: 12 * pulse,
                          ),
                        ],
                ),
                child: Row(
                  children: <Widget>[
                    const PopupSymbolIcon(
                      'today',
                      size: 18,
                      color: PopupStyle.accent,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.activity.source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PopupStyle.textPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.activity.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PopupStyle.textSecondary,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      TimeOfDay.fromDateTime(
                        widget.activity.completedAt.toLocal(),
                      ).format(context),
                      style: const TextStyle(
                        color: PopupStyle.textTertiary,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.onTap != null) ...<Widget>[
                      const SizedBox(width: 7),
                      Tooltip(
                        message: context.localized(
                          'Open Agent conversation',
                          '打开 Agent 对话',
                        ),
                        child: const Icon(
                          Icons.open_in_new_rounded,
                          key: Key('activity-open-conversation'),
                          size: 13,
                          color: PopupStyle.textTertiary,
                        ),
                      ),
                    ],
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.symbol,
    required this.value,
    required this.label,
    required this.onTap,
    this.showBadge = false,
    super.key,
  });

  final String symbol;
  final String value;
  final String label;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PopupStyle.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: PopupStyle.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 72,
          child: Stack(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        PopupSymbolIcon(
                          symbol,
                          size: 18,
                          color: PopupStyle.accent,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: PopupStyle.textPrimary,
                              fontSize: 15,
                              height: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: PopupStyle.textSecondary,
                        fontSize: 9,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (showBadge)
                Positioned(
                  key: const Key('today-mcp-badge'),
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: PopupStyle.accent,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: PopupStyle.accent.withValues(alpha: 0.20),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Text(
                      'MCP',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 7,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnabledResourceCard extends StatelessWidget {
  const _EnabledResourceCard({
    required this.resource,
    required this.onDisable,
    required this.onEdit,
    required this.contextMenuGateway,
  });

  final Resource resource;
  final VoidCallback onDisable;
  final VoidCallback? onEdit;
  final DesktopContextMenuGateway? contextMenuGateway;

  @override
  Widget build(BuildContext context) {
    final ResourceCardPresentation display =
        ResourceCardPresentation.fromResource(resource);
    final Color background = switch (resource.type) {
      ResourceType.prompt => PopupStyle.warmSurface,
      ResourceType.skill => PopupStyle.skillSurface,
      ResourceType.mcp => PopupStyle.mcpSoft,
      ResourceType.knowledge || ResourceType.clipboard => PopupStyle.surface,
    };
    final String symbol = switch (resource.type) {
      ResourceType.prompt => 'prompt',
      ResourceType.skill => 'skill',
      ResourceType.mcp => 'mcp',
      ResourceType.knowledge => 'knowledge',
      ResourceType.clipboard => 'clipboard',
    };
    final Color accent = switch (resource.type) {
      ResourceType.prompt => const Color(0xFFA97822),
      ResourceType.skill => const Color(0xFF4C63A1),
      ResourceType.mcp => PopupStyle.mcp,
      ResourceType.knowledge => PopupStyle.accent,
      ResourceType.clipboard => PopupStyle.textSecondary,
    };
    final List<String> tags = _enabledResourceTags(context, resource, display);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (TapDownDetails details) =>
          _showContextMenu(context, details.globalPosition),
      child: Container(
        key: Key('today-enabled-${resource.id}'),
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: PopupStyle.card(color: background, radius: 9),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 34,
              child: PopupSymbolIcon(symbol, color: accent, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    display.title,
                    key: Key('today-enabled-title-${resource.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PopupStyle.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    display.summary,
                    key: Key('today-enabled-summary-${resource.id}'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: PopupStyle.textSecondary,
                      fontSize: 9,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 4,
                    runSpacing: 3,
                    children: <Widget>[
                      ...tags
                          .take(4)
                          .map(
                            (String tag) => _TinyTag(
                              key:
                                  resource.isScopedSkill &&
                                      tag ==
                                          context.localized('Scoped', '有触发范围')
                                  ? Key('today-enabled-scope-${resource.id}')
                                  : null,
                              label: tag,
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
            const EnabledStatusIcon(enabled: true),
          ],
        ),
      ),
    );
  }

  Future<void> _showContextMenu(BuildContext context, Offset position) async {
    final _EnabledResourceAction? action = contextMenuGateway == null
        ? await showDesktopContextMenu<_EnabledResourceAction>(
            context: context,
            globalPosition: position,
            entries: <DesktopMenuEntry<_EnabledResourceAction>>[
              DesktopMenuItem<_EnabledResourceAction>(
                value: _EnabledResourceAction.edit,
                enabled: onEdit != null,
                symbol: 'edit',
                label: context.localized('Edit', '编辑'),
              ),
              DesktopMenuItem<_EnabledResourceAction>(
                value: _EnabledResourceAction.disable,
                symbol: 'paused',
                label: context.localized('Disable', '停用'),
              ),
            ],
          )
        : switch (await contextMenuGateway!.show(
            x: position.dx,
            y: position.dy,
            useChinese: Localizations.localeOf(context).languageCode == 'zh',
            items: <DesktopContextMenuItem>[
              DesktopContextMenuItem(
                id: 'edit',
                englishLabel: 'Edit',
                chineseLabel: '编辑',
                enabled: onEdit != null,
              ),
              const DesktopContextMenuItem(
                id: 'disable',
                englishLabel: 'Disable',
                chineseLabel: '停用',
              ),
            ],
          )) {
            'edit' => _EnabledResourceAction.edit,
            'disable' => _EnabledResourceAction.disable,
            _ => null,
          };
    switch (action) {
      case _EnabledResourceAction.edit:
        onEdit?.call();
      case _EnabledResourceAction.disable:
        onDisable();
      case null:
        return;
    }
  }
}

enum _EnabledResourceAction { edit, disable }

List<String> _enabledResourceTags(
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
      if (resource.isScopedSkill) context.localized('Scoped', '有触发范围'),
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
  return values
      .where((String value) {
        final String normalized = value.trim().toLowerCase();
        return normalized.isNotEmpty && seen.add(normalized);
      })
      .toList(growable: false);
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: PopupStyle.field,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: PopupStyle.textSecondary,
          fontSize: 9,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
