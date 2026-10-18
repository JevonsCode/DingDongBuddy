import 'dart:convert';

import 'package:dingdong/core/utils/text.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:flutter/foundation.dart';

/// Sound value meaning "use the completion sound" for the attention reminder.
const String sameAsCompletionSound = 'sameAsCompletion';

/// Sounds a reminder may use. `custom` reads the matching custom file path.
const Set<String> notificationSoundValues = <String>{
  'default',
  'dingSoft',
  'dingBright',
  'dingCrisp',
  'dingDeep',
  'custom',
  'system',
  'muted',
};

/// A daily local-time window in which reminders are recorded silently.
///
/// The window may cross midnight (for example 22:00–08:00). Equal start and
/// end minutes mean the whole day.
@immutable
final class QuietHours {
  const QuietHours({
    this.enabled = false,
    this.startMinute = 22 * 60,
    this.endMinute = 8 * 60,
    this.allowAttention = true,
  });

  final bool enabled;
  final int startMinute;
  final int endMinute;

  /// When true, "needs your input" reminders still ring during quiet hours.
  final bool allowAttention;

  bool covers(DateTime local) {
    if (!enabled) return false;
    final int minute = local.hour * 60 + local.minute;
    if (startMinute == endMinute) return true;
    return startMinute < endMinute
        ? minute >= startMinute && minute < endMinute
        : minute >= startMinute || minute < endMinute;
  }

  QuietHours copyWith({
    bool? enabled,
    int? startMinute,
    int? endMinute,
    bool? allowAttention,
  }) => QuietHours(
    enabled: enabled ?? this.enabled,
    startMinute: startMinute ?? this.startMinute,
    endMinute: endMinute ?? this.endMinute,
    allowAttention: allowAttention ?? this.allowAttention,
  );

  QuietHours sanitized() => QuietHours(
    enabled: enabled,
    startMinute: _minuteOfDay(startMinute, 22 * 60),
    endMinute: _minuteOfDay(endMinute, 8 * 60),
    allowAttention: allowAttention,
  );

  @override
  bool operator ==(Object other) =>
      other is QuietHours &&
      other.enabled == enabled &&
      other.startMinute == startMinute &&
      other.endMinute == endMinute &&
      other.allowAttention == allowAttention;

  @override
  int get hashCode =>
      Object.hash(enabled, startMinute, endMinute, allowAttention);
}

/// Per-kind reminder rules layered on top of the on/off switches.
///
/// Stored as one JSON preference so new rules do not widen the positional
/// settings contract.
@immutable
final class NotificationRules {
  const NotificationRules({
    this.attentionSound = sameAsCompletionSound,
    this.attentionCustomSoundPath,
    this.completionToPhone = true,
    this.attentionToPhone = true,
    this.quietHours = const QuietHours(),
    this.completionMinimumMinutes = 0,
  });

  static const NotificationRules defaultValue = NotificationRules();

  /// Allowed "only alert for tasks at least this long" choices, in minutes.
  static const List<int> completionMinimumChoices = <int>[0, 1, 3, 5, 10, 30];

  final String attentionSound;
  final String? attentionCustomSoundPath;
  final bool completionToPhone;
  final bool attentionToPhone;
  final QuietHours quietHours;

  /// Completions of tasks observed to run for less than this are recorded
  /// without sound, flashing or phone push. Zero alerts for every task.
  final int completionMinimumMinutes;

  static NotificationRules parse(Object? value) {
    if (value is! String || value.trim().isEmpty) return defaultValue;
    try {
      final Object? decoded = jsonDecode(value);
      if (decoded is! Map) return defaultValue;
      final Map<Object?, Object?> json = decoded;
      final Object? quiet = json['quietHours'];
      final Map<Object?, Object?> quietJson = quiet is Map
          ? quiet
          : const <Object?, Object?>{};
      return NotificationRules(
        attentionSound: json['attentionSound'] is String
            ? json['attentionSound']! as String
            : sameAsCompletionSound,
        attentionCustomSoundPath: json['attentionCustomSoundPath'] is String
            ? json['attentionCustomSoundPath']! as String
            : null,
        completionToPhone: json['completionToPhone'] != false,
        attentionToPhone: json['attentionToPhone'] != false,
        quietHours: QuietHours(
          enabled: quietJson['enabled'] == true,
          startMinute: quietJson['startMinute'] is int
              ? quietJson['startMinute']! as int
              : 22 * 60,
          endMinute: quietJson['endMinute'] is int
              ? quietJson['endMinute']! as int
              : 8 * 60,
          allowAttention: quietJson['allowAttention'] != false,
        ),
        completionMinimumMinutes: json['completionMinimumMinutes'] is int
            ? json['completionMinimumMinutes']! as int
            : 0,
      ).sanitized();
    } on FormatException {
      return defaultValue;
    }
  }

  String encode() => jsonEncode(<String, Object?>{
    'attentionSound': attentionSound,
    'attentionCustomSoundPath': ?attentionCustomSoundPath,
    'completionToPhone': completionToPhone,
    'attentionToPhone': attentionToPhone,
    'quietHours': <String, Object?>{
      'enabled': quietHours.enabled,
      'startMinute': quietHours.startMinute,
      'endMinute': quietHours.endMinute,
      'allowAttention': quietHours.allowAttention,
    },
    'completionMinimumMinutes': completionMinimumMinutes,
  });

  NotificationRules sanitized() => NotificationRules(
    attentionSound:
        attentionSound == sameAsCompletionSound ||
            notificationSoundValues.contains(attentionSound)
        ? attentionSound
        : sameAsCompletionSound,
    attentionCustomSoundPath: trimmedOrNull(attentionCustomSoundPath),
    completionToPhone: completionToPhone,
    attentionToPhone: attentionToPhone,
    quietHours: quietHours.sanitized(),
    completionMinimumMinutes:
        completionMinimumChoices.contains(completionMinimumMinutes)
        ? completionMinimumMinutes
        : 0,
  );

  NotificationRules copyWith({
    String? attentionSound,
    Object? attentionCustomSoundPath = _notSet,
    bool? completionToPhone,
    bool? attentionToPhone,
    QuietHours? quietHours,
    int? completionMinimumMinutes,
  }) => NotificationRules(
    attentionSound: attentionSound ?? this.attentionSound,
    attentionCustomSoundPath: identical(attentionCustomSoundPath, _notSet)
        ? this.attentionCustomSoundPath
        : attentionCustomSoundPath as String?,
    completionToPhone: completionToPhone ?? this.completionToPhone,
    attentionToPhone: attentionToPhone ?? this.attentionToPhone,
    quietHours: quietHours ?? this.quietHours,
    completionMinimumMinutes:
        completionMinimumMinutes ?? this.completionMinimumMinutes,
  ).sanitized();

  @override
  bool operator ==(Object other) =>
      other is NotificationRules &&
      other.attentionSound == attentionSound &&
      other.attentionCustomSoundPath == attentionCustomSoundPath &&
      other.completionToPhone == completionToPhone &&
      other.attentionToPhone == attentionToPhone &&
      other.quietHours == quietHours &&
      other.completionMinimumMinutes == completionMinimumMinutes;

  @override
  int get hashCode => Object.hash(
    attentionSound,
    attentionCustomSoundPath,
    completionToPhone,
    attentionToPhone,
    quietHours,
    completionMinimumMinutes,
  );
}

/// How one allowed reminder should be delivered.
@immutable
final class AgentNotificationPlan {
  const AgentNotificationPlan({
    required this.alertDesktop,
    required this.alertPhone,
    required this.sound,
    this.customSoundPath,
  });

  /// False records the reminder in activity without sound or flashing.
  final bool alertDesktop;

  /// False keeps the phone list in sync without a system notification.
  final bool alertPhone;

  /// Saved sound value for this kind, before any API-supplied override.
  final String sound;
  final String? customSoundPath;

  bool get silent => !alertDesktop && !alertPhone;
}

/// Applies per-kind sound, phone and timing rules to one allowed reminder.
AgentNotificationPlan planAgentNotification({
  required AgentNotificationKind kind,
  required String completionSound,
  required String? completionCustomSoundPath,
  required NotificationRules rules,
  required DateTime now,
  Duration? taskDuration,
}) {
  final bool attention = kind == AgentNotificationKind.attention;
  final bool quiet =
      rules.quietHours.covers(now.toLocal()) &&
      !(attention && rules.quietHours.allowAttention);
  final bool tooShort =
      !attention &&
      rules.completionMinimumMinutes > 0 &&
      taskDuration != null &&
      taskDuration < Duration(minutes: rules.completionMinimumMinutes);
  final bool alert = !quiet && !tooShort;
  final bool ownAttentionSound =
      attention && rules.attentionSound != sameAsCompletionSound;
  return AgentNotificationPlan(
    alertDesktop: alert,
    alertPhone:
        alert && (attention ? rules.attentionToPhone : rules.completionToPhone),
    sound: ownAttentionSound ? rules.attentionSound : completionSound,
    customSoundPath: ownAttentionSound
        ? rules.attentionCustomSoundPath
        : completionCustomSoundPath,
  );
}

int _minuteOfDay(int value, int fallback) =>
    value >= 0 && value < 24 * 60 ? value : fallback;

const Object _notSet = Object();
