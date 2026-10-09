import '../../agent_api/domain/conversation_token_usage.dart';

export '../../agent_api/domain/conversation_token_usage.dart'
    show ConversationTokenUsageSource;

/// Counts measured from local transcripts, with cache reads/writes included in
/// [inputTokens] for every source. Reasoning is a subset of output, never added
/// to [totalTokens]. A null component means that some contributing event did
/// not report it; zero means it was reported as zero.
final class TokenUsageTotals {
  const TokenUsageTotals({
    required this.totalTokens,
    this.inputTokens,
    this.outputTokens,
    this.cachedInputTokens,
    this.cacheWriteInputTokens,
    this.reasoningOutputTokens,
    this.totalIsExact = true,
    this.dateAttributionExact = true,
    bool breakdownComplete = true,
  }) : _hasReportedBreakdown = breakdownComplete;

  static const TokenUsageTotals zero = TokenUsageTotals(
    totalTokens: 0,
    inputTokens: 0,
    outputTokens: 0,
    cachedInputTokens: 0,
    cacheWriteInputTokens: 0,
    reasoningOutputTokens: 0,
  );

  final int totalTokens;
  final int? inputTokens;
  final int? outputTokens;
  final int? cachedInputTokens;
  final int? cacheWriteInputTokens;
  final int? reasoningOutputTokens;

  /// False when the source supplied incomplete components or counter epochs
  /// could not be distinguished. With exact date attribution, [totalTokens]
  /// is a measured lower bound; otherwise it must not be used as a daily bound.
  final bool totalIsExact;

  /// Exact cumulative differences may span an incomplete observation on an
  /// earlier date. The count remains exact, but its allocation to this day
  /// cannot be established from the available transcript counters.
  final bool dateAttributionExact;
  final bool _hasReportedBreakdown;

  bool get breakdownComplete =>
      _hasReportedBreakdown &&
      totalIsExact &&
      inputTokens != null &&
      outputTokens != null &&
      cachedInputTokens != null &&
      cacheWriteInputTokens != null &&
      inputTokens! + outputTokens! == totalTokens &&
      cachedInputTokens! <= inputTokens! &&
      cacheWriteInputTokens! <= inputTokens!;

  int? get nonCachedTokens => !breakdownComplete
      ? null
      : inputTokens! - cachedInputTokens! + outputTokens!;

  static TokenUsageTotals sum(Iterable<TokenUsageTotals> values) {
    var result = zero;
    for (final value in values) {
      result = TokenUsageTotals(
        totalTokens: result.totalTokens + value.totalTokens,
        inputTokens: _add(result.inputTokens, value.inputTokens),
        outputTokens: _add(result.outputTokens, value.outputTokens),
        cachedInputTokens: _add(
          result.cachedInputTokens,
          value.cachedInputTokens,
        ),
        cacheWriteInputTokens: _add(
          result.cacheWriteInputTokens,
          value.cacheWriteInputTokens,
        ),
        reasoningOutputTokens: _add(
          result.reasoningOutputTokens,
          value.reasoningOutputTokens,
        ),
        totalIsExact: result.totalIsExact && value.totalIsExact,
        dateAttributionExact:
            result.dateAttributionExact && value.dateAttributionExact,
        breakdownComplete: result.breakdownComplete && value.breakdownComplete,
      );
    }
    return result;
  }

  static int? _add(int? a, int? b) => a == null || b == null ? null : a + b;
}

final class TokenUsageDay {
  const TokenUsageDay({
    required this.day,
    required this.source,
    required this.totals,
    this.eventCount = 0,
    this.partialEventCount = 0,
  });

  /// Local calendar midnight. Queries use inclusive local calendar dates.
  final DateTime day;
  final ConversationTokenUsageSource source;
  final TokenUsageTotals totals;
  final int eventCount;
  final int partialEventCount;
}

enum TokenUsageAvailability { available, missing, unreadable }

final class TokenUsageSourceCoverage {
  const TokenUsageSourceCoverage({
    required this.source,
    required this.availability,
    this.filesScanned = 0,
    this.malformedRows = 0,
    this.undatedRows = 0,
    this.pendingFiles = 0,
  });

  final ConversationTokenUsageSource source;
  final TokenUsageAvailability availability;
  final int filesScanned;
  final int malformedRows;
  final int undatedRows;
  final int pendingFiles;
}

final class TokenUsageSnapshot {
  const TokenUsageSnapshot({
    this.days = const <TokenUsageDay>[],
    this.coverage = const <TokenUsageSourceCoverage>[],
    this.refreshedAt,
    this.storageAvailable = true,
    this.warnings = const <String>[],
  });

  final List<TokenUsageDay> days;
  final List<TokenUsageSourceCoverage> coverage;
  final DateTime? refreshedAt;
  final bool storageAvailable;

  /// Stable diagnostic codes only; no transcript content, credentials or paths.
  final List<String> warnings;

  TokenUsageTotals get totals =>
      TokenUsageTotals.sum(days.map((day) => day.totals));
}

final class TokenUsageRefreshReport {
  const TokenUsageRefreshReport({
    this.filesScanned = 0,
    this.importedEvents = 0,
    this.skippedRows = 0,
    this.storageAvailable = true,
    this.cancelled = false,
    this.warnings = const <String>[],
  });

  final int filesScanned;
  final int importedEvents;
  final int skippedRows;
  final bool storageAvailable;
  final bool cancelled;
  final List<String> warnings;
}
