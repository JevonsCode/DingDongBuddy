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
    this.sentAt,
    this.receivedAt,
    this.reminderColors = const <String>[],
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

  /// When the computer handed this reminder to the connection (newer
  /// desktops only) and when this phone received it.
  final DateTime? sentAt;
  final DateTime? receivedAt;

  /// The user's reminder colors on the computer (`#rrggbb`), so cards match.
  final List<String> reminderColors;

  /// Reminders that took longer than this to arrive are posted quietly and
  /// labelled as late instead of ringing as if they were new.
  static const Duration lateAfter = Duration(minutes: 10);

  /// Time between the Agent stopping (or the computer sending, whichever is
  /// earlier) and this phone receiving the reminder. A computer that was
  /// suspended or asleep sends with the original completion time.
  Duration? get deliveryDelay {
    final DateTime? sent = sentAt;
    final DateTime? completed = completedAt;
    final DateTime? from = sent == null
        ? completed
        : completed == null || sent.isBefore(completed)
        ? sent
        : completed;
    final DateTime? to = receivedAt;
    if (from == null || to == null) return null;
    final Duration delay = to.difference(from);
    return delay.isNegative ? Duration.zero : delay;
  }

  bool get isLate => (deliveryDelay ?? Duration.zero) > lateAfter;

  bool get needsAttention => kind == AgentKind.attention;

  /// Key the desktop accepts in `agent.seen.activityIds`.
  String get seenKey => activityId ?? id;

  /// One occurrence of an activity: live messages and `agent.state` items
  /// use different ids for the same reminder, but agree on these fields.
  String get occurrenceKey =>
      'occurrence:$seenKey@${completedAt?.toUtc().toIso8601String() ?? ''}';

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
      sentAt: DateTime.tryParse(_string(message['sentAt'])),
      receivedAt: DateTime.tryParse(_string(message['receivedAt'])),
      reminderColors: <String>[
        for (final Object? value
            in message['reminderColors'] as List? ?? const <Object?>[])
          if (value is String && _hexColor.hasMatch(value)) value,
      ].take(4).toList(growable: false),
    );
  }

  static final RegExp _hexColor = RegExp(r'^#[0-9a-fA-F]{6}$');

  /// This event as received now, for delay accounting.
  AgentEvent receivedNow([DateTime? now]) => AgentEvent(
    id: id,
    activityId: activityId,
    kind: kind,
    silent: silent,
    title: title,
    source: source,
    summary: summary,
    detail: detail,
    task: task,
    unseen: unseen,
    startedAt: startedAt,
    completedAt: completedAt,
    workspacePath: workspacePath,
    sentAt: sentAt,
    receivedAt: (now ?? DateTime.now()).toUtc(),
    reminderColors: reminderColors,
  );

  /// Notification title: "<source> · <title>" unless the title names it.
  String get notificationTitle {
    if (source.isEmpty || title.toLowerCase().contains(source.toLowerCase())) {
      return title;
    }
    return '$source · $title';
  }

  /// [notificationTitle] followed by the computer that sent it, as the PWA
  /// does, so reminders from several computers can be told apart.
  String notificationTitleFrom(String hostName) {
    final String name = _normalized(hostName);
    final String base = notificationTitle;
    if (name.isEmpty || base.toLowerCase().contains(name.toLowerCase())) {
      return base;
    }
    return '$base · $name';
  }

  /// One line for the collapsed notification: what the Agent needs, or what
  /// it finished. The task the user asked for comes second, in the expanded
  /// text, because it is usually the longest and least actionable part.
  String get notificationBody {
    final String? ask = needsAttention ? _requestLine(detail) : null;
    if (ask != null) return _clip(ask, 160);
    final String first = _firstLine(summary.isNotEmpty ? summary : detail);
    if (first.isNotEmpty) return _clip(first, 160);
    if (task.isNotEmpty) return _clip(task, 160);
    return needsAttention ? '请打开 Agent 提醒查看并继续处理。' : '本轮任务已经完成。';
  }

  /// The full reminder for the expanded notification: the Agent's whole
  /// message with its line breaks, then the task, project and timing.
  String notificationDetail({DateTime? now}) {
    final List<String> parts = <String>[];
    final String message = _paragraphs(detail.isNotEmpty ? detail : summary);
    parts.add(message.isNotEmpty ? message : notificationBody);
    if (task.isNotEmpty && _normalized(task) != _normalized(message)) {
      parts.add('任务：${_clip(task, 600)}');
    }
    final String? project = workspaceName;
    if (project != null) parts.add('项目 · $project');
    final String timing = timingLine(now: now);
    if (timing.isNotEmpty) parts.add(timing);
    return _clip(parts.join('\n\n'), 3800);
  }

  /// "完成于 14:03 · 延迟 3 小时 12 分送达" when the reminder came late.
  String timingLine({DateTime? now}) {
    final DateTime? completed = completedAt?.toLocal();
    final List<String> parts = <String>[
      if (completed != null)
        '${needsAttention ? '发出于' : '完成于'} ${_clock(completed, now: now)}',
      if (isLate) '延迟 ${formatDelay(deliveryDelay!)}送达',
    ];
    return parts.join(' · ');
  }

  String? get workspaceName {
    final String? path = workspacePath;
    if (path == null) return null;
    final List<String> segments = path
        .split(RegExp(r'[\\/]'))
        .where((String part) => part.isNotEmpty)
        .toList();
    return segments.isEmpty ? null : segments.last;
  }

  static String formatDelay(Duration delay) {
    if (delay.inMinutes < 1) return '${delay.inSeconds} 秒';
    if (delay.inHours < 1) return '${delay.inMinutes} 分钟';
    final int minutes = delay.inMinutes % 60;
    return minutes == 0
        ? '${delay.inHours} 小时'
        : '${delay.inHours} 小时 $minutes 分';
  }

  static String _clock(DateTime value, {DateTime? now}) {
    final DateTime today = (now ?? DateTime.now()).toLocal();
    final String time =
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    final bool sameDay =
        value.year == today.year &&
        value.month == today.month &&
        value.day == today.day;
    return sameDay ? time : '${value.month}月${value.day}日 $time';
  }

  /// The line of a waiting Agent's message that asks the user for
  /// something, so the collapsed notification says what to do.
  static String? _requestLine(String value) {
    for (final String line in value.split('\n')) {
      final String text = _normalized(line);
      if (text.isEmpty) continue;
      if (_request.hasMatch(text)) return text;
    }
    return null;
  }

  static final RegExp _request = RegExp(
    r'(?:^|[，。；！？、,.;!?:：\s🟥])请(?![求假他她它])|需要你|需要您|等你|要你|[?？]$'
    r'|please |need your|needs your|waiting for you',
    caseSensitive: false,
    unicode: true,
  );

  static String _firstLine(String value) {
    for (final String line in value.split('\n')) {
      final String text = _normalized(line);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  /// Keeps paragraph breaks, collapses runs of spaces and blank lines.
  static String _paragraphs(String value) => value
      .replaceAll('\r', '')
      .split('\n')
      .map((String line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  static String _clip(String value, int maximum) {
    final List<int> runes = value.runes.toList();
    if (runes.length <= maximum) return value;
    return '${String.fromCharCodes(runes.take(maximum - 1))}…';
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
    sentAt: sentAt,
    receivedAt: receivedAt,
    reminderColors: reminderColors,
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
    if (sentAt != null) 'sentAt': sentAt!.toUtc().toIso8601String(),
    if (receivedAt != null) 'receivedAt': receivedAt!.toUtc().toIso8601String(),
    if (reminderColors.isNotEmpty) 'reminderColors': reminderColors,
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
