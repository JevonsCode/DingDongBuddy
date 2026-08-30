import 'dart:async';

import 'package:dingdong/features/selection/domain/selection_plugin_gateway.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'window reload observes the host without replaying old enablement',
    () async {
      final MemoryPreferencesBackend backend = MemoryPreferencesBackend(
        <String, Object>{'dingdong.selection.enabled': true},
      );
      final _SelectionGateway gateway = _SelectionGateway();
      final SettingsViewModel primary = SettingsViewModel(
        SettingsRepository(backend),
        selectionPluginGateway: gateway,
      );
      addTearDown(primary.dispose);
      await primary.load();
      expect(gateway.configurations.single.enabled, isTrue);

      // The live host has stopped, while persisted preferences are still stale.
      await gateway.apply(const SelectionPluginConfiguration());
      await primary.reload();
      final SettingsViewModel secondary = SettingsViewModel(
        SettingsRepository(backend),
        selectionPluginGateway: gateway,
        restoreSelectionPluginOnLoad: false,
      );
      addTearDown(secondary.dispose);
      await secondary.load();

      expect(gateway.configurations, hasLength(2));
      expect(gateway.configurations.last.enabled, isFalse);
      expect(primary.settings.selectionPlugin.enabled, isFalse);
      expect(secondary.settings.selectionPlugin.enabled, isFalse);
    },
  );

  test('host synchronization happens only after a successful save', () async {
    final List<String> events = <String>[];
    final _RecordingPreferencesBackend backend = _RecordingPreferencesBackend(
      events,
    );
    final _SelectionGateway gateway = _SelectionGateway(events: events);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
      selectionPluginGateway: gateway,
      onSettingsSaved: () async {
        events.add('sync:${backend.values['dingdong.selection.enabled']}');
      },
    );
    addTearDown(model.dispose);
    await model.load();
    expect(events.where((String event) => event.startsWith('sync:')), isEmpty);
    events.clear();
    await model.setSelectionPluginEnabled(false);
    expect(events, <String>['native:false', 'persist:false', 'sync:false']);

    events.clear();
    backend.failWrites = true;
    await model.setSelectionPluginEnabled(true);
    expect(events, <String>['native:true']);
    expect(
      model.selectionPluginConfigurationError,
      SelectionPluginError.persistenceFailed,
    );
  });

  test('a native selection change still saves after disposal', () async {
    final List<String> events = <String>[];
    final _RecordingPreferencesBackend backend = _RecordingPreferencesBackend(
      events,
    );
    final _SelectionGateway gateway = _SelectionGateway(events: events);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
      selectionPluginGateway: gateway,
      onSettingsSaved: () async {
        events.add('sync:${backend.values['dingdong.selection.enabled']}');
      },
    );
    await model.load();
    events.clear();

    final Completer<void> applyStarted = Completer<void>();
    final Completer<void> releaseApply = Completer<void>();
    gateway.beforeApply = (_) {
      if (!applyStarted.isCompleted) {
        applyStarted.complete();
      }
      return releaseApply.future;
    };
    var notifications = 0;
    model.addListener(() => notifications += 1);
    final Future<void> operation = model.setSelectionPluginEnabled(false);

    await applyStarted.future;
    model.dispose();
    releaseApply.complete();
    await operation;

    expect(backend.values['dingdong.selection.enabled'], isFalse);
    expect(events, <String>['native:false', 'persist:false', 'sync:false']);
    expect(notifications, 0);
  });

  test('a missing host never claims that a token was saved', () async {
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
    );
    await model.load();

    await model.saveSelectionPluginToken('fixture-only');

    expect(model.isSelectionPluginTokenConfigured, isFalse);
    expect(
      model.selectionPluginConfigurationError,
      SelectionPluginError.tokenSaveFailed,
    );
  });

  test('queued enablement keeps the newly selected provider', () async {
    final Completer<void> release = Completer<void>();
    final _SelectionGateway gateway = _SelectionGateway();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      selectionPluginGateway: gateway,
    );
    await model.load();
    gateway.beforeApply = (_) => release.future;

    final Future<void> configure = model.setSelectionPluginConfiguration(
      model.settings.selectionPlugin.withProvider(
        SelectionModelProvider.gemini,
      ),
    );
    final Future<void> enable = model.setSelectionPluginEnabled(true);
    await Future<void>.delayed(Duration.zero);
    expect(gateway.configurations, hasLength(2));
    release.complete();
    await Future.wait(<Future<void>>[configure, enable]);

    expect(
      model.settings.selectionPlugin.provider,
      SelectionModelProvider.gemini,
    );
    expect(model.settings.selectionPlugin.enabled, isTrue);
    expect(gateway.configurations.last.provider, SelectionModelProvider.gemini);
    expect(gateway.configurations.last.enabled, isTrue);
  });

  test(
    'token save uses its applied endpoint before a queued provider change',
    () async {
      final Completer<void> release = Completer<void>();
      final _SelectionGateway gateway = _SelectionGateway();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(MemoryPreferencesBackend()),
        selectionPluginGateway: gateway,
      );
      await model.load();
      gateway.beforeApply = (_) => release.future;
      final SelectionPluginConfiguration first = model.settings.selectionPlugin
          .withProvider(SelectionModelProvider.openRouter)
          .copyWith(endpoint: 'https://first.invalid/v1');

      final Future<void> save = model.saveSelectionPluginToken(
        'fixture-only',
        configuration: first,
      );
      final Future<void> switchProvider = model.setSelectionPluginConfiguration(
        first.copyWith(endpoint: 'https://second.invalid/v1'),
      );
      await Future<void>.delayed(Duration.zero);
      release.complete();
      await Future.wait(<Future<void>>[save, switchProvider]);

      expect(gateway.savedTokenEndpoint, first.endpoint);
      expect(
        model.settings.selectionPlugin.endpoint,
        'https://second.invalid/v1',
      );
    },
  );

  test(
    'failed persistence leaves a disabled native plugin visibly disabled',
    () async {
      final _RecordingPreferencesBackend backend = _RecordingPreferencesBackend(
        <String>[],
      );
      final _SelectionGateway gateway = _SelectionGateway();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(backend),
        selectionPluginGateway: gateway,
      );
      await model.load();
      backend.failWrites = true;

      await model.setSelectionPluginEnabled(false);

      expect(gateway.configurations.last.enabled, isFalse);
      expect(model.settings.selectionPlugin.enabled, isFalse);
      expect(model.isSelectionPluginRunning, isFalse);
      expect(
        model.selectionPluginConfigurationError,
        SelectionPluginError.persistenceFailed,
      );
    },
  );

  test('saved enablement controls the native lifecycle on load', () async {
    final _SelectionGateway gateway = _SelectionGateway();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(
        MemoryPreferencesBackend(<String, Object>{
          'dingdong.selection.enabled': true,
        }),
      ),
      selectionPluginGateway: gateway,
    );

    await model.load();

    expect(model.settings.selectionPlugin.enabled, isTrue);
    expect(gateway.configurations.single.enabled, isTrue);
    expect(model.isSelectionPluginRunning, isTrue);
  });

  test('disabling stops native work before the setting is persisted', () async {
    final List<String> events = <String>[];
    final _SelectionGateway gateway = _SelectionGateway(events: events);
    final _RecordingPreferencesBackend backend = _RecordingPreferencesBackend(
      events,
    );
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
      selectionPluginGateway: gateway,
    );
    await model.load();
    events.clear();

    await model.setSelectionPluginEnabled(false);

    expect(events.first, 'native:false');
    expect(events, contains('persist:false'));
    expect(model.isSelectionPluginRunning, isFalse);
  });

  test(
    'token is delegated to secure native storage and never preferences',
    () async {
      final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
      final _SelectionGateway gateway = _SelectionGateway();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(backend),
        selectionPluginGateway: gateway,
      );
      await model.load();

      await model.saveSelectionPluginToken('  secret-token  ');

      expect(gateway.savedToken, 'secret-token');
      expect(model.isSelectionPluginTokenConfigured, isTrue);
      expect(
        backend.values.keys.where((String key) => key.contains('token')),
        isEmpty,
      );
    },
  );

  test('invalid model configuration is not sent to the native host', () async {
    final _SelectionGateway gateway = _SelectionGateway();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      selectionPluginGateway: gateway,
    );
    await model.load();
    final int initialCalls = gateway.configurations.length;

    await model.setSelectionPluginConfiguration(
      model.settings.selectionPlugin.copyWith(
        endpoint: 'https://remote.invalid',
      ),
    );

    expect(gateway.configurations, hasLength(initialCalls));
    expect(model.selectionPluginConfigurationError, isNotNull);
  });
}

final class _SelectionGateway implements SelectionPluginGateway {
  _SelectionGateway({this.events});

  final List<String>? events;
  final List<SelectionPluginConfiguration> configurations =
      <SelectionPluginConfiguration>[];
  String? savedToken;
  String? savedTokenEndpoint;
  Future<void> Function(SelectionPluginConfiguration)? beforeApply;

  @override
  Future<SelectionPluginRuntimeStatus> apply(
    SelectionPluginConfiguration configuration,
  ) async {
    configurations.add(configuration);
    await beforeApply?.call(configuration);
    events?.add('native:${configuration.enabled}');
    return SelectionPluginRuntimeStatus(
      enabled: configuration.enabled,
      running: configuration.enabled,
      permissionGranted: true,
      tokenConfigured: savedToken != null,
    );
  }

  @override
  Future<void> clearToken() async {
    savedToken = null;
  }

  @override
  Future<void> openAccessibilitySettings() async {}

  @override
  Future<void> saveToken(String token) async {
    savedToken = token;
    savedTokenEndpoint = configurations.last.endpoint;
  }

  @override
  Future<SelectionPluginRuntimeStatus> status() async {
    final bool enabled = configurations.lastOrNull?.enabled ?? false;
    return SelectionPluginRuntimeStatus(
      enabled: enabled,
      running: enabled,
      permissionGranted: true,
      tokenConfigured: savedToken != null,
    );
  }
}

final class _RecordingPreferencesBackend implements PreferencesBackend {
  _RecordingPreferencesBackend(this.events)
    : values = <String, Object>{'dingdong.selection.enabled': true};

  final List<String> events;
  final Map<String, Object> values;
  bool failWrites = false;

  @override
  Future<Object?> read(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> write(String key, Object value) async {
    if (failWrites) throw StateError('Simulated storage failure');
    if (key == 'dingdong.selection.enabled') {
      events.add('persist:$value');
    }
    values[key] = value;
  }
}
