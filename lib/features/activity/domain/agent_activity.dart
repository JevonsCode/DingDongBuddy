import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';

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
    int? unseenReminderCount,
    this.notificationKind = AgentNotificationKind.completion,
    this.conversationTarget,
    this.tokenUsage,
    this.reminder,
    this.pinned = false,
    this.sequence = 0,
    this.opened = false,
  }) : unseenReminderCount = unseenReminderCount ?? (unseen ? 1 : 0);

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
      unseenReminderCount: _unseenReminderCount(
        json['unseenReminderCount'],
        unseen: json['unseen'] == true,
      ),
      notificationKind: AgentNotificationKind.parse(json['notificationKind']),
      conversationTarget: json['conversationTarget'] is Map
          ? AgentConversationTarget.fromJson(
              Map<String, Object?>.from(json['conversationTarget']! as Map),
            )
          : null,
      tokenUsage: ConversationTokenUsage.tryParse(json['tokenUsage']),
      pinned: json['pinned'] == true,
      sequence: json['sequence'] is int && (json['sequence']! as int) >= 0
          ? json['sequence']! as int
          : 0,
      opened: json['opened'] == true,
      reminder: json['reminder'] is Map
          ? ReminderProfile.fromJson(
              Map<String, Object?>.from(json['reminder'] as Map),
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
  final int unseenReminderCount;
  final AgentNotificationKind notificationKind;
  final AgentConversationTarget? conversationTarget;
  final ConversationTokenUsage? tokenUsage;
  final ReminderProfile? reminder;
  final bool pinned;

  /// Local arrival order, independent of the Agent's completion timestamp.
  final int sequence;
  final bool opened;

  bool get needsUserAttention =>
      notificationKind == AgentNotificationKind.attention;

  AgentActivity withPinned(bool value) =>
      AgentActivity.fromJson({...toJson(), 'pinned': value});

  AgentActivity withOpened() =>
      AgentActivity.fromJson({...toJson(), 'opened': true});

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
    unseenReminderCount: 0,
    notificationKind: notificationKind,
    conversationTarget: conversationTarget,
    tokenUsage: tokenUsage,
    reminder: reminder,
    pinned: pinned,
    sequence: sequence,
    opened: opened,
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
    ConversationTokenUsage? tokenUsage,
    ReminderProfile? reminder,
    bool preserveLifecycle = false,
    bool countAsReminder = true,
    int? sequence,
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
      unseen: countAsReminder || unseen,
      task: preserveLifecycle ? this.task : task,
      detail: detail ?? (preserveLifecycle ? this.detail : null),
      startedAt: preserveLifecycle ? this.startedAt : startedAt,
      repeatCount: repeatCount + 1,
      unseenReminderCount: countAsReminder
          ? unseenReminderCount + 1
          : unseenReminderCount,
      notificationKind: notificationKind ?? this.notificationKind,
      conversationTarget: mergedTarget,
      tokenUsage: tokenUsage ?? this.tokenUsage,
      reminder: reminder ?? this.reminder,
      pinned: pinned,
      sequence: sequence ?? this.sequence,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    if (sequence > 0) 'sequence': sequence,
    if (opened) 'opened': true,
    if (pinned) 'pinned': true,
    if (reminder != null) 'reminder': reminder!.toJson(),
    'source': source,
    'message': message,
    'completedAt': completedAt.toUtc().toIso8601String(),
    'unseen': unseen,
    if (task != null) 'task': task,
    if (detail != null) 'detail': detail,
    if (startedAt != null) 'startedAt': startedAt!.toUtc().toIso8601String(),
    'repeatCount': repeatCount,
    if (unseenReminderCount > 0) 'unseenReminderCount': unseenReminderCount,
    if (notificationKind != AgentNotificationKind.completion)
      'notificationKind': notificationKind.apiValue,
    if (conversationTarget != null)
      'conversationTarget': conversationTarget!.toJson(),
    if (tokenUsage != null) 'tokenUsage': tokenUsage!.toJson(),
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

int _unseenReminderCount(Object? value, {required bool unseen}) {
  if (!unseen) {
    return 0;
  }
  if (value is int && value >= 1) {
    return value;
  }
  return 1;
}
