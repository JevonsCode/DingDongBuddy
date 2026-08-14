import 'dart:convert';

import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';

/// Sound values retained for compatibility with existing API clients.
enum DingSound {
  defaultSound('default'),
  dingSoft('dingSoft'),
  dingBright('dingBright'),
  dingCrisp('dingCrisp'),
  dingWood('dingWood'),
  dingDeep('dingDeep'),
  joy('joy'),
  levelUp('levelUp'),
  taDa('taDa'),
  bubble('bubble'),
  coin('coin'),
  fanfare('fanfare'),
  arcade('arcade'),
  bloom('bloom'),
  sunrise('sunrise'),
  popcorn('popcorn'),
  glimmer('glimmer'),
  rocket('rocket'),
  confetti('confetti'),
  marimba('marimba'),
  candy('candy'),
  sparkle('sparkle'),
  success('success'),
  celebrate('celebrate'),
  random('random'),
  custom('custom'),
  system('system'),
  muted('muted');

  const DingSound(this.apiValue);

  final String apiValue;

  static DingSound parse(Object? value) {
    if (value == null) {
      return DingSound.defaultSound;
    }
    return values.firstWhere(
      (DingSound sound) => sound.apiValue == value,
      orElse: () => throw FormatException('Unknown sound: $value'),
    );
  }
}

/// Parsed notification request delivered to the platform coordinator.
final class DingRequest {
  const DingRequest({
    this.message = 'Task complete',
    this.detail,
    this.source,
    this.sound = DingSound.defaultSound,
    this.flashCount = 8,
    this.fallback = false,
    this.notificationKind = AgentNotificationKind.completion,
    this.conversationTarget,
    this.receivedAt,
  });

  factory DingRequest.parse(String body) {
    if (body.isEmpty) {
      return const DingRequest();
    }
    final Map<String, Object?> json = jsonDecode(body) as Map<String, Object?>;
    final String message =
        _trimmedOrNull(json['message'] as String?) ?? 'Task complete';
    final String? detail = _trimmedOrNull(json['detail'] as String?);
    final int requestedFlashCount = json['flashCount'] as int? ?? 8;
    final String? source = _trimmedOrNull(json['source'] as String?);
    final Object? notificationKind = json['notificationKind'] ?? json['kind'];
    return DingRequest(
      message: message,
      detail: detail,
      source: source,
      sound: DingSound.parse(json['sound']),
      flashCount: requestedFlashCount.clamp(2, 30),
      fallback: json['fallback'] == true,
      notificationKind: AgentNotificationKind.parse(notificationKind),
      conversationTarget: _conversationTarget(json, source),
    );
  }

  final String message;
  final String? detail;
  final String? source;
  final DingSound sound;
  final int flashCount;
  final bool fallback;
  final AgentNotificationKind notificationKind;
  final AgentConversationTarget? conversationTarget;
  final DateTime? receivedAt;

  DingRequest copyWith({
    DingSound? sound,
    AgentNotificationKind? notificationKind,
    DateTime? receivedAt,
  }) {
    return DingRequest(
      message: message,
      detail: detail,
      source: source,
      sound: sound ?? this.sound,
      flashCount: flashCount,
      fallback: fallback,
      notificationKind: notificationKind ?? this.notificationKind,
      conversationTarget: conversationTarget,
      receivedAt: receivedAt ?? this.receivedAt,
    );
  }
}

AgentConversationTarget? _conversationTarget(
  Map<String, Object?> json,
  String? source,
) {
  final Map<String, Object?> nested = json['conversationTarget'] is Map
      ? Map<String, Object?>.from(json['conversationTarget']! as Map)
      : const <String, Object?>{};
  final AgentClient client =
      AgentClient.parse(nested['client']) == AgentClient.unknown
      ? AgentClient.fromSource(source ?? '')
      : AgentClient.parse(nested['client']);
  final String? conversationId = _firstTrimmed(<Object?>[
    nested['conversationId'],
    json['conversationId'],
    json['sessionId'],
    json['threadId'],
  ]);
  final String? workspacePath = _firstTrimmed(<Object?>[
    nested['workspacePath'],
    json['workspacePath'],
    json['cwd'],
  ]);
  final AgentConversationTarget target = AgentConversationTarget(
    client: client,
    conversationId: conversationId,
    workspacePath: workspacePath,
  );
  return target.hasDestination ? target : null;
}

String? _firstTrimmed(List<Object?> values) {
  for (final Object? value in values) {
    final String? trimmed = value is String ? _trimmedOrNull(value) : null;
    if (trimmed != null) {
      return trimmed;
    }
  }
  return null;
}

String? _trimmedOrNull(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
