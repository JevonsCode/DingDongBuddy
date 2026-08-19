import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/activity/ui/activity_repeat_count.dart';
import 'package:dingdong/features/activity/ui/agent_subagent_badge.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:flutter/material.dart';

/// Full-detail Agent completion history for the manager window.
class AgentActivityManagerScreen extends StatelessWidget {
  const AgentActivityManagerScreen({
    required this.controller,
    required this.conversationLauncher,
    this.showConversationTokenUsage = false,
    super.key,
  });

  final ActivityController controller;
  final AgentConversationLauncher conversationLauncher;
  final bool showConversationTokenUsage;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          controller,
          conversationLauncher,
        ]),
        builder: (BuildContext context, Widget? child) {
          final List<AgentActivity> activities = controller.activities;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Text(
                                context.l10n.recentAgents,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 9),
                              _ActivityCountBadge(count: activities.length),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            context
                                .l10n
                                .newestFirstClickAResumableItemToReturnToItsConversation,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: activities.isEmpty
                    ? Center(
                        child: Text(
                          context.l10n.noAgentCompletionsYet,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        key: const Key('agent-activity-manager-list'),
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                        itemCount: activities.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (BuildContext context, int index) =>
                            _ActivityHistoryRow(
                              activity: activities[index],
                              conversationLauncher: conversationLauncher,
                              showConversationTokenUsage:
                                  showConversationTokenUsage,
                              onOpen: (AgentConversationTarget target) =>
                                  unawaited(_openConversation(context, target)),
                            ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openConversation(
    BuildContext context,
    AgentConversationTarget target,
  ) async {
    try {
      await conversationLauncher.open(target);
    } on Object {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenThisAgentConversation)),
      );
    }
  }
}

class _ActivityCountBadge extends StatelessWidget {
  const _ActivityCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('agent-activity-count-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Text(
        context.l10n.countItems(count),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActivityHistoryRow extends StatelessWidget {
  const _ActivityHistoryRow({
    required this.activity,
    required this.conversationLauncher,
    required this.showConversationTokenUsage,
    required this.onOpen,
  });

  final AgentActivity activity;
  final AgentConversationLauncher conversationLauncher;
  final bool showConversationTokenUsage;
  final ValueChanged<AgentConversationTarget> onOpen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DateTime localTime = activity.completedAt.toLocal();
    final String date = MaterialLocalizations.of(
      context,
    ).formatShortDate(localTime);
    final String time = TimeOfDay.fromDateTime(localTime).format(context);
    final AgentConversationTarget? target = activity.conversationTarget;
    final bool isSubagent =
        target != null && conversationLauncher.isSubagent(target);
    final bool canOpen =
        !isSubagent && target != null && conversationLauncher.canOpen(target);
    return Material(
      key: Key('agent-activity-row-${activity.id}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: canOpen ? () => onOpen(target) : null,
        mouseCursor: canOpen
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 16,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            activity.source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (activity.needsUserAttention) ...<Widget>[
                          const SizedBox(width: 7),
                          const AgentAttentionBadge(compact: true),
                        ],
                        if (activity.repeatCount > 1) ...<Widget>[
                          const SizedBox(width: 6),
                          Tooltip(
                            message:
                                showConversationTokenUsage &&
                                    activity.tokenUsage != null
                                ? context.l10n
                                      .thisConversationHasNotifiedYouRepeatCountTimesAndUsed_3d5931a3(
                                        activity.repeatCount,
                                        formatExactConversationTokenCount(
                                          activity.tokenUsage!.totalTokens,
                                        ),
                                      )
                                : context.l10n
                                      .repeatcountNotificationsForThisConversation(
                                        activity.repeatCount,
                                      ),
                            child: ActivityRepeatCount(
                              key: Key(
                                'agent-activity-manager-repeat-count-${activity.id}',
                              ),
                              count: activity.repeatCount,
                              foregroundColor: activity.unseen
                                  ? PopupStyle.of(
                                      context,
                                    ).activityUnread.withValues(alpha: 0.58)
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ] else
                          const SizedBox(width: 12),
                        SizedBox(
                          width: 150,
                          child: Text(
                            '$date  $time',
                            maxLines: 1,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.clip,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontFeatures: const <FontFeature>[
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ),
                        if (isSubagent) ...<Widget>[
                          const SizedBox(width: 9),
                          AgentSubagentBadge(
                            key: Key(
                              'agent-activity-manager-subagent-${activity.id}',
                            ),
                            foregroundColor: colors.primary,
                            backgroundColor: colors.primary.withValues(
                              alpha: 0.09,
                            ),
                            borderColor: colors.primary.withValues(alpha: 0.22),
                          ),
                        ] else if (canOpen) ...<Widget>[
                          const SizedBox(width: 9),
                          Tooltip(
                            message: context.l10n.openAgentConversation,
                            child: Icon(
                              Icons.open_in_new_rounded,
                              key: const Key(
                                'agent-activity-manager-open-conversation',
                              ),
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ] else if (target != null) ...<Widget>[
                          const SizedBox(width: 9),
                          AgentUnknownConversationIcon(
                            key: Key(
                              'agent-activity-manager-unknown-${activity.id}',
                            ),
                            color: colors.onSurfaceVariant,
                          ),
                        ] else
                          SizedBox(
                            key: Key(
                              'agent-activity-manager-open-placeholder-${activity.id}',
                            ),
                            width: 25,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      activity.message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
