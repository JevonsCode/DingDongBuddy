part of 'activity_screen.dart';

class _AgentActivityCard extends StatefulWidget {
  const _AgentActivityCard({required this.activity, required this.animate});

  final AgentActivity activity;
  final bool animate;

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
          child: Container(
            key: Key('activity-${widget.activity.id}'),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
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
              ],
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
    super.key,
  });

  final String symbol;
  final String value;
  final String label;
  final VoidCallback onTap;

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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    PopupSymbolIcon(symbol, size: 18, color: PopupStyle.accent),
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
        ),
      ),
    );
  }
}

class _EnabledResourceCard extends StatelessWidget {
  const _EnabledResourceCard({required this.resource});

  final Resource resource;

  @override
  Widget build(BuildContext context) {
    final Color background = resource.type == ResourceType.skill
        ? PopupStyle.skillSurface
        : resource.type == ResourceType.prompt
        ? PopupStyle.warmSurface
        : PopupStyle.surface;
    return Container(
      key: Key('today-enabled-${resource.id}'),
      height: 92,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: PopupStyle.card(color: background, radius: 9),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 34,
            child: PopupSymbolIcon(
              resource.type == ResourceType.skill ? 'skill' : 'prompt',
              color: resource.type == ResourceType.skill
                  ? const Color(0xFF4C63A1)
                  : const Color(0xFFA97822),
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  resource.title,
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
                  resource.content.replaceAll('\n', ' '),
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
                    if (resource.group.isNotEmpty)
                      _TinyTag(label: resource.group),
                    ...resource.tags
                        .take(3)
                        .map((String tag) => _TinyTag(label: tag)),
                  ],
                ),
              ],
            ),
          ),
          const EnabledStatusIcon(enabled: true),
        ],
      ),
    );
  }
}

class _TinyTag extends StatelessWidget {
  const _TinyTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: PopupStyle.accentSoft,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: PopupStyle.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: PopupStyle.accent,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
