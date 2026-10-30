import 'dart:async';
import 'dart:convert';

import 'package:dingdong/features/screenshot/data/screenshot_plugin_service.dart';
import 'package:dingdong/features/screenshot/domain/screenshot_plugin.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryPreferencesBackend preferences;
  late _Gateway gateway;
  late ScreenshotPluginService service;
  setUp(() {
    preferences = MemoryPreferencesBackend();
    gateway = _Gateway();
    service = ScreenshotPluginService(preferences, gateway);
  });

  test('disabled defaults do not claim a registered shortcut', () async {
    await service.load();
    final status = await service.manage('status', {});
    expect(status['enabled'], false);
    expect(status['running'], false);
    expect(
      service.configuration.shortcut,
      ScreenshotConfiguration.defaultShortcut,
    );
  });

  test(
    'retired backend does not survive restart but its shortcut does',
    () async {
      await service.load();
      final shortcut = const GlobalHotKey(key: 'B', alt: true);
      await service.manage('configure', {
        'enabled': true,
        'backend': 'system',
        'shortcut': shortcut.toPlatformArguments(),
      });
      final restarted = ScreenshotPluginService(preferences, _Gateway());
      await restarted.load();
      final status = await restarted.manage('status', {});
      expect(status.containsKey('backend'), isFalse);
      expect(restarted.configuration.shortcut, shortcut);
      expect(status['running'], isTrue);
    },
  );

  test(
    'a failed shortcut write restores the previous native shortcut',
    () async {
      final failing = _FailingPreferences();
      final local = ScreenshotPluginService(failing, gateway);
      await local.load();
      await local.manage('configure', {'enabled': true});
      failing.fail = true;
      await expectLater(
        local.manage('configure', {
          'shortcut': const GlobalHotKey(
            key: 'B',
            alt: true,
          ).toPlatformArguments(),
        }),
        throwsA(isA<ScreenshotPluginException>()),
      );
      expect(gateway.current.shortcut, ScreenshotConfiguration.defaultShortcut);
      expect(
        local.configuration.shortcut,
        ScreenshotConfiguration.defaultShortcut,
      );
    },
  );

  test(
    'enabled configuration survives restart through one preference',
    () async {
      await service.load();
      await service.manage('configure', {'enabled': true});
      final restarted = ScreenshotPluginService(preferences, _Gateway());
      await restarted.load();
      expect(restarted.configuration.enabled, true);
      expect((await restarted.manage('status', {}))['running'], true);
      expect(preferences.values.keys, [ScreenshotPluginService.preferenceKey]);
    },
  );

  test(
    'registration failure preserves preference and native shortcut',
    () async {
      await service.load();
      await service.manage('configure', {'enabled': true});
      final before = preferences.values[ScreenshotPluginService.preferenceKey];
      gateway.failApply = true;
      await expectLater(
        service.manage('configure', {
          'shortcut': const GlobalHotKey(
            key: 'S',
            alt: true,
          ).toPlatformArguments(),
        }),
        throwsA(isA<ScreenshotPluginException>()),
      );
      expect(preferences.values[ScreenshotPluginService.preferenceKey], before);
      expect(
        service.configuration.shortcut,
        ScreenshotConfiguration.defaultShortcut,
      );
    },
  );

  test('persistence failure rolls back native registration', () async {
    final failing = _FailingPreferences();
    final local = ScreenshotPluginService(failing, gateway);
    await local.load();
    failing.fail = true;
    await expectLater(
      local.manage('configure', {'enabled': true}),
      throwsA(isA<ScreenshotPluginException>()),
    );
    expect(gateway.current.enabled, false);
    expect(local.configuration.enabled, false);
  });

  test('existing app shortcut is rejected even before registration', () async {
    final local = ScreenshotPluginService(
      preferences,
      gateway,
      conflictsWithShortcut: (_) async => true,
    );
    await local.load();
    await expectLater(
      local.manage('configure', {'enabled': true}),
      throwsA(
        isA<ScreenshotPluginException>().having(
          (e) => e.code,
          'code',
          'shortcut_conflict',
        ),
      ),
    );
    expect(local.configuration.enabled, false);
  });

  test('capture requires enablement and surfaces native failure', () async {
    await service.load();
    await expectLater(
      service.manage('capture', {}),
      throwsA(isA<ScreenshotPluginException>()),
    );
    await service.manage('configure', {'enabled': true});
    gateway.failCapture = true;
    await expectLater(
      service.manage('capture', {}),
      throwsA(isA<ScreenshotPluginException>()),
    );
  });

  test('mutations serialize and retain the latest queued intent', () async {
    await service.load();
    final wait = Completer<void>();
    gateway.pause = wait.future;
    final enable = service.manage('configure', {'enabled': true});
    final disable = service.manage('configure', {'enabled': false});
    wait.complete();
    await Future.wait([enable, disable]);
    expect(service.configuration.enabled, false);
    expect(
      (jsonDecode(
            preferences.values[ScreenshotPluginService.preferenceKey]!
                as String,
          )
          as Map<String, Object?>)['enabled'],
      false,
    );
  });

  test('missing native host never reports the feature as running', () async {
    gateway.failStatus = true;
    await service.load();
    expect((await service.manage('status', {}))['running'], false);
    expect((await service.manage('status', {}))['error'], 'unavailable');
  });

  test('invalid persisted shortcut falls back without enabling capture', () {
    expect(
      ScreenshotConfiguration.parse(
        '{"enabled":true,"shortcut":{"key":"BAD"}}',
      ).enabled,
      false,
    );
  });

  test(
    'disabling succeeds after another setting claims the shortcut',
    () async {
      var conflicts = false;
      final local = ScreenshotPluginService(
        preferences,
        gateway,
        conflictsWithShortcut: (_) async => conflicts,
      );
      await local.load();
      await local.manage('configure', {'enabled': true});
      conflicts = true;
      await local.manage('configure', {'enabled': false});
      expect(gateway.current.enabled, false);
      expect(local.configuration.enabled, false);
    },
  );

  test(
    'rollback mismatch remains visible through repeated status refreshes',
    () async {
      final failing = _FailingPreferences();
      final local = ScreenshotPluginService(failing, gateway);
      await local.load();
      await local.manage('configure', {'enabled': true});
      failing.fail = true;
      gateway.rejectShortcut = ScreenshotConfiguration.defaultShortcut;
      await expectLater(
        local.manage('configure', {
          'shortcut': const GlobalHotKey(
            key: 'B',
            alt: true,
          ).toPlatformArguments(),
        }),
        throwsA(
          isA<ScreenshotPluginException>().having(
            (e) => e.code,
            'code',
            'rollback_failed',
          ),
        ),
      );
      for (var i = 0; i < 2; i++) {
        final status = await local.manage('status', {});
        expect(status['error'], 'rollback_failed');
        expect(status['running'], false);
      }
      gateway.failStatus = true;
      expect((await local.manage('status', {}))['error'], 'rollback_failed');
      gateway.failStatus = false;
      expect((await local.manage('status', {}))['running'], false);
      expect((await local.manage('status', {}))['error'], 'rollback_failed');
      failing.fail = false;
      await local.manage('configure', {'enabled': false});
      expect((await local.manage('status', {}))['error'], null);
    },
  );
}

class _FailingPreferences implements PreferencesBackend {
  final backend = MemoryPreferencesBackend();
  bool fail = false;
  @override
  Future<void> write(String key, Object value) async {
    if (fail) throw StateError('disk full');
    await backend.write(key, value);
  }

  @override
  Future<Object?> read(String key) => backend.read(key);
  @override
  Future<void> remove(String key) => backend.remove(key);
}

class _Gateway implements ScreenshotPluginGateway {
  ScreenshotConfiguration current = const ScreenshotConfiguration();
  bool failApply = false;
  bool failCapture = false;
  bool failStatus = false;
  GlobalHotKey? rejectShortcut;
  Future<void>? pause;
  @override
  Future<ScreenshotRuntimeStatus> apply(ScreenshotConfiguration value) async {
    await pause;
    if (failApply) throw const ScreenshotPluginException('shortcut_conflict');
    if (value.enabled && value.shortcut == rejectShortcut) {
      throw const ScreenshotPluginException('shortcut_conflict');
    }
    current = value;
    return status();
  }

  @override
  Future<ScreenshotRuntimeStatus> status() async {
    if (failStatus) throw const ScreenshotPluginException('unavailable');
    return ScreenshotRuntimeStatus(
      supported: true,
      running: current.enabled,
      capturing: false,
    );
  }

  @override
  Future<void> capture() async {
    if (failCapture) throw const ScreenshotPluginException('capture_failed');
  }
}
