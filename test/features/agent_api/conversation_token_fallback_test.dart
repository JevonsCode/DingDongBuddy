import 'package:dingdong/features/activity/ui/conversation_usage_tooltip.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:dingdong/l10n/generated/dingdong_localizations_en.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'only complete, consistent and explicitly present counts enable details',
    () {
      const complete = ConversationTokenUsage(
        source: ConversationTokenUsageSource.codex,
        totalTokens: 120,
        inputTokens: 100,
        outputTokens: 20,
        cachedInputTokens: 0,
      );
      expect(
        formatConversationTokenUsage(complete),
        '输入 100 · 输出 20 · 命中缓存 0 · 非缓存 120',
      );
      for (final usage in [
        const ConversationTokenUsage(
          source: ConversationTokenUsageSource.codex,
          totalTokens: 120,
        ),
        const ConversationTokenUsage(
          source: ConversationTokenUsageSource.codex,
          totalTokens: 120,
          inputTokens: 100,
          outputTokens: 20,
        ),
        const ConversationTokenUsage(
          source: ConversationTokenUsageSource.codex,
          totalTokens: 120,
          inputTokens: 90,
          outputTokens: 20,
          cachedInputTokens: 0,
        ),
        const ConversationTokenUsage(
          source: ConversationTokenUsageSource.codex,
          totalTokens: 120,
          inputTokens: 100,
          outputTokens: 20,
          cachedInputTokens: 101,
        ),
        const ConversationTokenUsage(
          source: ConversationTokenUsageSource.claudeCode,
          totalTokens: 120,
          inputTokens: 100,
          outputTokens: 20,
          cachedInputTokens: 0,
        ),
      ]) {
        expect(formatConversationTokenUsage(usage), '120 Token');
        final restored = ConversationTokenUsage.tryParse(usage.toJson())!;
        expect(formatConversationTokenUsage(restored), '120 Token');
        expect(
          conversationUsageTooltip(DingDongLocalizationsEn(), 2, restored),
          'This conversation has notified you 2 times and used 120 tokens.',
        );
      }
      expect(
        formatConversationTokenUsage(
          ConversationTokenUsage.tryParse(complete.toJson())!,
        ),
        '输入 100 · 输出 20 · 命中缓存 0 · 非缓存 120',
      );
    },
  );

  test(
    'legacy serialized snapshots and malformed fields keep their known total',
    () {
      final legacy = {
        'source': 'codex',
        'totalTokens': 120,
        'inputTokens': 100,
        'outputTokens': 20,
        'cachedInputTokens': 0,
      };
      expect(
        formatConversationTokenUsage(ConversationTokenUsage.tryParse(legacy)!),
        '120 Token',
      );
      for (final field in [
        'inputTokens',
        'outputTokens',
        'cachedInputTokens',
      ]) {
        for (final invalid in [null, -1, '0']) {
          final parsed = ConversationTokenUsage.tryParse({
            ...legacy,
            'breakdownComplete': true,
            field: invalid,
          })!;
          expect(formatConversationTokenUsage(parsed), '120 Token');
        }
      }
    },
  );
}
