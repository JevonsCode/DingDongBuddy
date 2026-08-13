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
        color: PopupStyle.of(context).surface,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: PopupStyle.of(context).border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.schedule_rounded,
              size: 9,
              color: PopupStyle.of(context).textTertiary,
            ),
            const SizedBox(width: 4),
            Text(
              context.localized('$hours h · $count', '$hours 小时 · $count'),
              style: TextStyle(
                color: PopupStyle.of(context).textSecondary,
                fontSize: 10,
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
          hoverColor: PopupStyle.of(context).accentSoft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(7, 4, 4, 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  context.localized('More', '更多'),
                  style: TextStyle(
                    color: PopupStyle.of(context).accent,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 13,
                  color: PopupStyle.of(context).accent,
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
    required this.isSubagent,
    this.onTap,
    super.key,
  });

  final AgentActivity activity;
  final bool animate;
  final bool isSubagent;
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
    } else if (oldWidget.animate && !widget.animate) {
      _resetAnimation();
    }
  }

  void _startIfNeeded() {
    if (!widget.animate) {
      _resetAnimation();
      return;
    }
    _controller
      ..stop()
      ..value = 0;
    _controller.repeat(reverse: true, count: 4);
  }

  void _resetAnimation() {
    _controller
      ..stop()
      ..value = 0;
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
                    PopupStyle.of(context).surface,
                    PopupStyle.of(context).accentSoft,
                    pulse * 0.72,
                  ),
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(
                    color: Color.lerp(
                      PopupStyle.of(context).border,
                      PopupStyle.of(context).accent,
                      pulse * 0.42,
                    )!,
                  ),
                  boxShadow: pulse == 0
                      ? const <BoxShadow>[]
                      : <BoxShadow>[
                          BoxShadow(
                            color: PopupStyle.of(
                              context,
                            ).accent.withValues(alpha: 0.14 * pulse),
                            blurRadius: 12 * pulse,
                          ),
                        ],
                ),
                child: Row(
                  children: <Widget>[
                    PopupSymbolIcon(
                      'today',
                      size: 18,
                      color: PopupStyle.of(context).accent,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  widget.activity.source,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: PopupStyle.of(context).textPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.activity.message,
                            key: Key('activity-message-${widget.activity.id}'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: PopupStyle.of(context).textSecondary,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.activity.repeatCount > 1) ...<Widget>[
                      const SizedBox(width: 5),
                      SizedBox(
                        height: 32,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Tooltip(
                            message: context.localized(
                              '${widget.activity.repeatCount} notifications for this conversation',
                              '此会话已提醒 ${widget.activity.repeatCount} 次',
                            ),
                            child: ActivityRepeatCount(
                              key: Key(
                                'activity-repeat-count-${widget.activity.id}',
                              ),
                              count: widget.activity.repeatCount,
                              foregroundColor: widget.activity.unseen
                                  ? PopupStyle.of(
                                      context,
                                    ).activityUnread.withValues(alpha: 0.58)
                                  : PopupStyle.of(
                                      context,
                                    ).textPrimary.withValues(alpha: 0.13),
                              verticalOffset: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    SizedBox(
                      width: 52,
                      child: Text(
                        TimeOfDay.fromDateTime(
                          widget.activity.completedAt.toLocal(),
                        ).format(context),
                        key: Key(
                          'activity-completed-time-${widget.activity.id}',
                        ),
                        maxLines: 1,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.clip,
                        style: TextStyle(
                          color: PopupStyle.of(context).textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          fontFeatures: <FontFeature>[
                            FontFeature.tabularFigures(),
                          ],
                        ),
                      ),
                    ),
                    if (widget.isSubagent) ...<Widget>[
                      const SizedBox(width: 7),
                      AgentSubagentBadge(
                        key: Key('activity-subagent-${widget.activity.id}'),
                        compact: true,
                      ),
                    ] else if (widget.onTap != null) ...<Widget>[
                      const SizedBox(width: 7),
                      Tooltip(
                        message: context.localized(
                          'Open Agent conversation',
                          '打开 Agent 对话',
                        ),
                        child: Icon(
                          Icons.open_in_new_rounded,
                          key: Key('activity-open-conversation'),
                          size: 13,
                          color: PopupStyle.of(context).textTertiary,
                        ),
                      ),
                    ] else if (widget.activity.conversationTarget !=
                        null) ...<Widget>[
                      const SizedBox(width: 7),
                      AgentUnknownConversationIcon(
                        key: Key(
                          'activity-unknown-conversation-${widget.activity.id}',
                        ),
                        compact: true,
                      ),
                    ] else
                      SizedBox(
                        key: Key(
                          'activity-open-conversation-placeholder-${widget.activity.id}',
                        ),
                        width: 20,
                      ),
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
    this.badge,
    super.key,
  });

  final String symbol;
  final String value;
  final String label;
  final VoidCallback onTap;
  final _MetricCardBadge? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: <String>[
        label,
        value,
        if (badge != null) badge!.semanticLabel,
      ].join(', '),
      child: ExcludeSemantics(
        child: Material(
          color: PopupStyle.of(context).surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: PopupStyle.of(context).border),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 72,
              child: Stack(
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 8,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            PopupSymbolIcon(
                              symbol,
                              size: 18,
                              color: PopupStyle.of(context).accent,
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: PopupStyle.of(context).textPrimary,
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
                          style: TextStyle(
                            color: PopupStyle.of(context).textSecondary,
                            fontSize: 10,
                            height: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (badge != null)
                    Positioned(
                      key: badge!.key,
                      top: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: badge!.tone == _MetricCardBadgeTone.attention
                              ? PopupStyle.of(context).warmTagSurface
                              : PopupStyle.of(context).accent,
                          borderRadius: BorderRadius.circular(4),
                          border: badge!.tone == _MetricCardBadgeTone.attention
                              ? Border.all(
                                  color: PopupStyle.of(
                                    context,
                                  ).warmAccent.withValues(alpha: 0.28),
                                )
                              : null,
                          boxShadow:
                              badge!.tone == _MetricCardBadgeTone.attention
                              ? null
                              : <BoxShadow>[
                                  BoxShadow(
                                    color: PopupStyle.of(
                                      context,
                                    ).accent.withValues(alpha: 0.20),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: Text(
                          badge!.label,
                          style: TextStyle(
                            color: badge!.tone == _MetricCardBadgeTone.attention
                                ? PopupStyle.of(context).warmAccent
                                : PopupStyle.of(context).background,
                            fontSize:
                                badge!.tone == _MetricCardBadgeTone.attention
                                ? 9.5
                                : 9,
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
        ),
      ),
    );
  }
}

enum _MetricCardBadgeTone { accent, attention }

@immutable
class _MetricCardBadge {
  const _MetricCardBadge({
    required this.key,
    required this.label,
    String? semanticLabel,
    this.tone = _MetricCardBadgeTone.accent,
  }) : semanticLabel = semanticLabel ?? label;

  final Key key;
  final String label;
  final String semanticLabel;
  final _MetricCardBadgeTone tone;
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
    final Brightness brightness = Theme.of(context).brightness;
    final ResourceCardPresentation display =
        ResourceCardPresentation.fromResource(resource);
    final Color background = switch (resource.type) {
      ResourceType.prompt => PopupStyle.of(context).warmSurface,
      ResourceType.skill => PopupStyle.of(context).skillSurface,
      ResourceType.mcp => PopupStyle.mcpSurface(brightness),
      ResourceType.knowledge ||
      ResourceType.clipboard => PopupStyle.of(context).surface,
    };
    final String symbol = switch (resource.type) {
      ResourceType.prompt => 'prompt',
      ResourceType.skill => 'skill',
      ResourceType.mcp => 'mcp',
      ResourceType.knowledge => 'knowledge',
      ResourceType.clipboard => 'clipboard',
    };
    final Color accent = switch (resource.type) {
      ResourceType.prompt => PopupStyle.of(context).warmAccent,
      ResourceType.skill => PopupStyle.of(context).skillAccent,
      ResourceType.mcp => PopupStyle.mcpAccent(brightness),
      ResourceType.knowledge => PopupStyle.of(context).accent,
      ResourceType.clipboard => PopupStyle.of(context).textSecondary,
    };
    final List<String> tags = _enabledResourceTags(context, resource, display);
    final String scopedLabel = context.localized('Scoped', '有触发范围');
    final List<String> visibleTags = <String>[
      ...tags.take(2),
      if (resource.isScopedSkill && !tags.take(2).contains(scopedLabel))
        scopedLabel,
    ];
    final int hiddenTagCount = tags.length - visibleTags.length;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (TapDownDetails details) =>
          _showContextMenu(context, details.globalPosition),
      child: Container(
        key: Key('today-enabled-${resource.id}'),
        height: 92,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: PopupStyle.of(context).card(color: background, radius: 9),
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
                    style: TextStyle(
                      color: PopupStyle.of(context).textPrimary,
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
                    style: TextStyle(
                      color: PopupStyle.of(context).textSecondary,
                      fontSize: 10,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 16,
                    child: ClipRect(
                      child: Wrap(
                        spacing: 4,
                        children: <Widget>[
                          for (final String tag in visibleTags)
                            _TinyTag(
                              key: resource.isScopedSkill && tag == scopedLabel
                                  ? Key('today-enabled-scope-${resource.id}')
                                  : null,
                              label: tag,
                            ),
                          if (hiddenTagCount > 0)
                            _TinyTag(label: '+$hiddenTagCount'),
                        ],
                      ),
                    ),
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
            isDark: Theme.of(context).brightness == Brightness.dark,
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
        color: PopupStyle.of(context).field,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: PopupStyle.of(context).textSecondary,
          fontSize: 10,
          height: 1,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
