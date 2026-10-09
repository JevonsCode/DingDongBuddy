import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// A Monday-first calendar. Calendar arithmetic stays correct across DST.
class TokenUsageHeatmap extends StatefulWidget {
  const TokenUsageHeatmap({
    required this.year,
    required this.today,
    required this.dailyTotals,
    required this.selectedDay,
    required this.onSelected,
    super.key,
  });

  final int year;
  final DateTime today;
  final Map<DateTime, TokenUsageTotals> dailyTotals;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelected;

  @override
  State<TokenUsageHeatmap> createState() => _TokenUsageHeatmapState();
}

class _TokenUsageHeatmapState extends State<TokenUsageHeatmap> {
  static const double _pitch = 16;
  static const double _labelsWidth = 34;
  final ScrollController _scrollController = ScrollController();
  final Map<DateTime, FocusNode> _dayFocus = <DateTime, FocusNode>{};

  @override
  void didUpdateWidget(TokenUsageHeatmap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year != widget.year) {
      for (final FocusNode node in _dayFocus.values) {
        node.dispose();
      }
      _dayFocus.clear();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    for (final FocusNode node in _dayFocus.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _moveFocus(DateTime date, int offset) {
    final DateTime target = DateTime(date.year, date.month, date.day + offset);
    _dayFocus[target]?.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime first = DateTime(widget.year, 1, 1);
    final int dayCount = DateTime.utc(
      widget.year + 1,
    ).difference(DateTime.utc(widget.year)).inDays;
    final int startOffset = first.weekday - DateTime.monday;
    final int weekCount = ((dayCount + startOffset) / 7).ceil();
    final String locale = Localizations.localeOf(context).toLanguageTag();
    final List<int> activeCounts =
        widget.dailyTotals.values
            .map((TokenUsageTotals totals) => totals.totalTokens)
            .where((int total) => total > 0)
            .toList()
          ..sort();
    // Quartiles keep ordinary days legible when one unusually large session
    // would otherwise flatten the entire calendar into the lightest color.
    final List<int> thresholds = activeCounts.isEmpty
        ? const <int>[]
        : <int>[
            for (final double quartile in <double>[0.25, 0.5, 0.75])
              activeCounts[(activeCounts.length * quartile).ceil() - 1],
          ];
    final List<Color> palette = _palette(Theme.of(context).colorScheme);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            key: const Key('token-usage-heatmap-scroll'),
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 13),
            child: SizedBox(
              width: _labelsWidth + weekCount * _pitch,
              height: 24 + 7 * _pitch,
              child: FocusTraversalGroup(
                policy: OrderedTraversalPolicy(),
                child: Stack(
                  children: <Widget>[
                    for (final int weekday in <int>[0, 2, 4])
                      Positioned(
                        left: 0,
                        top: 24 + weekday * _pitch,
                        child: Text(
                          DateFormat.E(
                            locale,
                          ).format(DateTime(2024, 1, 1 + weekday)),
                          style: TextStyle(
                            fontSize: 9,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    for (int month = 1; month <= 12; month += 1)
                      Positioned(
                        left:
                            _labelsWidth +
                            ((DateTime.utc(widget.year, month)
                                            .difference(
                                              DateTime.utc(widget.year),
                                            )
                                            .inDays +
                                        startOffset) ~/
                                    7) *
                                _pitch,
                        top: 0,
                        child: Text(
                          DateFormat.MMM(
                            locale,
                          ).format(DateTime(widget.year, month)),
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    for (int index = 0; index < dayCount; index += 1)
                      _cell(
                        context,
                        date: DateTime(widget.year, 1, index + 1),
                        index: index,
                        startOffset: startOffset,
                        thresholds: thresholds,
                        palette: palette,
                        locale: locale,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Text(
              context.l10n.tokenUsageLess,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(width: 8),
            for (final Color color in palette)
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: 4),
            Text(
              context.l10n.tokenUsageMore,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }

  Widget _cell(
    BuildContext context, {
    required DateTime date,
    required int index,
    required int startOffset,
    required List<int> thresholds,
    required List<Color> palette,
    required String locale,
  }) {
    final bool future = date.isAfter(widget.today);
    final TokenUsageTotals totals =
        widget.dailyTotals[date] ?? TokenUsageTotals.zero;
    final int intensity = totals.totalTokens == 0
        ? 0
        : 1 +
              thresholds
                  .where((int count) => totals.totalTokens >= count)
                  .length;
    final String prefix = totals.totalIsExact
        ? ''
        : totals.dateAttributionExact
        ? '≥ '
        : '≈ ';
    final String count =
        '$prefix${NumberFormat.decimalPattern(locale).format(totals.totalTokens)}';
    final String label = context.l10n.tokenUsageDayTooltip(
      DateFormat.yMMMMEEEEd(locale).format(date),
      count,
    );
    final Color color = palette[intensity];
    return Positioned(
      left: _labelsWidth + ((index + startOffset) ~/ 7) * _pitch,
      top: 24 + ((index + startOffset) % 7) * _pitch,
      child: SizedBox.square(
        dimension: _pitch,
        child: future
            ? Padding(
                padding: const EdgeInsets.all(2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.first.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              )
            : FocusTraversalOrder(
                order: NumericFocusOrder(index.toDouble()),
                child: _DayCell(
                  key: Key('token-usage-day-${_dateKey(date)}'),
                  focusNode: _dayFocus.putIfAbsent(
                    date,
                    () => FocusNode(debugLabel: _dateKey(date)),
                  ),
                  label: label,
                  color: color,
                  selected: DateUtils.isSameDay(widget.selectedDay, date),
                  onSelected: () => widget.onSelected(date),
                  onMove: (int offset) => _moveFocus(date, offset),
                ),
              ),
      ),
    );
  }
}

String _dateKey(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

List<Color> _palette(ColorScheme colors) => <Color>[
  colors.surfaceContainerHighest,
  Color.lerp(colors.surfaceContainerHighest, colors.primary, 0.28)!,
  Color.lerp(colors.surfaceContainerHighest, colors.primary, 0.5)!,
  Color.lerp(colors.surfaceContainerHighest, colors.primary, 0.75)!,
  colors.primary,
];

class _DayCell extends StatefulWidget {
  const _DayCell({
    required this.focusNode,
    required this.label,
    required this.color,
    required this.selected,
    required this.onSelected,
    required this.onMove,
    super.key,
  });

  final FocusNode focusNode;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onSelected;
  final ValueChanged<int> onMove;

  @override
  State<_DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<_DayCell> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: (FocusNode node, KeyEvent event) {
      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
        return KeyEventResult.ignored;
      }
      final int? offset = switch (event.logicalKey) {
        LogicalKeyboardKey.arrowUp => -1,
        LogicalKeyboardKey.arrowDown => 1,
        LogicalKeyboardKey.arrowLeft => -7,
        LogicalKeyboardKey.arrowRight => 7,
        _ => null,
      };
      if (offset == null) return KeyEventResult.ignored;
      widget.onMove(offset);
      return KeyEventResult.handled;
    },
    child: Tooltip(
      message: widget.label,
      preferBelow: false,
      excludeFromSemantics: true,
      child: Semantics(
        label: widget.label,
        button: true,
        selected: widget.selected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            focusNode: widget.focusNode,
            onFocusChange: (bool focused) {
              setState(() => _focused = focused);
              if (focused) {
                widget.onSelected();
                unawaited(Scrollable.ensureVisible(context, alignment: 0.5));
              }
            },
            onTap: widget.onSelected,
            borderRadius: BorderRadius.circular(3),
            child: Container(
              margin: const EdgeInsets.all(1),
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                border: Border.all(
                  color: widget.selected || _focused
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: _focused ? 1.5 : 1,
                ),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
