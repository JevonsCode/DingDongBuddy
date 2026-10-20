import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_models.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_privacy.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';

final class AiCompanionAnalyzer {
  const AiCompanionAnalyzer();

  Future<AiCompanionReport> analyze(
    AiCompanionSettings settings,
    AiCompanionMetadata metadata,
    DateTime now,
  ) async {
    final List<AiSuggestion> suggestions = <AiSuggestion>[];
    if (settings.clipboardAnalysis) {
      final Map<String, List<ClipboardRecord>> hashes =
          <String, List<ClipboardRecord>>{};
      for (final ClipboardRecord record in metadata.clipboard.take(500)) {
        if (!_eligibleClipboard(record)) continue;
        if (record.copyCount >= 3 && !record.pinned) {
          suggestions.add(
            AiSuggestion(
              code: AiSuggestionCode.frequentClipboard,
              count: record.copyCount,
              targetId: record.id,
            ),
          );
        }
        final String digest = base64Encode(
          (await Sha256().hash(utf8.encode(record.content.trim()))).bytes,
        );
        (hashes[digest] ??= <ClipboardRecord>[]).add(record);
      }
      for (final List<ClipboardRecord> repeated in hashes.values) {
        if (repeated.length >= 2) {
          suggestions.add(
            AiSuggestion(
              code: AiSuggestionCode.repeatedClipboard,
              count: repeated.length,
              targetId: repeated.first.id,
            ),
          );
        }
      }
      final int ungrouped = metadata.clipboard
          .take(500)
          .where(
            (record) => _eligibleClipboard(record) && record.groupNames.isEmpty,
          )
          .length;
      if (ungrouped > 0) {
        suggestions.add(
          AiSuggestion(
            code: AiSuggestionCode.ungroupedClipboard,
            count: ungrouped,
          ),
        );
      }
    }
    for (final Resource resource in metadata.resources.take(500)) {
      if (!resource.enabled || !resource.type.isConfigurableAgentResource) {
        continue;
      }
      // MCP usage means an actual invocation, while Skill usage means loading
      // and Prompt usage means activation. Candidates are never called usage.
      final int actualUse = resource.type == ResourceType.mcp
          ? resource.invocationCount
          : resource.usageCount;
      if (settings.usageOptimization) {
        if (resource.type != ResourceType.prompt &&
            resource.candidateCount >= 5 &&
            actualUse == 0) {
          suggestions.add(
            AiSuggestion(
              code: AiSuggestionCode.candidateWithoutUse,
              count: resource.candidateCount,
              targetId: resource.id,
            ),
          );
        }
        if (resource.activation == ResourceActivation.always &&
            actualUse == 0 &&
            now.difference(resource.createdAt).inDays >= 7) {
          suggestions.add(
            AiSuggestion(
              code: AiSuggestionCode.alwaysOnUnused,
              targetId: resource.id,
            ),
          );
        }
      }
      if (settings.tokenOptimization &&
          resource.type == ResourceType.prompt &&
          resource.activation == ResourceActivation.always &&
          resource.content.length >= 2000) {
        suggestions.add(
          AiSuggestion(
            code: AiSuggestionCode.largeAlwaysOnPrompt,
            count: resource.content.length,
            targetId: resource.id,
          ),
        );
      }
    }
    if (settings.tokenOptimization) {
      final totals = metadata.tokenUsage.totals;
      if (!totals.breakdownComplete ||
          !totals.dateAttributionExact ||
          metadata.tokenUsage.days.isEmpty ||
          !metadata.tokenUsage.storageAvailable ||
          metadata.tokenUsage.coverage.any(
            (source) =>
                source.pendingFiles > 0 ||
                source.availability != TokenUsageAvailability.available,
          )) {
        suggestions.add(
          const AiSuggestion(code: AiSuggestionCode.incompleteTokenData),
        );
      } else {
        final int input = totals.inputTokens!;
        if (input >= 10000 && input > totals.outputTokens! * 4) {
          suggestions.add(
            AiSuggestion(code: AiSuggestionCode.highInputTokens, count: input),
          );
        }
        if (input >= 10000 && totals.cachedInputTokens! < input ~/ 10) {
          suggestions.add(
            AiSuggestion(
              code: AiSuggestionCode.lowCacheReuse,
              count: totals.cachedInputTokens!,
            ),
          );
        }
      }
    }
    return AiCompanionReport(
      createdAt: now,
      suggestions: List<AiSuggestion>.unmodifiable(suggestions.take(100)),
    );
  }

  /// The sole analysis serialization boundary. Never add content, user-defined
  /// names, hashes, paths, source labels, dates or original identifiers here.
  Map<String, Object> cloudMetadata(
    AiCompanionSettings settings,
    AiCompanionMetadata metadata,
  ) => <String, Object>{
    'schema': 1,
    if (settings.clipboardAnalysis)
      'clipboard': <String, Object>{
        'recordCount': boundedAiCount(metadata.clipboard.length),
        'textRecordCount': metadata.clipboard
            .take(500)
            .where(_eligibleClipboard)
            .length,
        'frequentlyCopiedCount': metadata.clipboard
            .take(500)
            .where(
              (record) => _eligibleClipboard(record) && record.copyCount >= 3,
            )
            .length,
      },
    if (settings.usageOptimization)
      'resources': <Map<String, Object>>[
        for (final (index, resource) in metadata.resources.take(100).indexed)
          if (resource.type.isConfigurableAgentResource)
            <String, Object>{
              'id': 'r${index + 1}',
              'kind': resource.type.name,
              'activation': resource.activation.name,
              'enabled': resource.enabled,
              'candidateCount': boundedAiCount(resource.candidateCount),
              'activationOrLoadCount': boundedAiCount(resource.usageCount),
              'invocationCount': boundedAiCount(resource.invocationCount),
            },
      ],
    if (settings.tokenOptimization)
      'tokens': <String, Object>{
        if (_hasTokenData(metadata.tokenUsage))
          'total': boundedAiCount(metadata.tokenUsage.totals.totalTokens),
        if (_hasTokenData(metadata.tokenUsage) &&
            metadata.tokenUsage.totals.inputTokens != null)
          'input': boundedAiCount(metadata.tokenUsage.totals.inputTokens),
        if (_hasTokenData(metadata.tokenUsage) &&
            metadata.tokenUsage.totals.outputTokens != null)
          'output': boundedAiCount(metadata.tokenUsage.totals.outputTokens),
        if (_hasTokenData(metadata.tokenUsage) &&
            metadata.tokenUsage.totals.cachedInputTokens != null)
          'cachedInput': boundedAiCount(
            metadata.tokenUsage.totals.cachedInputTokens,
          ),
        'complete':
            _hasTokenData(metadata.tokenUsage) &&
            metadata.tokenUsage.totals.breakdownComplete &&
            metadata.tokenUsage.totals.dateAttributionExact &&
            metadata.tokenUsage.coverage.every(
              (source) =>
                  source.availability == TokenUsageAvailability.available &&
                  source.pendingFiles == 0,
            ),
        'dateAttributionExact': metadata.tokenUsage.totals.dateAttributionExact,
        'storageAvailable': metadata.tokenUsage.storageAvailable,
        'dataAvailable': _hasTokenData(metadata.tokenUsage),
        'pendingFilesCount': boundedAiCount(
          metadata.tokenUsage.coverage.fold<int>(
            0,
            (sum, source) => sum + source.pendingFiles,
          ),
        ),
      },
  };
}

bool _hasTokenData(TokenUsageSnapshot snapshot) =>
    snapshot.storageAvailable && snapshot.days.isNotEmpty;

bool _eligibleClipboard(ClipboardRecord record) =>
    !record.sensitive &&
    record.enabled &&
    record.kind != ClipboardKind.file &&
    record.kind != ClipboardKind.image &&
    record.content.isNotEmpty &&
    record.content.length <= 16000 &&
    const AiCompanionPrivacy().isSafeText(record.content);
