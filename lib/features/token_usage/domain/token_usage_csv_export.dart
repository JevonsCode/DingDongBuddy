import 'token_usage_models.dart';

/// A portable export of the displayed calendar scope. Empty components remain
/// empty; confidence columns distinguish counts, lower bounds and estimates.
final class TokenUsageCsvExport {
  ///
  /// With [from] and [to] (inclusive local calendar dates) the export covers
  /// that range instead of the whole [year].
  TokenUsageCsvExport.fromSnapshot(
    TokenUsageSnapshot snapshot, {
    required this.year,
    this.source,
    this.sources,
    this.from,
    this.to,
  }) : assert((from == null) == (to == null)),
       _snapshot = snapshot,
       days = snapshot.days
           .where(
             (day) =>
                 (from == null
                     ? day.day.year == year
                     : tokenUsageDayInRange(day.day, from, to!)) &&
                 (source == null || day.source == source) &&
                 (sources == null || sources.contains(day.source)),
           )
           .toList(growable: false) {
    days.sort((a, b) {
      final dateOrder = a.day.compareTo(b.day);
      return dateOrder != 0
          ? dateOrder
          : a.source.apiValue.compareTo(b.source.apiValue);
    });
  }

  final int year;
  final ConversationTokenUsageSource? source;
  final Set<ConversationTokenUsageSource>? sources;
  final DateTime? from;
  final DateTime? to;
  final List<TokenUsageDay> days;
  final TokenUsageSnapshot _snapshot;

  List<String> get _diagnostics {
    // Only known diagnostic identifiers cross this boundary. Never serialize
    // arbitrary warning text, paths or exception messages into an export.
    const supportedWarnings = {
      'storage_unavailable',
      'repository_closed',
      'refresh_interrupted',
      'refresh_cancelled',
      'incomplete_cumulative_totals',
      'daily_attribution_gap',
      'ambiguous_counter_epoch',
      'source_unreadable',
      'malformed_usage_rows',
      'missing_event_dates',
      'pending_transcript_tail',
    };
    final warnings = <String>{
      ..._snapshot.warnings.where(supportedWarnings.contains),
      if (!_snapshot.storageAvailable) 'storage_unavailable',
      if (_snapshot.refreshedAt == null) 'never_refreshed',
    };
    for (final selectedSource
        in sources ??
            (source == null
                ? ConversationTokenUsageSource.values.toSet()
                : {source!})) {
      if (selectedSource == ConversationTokenUsageSource.dingdong &&
          !_snapshot.coverage.any((c) => c.source == selectedSource)) {
        continue;
      }
      final coverage = _snapshot.coverage.where(
        (item) => item.source == selectedSource,
      );
      if (coverage.isEmpty) {
        warnings.add('coverage_unknown');
        continue;
      }
      for (final item in coverage) {
        if (item.availability == TokenUsageAvailability.missing) {
          warnings.add('source_missing');
        }
        if (item.availability == TokenUsageAvailability.unreadable) {
          warnings.add('source_unreadable');
        }
        if (item.filesScanned == 0 &&
            item.source != ConversationTokenUsageSource.dingdong) {
          warnings.add('no_importable_logs');
        }
        if (item.malformedRows > 0) warnings.add('malformed_usage_rows');
        if (item.undatedRows > 0) warnings.add('missing_event_dates');
        if (item.pendingFiles > 0) warnings.add('pending_transcript_tail');
      }
    }
    return warnings.toList()..sort();
  }

  String get suggestedName =>
      'dingdong-token-usage-${from == null ? '$year' : '${_compactDate(from!)}-${_compactDate(to!)}'}'
      '-${source?.apiValue ?? (sources == null ? 'all' : ((sources!.map((s) => s.apiValue).toList()..sort()).join('+')))}.csv';

  static String _compactDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}'
      '${value.month.toString().padLeft(2, '0')}'
      '${value.day.toString().padLeft(2, '0')}';

  String get contents {
    final diagnostics = _diagnostics;
    final rows = <List<Object?>>[
      [
        'date',
        'source',
        'total_tokens',
        'input_tokens',
        'output_tokens',
        'cached_input_tokens',
        'cache_write_input_tokens',
        'reasoning_output_tokens',
        'non_cached_tokens',
        'total_confidence',
        'date_attribution',
        'breakdown_complete',
        'event_count',
        'partial_event_count',
        'coverage_status',
        'coverage_diagnostics',
        'internal_function',
      ],
      for (final day in days)
        [
          '${day.day.year.toString().padLeft(4, '0')}-'
              '${day.day.month.toString().padLeft(2, '0')}-'
              '${day.day.day.toString().padLeft(2, '0')}',
          day.source.apiValue,
          day.totals.totalTokens,
          day.totals.inputTokens,
          day.totals.outputTokens,
          day.totals.cachedInputTokens,
          day.totals.cacheWriteInputTokens,
          day.totals.reasoningOutputTokens,
          day.totals.nonCachedTokens,
          day.totals.totalIsExact
              ? 'exact'
              : day.totals.dateAttributionExact
              ? 'lower_bound'
              : 'estimate',
          day.totals.dateAttributionExact ? 'exact' : 'uncertain',
          day.totals.breakdownComplete,
          day.eventCount,
          day.partialEventCount,
          diagnostics.isEmpty ? 'complete_scan' : 'partial_or_unavailable',
          diagnostics.join(','),
          day.internalPurpose,
        ],
    ];
    // Machine-readable integers never contain locale thousands separators.
    return '${rows.map((row) => row.map(_cell).join(',')).join('\r\n')}\r\n';
  }

  static String _cell(Object? value) {
    final text = value?.toString() ?? '';
    return text.contains(RegExp('[,"\r\n]'))
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }
}

/// Whether a stored local-midnight [day] falls within inclusive calendar
/// dates [from] and [to]; times of day on the bounds are ignored.
bool tokenUsageDayInRange(DateTime day, DateTime from, DateTime to) {
  final DateTime date = DateTime(day.year, day.month, day.day);
  return !date.isBefore(DateTime(from.year, from.month, from.day)) &&
      !date.isAfter(DateTime(to.year, to.month, to.day));
}

typedef TokenUsageCsvSaver =
    Future<bool> Function({
      required String contents,
      required String suggestedName,
      required String confirmButtonText,
      required String fileTypeLabel,
    });
