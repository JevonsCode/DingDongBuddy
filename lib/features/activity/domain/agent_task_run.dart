import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';

/// One Agent task that DingDong has directly observed starting.
///
/// Running tasks intentionally stay in memory only. After a desktop restart,
/// DingDong cannot prove that an earlier process is still running, so it does
/// not restore stale sessions or fabricate lifecycle state.
final class AgentTaskRun {
  const AgentTaskRun({
    required this.id,
    required this.source,
    required this.task,
    required this.startedAt,
    this.repositoryUrl,
    this.conversationTarget,
  });

  final String id;
  final String source;
  final String task;
  final DateTime startedAt;
  final String? repositoryUrl;
  final AgentConversationTarget? conversationTarget;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'source': source,
    'task': task,
    'startedAt': startedAt.toUtc().toIso8601String(),
    if (repositoryUrl != null) 'repositoryUrl': repositoryUrl,
    if (conversationTarget != null)
      'conversationTarget': conversationTarget!.toJson(),
  };
}
