import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';
import 'package:dingdong/features/token_usage/ui/token_usage_controller.dart';
import 'package:dingdong/features/token_usage/ui/token_usage_heatmap.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

part 'token_usage_details.dart';
part 'token_usage_widgets.dart';

/// Local daily token history. Explicit source totals remain authoritative.
class TokenUsageScreen extends StatefulWidget {
  const TokenUsageScreen({required this.controller, this.now, super.key});

  final TokenUsageController controller;
  final DateTime Function()? now;

  @override
  State<TokenUsageScreen> createState() => _TokenUsageScreenState();
}

class _TokenUsageScreenState extends State<TokenUsageScreen> {
  late int _year;
  late DateTime _selectedDay;
  ConversationTokenUsageSource? _source;

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
        final List<TokenUsageDay> period = filtered
            .where((TokenUsageDay day) => day.day.year == _year)
            .toList(growable: false);
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
                  warning == 'refresh_interrupted',
            ) &&
            !snapshot.coverage.any(
              (TokenUsageSourceCoverage coverage) =>
                  (_source == null || coverage.source == _source) &&
                  (coverage.pendingFiles > 0 ||
                      coverage.malformedRows > 0 ||
                      coverage.undatedRows > 0),
            ) &&
            snapshot.coverage.any(
              (TokenUsageSourceCoverage coverage) =>
                  (_source == null || coverage.source == _source) &&
                  coverage.availability == TokenUsageAvailability.available,
            );
        final Map<DateTime, List<TokenUsageTotals>> byDay =
            <DateTime, List<TokenUsageTotals>>{};
        for (final TokenUsageDay day in period) {
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
        final int activeDayCount = dailyTotals.values
            .where((TokenUsageTotals totals) => totals.totalTokens > 0)
            .length;
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
                        label: context.l10n.tokenUsagePeriodTotal,
                        value: _formatObservedTotal(
                          context,
                          total,
                          canConfirmEmpty,
                        ),
                        detail: '$_year · ${context.l10n.tokenUsageTokens}',
                        icon: Icons.stacked_line_chart_rounded,
                      ),
                      _SummaryCard(
                        key: const Key('token-usage-active-days'),
                        width: width,
                        label: context.l10n.tokenUsageActiveDays,
                        value: activeDayCount == 0 && !canConfirmEmpty
                            ? context.l10n.tokenUsageNotReported
                            : _formatNumber(context, activeDayCount),
                        detail: '$_year',
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
                  for (final ConversationTokenUsageSource? source
                      in <ConversationTokenUsageSource?>[
                        null,
                        ...ConversationTokenUsageSource.values,
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
              if (snapshot.days.isEmpty) ...<Widget>[
                const SizedBox(height: 16),
                _Notice(
                  key: const Key('token-usage-empty'),
                  icon: Icons.insights_outlined,
                  title: context.l10n.tokenUsageEmpty,
                  message: context.l10n.tokenUsageEmptyBody,
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

String tokenUsageSourceLabel(ConversationTokenUsageSource source) =>
    switch (source) {
      ConversationTokenUsageSource.codex => 'Codex',
      ConversationTokenUsageSource.claudeCode => 'Claude Code',
      ConversationTokenUsageSource.pi => 'Pi',
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
