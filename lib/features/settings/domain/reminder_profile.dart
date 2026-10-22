import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/settings/domain/reminder_sounds.dart';
import 'package:dingdong/features/settings/domain/tray_reminder_style.dart';

/// A named delivery preset. The caller decides when its condition applies.
final class ReminderProfile {
  const ReminderProfile({
    required this.id,
    required this.name,
    this.description = '',
    this.enabled = true,
    this.kind = AgentNotificationKind.attention,
    this.style = TrayReminderStyle.softPulse,
    this.color = TrayNotificationColor.amber,
    this.sound = 'default',
    this.customSoundPath,
    this.toPhone = true,
  });
  factory ReminderProfile.fromJson(Map<String, Object?> json) {
    String field(String key, int max, {String fallback = ''}) {
      final value = json[key] ?? fallback;
      if (value is! String || value.length > max) {
        throw FormatException('Invalid $key (maximum $max characters).');
      }
      return value.trim();
    }

    final id = field('id', 64);
    final name = field('name', 64);
    if (id.isEmpty ||
        name.isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id)) {
      throw const FormatException(
        'A reminder needs an ID (letters, numbers, _ or -) and name.',
      );
    }
    final kind = field('kind', 16, fallback: 'attention');
    final style = field('style', 32, fallback: 'softPulse');
    final color = field('color', 16, fallback: 'amber');
    final sound = field('sound', 32, fallback: 'default');
    if (!AgentNotificationKind.values.any((x) => x.apiValue == kind) ||
        !TrayReminderStyle.values.any((x) => x.name == style) ||
        !TrayNotificationColor.values.any((x) => x.name == color) ||
        !notificationSoundValues.contains(sound)) {
      throw const FormatException(
        'Unknown reminder kind, style, color or sound.',
      );
    }
    for (final key in ['enabled', 'toPhone']) {
      if (json[key] != null && json[key] is! bool) {
        throw FormatException('$key must be a boolean.');
      }
    }
    final path = field('customSoundPath', 4096);
    return ReminderProfile(
      id: id,
      name: name,
      description: field('description', 160),
      enabled: json['enabled'] != false,
      kind: AgentNotificationKind.parse(kind),
      style: TrayReminderStyle.values.byName(style),
      color: TrayNotificationColor.values.byName(color),
      sound: sound,
      customSoundPath: path.isEmpty ? null : path,
      toPhone: json['toPhone'] != false,
    );
  }
  final String id;
  final String name;
  final String description;
  final bool enabled;
  final AgentNotificationKind kind;
  final TrayReminderStyle style;
  final TrayNotificationColor color;
  final String sound;
  final String? customSoundPath;
  final bool toPhone;
  bool get builtIn => id == 'completion' || id == 'attention';
  String get soundKey =>
      sound == 'custom' ? customSoundPath ?? 'custom' : sound;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'enabled': enabled,
    'kind': kind.apiValue,
    'style': style.name,
    'color': color.name,
    'sound': sound,
    'customSoundPath': ?customSoundPath,
    'toPhone': toPhone,
  };
  ReminderProfile copyWith({
    String? name,
    String? description,
    bool? enabled,
    AgentNotificationKind? kind,
    TrayReminderStyle? style,
    TrayNotificationColor? color,
    String? sound,
    String? customSoundPath,
    bool? toPhone,
  }) => ReminderProfile(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    enabled: enabled ?? this.enabled,
    kind: kind ?? this.kind,
    style: style ?? this.style,
    color: color ?? this.color,
    sound: sound ?? this.sound,
    customSoundPath: customSoundPath ?? this.customSoundPath,
    toPhone: toPhone ?? this.toPhone,
  );
  @override
  bool operator ==(Object other) =>
      other is ReminderProfile &&
      id == other.id &&
      name == other.name &&
      description == other.description &&
      enabled == other.enabled &&
      kind == other.kind &&
      style == other.style &&
      color == other.color &&
      sound == other.sound &&
      customSoundPath == other.customSoundPath &&
      toPhone == other.toPhone;
  @override
  int get hashCode => Object.hashAll(toJson().values);
}

final class ReminderAudio {
  const ReminderAudio({required this.name, required this.path});
  final String name;
  final String path;
  Map<String, Object?> toJson() => {'name': name, 'path': path};
  @override
  bool operator ==(Object other) =>
      other is ReminderAudio && name == other.name && path == other.path;
  @override
  int get hashCode => Object.hash(name, path);
}
