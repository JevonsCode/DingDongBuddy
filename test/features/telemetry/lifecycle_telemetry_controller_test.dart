import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/telemetry/data/lifecycle_telemetry_controller.dart';
import 'package:dingdong/features/telemetry/domain/lifecycle_telemetry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('disabled telemetry creates no identifier or request', () async {
    final MemoryPreferencesBackend preferences = MemoryPreferencesBackend();
    final _RecordingGateway gateway = _RecordingGateway();
    final LifecycleTelemetryController controller = _controller(
      preferences: preferences,
      gateway: gateway,
      hadExistingApplicationData: false,
    );

    await controller.setEnabled(false);

    expect(gateway.attempts, isEmpty);
    expect(preferences.values, isEmpty);
  });

  test('a fresh installation emits one install event when enabled', () async {
    final MemoryPreferencesBackend preferences = MemoryPreferencesBackend();
    final _RecordingGateway gateway = _RecordingGateway();
    final LifecycleTelemetryController controller = _controller(
      preferences: preferences,
      gateway: gateway,
      hadExistingApplicationData: false,
    );

    await Future.wait(<Future<void>>[
      controller.setEnabled(true),
      controller.setEnabled(true),
    ]);
    await controller.setEnabled(true);

    expect(gateway.attempts, hasLength(1));
    final LifecycleTelemetryEvent event = gateway.attempts.single;
    expect(event.kind, LifecycleTelemetryEventKind.install);
    expect(event.installationId, _installationId);
    expect(event.eventId, _eventId);
    expect(event.currentVersion, '1.3.0');
    expect(event.currentBuild, '42');
    expect(event.previousVersion, isNull);
    expect(event.previousBuild, isNull);
    expect(event.platform, 'macos');
    expect(event.architecture, 'arm64');
    expect(event.occurredAt, DateTime.utc(2026, 8, 9, 3, 4, 5));
    expect(
      preferences.values['dingdong.telemetry.installationId'],
      _installationId,
    );
    expect(preferences.values['dingdong.telemetry.lastVersion'], '1.3.0');
    expect(preferences.values['dingdong.telemetry.lastBuild'], '42');
    expect(
      preferences.values.containsKey(
        'dingdong.telemetry.pendingLifecycleEvent',
      ),
      isFalse,
    );
  });

  test(
    'an existing pre-telemetry installation is not counted as new',
    () async {
      final _RecordingGateway gateway = _RecordingGateway();
      final LifecycleTelemetryController controller = _controller(
        preferences: MemoryPreferencesBackend(),
        gateway: gateway,
        hadExistingApplicationData: true,
      );

      await controller.setEnabled(true);

      expect(gateway.attempts.single.kind, LifecycleTelemetryEventKind.upgrade);
      expect(gateway.attempts.single.previousVersion, isNull);
    },
  );

  test(
    'a version transition emits an upgrade with its previous version',
    () async {
      final MemoryPreferencesBackend preferences =
          MemoryPreferencesBackend(<String, Object>{
            'dingdong.telemetry.installationId': _installationId,
            'dingdong.telemetry.lastVersion': '1.2.0',
            'dingdong.telemetry.lastBuild': '37',
          });
      final _RecordingGateway gateway = _RecordingGateway();
      final LifecycleTelemetryController controller = _controller(
        preferences: preferences,
        gateway: gateway,
        hadExistingApplicationData: true,
        ids: <String>[_eventId],
      );

      await controller.setEnabled(true);

      final LifecycleTelemetryEvent event = gateway.attempts.single;
      expect(event.kind, LifecycleTelemetryEventKind.upgrade);
      expect(event.installationId, _installationId);
      expect(event.previousVersion, '1.2.0');
      expect(event.previousBuild, '37');
    },
  );

  test(
    'a failed request remains idempotently pending for the next launch',
    () async {
      final MemoryPreferencesBackend preferences = MemoryPreferencesBackend();
      final _RecordingGateway failingGateway = _RecordingGateway(failures: 1);
      final LifecycleTelemetryController firstLaunch = _controller(
        preferences: preferences,
        gateway: failingGateway,
        hadExistingApplicationData: false,
      );

      await firstLaunch.setEnabled(true);

      expect(failingGateway.attempts, hasLength(1));
      expect(
        preferences.values['dingdong.telemetry.pendingLifecycleEvent'],
        isA<String>(),
      );
      expect(
        preferences.values.containsKey('dingdong.telemetry.lastVersion'),
        isFalse,
      );

      final _RecordingGateway retryGateway = _RecordingGateway();
      final LifecycleTelemetryController nextLaunch = _controller(
        preferences: preferences,
        gateway: retryGateway,
        hadExistingApplicationData: true,
        ids: const <String>[],
      );
      await nextLaunch.setEnabled(true);

      expect(retryGateway.attempts, hasLength(1));
      expect(
        retryGateway.attempts.single.eventId,
        failingGateway.attempts.single.eventId,
      );
      expect(
        retryGateway.attempts.single.installationId,
        failingGateway.attempts.single.installationId,
      );
      expect(
        preferences.values.containsKey(
          'dingdong.telemetry.pendingLifecycleEvent',
        ),
        isFalse,
      );
    },
  );

  test('opting out discards an unsent lifecycle event', () async {
    final MemoryPreferencesBackend preferences = MemoryPreferencesBackend();
    final _RecordingGateway gateway = _RecordingGateway(failures: 1);
    final LifecycleTelemetryController controller = _controller(
      preferences: preferences,
      gateway: gateway,
      hadExistingApplicationData: false,
    );

    await controller.setEnabled(true);
    await controller.setEnabled(false);

    expect(gateway.attempts, hasLength(1));
    expect(
      preferences.values.containsKey(
        'dingdong.telemetry.pendingLifecycleEvent',
      ),
      isFalse,
    );
  });

  test('development builds never create state or send requests', () async {
    final MemoryPreferencesBackend preferences = MemoryPreferencesBackend();
    final _RecordingGateway gateway = _RecordingGateway();
    final LifecycleTelemetryController controller = _controller(
      preferences: preferences,
      gateway: gateway,
      hadExistingApplicationData: false,
      disabled: true,
    );

    await controller.setEnabled(true);

    expect(preferences.values, isEmpty);
    expect(gateway.attempts, isEmpty);
  });
}

LifecycleTelemetryController _controller({
  required MemoryPreferencesBackend preferences,
  required _RecordingGateway gateway,
  required bool hadExistingApplicationData,
  List<String> ids = const <String>[_installationId, _eventId],
  bool disabled = false,
}) {
  int nextId = 0;
  return LifecycleTelemetryController(
    preferences: preferences,
    gateway: gateway,
    currentVersion: '1.3.0',
    currentBuild: '42',
    platform: 'macos',
    architecture: 'arm64',
    hadExistingApplicationData: hadExistingApplicationData,
    now: () => DateTime.utc(2026, 8, 9, 3, 4, 5),
    createId: () => ids[nextId++],
    disabled: disabled,
  );
}

final class _RecordingGateway implements LifecycleTelemetryGateway {
  _RecordingGateway({this.failures = 0});

  int failures;
  final List<LifecycleTelemetryEvent> attempts = <LifecycleTelemetryEvent>[];

  @override
  Future<void> send(LifecycleTelemetryEvent event) async {
    attempts.add(event);
    if (failures > 0) {
      failures -= 1;
      throw StateError('offline');
    }
  }
}

const String _installationId = '11111111-1111-4111-8111-111111111111';
const String _eventId = '22222222-2222-4222-8222-222222222222';
