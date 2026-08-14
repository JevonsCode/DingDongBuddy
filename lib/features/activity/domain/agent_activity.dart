import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';

/// One locally observed Agent update shown in the Dynamic workspace.
final class AgentActivity {
  const AgentActivity({
    required this.id,
    required this.source,
    required this.message,
    required this.completedAt,
    required this.unseen,
    this.task,
    this.detail,
    this.startedAt,
    this.repeatCount = 1,
    this.notificationKind = AgentNotificationKind.completion,
    this.conversationTarget,
  });

  factory AgentActivity.fromJson(Map<String, Object?> json) {
    return AgentActivity(
      id: json['id']! as String,
      source: json['source']! as String,
      message: json['message']! as String,
      completedAt: DateTime.parse(json['completedAt']! as String).toUtc(),
      unseen: json['unseen'] == true,
      task: _trimmed(json['task']),
      detail: _trimmed(json['detail']),
      startedAt: _dateTime(json['startedAt']),
      repeatCount: _repeatCount(json['repeatCount']),
      notificationKind: AgentNotificationKind.parse(json['notificationKind']),
      conversationTarget: json['conversationTarget'] is Map
          ? AgentConversationTarget.fromJson(
              Map<String, Object?>.from(json['conversationTarget']! as Map),
            )
          : null,
    );
  }

  final String id;
  final String source;
  final String message;
  final DateTime completedAt;
  final bool unseen;
  final String? task;
  final String? detail;
  final DateTime? startedAt;
  final int repeatCount;
  final AgentNotificationKind notificationKind;
  final AgentConversationTarget? conversationTarget;

  bool get needsUserAttention =>
      notificationKind == AgentNotificationKind.attention;

  AgentActivity seen() => AgentActivity(
    id: id,
    source: source,
    message: message,
    completedAt: completedAt,
    unseen: false,
    task: task,
    detail: detail,
    startedAt: startedAt,
    repeatCount: repeatCount,
    notificationKind: notificationKind,
    conversationTarget: conversationTarget,
  );

  AgentActivity repeated({
    required String source,
    required String message,
    required DateTime completedAt,
    String? task,
    String? detail,
    DateTime? startedAt,
    AgentConversationTarget? conversationTarget,
    AgentNotificationKind? notificationKind,
    bool preserveLifecycle = false,
  }) {
    final AgentConversationTarget? mergedTarget =
        this.conversationTarget == null
        ? conversationTarget
        : this.conversationTarget!.merge(
            conversationTarget ?? this.conversationTarget!,
          );
    return AgentActivity(
      id: id,
      source: source,
      message: message,
      completedAt: completedAt,
      unseen: true,
      task: preserveLifecycle ? this.task : task,
      detail: detail ?? (preserveLifecycle ? this.detail : null),
      startedAt: preserveLifecycle ? this.startedAt : startedAt,
      repeatCount: repeatCount + 1,
      notificationKind: notificationKind ?? this.notificationKind,
      conversationTarget: mergedTarget,
    );
  }

  AgentActivity withConversationTarget(AgentConversationTarget target) =>
      AgentActivity(
        id: id,
        source: source,
        message: message,
        completedAt: completedAt,
        unseen: unseen,
        task: task,
        detail: detail,
        startedAt: startedAt,
        repeatCount: repeatCount,
        notificationKind: notificationKind,
        conversationTarget: conversationTarget?.merge(target) ?? target,
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'source': source,
    'message': message,
    'completedAt': completedAt.toUtc().toIso8601String(),
    'unseen': unseen,
    if (task != null) 'task': task,
    if (detail != null) 'detail': detail,
    if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
    'repeatCount': repeatCount,
    if (notificationKind != AgentNotificationKind.completion)
      'notificationKind': notificationKind.apiValue,
    if (conversationTarget != null)
      'conversationTarget': conversationTarget!.toJson(),
  };
}

String? _trimmed(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}

DateTime? _dateTime(Object? value) {
  final String? text = _trimmed(value);
  return text == null ? null : DateTime.tryParse(text)?.toUtc();
}

int _repeatCount(Object? value) {
  if (value is int && value >= 1) {
    return value;
  }
  return 1;
}
