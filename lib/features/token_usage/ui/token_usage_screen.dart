import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_csv_export.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';
import 'package:dingdong/features/token_usage/ui/token_usage_controller.dart';
import 'package:dingdong/features/token_usage/ui/token_usage_heatmap.dart';
import 'package:dingdong/platform/file_selector_token_usage_export.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

part 'token_usage_details.dart';
part 'token_usage_widgets.dart';

/// Local daily token history. Explicit source totals remain authoritative.
class TokenUsageScreen extends StatefulWidget {
  const TokenUsageScreen({
    required this.controller,
    this.now,
    this.saveExport = saveTokenUsageCsv,
    super.key,
  });

  final TokenUsageController controller;
  final DateTime Function()? now;
  final TokenUsageCsvSaver saveExport;

  @override
  State<TokenUsageScreen> createState() => _TokenUsageScreenState();
}

class _TokenUsageScreenState extends State<TokenUsageScreen> {
  late int _year;
  late DateTime _selectedDay;
  ConversationTokenUsageSource? _source;
  _TokenUsageRange _range = _TokenUsageRange.year;
  DateTimeRange? _customRange;
  int _rangeFieldGeneration = 0;
  bool _isExporting = false;

  /// Inclusive local calendar bounds of the selected range, or null for the
  /// whole selected year.
  DateTimeRange? get _rangeBounds {
    final DateTime today = _today;
    return switch (_range) {
      _TokenUsageRange.year => null,
      _TokenUsageRange.last7 => DateTimeRange(
        start: DateTime(today.year, today.month, today.day - 6),
        end: today,
      ),
      _TokenUsageRange.last30 => DateTimeRange(
        start: DateTime(today.year, today.month, today.day - 29),
        end: today,
      ),
      _TokenUsageRange.thisMonth => DateTimeRange(
        start: DateTime(today.year, today.month),
        end: today,
      ),
      _TokenUsageRange.custom => _customRange,
    };
  }

  Future<void> _selectRange(_TokenUsageRange? range) async {
    if (range == null) return;
    if (range != _TokenUsageRange.custom) {
      setState(() => _range = range);
      return;
    }
    final DateTime today = _today;
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: today,
      initialDateRange:
          _customRange ??
          DateTimeRange(
            start: DateTime(today.year, today.month, today.day - 6),
            end: today,
          ),
    );
    if (!mounted) return;
    if (picked == null) {
      setState(() => _rangeFieldGeneration += 1);
      return;
    }
    setState(() {
      _rangeFieldGeneration += 1;
      _range = _TokenUsageRange.custom;
      _customRange = picked;
      _year = picked.end.year;
      _selectedDay = picked.end;
    });
  }

  Future<void> _export() async {
    if (_isExporting || widget.controller.isLoading) return;
    final DateTimeRange? bounds = _rangeBounds;
    final export = TokenUsageCsvExport.fromSnapshot(
      widget.controller.snapshot,
      year: _year,
      source: _source,
      from: bounds?.start,
      to: bounds?.end,
    );
    if (export.days.isEmpty) return;
    setState(() => _isExporting = true);
    try {
      final saved = await widget.saveExport(
        contents: export.contents,
        suggestedName: export.suggestedName,
        confirmButtonText: context.l10n.tokenUsageExport,
        fileTypeLabel: context.l10n.tokenUsageExportFileType,
      );
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.tokenUsageExportSaved)),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.tokenUsageExportFailed)),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  DateTime get _today {
    final DateTime now = (widget.now ?? DateTime.now)().toLocal();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _selectedDay = _today;
    _year = _selectedDay.year;
    if (!widget.controller.hasLoaded) {
      unawaited(widget.controller.refresh());
    }
  }

  void _selectYear(int? year) {
    if (year == null) return;
    final List<TokenUsageDay> recorded =
        widget.controller.snapshot.days
            .where((TokenUsageDay day) => day.day.year == year)
            .toList()
          ..sort((TokenUsageDay a, TokenUsageDay b) => a.day.compareTo(b.day));
    setState(() {
      _year = year;
      _range = _TokenUsageRange.year;
      _rangeFieldGeneration += 1;
      _selectedDay = year == _today.year
          ? _today
          : recorded.isNotEmpty
          ? recorded.last.day
          : DateTime(year, 12, 31);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final TokenUsageSnapshot snapshot = widget.controller.snapshot;
        final List<TokenUsageDay> filtered = snapshot.days
            .where(
              (TokenUsageDay day) => _source == null || day.source == _source,
            )
            .toList(growable: false);
        final DateTimeRange? bounds = _rangeBounds;
        final List<TokenUsageDay> yearDays = filtered
            .where((TokenUsageDay day) => day.day.year == _year)
            .toList(growable: false);
        final List<TokenUsageDay> period = bounds == null
            ? yearDays
            : filtered
                  .where(
                    (TokenUsageDay day) =>
                        tokenUsageDayInRange(day.day, bounds.start, bounds.end),
                  )
                  .toList(growable: false);
        final String periodLabel = bounds == null
            ? '$_year'
            : _formatRange(context, bounds);
        final TokenUsageTotals today = TokenUsageTotals.sum(
          filtered
              .where(
                (TokenUsageDay day) => DateUtils.isSameDay(day.day, _today),
              )
              .map((TokenUsageDay day) => day.totals),
        );
        final TokenUsageTotals total = TokenUsageTotals.sum(
          period.map((TokenUsageDay day) => day.totals),
        );
        final bool canConfirmEmpty =
            widget.controller.hasLoaded &&
            snapshot.storageAvailable &&
            !snapshot.warnings.any(
              (String warning) =>
                  warning == 'incomplete_cumulative_totals' ||
                  warning == 'daily_attribution_gap' ||
                  warning == 'ambiguous_counter_epoch' ||
                  warning == 'pending_transcript_tail' ||
                  warning == 'malformed_usage_rows' ||
                  warning == 'missing_event_dates' ||
                  warning == 'refresh_interrupted' ||
                  warning == 'refresh_cancelled',
            ) &&
            !snapshot.coverage.any(
              (TokenUsageSourceCoverage coverage) =>
                  (_source == null || coverage.source == _source) &&
                  (coverage.availability == TokenUsageAvailability.unreadable ||
                      coverage.pendingFiles > 0 ||
                      coverage.malformedRows > 0 ||
                      coverage.undatedRows > 0),
            ) &&
            snapshot.coverage.any(
              (TokenUsageSourceCoverage coverage) =>
                  (_source == null || coverage.source == _source) &&
                  coverage.availability == TokenUsageAvailability.available &&
                  (coverage.filesScanned > 0 ||
                      coverage.source == ConversationTokenUsageSource.dingdong),
            );
        final Map<DateTime, List<TokenUsageTotals>> byDay =
            <DateTime, List<TokenUsageTotals>>{};
        for (final TokenUsageDay day in yearDays) {
          (byDay[DateTime(day.day.year, day.day.month, day.day.day)] ??=
                  <TokenUsageTotals>[])
              .add(day.totals);
        }
        final Map<DateTime, TokenUsageTotals> dailyTotals =
            <DateTime, TokenUsageTotals>{
              for (final MapEntry<DateTime, List<TokenUsageTotals>> day
                  in byDay.entries)
                day.key: TokenUsageTotals.sum(day.value),
            };
        final int activeDayCount = <DateTime>{
          for (final TokenUsageDay day in period)
            if (day.totals.totalTokens > 0)
              DateTime(day.day.year, day.day.month, day.day.day),
        }.length;
        final List<int> years = <int>{
          _today.year,
          _year,
          ...snapshot.days.map((TokenUsageDay day) => day.day.year),
        }.toList()..sort((int a, int b) => b.compareTo(a));
        final List<TokenUsageDay> selected = filtered
            .where(
              (TokenUsageDay day) => DateUtils.isSameDay(day.day, _selectedDay),
            )
            .toList(growable: false);

        return ListView(
          key: const Key('token-usage-screen'),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 28),
          children: <Widget>[
            _Header(
              controller: widget.controller,
              refreshedAt: snapshot.refreshedAt,
              isExporting: _isExporting,
              onExport:
                  period.isEmpty || widget.controller.isLoading || _isExporting
                  ? null
                  : () => unawaited(_export()),
            ),
            const SizedBox(height: 20),
            if (widget.controller.error != null ||
                snapshot.warnings.contains('refresh_interrupted')) ...<Widget>[
              _Notice(
                key: const Key('token-usage-error'),
                icon: Icons.error_outline_rounded,
                message: context.l10n.tokenUsageError,
                isError: true,
              ),
              const SizedBox(height: 14),
            ],
            if (!snapshot.storageAvailable) ...<Widget>[
              _Notice(
                icon: Icons.save_outlined,
                message: context.l10n.tokenUsageStorageUnavailable,
              ),
              const SizedBox(height: 14),
            ],
            if (snapshot.warnings.contains('refresh_cancelled')) ...<Widget>[
              _Notice(
                key: const Key('token-usage-cancelled'),
                icon: Icons.pause_circle_outline_rounded,
                message: context.l10n.tokenUsageRefreshStopped,
              ),
              const SizedBox(height: 14),
            ],
            if (widget.controller.isLoading && !widget.controller.hasLoaded)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 72),
                child: Column(
                  children: <Widget>[
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(height: 16),
                    Text(context.l10n.tokenUsageLoading),
                  ],
                ),
              )
            else ...<Widget>[
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final double width = constraints.maxWidth < 550
                      ? constraints.maxWidth
                      : (constraints.maxWidth - 24) / 3;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: <Widget>[
                      _SummaryCard(
                        key: const Key('token-usage-today'),
                        width: width,
                        label: context.l10n.tokenUsageToday,
                        value: _formatObservedTotal(
                          context,
                          today,
                          canConfirmEmpty,
                        ),
                        detail: context.l10n.tokenUsageTokens,
                        icon: Icons.today_outlined,
                      ),
                      _SummaryCard(
                        key: const Key('token-usage-period'),
                        width: width,
                        label: bounds == null
                            ? context.l10n.tokenUsagePeriodTotal
                            : context.l10n.tokenUsageRangeTotal,
                        value: _formatObservedTotal(
                          context,
                          total,
                          canConfirmEmpty,
                        ),
                        detail:
                            '$periodLabel · ${context.l10n.tokenUsageTokens}',
                        icon: Icons.stacked_line_chart_rounded,
                      ),
                      _SummaryCard(
                        key: const Key('token-usage-active-days'),
                        width: width,
                        label: context.l10n.tokenUsageActiveDays,
                        value: activeDayCount == 0 && !canConfirmEmpty
                            ? context.l10n.tokenUsageNotReported
                            : _formatNumber(context, activeDayCount),
                        detail: periodLabel,
                        icon: Icons.calendar_month_outlined,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 14,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<int>(
                      key: const Key('token-usage-year-filter'),
                      initialValue: _year,
                      decoration: InputDecoration(
                        labelText: context.l10n.tokenUsageYear,
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<int>>[
                        for (final int year in years)
                          DropdownMenuItem<int>(
                            value: year,
                            child: Text('$year'),
                          ),
                      ],
                      onChanged: _selectYear,
                    ),
                  ),
                  SizedBox(
                    key: const Key('token-usage-range-filter'),
                    width: 190,
                    child: DropdownButtonFormField<_TokenUsageRange>(
                      // Form fields keep their own value; rebuild on every
                      // committed or cancelled range change.
                      key: ValueKey<int>(_rangeFieldGeneration),
                      initialValue: _range,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.tokenUsageRange,
                        isDense: true,
                      ),
                      items: <DropdownMenuItem<_TokenUsageRange>>[
                        for (final _TokenUsageRange range
                            in _TokenUsageRange.values)
                          DropdownMenuItem<_TokenUsageRange>(
                            value: range,
                            child: Text(
                              range == _TokenUsageRange.custom &&
                                      _customRange != null
                                  ? _formatRange(context, _customRange!)
                                  : _rangeLabel(context, range),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (_TokenUsageRange? range) =>
                          unawaited(_selectRange(range)),
                    ),
                  ),
                  for (final ConversationTokenUsageSource? source
                      in <ConversationTokenUsageSource?>[
                        null,
                        ...ConversationTokenUsageSource.values.where(
                          (source) =>
                              source != ConversationTokenUsageSource.dingdong ||
                              snapshot.coverage.any((c) => c.source == source),
                        ),
                      ])
                    ChoiceChip(
                      key: Key(
                        'token-usage-source-${source?.apiValue ?? 'all'}',
                      ),
                      label: Text(
                        source == null
                            ? context.l10n.tokenUsageAllAgents
                            : tokenUsageSourceLabel(source),
                      ),
                      selected: _source == source,
                      onSelected: (_) => setState(() => _source = source),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      context.l10n.tokenUsageDailyActivity,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 18),
                    TokenUsageHeatmap(
                      year: _year,
                      today: _today,
                      dailyTotals: dailyTotals,
                      selectedDay: _selectedDay,
                      onSelected: (DateTime day) =>
                          setState(() => _selectedDay = day),
                    ),
                  ],
                ),
              ),
              if (period.isEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _Notice(
                  key: const Key('token-usage-empty'),
                  icon: Icons.insights_outlined,
                  title: snapshot.days.isEmpty
                      ? context.l10n.tokenUsageEmpty
                      : context.l10n.tokenUsageFilteredEmpty,
                  message: snapshot.days.isEmpty
                      ? context.l10n.tokenUsageEmptyBody
                      : context.l10n.tokenUsageFilteredEmptyBody,
                ),
              ],
              const SizedBox(height: 20),
              _DailyDetail(day: _selectedDay, records: selected),
              const SizedBox(height: 20),
              _Coverage(snapshot: snapshot),
            ],
          ],
        );
      },
    );
  }
}

/// Summary scopes for the Token usage cards and CSV export. The heatmap
/// always shows the selected year.
enum _TokenUsageRange { year, last7, last30, thisMonth, custom }

String _rangeLabel(BuildContext context, _TokenUsageRange range) =>
    switch (range) {
      _TokenUsageRange.year => context.l10n.tokenUsageRangeYear,
      _TokenUsageRange.last7 => context.l10n.tokenUsageRangeLast7,
      _TokenUsageRange.last30 => context.l10n.tokenUsageRangeLast30,
      _TokenUsageRange.thisMonth => context.l10n.tokenUsageRangeThisMonth,
      _TokenUsageRange.custom => context.l10n.tokenUsageRangeCustom,
    };

String _formatRange(BuildContext context, DateTimeRange range) {
  final DateFormat format = DateFormat.yMd(_locale(context));
  return '${format.format(range.start)} – ${format.format(range.end)}';
}

String tokenUsageSourceLabel(ConversationTokenUsageSource source) =>
    switch (source) {
      ConversationTokenUsageSource.codex => 'Codex',
      ConversationTokenUsageSource.claudeCode => 'Claude Code',
      ConversationTokenUsageSource.pi => 'Pi',
      ConversationTokenUsageSource.dingdong => 'DingDong',
    };

String _locale(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();

String _formatNumber(BuildContext context, int number) =>
    NumberFormat.decimalPattern(_locale(context)).format(number);

String _formatTotal(BuildContext context, TokenUsageTotals totals) {
  final String prefix = totals.totalIsExact
      ? ''
      : totals.dateAttributionExact
      ? '≥ '
      : '≈ ';
  return '$prefix${_formatNumber(context, totals.totalTokens)}';
}

String _formatObservedTotal(
  BuildContext context,
  TokenUsageTotals totals,
  bool canConfirmEmpty,
) => totals.totalTokens == 0 && !canConfirmEmpty
    ? context.l10n.tokenUsageNotReported
    : _formatTotal(context, totals);
