import 'dart:async';
import 'dart:math';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/date_filter_range.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_date_range_picker.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_multi_select_field.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:flutter/material.dart';

/// Shared virtual viewport. Only requested pages are retained by the view;
/// slivers construct rows on demand, including when the page size exceeds 21.
class RecentAgentFeed extends StatefulWidget {
  const RecentAgentFeed({
    required this.controller,
    required this.rowBuilder,
    this.header,
    this.empty,
    this.compact = false,
    this.pageSize = 21,
    this.now,
    this.visible = true,
    this.onViewed,
    super.key,
  });
  final ActivityController controller;
  final Widget Function(BuildContext, AgentActivity, bool isNewThisVisit)
  rowBuilder;
  final Widget? header, empty;
  final bool compact;
  final int pageSize;
  final DateTime Function()? now;
  final bool visible;
  final Future<void> Function(int sequence)? onViewed;
  @override
  State<RecentAgentFeed> createState() => _RecentAgentFeedState();
}

class _RecentAgentFeedState extends State<RecentAgentFeed> {
  final _scroll = ScrollController();
  List<AgentActivity> _items = const [];
  int _total = 0, _generation = 0;
  bool _loading = false;
  Set<String>? _sources;
  DateFilterPreset? _preset;
  DateTimeRange? _custom;
  int? _visitBoundary;

  @override
  void initState() {
    super.initState();
    if (widget.visible) _visitBoundary = widget.controller.lastViewedSequence;
    widget.controller.addListener(_changed);
    _scroll.addListener(_onScroll);
    unawaited(_load(reset: true));
  }

  @override
  void didUpdateWidget(RecentAgentFeed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (widget.visible &&
        (!oldWidget.visible || oldWidget.controller != widget.controller)) {
      _visitBoundary = widget.controller.lastViewedSequence;
    }
    if (oldWidget.controller != widget.controller ||
        oldWidget.pageSize != widget.pageSize ||
        oldWidget.visible != widget.visible) {
      if (_scroll.hasClients) _scroll.jumpTo(0);
      unawaited(_load(reset: true, resetPagination: true));
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    if (_visitBoundary != null &&
        widget.controller.latestSequence < _visitBoundary!) {
      _visitBoundary = null;
    }
    unawaited(_load(reset: true));
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 220) {
      unawaited(_load());
    }
  }

  Future<void> _load({bool reset = false, bool resetPagination = false}) async {
    if (!reset && (_loading || _items.length >= _total)) return;
    final generation = reset ? ++_generation : _generation;
    final offset = reset ? 0 : _items.length;
    _loading = true;
    final observedSequence = widget.controller.latestSequence;
    // Keep the last page on screen until its replacement arrives.
    final page = await widget.controller.queryPage(
      offset: offset,
      limit: reset && !resetPagination
          ? max(widget.pageSize, _items.length)
          : widget.pageSize,
      sources: _sources,
      newerThanSequence: _visitBoundary,
      range: _preset == DateFilterPreset.custom
          ? _custom
          : _preset?.bounds((widget.now ?? DateTime.now)()),
    );
    if (!mounted || generation != _generation) return;
    setState(() {
      _items = reset ? page.items : [..._items, ...page.items];
      _total = page.total;
      _loading = false;
    });
    if (widget.visible &&
        (widget.controller.lastViewedSequence == null ||
            observedSequence > widget.controller.lastViewedSequence!)) {
      if (widget.onViewed case final onViewed?) {
        await onViewed(observedSequence);
      } else {
        widget.controller.markFeedViewed(observedSequence);
      }
    }
  }

  void _filter(VoidCallback edit) {
    setState(edit);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(_load(reset: true, resetPagination: true));
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.compact ? 16.0 : 24.0;
    final boundaryIndex = _visitBoundary == null
        ? -1
        : _items.indexWhere((item) => item.sequence <= _visitBoundary!);
    return Stack(
      children: [
        CustomScrollView(
          key: const Key('recent-agent-feed-list'),
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(padding, 12, padding, 8),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.header != null) widget.header!,
                    if (!widget.compact) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 170,
                            height: 38,
                            child: DesktopMultiSelectField<String>(
                              key: const Key('recent-agent-source-filter'),
                              label: context.l10n.activitySourceFilter,
                              items: [
                                for (final source in widget.controller.sources)
                                  DesktopSelectItem(
                                    value: source,
                                    label: source,
                                  ),
                              ],
                              selected: _sources,
                              onChanged: (value) =>
                                  _filter(() => _sources = value),
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            height: 38,
                            child: DesktopDateFilter(
                              key: const Key('recent-agent-date-filter'),
                              allowAll: true,
                              value: _preset,
                              customRange: _custom,
                              now: widget.now,
                              onChanged: (preset, range) => _filter(() {
                                _preset = preset;
                                _custom = range;
                              }),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_items.isEmpty && !_loading)
              SliverPadding(
                padding: EdgeInsets.all(padding),
                sliver: SliverToBoxAdapter(
                  child:
                      widget.controller.activities.isEmpty &&
                          widget.empty != null
                      ? widget.empty!
                      : Text(context.l10n.activityNoMatches),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 16 : 14,
              ),
              sliver: SliverList.separated(
                itemCount: _items.length,
                separatorBuilder: (_, _) => widget.compact
                    ? const SizedBox(height: 7)
                    : const Divider(height: 1),
                itemBuilder: (context, index) {
                  final activity = _items[index];
                  return KeyedSubtree(
                    key: ValueKey('feed-row-${activity.id}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (boundaryIndex > 0 && index == boundaryIndex)
                          const _LastSeenDivider(),
                        widget.rowBuilder(
                          context,
                          activity,
                          _visitBoundary == null ||
                              activity.sequence > _visitBoundary!,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: _items.length < _total
                      ? DesktopActionButton(
                          key: const Key('recent-agent-load-more'),
                          onPressed: _loading ? null : () => unawaited(_load()),
                          label: context.l10n.activityLoadMore,
                          compact: true,
                        )
                      : const SizedBox(height: 4),
                ),
              ),
            ),
          ],
        ),
        Positioned(
          right: 12,
          bottom: 12,
          child: AnimatedBuilder(
            animation: _scroll,
            builder: (context, _) => _scroll.hasClients && _scroll.offset > 320
                ? DesktopIconButton(
                    key: const Key('recent-agent-back-to-top'),
                    icon: const Icon(Icons.vertical_align_top),
                    tooltip: context.l10n.activityBackToTop,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHigh,
                    onPressed: () => unawaited(
                      _scroll.animateTo(
                        0,
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _LastSeenDivider extends StatelessWidget {
  const _LastSeenDivider();

  @override
  Widget build(BuildContext context) => Padding(
    key: const Key('activity-last-seen-divider'),
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        const Expanded(child: Divider(height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            context.l10n.activityLastSeenHere,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Expanded(child: Divider(height: 1)),
      ],
    ),
  );
}
