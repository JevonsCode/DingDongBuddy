import 'package:dingdong/features/clipboard/domain/clipboard_monitor_service.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/launch_at_startup.dart';
import 'package:dingdong/features/settings/domain/quick_paste_permission.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:dingdong/features/settings/domain/system_usage.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'load starts clipboard monitoring only when the saved setting enables it',
    () async {
      final _FakeClipboardMonitoring monitoring = _FakeClipboardMonitoring();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(
          MemoryPreferencesBackend(<String, Object>{
            'dingdong.clipboard.monitoring': true,
          }),
        ),
        clipboardMonitoring: monitoring,
      );

      await model.load();

      expect(model.settings.clipboardMonitoring, isTrue);
      expect(monitoring.startCount, 1);
    },
  );

  test('updates persist immediately and control the native monitor', () async {
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
    final _FakeClipboardMonitoring monitoring = _FakeClipboardMonitoring();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
      clipboardMonitoring: monitoring,
    );
    await model.load();

    await model.setClipboardMonitoring(true);
    await model.setThemeMode(AppThemePreference.dark);
    await model.setRetention(maxItems: 2500, maxAgeDays: 45);

    expect(monitoring.startCount, 1);
    expect(backend.values['dingdong.clipboard.monitoring'], isTrue);
    expect(backend.values['dingdong.panel.themeMode'], 'dark');
    expect(backend.values['dingdong.clipboard.maxItems'], 2500);
    expect(backend.values['dingdong.clipboard.maxAgeDays'], 45);
  });

  test(
    'reload applies settings saved by the dedicated settings window',
    () async {
      final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(backend),
      );
      await model.load();
      expect(model.settings.themeMode, AppThemePreference.light);

      backend.values['dingdong.panel.themeMode'] = 'dark';
      await model.reload();

      expect(model.settings.themeMode, AppThemePreference.dark);
    },
  );

  test('loads and updates native launch-at-startup state', () async {
    final _FakeLaunchAtStartup launchAtStartup = _FakeLaunchAtStartup(true);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      launchAtStartup: launchAtStartup,
    );

    await model.load();
    await model.setLaunchAtStartup(false);

    expect(model.settings.launchAtStartup, isFalse);
    expect(launchAtStartup.setValues, <bool>[false]);
  });

  test(
    'applies saved and updated window opacity through the desktop seam',
    () async {
      final List<double> values = <double>[];
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(
          MemoryPreferencesBackend(<String, Object>{
            'dingdong.panel.backgroundOpacity': 0.86,
          }),
        ),
        onWindowOpacityChanged: (double value) async => values.add(value),
      );

      await model.load();
      await model.setBackgroundOpacity(0.92);

      expect(values, <double>[0.86, 0.92]);
    },
  );

  test('custom notification sound can be selected and cleared', () async {
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
    );
    await model.load();

    await model.setCustomSoundPath('/tmp/ding.wav');
    expect(model.settings.selectedSound, 'custom');
    expect(backend.values['dingdong.customSoundPath'], '/tmp/ding.wav');

    await model.setCustomSoundPath(null);
    expect(model.settings.selectedSound, 'default');
    expect(backend.values, isNot(contains('dingdong.customSoundPath')));
  });

  test(
    'API port requires restart only while it differs from the loaded port',
    () async {
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(
          MemoryPreferencesBackend(<String, Object>{'dingdong.api.port': 2333}),
        ),
      );

      await model.load();
      expect(model.requiresRestart, isFalse);

      await model.setApiPort(2444);
      expect(model.requiresRestart, isTrue);

      await model.setApiPort(2333);
      expect(model.requiresRestart, isFalse);
    },
  );

  test('release check exposes a newer version and its release links', () async {
    final _FakeReleaseMetadataSource source = _FakeReleaseMetadataSource(
      ReleaseMetadata(
        app: 'DingDong',
        latestVersion: '0.8.0',
        latestBuild: '8',
        website: Uri.parse('https://example.com/dingdong'),
        releasePage: Uri.parse('https://example.com/dingdong/releases/0.8.0'),
        notes: const <String>['Faster history search'],
      ),
    );
    final _FakeExternalLinkGateway links = _FakeExternalLinkGateway();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      releaseMetadataSource: source,
      externalLinkGateway: links,
    );

    await model.checkForUpdates();
    await model.openReleasePage();
    await model.reportProblem();
    await model.requestFeature();

    expect(model.releaseStatus.latestVersion, '0.8.0');
    expect(model.releaseStatus.isUpdateAvailable, isTrue);
    expect(model.releaseStatus.notes, <String>['Faster history search']);
    expect(links.opened, <Uri>[
      Uri.parse('https://example.com/dingdong/releases/0.8.0'),
      defaultBugReportUri,
      defaultFeatureRequestUri,
    ]);
  });

  test('quick paste permission can be inspected and opened', () async {
    final _FakeQuickPastePermission permission = _FakeQuickPastePermission();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      quickPastePermissionGateway: permission,
    );

    await model.load();
    expect(model.isQuickPastePermissionGranted, isFalse);

    permission.granted = true;
    await model.openQuickPastePermissionSettings();
    await model.refreshQuickPastePermission();

    expect(permission.openCount, 1);
    expect(model.isQuickPastePermissionGranted, isTrue);
  });

  test(
    'MCP setup prompt always uses the built-in platform-specific instructions',
    () async {
      final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(backend),
        mcpCommandPath: r'C:\Program Files\DingDong\dingdong-mcp.exe',
      );
      await model.load();

      expect(
        model.mcpSetupPrompt,
        contains(r'C:\Program Files\DingDong\dingdong-mcp.exe'),
      );
      expect(
        model.mcpSetupPrompt,
        contains('global STDIO MCP server named dingdong'),
      );
      expect(
        model.mcpSetupPrompt,
        startsWith('Connect DingDong to the current agent or IDE'),
      );
      expect(model.mcpSetupPrompt, isNot(contains('Do not explain DingDong')));
      expect(model.mcpSetupPrompt, contains('Preserve every unrelated'));
      expect(model.mcpSetupPrompt, contains('Reload or restart'));
      expect(model.mcpSetupPrompt, contains('dingdong_notify'));
      expect(model.mcpSetupPrompt, contains('--notify-stop'));
      expect(model.mcpSetupPrompt, contains('Stop command hook'));
      expect(model.mcpSetupPrompt, contains('review and trust'));
      expect(model.mcpSetupPrompt, contains('task-completion alerts'));
      expect(model.mcpSetupPrompt, isNot(contains('clipboard content')));

      expect(
        backend.values,
        isNot(contains('dingdong.mcpSetupPromptOverride')),
      );
    },
  );

  test(
    'Chinese MCP setup prompt asks for an immediate DingDong test',
    () async {
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(
          MemoryPreferencesBackend(<String, Object>{'dingdong.language': 'zh'}),
        ),
        mcpCommandPath: '/Applications/DingDong.app/Contents/MCP/dingdong_mcp',
      );

      await model.load();

      expect(
        model.mcpSetupPrompt,
        startsWith('请为当前 Agent 或 IDE 完成 DingDong 接入'),
      );
      expect(model.mcpSetupPrompt, isNot(contains('不要介绍 DingDong')));
      expect(model.mcpSetupPrompt, contains('立即调用一次 dingdong_notify'));
      expect(model.mcpSetupPrompt, contains('DingDong MCP 已接入'));
      expect(model.mcpSetupPrompt, contains('--notify-stop'));
      expect(model.mcpSetupPrompt, contains('Stop command Hook'));
      expect(model.mcpSetupPrompt, contains('审核并信任'));
    },
  );

  test('MCP access onboarding is marked once and persisted', () async {
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
    );
    await model.load();

    expect(model.settings.mcpAccessSeen, isFalse);

    await model.markMcpAccessSeen();
    await model.markMcpAccessSeen();

    expect(model.settings.mcpAccessSeen, isTrue);
    expect(backend.values['dingdong.onboarding.mcpAccessSeen'], isTrue);
  });

  test(
    'system usage can be refreshed without coupling settings to IO',
    () async {
      final _SystemUsageSource source = _SystemUsageSource();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(MemoryPreferencesBackend()),
        systemUsageSource: source,
      );

      await model.load();
      expect(model.systemUsage?.residentMemoryBytes, 64 * 1024 * 1024);
      expect(model.systemUsage?.storageBytes, 12 * 1024 * 1024);

      await model.refreshSystemUsage();
      expect(source.loadCount, 2);
    },
  );
}

final class _SystemUsageSource implements SystemUsageSource {
  int loadCount = 0;

  @override
  Future<SystemUsageSnapshot> load() async {
    loadCount += 1;
    return const SystemUsageSnapshot(
      residentMemoryBytes: 64 * 1024 * 1024,
      storageBytes: 12 * 1024 * 1024,
    );
  }
}

final class _FakeQuickPastePermission implements QuickPastePermissionGateway {
  bool granted = false;
  int openCount = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<void> openSettings() async {
    openCount += 1;
  }
}

final class _FakeReleaseMetadataSource implements ReleaseMetadataSource {
  _FakeReleaseMetadataSource(this.metadata);

  final ReleaseMetadata metadata;

  @override
  Future<ReleaseMetadata> fetch() async => metadata;
}

final class _FakeExternalLinkGateway implements ExternalLinkGateway {
  final List<Uri> opened = <Uri>[];

  @override
  Future<void> open(Uri uri) async => opened.add(uri);
}

final class _FakeLaunchAtStartup implements LaunchAtStartup {
  _FakeLaunchAtStartup(this.enabled);

  bool enabled;
  final List<bool> setValues = <bool>[];

  @override
  Future<bool> isEnabled() async => enabled;

  @override
  Future<void> setEnabled(bool value) async {
    enabled = value;
    setValues.add(value);
  }
}

final class _FakeClipboardMonitoring implements ClipboardMonitoring {
  int startCount = 0;
  int stopCount = 0;

  @override
  bool get isRunning => startCount > stopCount;

  @override
  Future<void> start() async {
    startCount += 1;
  }

  @override
  Future<void> stop() async {
    stopCount += 1;
  }
}
