import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';

String conversationUsageTooltip(
  DingDongLocalizations l10n,
  int repeatCount,
  ConversationTokenUsage usage,
) {
  if (!usage.hasTokenBreakdown) {
    return l10n.thisConversationHasNotifiedYouRepeatCountTimesAndUsed_3d5931a3(
      repeatCount,
      formatExactConversationTokenCount(usage.totalTokens),
    );
  }
  String count(int value) =>
      usage.hasTokenBreakdown ? formatExactConversationTokenCount(value) : '—';
  final nonCached = usage.nonCachedTokens;
  return '${l10n.repeatcountNotificationsForThisConversation(repeatCount)}\n'
      '${l10n.conversationUsageDetails(count(usage.totalInputTokens), count(usage.outputTokens), count(usage.cachedInputTokens), nonCached == null ? '—' : count(nonCached))}';
}
