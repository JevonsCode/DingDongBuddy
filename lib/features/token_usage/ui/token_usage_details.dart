part of 'token_usage_screen.dart';

class _DailyDetail extends StatelessWidget {
  const _DailyDetail({required this.day, required this.records});
  final DateTime day;
  final List<TokenUsageDay> records;

  @override
  Widget build(BuildContext context) {
    final TokenUsageTotals totals = TokenUsageTotals.sum(
      records.map((TokenUsageDay day) => day.totals),
    );
    return _Panel(
      child: Column(
        key: const Key('token-usage-day-detail'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                DateFormat.yMMMMEEEEd(_locale(context)).format(day),
                key: const Key('token-usage-selected-date'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                context.l10n.tokenUsageDayDetail,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (records.isEmpty)
            Text(
              context.l10n.tokenUsageNoDayRecords,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else ...<Widget>[
            for (final ConversationTokenUsageSource source
                in ConversationTokenUsageSource.values)
              if (records.any(
                (TokenUsageDay record) => record.source == source,
              ))
                _SourceDetail(
                  source: source,
                  records: records
                      .where((TokenUsageDay record) => record.source == source)
                      .toList(growable: false),
                ),
            const SizedBox(height: 4),
            Text(
              context.l10n.tokenUsageBreakdownNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (!totals.breakdownComplete) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                context.l10n.tokenUsagePartialDetail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (!totals.totalIsExact &&
                totals.dateAttributionExact) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                context.l10n.tokenUsageLowerBoundNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (!totals.dateAttributionExact) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                context.l10n.tokenUsageDateAttributionNote,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _SourceDetail extends StatelessWidget {
  const _SourceDetail({required this.source, required this.records});
  final ConversationTokenUsageSource source;
  final List<TokenUsageDay> records;

  @override
  Widget build(BuildContext context) {
    final TokenUsageTotals totals = TokenUsageTotals.sum(
      records.map((TokenUsageDay day) => day.totals),
    );
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<(String, int?)> values = <(String, int?)>[
      (context.l10n.tokenUsageInput, totals.inputTokens),
      (context.l10n.tokenUsageOutput, totals.outputTokens),
      (context.l10n.tokenUsageCacheRead, totals.cachedInputTokens),
      (context.l10n.tokenUsageCacheWrite, totals.cacheWriteInputTokens),
      (context.l10n.tokenUsageReasoning, totals.reasoningOutputTokens),
      (context.l10n.tokenUsageNonCached, totals.nonCachedTokens),
    ];
    return Container(
      key: Key('token-usage-detail-${source.apiValue}'),
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text(
                tokenUsageSourceLabel(source),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                '${context.l10n.tokenUsageTotal}  ${_formatTotal(context, totals)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                context.l10n.tokenUsageRecords(
                  _formatNumber(
                    context,
                    records.fold<int>(
                      0,
                      (int count, TokenUsageDay day) => count + day.eventCount,
                    ),
                  ),
                ),
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final int columns = constraints.maxWidth >= 650
                  ? 3
                  : constraints.maxWidth >= 350
                  ? 2
                  : 1;
              final double width =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 12,
                children: <Widget>[
                  for (final (String label, int? value) in values)
                    SizedBox(
                      width: width,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            label,
                            style: TextStyle(
                              color: colors.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            value == null
                                ? context.l10n.tokenUsageNotReported
                                : _formatNumber(context, value),
                            style: TextStyle(
                              color: value == null
                                  ? colors.onSurfaceVariant
                                  : colors.onSurface,
                              fontWeight: value == null
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Coverage extends StatelessWidget {
  const _Coverage({required this.snapshot});
  final TokenUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      key: const Key('token-usage-coverage'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.tokenUsageCoverageTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.tokenUsageCoverageNote,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        if (snapshot.coverage.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            children: <Widget>[
              for (final TokenUsageSourceCoverage coverage in snapshot.coverage)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      coverage.availability == TokenUsageAvailability.available
                          ? Icons.check_circle_outline_rounded
                          : Icons.info_outline_rounded,
                      size: 14,
                      color:
                          coverage.availability ==
                              TokenUsageAvailability.available
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${tokenUsageSourceLabel(coverage.source)} · ${switch (coverage.availability) {
                          TokenUsageAvailability.available => context.l10n.tokenUsageAvailable,
                          TokenUsageAvailability.missing => context.l10n.tokenUsageMissing,
                          TokenUsageAvailability.unreadable => context.l10n.tokenUsageUnreadable,
                        }}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (snapshot.coverage.any(
            (TokenUsageSourceCoverage coverage) =>
                coverage.malformedRows + coverage.undatedRows > 0,
          )) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              context.l10n.tokenUsageSkippedRecords(
                _formatNumber(
                  context,
                  snapshot.coverage.fold<int>(
                    0,
                    (int count, TokenUsageSourceCoverage coverage) =>
                        count + coverage.malformedRows + coverage.undatedRows,
                  ),
                ),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (snapshot.coverage.any(
            (TokenUsageSourceCoverage coverage) => coverage.pendingFiles > 0,
          )) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              context.l10n.tokenUsagePendingFiles(
                _formatNumber(
                  context,
                  snapshot.coverage.fold<int>(
                    0,
                    (int count, TokenUsageSourceCoverage coverage) =>
                        count + coverage.pendingFiles,
                  ),
                ),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
        if (snapshot.warnings.contains('daily_attribution_gap')) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            context.l10n.tokenUsageDateAttributionNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (snapshot.warnings.contains(
          'incomplete_cumulative_totals',
        )) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            context.l10n.tokenUsageIncompleteCumulativeNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (snapshot.warnings.contains('ambiguous_counter_epoch')) ...<Widget>[
          const SizedBox(height: 10),
          Text(
            context.l10n.tokenUsageAmbiguousCumulativeNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    ),
  );
}
