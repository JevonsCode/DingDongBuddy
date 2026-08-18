/// Agents whose local session files expose exact, cumulative token usage.
enum ConversationTokenUsageSource {
  codex('codex'),
  claudeCode('claude-code'),
  pi('pi');

  const ConversationTokenUsageSource(this.apiValue);

  final String apiValue;

  static ConversationTokenUsageSource? parse(Object? value) {
    if (value is! String) {
      return null;
    }
    final String normalized = value.trim().toLowerCase();
    for (final ConversationTokenUsageSource source in values) {
      if (source.apiValue == normalized) {
        return source;
      }
    }
    return null;
  }
}

/// One exact cumulative snapshot reported by a supported Agent session.
///
/// Cache and reasoning values are breakdowns and may already be included in
/// another field depending on the Agent. [totalTokens] is therefore stored
/// explicitly instead of recomputed by presentation code.
final class ConversationTokenUsage {
  const ConversationTokenUsage({
    required this.source,
    required this.totalTokens,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cachedInputTokens = 0,
    this.cacheWriteInputTokens = 0,
    this.reasoningOutputTokens = 0,
  });

  static ConversationTokenUsage? tryParse(Object? value) {
    if (value is! Map<Object?, Object?>) {
      return null;
    }
    final Map<String, Object?> json = <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        if (entry.key is String) entry.key! as String: entry.value,
    };
    final ConversationTokenUsageSource? source =
        ConversationTokenUsageSource.parse(json['source']);
    final int? totalTokens = _nonNegativeInt(json['totalTokens']);
    if (source == null || totalTokens == null || totalTokens <= 0) {
      return null;
    }
    return ConversationTokenUsage(
      source: source,
      totalTokens: totalTokens,
      inputTokens: _nonNegativeInt(json['inputTokens']) ?? 0,
      outputTokens: _nonNegativeInt(json['outputTokens']) ?? 0,
      cachedInputTokens: _nonNegativeInt(json['cachedInputTokens']) ?? 0,
      cacheWriteInputTokens:
          _nonNegativeInt(json['cacheWriteInputTokens']) ?? 0,
      reasoningOutputTokens:
          _nonNegativeInt(json['reasoningOutputTokens']) ?? 0,
    );
  }

  final ConversationTokenUsageSource source;
  final int totalTokens;
  final int inputTokens;
  final int outputTokens;
  final int cachedInputTokens;
  final int cacheWriteInputTokens;
  final int reasoningOutputTokens;

  Map<String, Object?> toJson() => <String, Object?>{
    'source': source.apiValue,
    'totalTokens': totalTokens,
    'inputTokens': inputTokens,
    'outputTokens': outputTokens,
    'cachedInputTokens': cachedInputTokens,
    'cacheWriteInputTokens': cacheWriteInputTokens,
    'reasoningOutputTokens': reasoningOutputTokens,
  };
}

/// Compact footer rendering such as `12.4K Token`.
String formatCompactConversationTokenCount(int value) {
  final int safeValue = value < 0 ? 0 : value;
  if (safeValue < 1000) {
    return '$safeValue';
  }
  if (safeValue < 1000000) {
    return _compactUnit(safeValue / 1000, 'K');
  }
  if (safeValue < 1000000000) {
    return _compactUnit(safeValue / 1000000, 'M');
  }
  return _compactUnit(safeValue / 1000000000, 'B');
}

/// Exact tooltip rendering such as `12,345,678`.
String formatExactConversationTokenCount(int value) {
  final String digits = (value < 0 ? 0 : value).toString();
  final StringBuffer result = StringBuffer();
  for (int index = 0; index < digits.length; index += 1) {
    if (index > 0 && (digits.length - index) % 3 == 0) {
      result.write(',');
    }
    result.write(digits[index]);
  }
  return result.toString();
}

String _compactUnit(double value, String suffix) {
  final String fixed = value.toStringAsFixed(value >= 100 ? 0 : 1);
  final String trimmed = fixed.endsWith('.0')
      ? fixed.substring(0, fixed.length - 2)
      : fixed;
  return '$trimmed$suffix';
}

int? _nonNegativeInt(Object? value) {
  if (value is int && value >= 0) {
    return value;
  }
  if (value is num && value.isFinite && value >= 0 && value == value.round()) {
    return value.toInt();
  }
  return null;
}
