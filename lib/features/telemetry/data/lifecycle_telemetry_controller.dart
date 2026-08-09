// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:math';

import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/telemetry/domain/lifecycle_telemetry.dart';

/// Emits at most one event for a successful install or version transition.
///
/// There are no sessions, heartbeats, feature events, or background timers.
final class LifecycleTelemetryController {
  LifecycleTelemetryController({
    required PreferencesBackend preferences,
    required LifecycleTelemetryGateway gateway,
    required this.currentVersion,
    required this.currentBuild,
    required this.platform,
    required this.architecture,
    required this.hadExistingApplicationData,
    DateTime Function()? now,
    String Function()? createId,
    this.disabled = false,
  }) : _preferences = preferences,
       _gateway = gateway,
       _now = now ?? DateTime.now,
       _createId = createId ?? _createUuidV4;

  final PreferencesBackend _preferences;
  final LifecycleTelemetryGateway _gateway;
  final String currentVersion;
  final String currentBuild;
  final String platform;
  final String architecture;
  final bool hadExistingApplicationData;
  final bool disabled;
  final DateTime Function() _now;
  final String Function() _createId;

  LifecycleTelemetryConsent _consent = LifecycleTelemetryConsent.undecided;
  Future<void>? _processing;

  Future<void> applyConsent(LifecycleTelemetryConsent value) {
    _consent = value;
    if (disabled || value == LifecycleTelemetryConsent.undecided) {
      return Future<void>.value();
    }
    if (value == LifecycleTelemetryConsent.disabled) {
      return _discardPendingAfterCurrentAttempt();
    }
    final Future<void>? existing = _processing;
    if (existing != null) return existing;
    final Future<void> processing = _process();
    _processing = processing;
    return processing.whenComplete(() {
      if (identical(_processing, processing)) {
        _processing = null;
      }
    });
  }

  Future<void> _discardPendingAfterCurrentAttempt() async {
    final Future<void>? processing = _processing;
    if (processing != null) await processing;
    await _preferences.remove(_pendingEventKey);
  }

  Future<void> _process() async {
    while (_consent == LifecycleTelemetryConsent.enabled) {
      final LifecycleTelemetryEvent? pending = await _loadPendingEvent();
      final LifecycleTelemetryEvent? event =
          pending ?? await _createCurrentEvent();
      if (event == null) return;
      if (!await _trySend(event)) return;
      await _markDelivered(event);
    }
  }

  Future<LifecycleTelemetryEvent?> _loadPendingEvent() async {
    final Object? stored = await _preferences.read(_pendingEventKey);
    if (stored is! String || stored.isEmpty) return null;
    try {
      final LifecycleTelemetryEvent? event = LifecycleTelemetryEvent.fromJson(
        jsonDecode(stored),
      );
      if (event != null) return event;
    } on Object {
      // Invalid local state is discarded without affecting application launch.
    }
    await _preferences.remove(_pendingEventKey);
    return null;
  }

  Future<LifecycleTelemetryEvent?> _createCurrentEvent() async {
    final String? previousVersion = _stringValue(
      await _preferences.read(_lastVersionKey),
    );
    final String? previousBuild = _stringValue(
      await _preferences.read(_lastBuildKey),
    );
    if (previousVersion == currentVersion &&
        (previousBuild == null || previousBuild == currentBuild)) {
      return null;
    }
    final String installationId = await _installationId();
    final LifecycleTelemetryEvent event = LifecycleTelemetryEvent(
      eventId: _createId(),
      installationId: installationId,
      kind: previousVersion == null && !hadExistingApplicationData
          ? LifecycleTelemetryEventKind.install
          : LifecycleTelemetryEventKind.upgrade,
      currentVersion: currentVersion,
      currentBuild: currentBuild,
      previousVersion: previousVersion,
      previousBuild: previousBuild,
      platform: platform,
      architecture: architecture,
      occurredAt: _now().toUtc(),
    );
    await _preferences.write(_pendingEventKey, jsonEncode(event.toJson()));
    return event;
  }

  Future<String> _installationId() async {
    final String? existing = _stringValue(
      await _preferences.read(_installationIdKey),
    );
    if (existing != null) return existing;
    final String created = _createId();
    await _preferences.write(_installationIdKey, created);
    return created;
  }

  Future<bool> _trySend(LifecycleTelemetryEvent event) async {
    if (_consent != LifecycleTelemetryConsent.enabled) return false;
    try {
      await _gateway.send(event);
      return true;
    } on Object {
      return false;
    }
  }

  Future<void> _markDelivered(LifecycleTelemetryEvent event) async {
    await _preferences.write(_lastVersionKey, event.currentVersion);
    await _preferences.write(_lastBuildKey, event.currentBuild);
    await _preferences.remove(_pendingEventKey);
  }
}

String? _stringValue(Object? value) {
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

String _createUuidV4() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final String hex = bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

const String _installationIdKey = 'dingdong.telemetry.installationId';
const String _lastVersionKey = 'dingdong.telemetry.lastVersion';
const String _lastBuildKey = 'dingdong.telemetry.lastBuild';
const String _pendingEventKey = 'dingdong.telemetry.pendingLifecycleEvent';
