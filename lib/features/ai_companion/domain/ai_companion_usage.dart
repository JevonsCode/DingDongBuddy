import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';

import 'ai_companion_models.dart';

enum AiCompanionUsagePurpose { analysis, connectionTest, resourceSelection }

/// Numeric receipt only: never persist a prompt, response, endpoint or key.
final class AiCompanionUsageRecord {
  const AiCompanionUsageRecord({
    required this.id,
    required this.occurredAt,
    required this.purpose,
    required this.totals,
  });
  final String id;
  final DateTime occurredAt;
  final AiCompanionUsagePurpose purpose;
  final TokenUsageTotals totals;
}

typedef AiCompanionUsageSink =
    Future<void> Function(AiCompanionUsageRecord record);

TokenUsageTotals parseAiCompanionUsage(
  Object? value,
  AiCompanionProtocol protocol,
) {
  final usage = value is Map ? value : const <String, Object?>{};
  int? count(Object? v) =>
      v is int && v >= 0 && v <= 9007199254740991 ? v : null;
  int? detail(String key, String field) =>
      usage[key] is Map ? count((usage[key] as Map)[field]) : null;
  final anthropic = protocol == AiCompanionProtocol.anthropic;
  final fresh = count(usage[anthropic ? 'input_tokens' : 'prompt_tokens']);
  final output = count(
    usage[anthropic ? 'output_tokens' : 'completion_tokens'],
  );
  final cached = anthropic
      ? count(usage['cache_read_input_tokens'])
      : detail('prompt_tokens_details', 'cached_tokens');
  // Chat Completions has no separate cache-creation input category.
  final write = anthropic ? count(usage['cache_creation_input_tokens']) : 0;
  final input = anthropic
      ? (fresh != null && cached != null && write != null
            ? fresh + cached + write
            : null)
      : fresh;
  final explicit = count(usage['total_tokens']);
  final exact = explicit != null || (input != null && output != null);
  final total =
      explicit ??
      (input ?? (anthropic ? (fresh ?? 0) + (cached ?? 0) + (write ?? 0) : 0)) +
          (output ?? 0);
  return TokenUsageTotals(
    totalTokens: total,
    inputTokens: input,
    outputTokens: output,
    cachedInputTokens: cached,
    cacheWriteInputTokens: write,
    reasoningOutputTokens: anthropic
        ? null
        : detail('completion_tokens_details', 'reasoning_tokens'),
    totalIsExact: exact,
  );
}
