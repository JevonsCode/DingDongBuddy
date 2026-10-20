import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';

/// Every capability is independently opt-in. Provider credentials live elsewhere.
final class AiCompanionSettings {
  const AiCompanionSettings({
    this.clipboardAnalysis = false,
    this.usageOptimization = false,
    this.tokenOptimization = false,
    this.proactiveCheckIns = false,
    this.emotionalSupport = false,
    this.cloudAnalysis = false,
    this.providerEndpoint = '',
    this.model = '',
  });

  factory AiCompanionSettings.fromJson(Map<String, Object?> json) =>
      AiCompanionSettings(
        clipboardAnalysis: json['clipboardAnalysis'] == true,
        usageOptimization: json['usageOptimization'] == true,
        tokenOptimization: json['tokenOptimization'] == true,
        proactiveCheckIns: json['proactiveCheckIns'] == true,
        emotionalSupport: json['emotionalSupport'] == true,
        cloudAnalysis: json['cloudAnalysis'] == true,
        providerEndpoint: json['providerEndpoint'] is String
            ? (json['providerEndpoint']! as String).trim()
            : '',
        model: json['model'] is String ? (json['model']! as String).trim() : '',
      );

  final bool clipboardAnalysis;
  final bool usageOptimization;
  final bool tokenOptimization;
  final bool proactiveCheckIns;
  final bool emotionalSupport;
  final bool cloudAnalysis;
  final String providerEndpoint;
  final String model;

  bool get analysisEnabled =>
      clipboardAnalysis || usageOptimization || tokenOptimization;

  AiCompanionSettings copyWith({
    bool? clipboardAnalysis,
    bool? usageOptimization,
    bool? tokenOptimization,
    bool? proactiveCheckIns,
    bool? emotionalSupport,
    bool? cloudAnalysis,
    String? providerEndpoint,
    String? model,
  }) => AiCompanionSettings(
    clipboardAnalysis: clipboardAnalysis ?? this.clipboardAnalysis,
    usageOptimization: usageOptimization ?? this.usageOptimization,
    tokenOptimization: tokenOptimization ?? this.tokenOptimization,
    proactiveCheckIns: proactiveCheckIns ?? this.proactiveCheckIns,
    emotionalSupport: emotionalSupport ?? this.emotionalSupport,
    cloudAnalysis: cloudAnalysis ?? this.cloudAnalysis,
    providerEndpoint: providerEndpoint ?? this.providerEndpoint,
    model: model ?? this.model,
  );

  Map<String, Object> toJson() => <String, Object>{
    'clipboardAnalysis': clipboardAnalysis,
    'usageOptimization': usageOptimization,
    'tokenOptimization': tokenOptimization,
    'proactiveCheckIns': proactiveCheckIns,
    'emotionalSupport': emotionalSupport,
    'cloudAnalysis': cloudAnalysis,
    'providerEndpoint': providerEndpoint,
    'model': model,
  };
}

/// Local-only input. There is deliberately no general-purpose JSON serializer.
final class AiCompanionMetadata {
  const AiCompanionMetadata({
    this.clipboard = const <ClipboardRecord>[],
    this.resources = const <Resource>[],
    this.tokenUsage = const TokenUsageSnapshot(),
    this.consecutiveActiveMinutes = 0,
  });

  final List<ClipboardRecord> clipboard;
  final List<Resource> resources;
  final TokenUsageSnapshot tokenUsage;
  final int consecutiveActiveMinutes;
}

typedef AiCompanionMetadataLoader = Future<AiCompanionMetadata> Function();

enum AiSuggestionCode {
  frequentClipboard,
  repeatedClipboard,
  ungroupedClipboard,
  candidateWithoutUse,
  alwaysOnUnused,
  largeAlwaysOnPrompt,
  highInputTokens,
  lowCacheReuse,
  incompleteTokenData,
  takeBreak,
}

final class AiSuggestion {
  const AiSuggestion({required this.code, this.count = 0, this.targetId});
  final AiSuggestionCode code;
  final int count;

  /// A local navigation reference. Never part of any provider request.
  final String? targetId;

  Map<String, Object> toJson() => <String, Object>{
    'code': code.name,
    'count': count,
    'targetId': ?targetId,
  };

  static AiSuggestion? fromJson(Map<String, Object?> json) {
    final AiSuggestionCode? code = AiSuggestionCode.values
        .where((value) => value.name == json['code'])
        .firstOrNull;
    if (code == null) return null;
    return AiSuggestion(
      code: code,
      count: boundedAiCount(json['count']),
      targetId: json['targetId'] is String ? json['targetId']! as String : null,
    );
  }
}

final class AiCompanionReport {
  const AiCompanionReport({
    required this.createdAt,
    this.suggestions = const <AiSuggestion>[],
    this.cloudSummary,
    this.localOnly = true,
  });
  final DateTime createdAt;
  final List<AiSuggestion> suggestions;
  final String? cloudSummary;
  final bool localOnly;

  Map<String, Object> toJson() => <String, Object>{
    'createdAt': createdAt.toUtc().toIso8601String(),
    'suggestions': suggestions.map((item) => item.toJson()).toList(),
    'cloudSummary': ?cloudSummary,
    'localOnly': localOnly,
  };

  static AiCompanionReport? fromJson(Map<String, Object?> json) {
    final DateTime? created = DateTime.tryParse('${json['createdAt']}');
    if (created == null) return null;
    return AiCompanionReport(
      createdAt: created,
      suggestions: json['suggestions'] is List
          ? (json['suggestions']! as List)
                .take(100)
                .whereType<Map<String, Object?>>()
                .map(AiSuggestion.fromJson)
                .whereType<AiSuggestion>()
                .toList(growable: false)
          : const <AiSuggestion>[],
      cloudSummary: json['cloudSummary'] is String
          ? (json['cloudSummary']! as String)
          : null,
      localOnly: json['localOnly'] != false,
    );
  }
}

final class AiChatMessage {
  const AiChatMessage({required this.role, required this.text});
  final String role;
  final String text;
}

enum AiCompanionError {
  disabled,
  invalidProvider,
  missingApiKey,
  sensitiveInput,
  sensitiveOutput,
  providerUnavailable,
  invalidResponse,
  timeout,
  storageUnavailable,
  emptyMessage,
  messageTooLong,
}

/// Stable diagnostics only: never contains response bodies, input or credentials.
final class AiCompanionException implements Exception {
  const AiCompanionException(this.code);
  final AiCompanionError code;
  @override
  String toString() => 'AiCompanionException(${code.name})';
}

int boundedAiCount(Object? value) =>
    value is int ? value.clamp(0, 1000000000000) : 0;
