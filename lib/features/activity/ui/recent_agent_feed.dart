import 'dart:async';
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
    super.key,
  });
  final ActivityController controller;
  final Widget Function(BuildContext, AgentActivity) rowBuilder;
  final Widget? header, empty;
  final bool compact;
  final int pageSize;
  final DateTime Function()? now;
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

  @override
  void initState() {
    super.initState();
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
    if (oldWidget.controller != widget.controller ||
        oldWidget.pageSize != widget.pageSize) {
      _changed();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _scroll.dispose();
    super.dispose();
  }

  void _changed() {
    unawaited(_load(reset: true));
  }

  void _onScroll() {
    if (_scroll.hasClients && _scroll.position.extentAfter < 220) {
      unawaited(_load());
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loading || _items.length >= _total)) return;
    final generation = reset ? ++_generation : _generation;
    final offset = reset ? 0 : _items.length;
    _loading = true;
    // Keep the last page on screen until its replacement arrives.
    final page = await widget.controller.queryPage(
      offset: offset,
      limit: widget.pageSize,
      sources: _sources,
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
  }

  void _filter(VoidCallback edit) {
    setState(edit);
    if (_scroll.hasClients) _scroll.jumpTo(0);
    unawaited(_load(reset: true));
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.compact ? 16.0 : 24.0;
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
                    child: widget.rowBuilder(context, activity),
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
