/// Agent reminder kinds; each maps to its own Android notification channel.
enum AgentKind {
  completion,
  attention;

  String get channelId => switch (this) {
    AgentKind.completion => 'agent_completion_v2',
    AgentKind.attention => 'agent_attention_v2',
  };
}

/// A completed or waiting Agent task, from `agent.completed` or the
/// `completed` list of `agent.state`. Fallback texts match the PWA
/// (docs/app/notification-policy.js).
final class AgentEvent {
  const AgentEvent({
    required this.id,
    required this.activityId,
    required this.kind,
    required this.silent,
    required this.title,
    required this.source,
    required this.summary,
    required this.detail,
    required this.task,
    required this.unseen,
    required this.startedAt,
    required this.completedAt,
    required this.workspacePath,
  });

  final String id;
  final String? activityId;
  final AgentKind kind;

  /// Set by the desktop's per-kind rules: keep the list current but raise no
  /// system notification.
  final bool silent;
  final String title;
  final String source;
  final String summary;
  final String detail;
  final String task;
  final bool unseen;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? workspacePath;

  bool get needsAttention => kind == AgentKind.attention;

  /// Key the desktop accepts in `agent.seen.activityIds`.
  String get seenKey => activityId ?? id;

  static AgentEvent? parse(Map<String, Object?> message) {
    final String id = _string(message['id']);
    if (id.isEmpty || id.length > 160) return null;
    final AgentKind kind =
        message['needsUserAttention'] == true ||
            message['notificationKind'] == 'attention'
        ? AgentKind.attention
        : AgentKind.completion;
    final String title = _normalized(message['title']);
    return AgentEvent(
      id: id,
      activityId: _string(message['activityId']).isEmpty
          ? null
          : _string(message['activityId']),
      kind: kind,
      silent: message['silent'] == true,
      title: title.isNotEmpty
          ? title
          : kind == AgentKind.attention
          ? 'Agent 需要你处理'
          : 'Agent 完成啦',
      source: _normalized(message['source']),
      summary: _normalized(message['summary']),
      detail: _string(message['detail']).trim(),
      task: _normalized(message['task']),
      unseen: message['unseen'] != false,
      startedAt: DateTime.tryParse(_string(message['startedAt'])),
      completedAt: DateTime.tryParse(_string(message['completedAt'])),
      workspacePath: _string(message['workspacePath']).isEmpty
          ? null
          : _string(message['workspacePath']),
    );
  }

  /// Notification title: "<source> · <title>" unless the title names it.
  String get notificationTitle {
    if (source.isEmpty || title.toLowerCase().contains(source.toLowerCase())) {
      return title;
    }
    return '$source · $title';
  }

  /// Notification body with the PWA's task/detail combination rules.
  String get notificationBody {
    final String detailText = _normalized(detail.isEmpty ? summary : detail);
    final String fallback = needsAttention
        ? '请打开 Agent 提醒查看并继续处理。'
        : '本轮任务已经完成。';
    final String body =
        task.isNotEmpty && detailText.isNotEmpty && task != detailText
        ? '$task：$detailText'
        : detailText.isNotEmpty
        ? detailText
        : task.isNotEmpty
        ? task
        : fallback;
    final List<int> runes = body.runes.toList();
    if (runes.length <= 260) return body;
    return '${String.fromCharCodes(runes.take(259))}…';
  }

  AgentEvent copyWith({bool? unseen}) => AgentEvent(
    id: id,
    activityId: activityId,
    kind: kind,
    silent: silent,
    title: title,
    source: source,
    summary: summary,
    detail: detail,
    task: task,
    unseen: unseen ?? this.unseen,
    startedAt: startedAt,
    completedAt: completedAt,
    workspacePath: workspacePath,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'activityId': activityId,
    'notificationKind': kind.name,
    'silent': silent,
    'title': title,
    'source': source,
    'summary': summary,
    'detail': detail,
    'task': task,
    'unseen': unseen,
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'workspacePath': workspacePath,
  };

  static String _string(Object? value) => value is String ? value : '';

  static String _normalized(Object? value) =>
      _string(value).replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// A task the desktop reports as still running (`agent.state.running`).
final class AgentRun {
  const AgentRun({
    required this.id,
    required this.source,
    required this.task,
    required this.startedAt,
    required this.workspacePath,
  });

  final String id;
  final String source;
  final String task;
  final DateTime? startedAt;
  final String? workspacePath;

  static AgentRun? parse(Object? value) {
    if (value is! Map) return null;
    final Object? id = value['id'];
    if (id is! String || id.isEmpty) return null;
    return AgentRun(
      id: id,
      source: value['source'] is String ? value['source']! as String : '',
      task: value['task'] is String ? value['task']! as String : '',
      startedAt: DateTime.tryParse('${value['startedAt'] ?? ''}'),
      workspacePath: value['workspacePath'] is String
          ? value['workspacePath']! as String
          : null,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'source': source,
    'task': task,
    'startedAt': startedAt?.toUtc().toIso8601String(),
    'workspacePath': workspacePath,
  };
}
