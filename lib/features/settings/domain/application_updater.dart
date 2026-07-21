/// Native installation phases shared by the macOS and Windows updaters.
enum ApplicationUpdatePhase {
  idle,
  checking,
  downloading,
  extracting,
  installing,
  current,
  unsupported,
  failed;

  static ApplicationUpdatePhase parse(Object? value) {
    return values.firstWhere(
      (ApplicationUpdatePhase phase) => phase.name == value,
      orElse: () => ApplicationUpdatePhase.failed,
    );
  }
}

/// A small polling contract keeps the dedicated settings window independent
/// from the primary Flutter engine that owns each platform updater.
abstract interface class ApplicationUpdater {
  Future<bool> isSupported();

  Future<ApplicationUpdateStatus> readStatus();

  /// Starts a user-approved, one-click update and returns immediately.
  Future<void> installLatest();
}

/// Immutable updater state rendered by the version settings section.
final class ApplicationUpdateStatus {
  const ApplicationUpdateStatus({
    this.phase = ApplicationUpdatePhase.idle,
    this.progress,
    this.targetVersion,
    this.message,
  });

  factory ApplicationUpdateStatus.fromJson(Map<Object?, Object?> json) {
    final Object? rawProgress = json['progress'];
    return ApplicationUpdateStatus(
      phase: ApplicationUpdatePhase.parse(json['phase']),
      progress: rawProgress is num ? rawProgress.toDouble().clamp(0, 1) : null,
      targetVersion: _trimmed(json['targetVersion']),
      message: _trimmed(json['message']),
    );
  }

  final ApplicationUpdatePhase phase;
  final double? progress;
  final String? targetVersion;
  final String? message;

  bool get isBusy => switch (phase) {
    ApplicationUpdatePhase.checking ||
    ApplicationUpdatePhase.downloading ||
    ApplicationUpdatePhase.extracting ||
    ApplicationUpdatePhase.installing => true,
    _ => false,
  };

  Map<String, Object?> toJson() => <String, Object?>{
    'phase': phase.name,
    if (progress case final double value) 'progress': value,
    if (targetVersion case final String value) 'targetVersion': value,
    if (message case final String value) 'message': value,
  };

  @override
  bool operator ==(Object other) {
    return other is ApplicationUpdateStatus &&
        other.phase == phase &&
        other.progress == progress &&
        other.targetVersion == targetVersion &&
        other.message == message;
  }

  @override
  int get hashCode => Object.hash(phase, progress, targetVersion, message);
}

String? _trimmed(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    return null;
  }
  return value.trim();
}
