import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:flutter/material.dart';

/// Full-detail Agent completion history for the manager window.
class AgentActivityManagerScreen extends StatelessWidget {
  const AgentActivityManagerScreen({
    required this.controller,
    required this.conversationLauncher,
    super.key,
  });

  final ActivityController controller;
  final AgentConversationLauncher conversationLauncher;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      child: AnimatedBuilder(
        animation: controller,
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
                                context.localized('Recent agents', '最近 Agent'),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 9),
                              _ActivityCountBadge(count: activities.length),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            context.localized(
                              'Newest first. Click a resumable item to return to its conversation.',
                              '按时间倒序排列；点击可恢复的记录可返回对应对话。',
                            ),
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
                          context.localized(
                            'No Agent completions yet',
                            '暂无 Agent 完成记录',
                          ),
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
        SnackBar(
          content: Text(
            context.localized(
              'Could not open this Agent conversation.',
              '无法打开这个 Agent 对话。',
            ),
          ),
        ),
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
        context.localized('$count items', '$count 条'),
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
    required this.onOpen,
  });

  final AgentActivity activity;
  final AgentConversationLauncher conversationLauncher;
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
    final bool canOpen = target != null && conversationLauncher.canOpen(target);
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
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '$date  $time',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        if (canOpen) ...<Widget>[
                          const SizedBox(width: 9),
                          Tooltip(
                            message: context.localized(
                              'Open Agent conversation',
                              '打开 Agent 对话',
                            ),
                            child: Icon(
                              Icons.open_in_new_rounded,
                              key: const Key(
                                'agent-activity-manager-open-conversation',
                              ),
                              size: 16,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
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
