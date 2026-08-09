/// The only remote lifecycle events DingDong supports.
enum LifecycleTelemetryEventKind { install, upgrade }

/// One idempotent lifecycle event with a bounded, documented payload.
final class LifecycleTelemetryEvent {
  const LifecycleTelemetryEvent({
    required this.eventId,
    required this.installationId,
    required this.kind,
    required this.currentVersion,
    required this.currentBuild,
    required this.platform,
    required this.architecture,
    required this.occurredAt,
    this.previousVersion,
    this.previousBuild,
  });

  final String eventId;
  final String installationId;
  final LifecycleTelemetryEventKind kind;
  final String currentVersion;
  final String currentBuild;
  final String? previousVersion;
  final String? previousBuild;
  final String platform;
  final String architecture;
  final DateTime occurredAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'eventId': eventId,
    'installationId': installationId,
    'event': kind.name,
    'currentVersion': currentVersion,
    'currentBuild': currentBuild,
    'previousVersion': ?previousVersion,
    'previousBuild': ?previousBuild,
    'platform': platform,
    'architecture': architecture,
    'occurredAt': occurredAt.toUtc().toIso8601String(),
  };

  static LifecycleTelemetryEvent? fromJson(Object? value) {
    if (value is! Map<String, Object?> || value['schemaVersion'] != 1) {
      return null;
    }
    LifecycleTelemetryEventKind? kind;
    for (final LifecycleTelemetryEventKind item
        in LifecycleTelemetryEventKind.values) {
      if (item.name == value['event']) {
        kind = item;
        break;
      }
    }
    final DateTime? occurredAt = DateTime.tryParse(
      value['occurredAt'] as String? ?? '',
    );
    final List<Object?> required = <Object?>[
      value['eventId'],
      value['installationId'],
      value['currentVersion'],
      value['currentBuild'],
      value['platform'],
      value['architecture'],
    ];
    if (kind == null ||
        occurredAt == null ||
        required.any((Object? item) => item is! String || item.isEmpty)) {
      return null;
    }
    return LifecycleTelemetryEvent(
      eventId: value['eventId']! as String,
      installationId: value['installationId']! as String,
      kind: kind,
      currentVersion: value['currentVersion']! as String,
      currentBuild: value['currentBuild']! as String,
      previousVersion: value['previousVersion'] as String?,
      previousBuild: value['previousBuild'] as String?,
      platform: value['platform']! as String,
      architecture: value['architecture']! as String,
      occurredAt: occurredAt.toUtc(),
    );
  }
}

abstract interface class LifecycleTelemetryGateway {
  Future<void> send(LifecycleTelemetryEvent event);
}
