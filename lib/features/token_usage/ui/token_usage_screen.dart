import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/date_filter_range.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_choice_chip.dart';
import 'package:dingdong/core/widgets/desktop_date_range_picker.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_csv_export.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';
import 'package:dingdong/features/token_usage/ui/token_usage_controller.dart';
import 'package:dingdong/features/token_usage/ui/token_usage_heatmap.dart';
import 'package:dingdong/platform/file_selector_token_usage_export.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

part 'token_usage_details.dart';
part 'token_usage_filters.dart';
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

class _TokenUsageScreenState extends State<TokenUsageScreen>
    with WidgetsBindingObserver {
  late int _year;
  late DateTime _selectedDay;
  Set<ConversationTokenUsageSource>? _agents;
  bool _onlyInternal = false;
  Set<ConversationTokenUsageSource> get _sources => _onlyInternal
      ? {ConversationTokenUsageSource.dingdong}
      : {
          ...?_agents,
          if (_agents == null)
            ...ConversationTokenUsageSource.values.where(
              (s) => s != ConversationTokenUsageSource.dingdong,
            ),
          if (widget.controller.includeInternal)
            ConversationTokenUsageSource.dingdong,
        };
  TokenUsageSnapshot get _visibleSnapshot =>
      widget.controller.allSnapshot.forSources(_sources);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.refresh());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  DateFilterPreset _range = DateFilterPreset.thisYear;
  DateTimeRange? _customRange;
  bool _isExporting = false;

  DateTimeRange? get _rangeBounds =>
      _range == DateFilterPreset.custom ? _customRange : _range.bounds(_today);

  Future<void> _export() async {
    if (_isExporting || widget.controller.isLoading) return;
    final DateTimeRange? bounds = _rangeBounds;
    final export = TokenUsageCsvExport.fromSnapshot(
      _visibleSnapshot,
      year: _year,
      sources: _sources,
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
    WidgetsBinding.instance.addObserver(this);
    _selectedDay = _today;
    _year = _selectedDay.year;
    if (!widget.controller.hasLoaded ||
        widget.controller.readInternalInclusion != null) {
      unawaited(widget.controller.refresh());
    }
  }

  void _selectYear(int? year) {
    if (year == null) return;
    final List<TokenUsageDay> recorded =
        widget.controller.allSnapshot.days
            .where((TokenUsageDay day) => day.day.year == year)
            .toList()
          ..sort((TokenUsageDay a, TokenUsageDay b) => a.day.compareTo(b.day));
    setState(() {
      _year = year;
      _range = DateFilterPreset.custom;
      _customRange = DateTimeRange(
        start: DateTime(year),
        end: year == _today.year ? _today : DateTime(year, 12, 31),
      );
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
        final TokenUsageSnapshot snapshot = _visibleSnapshot;
        final List<TokenUsageDay> filtered = snapshot.days;
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
                  (coverage.availability == TokenUsageAvailability.unreadable ||
                  coverage.pendingFiles > 0 ||
                  coverage.malformedRows > 0 ||
                  coverage.undatedRows > 0),
            ) &&
            snapshot.coverage.any(
              (TokenUsageSourceCoverage coverage) =>
                  coverage.availability == TokenUsageAvailability.available &&
                  (coverage.filesScanned > 0 ||
                      coverage.source == ConversationTokenUsageSource.dingdong),
            );
        final Map<DateTime, List<TokenUsageTotals>> byDay =
            <DateTime, List<TokenUsageTotals>>{};
        for (final TokenUsageDay day in period.where(
          (day) => day.day.year == _year,
        )) {
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
          ...widget.controller.allSnapshot.days.map(
            (TokenUsageDay day) => day.day.year,
          ),
        }.toList()..sort((int a, int b) => b.compareTo(a));
        final List<TokenUsageDay> selected = period
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
              Wrap(
                spacing: 20,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: context.l10n.tokenUsageIncludeInternal,
                        child: CompactSwitch(
                          key: const Key('token-usage-include-internal'),
                          value:
                              _onlyInternal ||
                              widget.controller.includeInternal,
                          onChanged:
                              _onlyInternal || widget.controller.savingInclusion
                              ? null
                              : (value) => unawaited(
                                  widget.controller.setIncludeInternal(value),
                                ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(context.l10n.tokenUsageIncludeInternal),
                      ),
                    ],
                  ),
                  IntrinsicWidth(
                    child: DesktopChoiceChip(
                      key: const Key('token-usage-only-internal'),
                      height: 34,
                      leading: _onlyInternal
                          ? const Icon(Icons.check, size: 14)
                          : null,
                      label: Text(context.l10n.tokenUsageOnlyInternal),
                      selected: _onlyInternal,
                      onSelected: (value) =>
                          setState(() => _onlyInternal = value),
                    ),
                  ),
                ],
              ),
              if (widget.controller.inclusionError != null)
                Text(
                  context.l10n.tokenUsageFilterSaveFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: 130,
                    child: DesktopSelectField<int>(
                      key: const Key('token-usage-year-filter'),
                      value: _year,
                      semanticLabel: context.l10n.tokenUsageYear,
                      items: [
                        for (final year in years)
                          DesktopSelectItem(value: year, label: '$year'),
                      ],
                      onChanged: _selectYear,
                    ),
                  ),
                  SizedBox(
                    key: const Key('token-usage-range-filter'),
                    width: 210,
                    child: DesktopDateFilter(
                      value: _range,
                      customRange: _customRange,
                      now: widget.now,
                      onChanged: (preset, custom) => setState(() {
                        _range = preset!;
                        _customRange = custom;
                        final bounds = _rangeBounds;
                        if (bounds != null) {
                          _year = bounds.end.year;
                          _selectedDay = bounds.end;
                        }
                      }),
                    ),
                  ),
                  _AgentFilter(
                    selected: _agents,
                    enabled: !_onlyInternal,
                    snapshot: widget.controller.allSnapshot,
                    onChanged: (value) => setState(() => _agents = value),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
              if (_sources.contains(ConversationTokenUsageSource.dingdong) &&
                  snapshot.storageAvailable &&
                  snapshot.coverage.any(
                    (c) =>
                        c.source == ConversationTokenUsageSource.dingdong &&
                        c.availability == TokenUsageAvailability.available,
                  )) ...[
                const SizedBox(height: 20),
                _InternalFunctions(
                  records: period
                      .where(
                        (day) =>
                            day.source == ConversationTokenUsageSource.dingdong,
                      )
                      .toList(),
                  periodLabel: periodLabel,
                ),
              ],
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
