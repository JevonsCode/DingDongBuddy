import 'package:dingdong/features/clipboard/domain/clipboard_monitor_service.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/application_updater.dart';
import 'package:dingdong/features/settings/domain/launch_at_startup.dart';
import 'package:dingdong/features/settings/domain/quick_paste_permission.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:dingdong/features/settings/domain/system_usage.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/foundation.dart';
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
    await model.setAllowAgentClipboardContent(true);

    expect(monitoring.startCount, 1);
    expect(backend.values['dingdong.clipboard.monitoring'], isTrue);
    expect(backend.values['dingdong.panel.themeMode'], 'dark');
    expect(backend.values['dingdong.clipboard.maxItems'], 2500);
    expect(backend.values['dingdong.clipboard.maxAgeDays'], 45);
    expect(backend.values['dingdong.agentApi.allowClipboardContent'], isTrue);
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

  test('rapid setting edits persist the newest value last', () async {
    final _DelayedOpacityPreferencesBackend backend =
        _DelayedOpacityPreferencesBackend();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
    );
    await model.load();

    final Future<void> first = model.setBackgroundOpacity(0.83);
    await Future<void>.delayed(Duration.zero);
    final Future<void> second = model.setBackgroundOpacity(0.96);
    await Future.wait(<Future<void>>[first, second]);

    expect(backend.values['dingdong.panel.backgroundOpacity'], 0.96);
  });

  test(
    'an in-flight setting save can finish while the window closes',
    () async {
      final _DelayedOpacityPreferencesBackend backend =
          _DelayedOpacityPreferencesBackend();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(backend),
      );
      await model.load();

      final Future<void> save = model.setBackgroundOpacity(0.83);
      model.dispose();

      await expectLater(save, completes);
      expect(backend.values['dingdong.panel.backgroundOpacity'], 0.83);
    },
  );

  test('applies saved and updated Dock icon visibility', () async {
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend(
      <String, Object>{'dingdong.macos.hideDockIcon': true},
    );
    final List<bool> values = <bool>[];
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
      onDockIconHiddenChanged: (bool value) async => values.add(value),
    );

    await model.load();
    await model.setHideDockIcon(false);

    expect(values, <bool>[true, false]);
    expect(model.settings.hideDockIcon, isFalse);
    expect(backend.values['dingdong.macos.hideDockIcon'], isFalse);
  });

  test('applies and persists the menu bar notification color', () async {
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend(
      <String, Object>{'dingdong.macos.trayNotificationColor': 'blue'},
    );
    final List<TrayNotificationColor> values = <TrayNotificationColor>[];
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
      onTrayNotificationColorChanged: (TrayNotificationColor value) async =>
          values.add(value),
    );

    await model.load();
    await model.setTrayNotificationColor(TrayNotificationColor.purple);

    expect(values, <TrayNotificationColor>[
      TrayNotificationColor.blue,
      TrayNotificationColor.purple,
    ]);
    expect(model.settings.trayNotificationColor, TrayNotificationColor.purple);
    expect(backend.values['dingdong.macos.trayNotificationColor'], 'purple');
  });

  test('applies and persists a registered global shortcut', () async {
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
    final List<GlobalHotKey> values = <GlobalHotKey>[];
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
      onGlobalHotKeyChanged: (GlobalHotKey value) async {
        values.add(value);
        return true;
      },
    );
    const GlobalHotKey shortcut = GlobalHotKey(
      key: 'K',
      primary: true,
      shift: false,
      alt: true,
    );

    await model.load();
    await model.setGlobalHotKey(shortcut);

    expect(values, <GlobalHotKey>[GlobalHotKey.defaultValue, shortcut]);
    expect(model.settings.globalHotKey, shortcut);
    expect(
      GlobalHotKey.parse(backend.values['dingdong.shortcut.openClipboard']),
      shortcut,
    );
  });

  test('keeps the previous shortcut when native registration fails', () async {
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
      onGlobalHotKeyChanged: (GlobalHotKey value) async =>
          value == GlobalHotKey.defaultValue,
    );

    await model.load();
    await model.setGlobalHotKey(
      const GlobalHotKey(key: 'K', primary: true, shift: false),
    );

    expect(model.settings.globalHotKey, GlobalHotKey.defaultValue);
    expect(
      model.errorMessage,
      'Shortcut could not be registered. It may already be used by another app.',
    );
    expect(backend.values, isNot(contains('dingdong.shortcut.openClipboard')));
  });

  test('falls back when a saved shortcut is no longer available', () async {
    const GlobalHotKey savedShortcut = GlobalHotKey(
      key: 'K',
      primary: true,
      shift: false,
    );
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend(
      <String, Object>{
        'dingdong.shortcut.openClipboard': savedShortcut.encode(),
      },
    );
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
      onGlobalHotKeyChanged: (GlobalHotKey value) async => false,
    );

    await model.load();

    expect(model.settings.globalHotKey, GlobalHotKey.defaultValue);
    expect(
      GlobalHotKey.parse(backend.values['dingdong.shortcut.openClipboard']),
      GlobalHotKey.defaultValue,
    );
    expect(
      model.errorMessage,
      'Shortcut could not be registered. It may already be used by another app.',
    );
  });

  test('persists a custom workspace shortcut immediately', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
    );
    await model.load();

    const WorkspaceShortcut shortcut = WorkspaceShortcut(
      key: 'T',
      secondary: true,
    );
    expect(await model.setWorkspaceShortcut(0, shortcut), isTrue);

    expect(model.settings.workspaceShortcuts.today, shortcut);
    expect(
      WorkspaceShortcuts.parse(
        backend.values['dingdong.shortcut.workspaces'],
        platform: TargetPlatform.macOS,
      ).today,
      shortcut,
    );
  });

  test('rejects duplicate and reserved workspace shortcuts', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
    );
    await model.load();

    expect(
      await model.setWorkspaceShortcut(
        0,
        const WorkspaceShortcut(key: 'W', secondary: true),
      ),
      isFalse,
    );
    expect(
      await model.setWorkspaceShortcut(
        0,
        const WorkspaceShortcut(key: 'R', primary: true),
      ),
      isFalse,
    );
    expect(model.settings.workspaceShortcuts, WorkspaceShortcuts.defaultValue);
    expect(
      model.errorMessage,
      'Shortcut conflicts with another DingDong or system action.',
    );
  });

  test(
    'rejects a workspace shortcut that shadows the global shortcut',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(MemoryPreferencesBackend()),
      );
      await model.load();

      expect(
        await model.setWorkspaceShortcut(
          0,
          const WorkspaceShortcut(key: 'V', primary: true, shift: true),
        ),
        isFalse,
      );
      expect(
        model.settings.workspaceShortcuts.today,
        WorkspaceShortcuts.defaultToday,
      );
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
        latestVersion: '1.1.1',
        latestBuild: '38',
        website: Uri.parse('https://example.com/dingdong'),
        releasePage: Uri.parse('https://example.com/dingdong/releases/1.1.1'),
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

    expect(model.releaseStatus.latestVersion, '1.1.1');
    expect(model.releaseStatus.isUpdateAvailable, isTrue);
    expect(model.releaseStatus.notes, <String>['Faster history search']);
    expect(links.opened, <Uri>[
      Uri.parse('https://example.com/dingdong/releases/1.1.1'),
      defaultBugReportUri,
      defaultFeatureRequestUri,
    ]);
  });

  test('one-click updater starts and exposes native progress', () async {
    final _FakeApplicationUpdater updater = _FakeApplicationUpdater();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      applicationUpdater: updater,
    );

    await model.load();
    await model.installLatestUpdate();

    expect(model.applicationUpdaterSupported, isTrue);
    expect(updater.installCount, 1);
    expect(
      model.applicationUpdateStatus.phase,
      ApplicationUpdatePhase.downloading,
    );
    expect(model.applicationUpdateStatus.progress, 0.42);
    model.dispose();
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

  test('quick paste grant presentation defers lifecycle refreshes', () async {
    final _FakeQuickPastePermission permission = _FakeQuickPastePermission();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      quickPastePermissionGateway: permission,
    );

    await model.load();
    model.beginQuickPastePermissionGrantPresentation();
    permission.granted = true;

    await model.refreshQuickPastePermission();
    expect(model.isQuickPastePermissionGranted, isFalse);
    expect(permission.inspectCount, 1);

    await model.completeQuickPastePermissionGrantPresentation();
    expect(model.isQuickPastePermissionGranted, isTrue);
    expect(permission.inspectCount, 2);
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
      expect(model.mcpSetupPrompt, contains('STDIO MCP server named dingdong'));
      expect(
        model.mcpSetupPrompt,
        startsWith('Connect DingDong on this computer'),
      );
      expect(model.mcpSetupPrompt, isNot(contains('Do not explain DingDong')));
      expect(model.mcpSetupPrompt, contains('Preserve every existing entry'));
      expect(model.mcpSetupPrompt, contains('reload the client'));
      expect(model.mcpSetupPrompt, contains('dingdong_notify'));
      expect(model.mcpSetupPrompt, contains('required instruction'));
      expect(
        model.mcpSetupPrompt,
        contains('a Skill candidate is not an instruction'),
      );
      expect(
        model.mcpSetupPrompt,
        contains('MCP summary is not an instruction'),
      );
      expect(
        model.mcpSetupPrompt,
        contains('--notify-stop --source "Current client name"'),
      );
      expect(model.mcpSetupPrompt, contains('~/.codex/config.toml'));
      expect(model.mcpSetupPrompt, contains('~/.claude/settings.json'));
      expect(model.mcpSetupPrompt, contains('~/.cursor/hooks.json'));
      expect(model.mcpSetupPrompt, contains('~/.gemini/settings.json'));
      expect(model.mcpSetupPrompt, contains('~/.kiro/settings/mcp.json'));
      expect(model.mcpSetupPrompt, contains('Kiro CLI v3'));
      expect(model.mcpSetupPrompt, contains('afterAgentResponse command hook'));
      expect(model.mcpSetupPrompt, contains('AfterAgent command hook'));
      expect(model.mcpSetupPrompt, contains('Resource Manager'));
      expect(model.mcpSetupPrompt, contains('Trust & enable'));
      expect(model.mcpSetupPrompt, contains('review and trust'));
      expect(model.mcpSetupPrompt, contains('Test both paths'));
      expect(
        model.mcpSetupPrompt,
        contains('DingDong task-completion hook is connected'),
      );
      expect(model.mcpSetupPrompt, contains('remote or cloud agent'));
      expect(model.mcpSetupPrompt, isNot(contains('clipboard content')));
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
        startsWith('请把这台电脑上的 DingDong 接入当前 Agent 或 IDE'),
      );
      expect(model.mcpSetupPrompt, isNot(contains('不要介绍 DingDong')));
      expect(model.mcpSetupPrompt, contains('立即调用一次'));
      expect(model.mcpSetupPrompt, contains('DingDong MCP 已接入'));
      expect(model.mcpSetupPrompt, contains('必须自动应用的指令'));
      expect(model.mcpSetupPrompt, contains('Skill 候选不是指令'));
      expect(model.mcpSetupPrompt, contains('MCP 摘要不是指令'));
      expect(
        model.mcpSetupPrompt,
        contains('--notify-stop --source "当前客户端名称"'),
      );
      expect(model.mcpSetupPrompt, contains('Stop command Hook'));
      expect(model.mcpSetupPrompt, contains('afterAgentResponse command Hook'));
      expect(model.mcpSetupPrompt, contains('AfterAgent command Hook'));
      expect(model.mcpSetupPrompt, contains('Kiro'));
      expect(model.mcpSetupPrompt, contains('资源管理'));
      expect(model.mcpSetupPrompt, contains('信任并启用'));
      expect(model.mcpSetupPrompt, contains('审核并信任'));
      expect(model.mcpSetupPrompt, contains('分别验证两条链路'));
      expect(model.mcpSetupPrompt, contains('远程或云端 Agent'));
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

  test('Agent activity policy updates persist immediately', () async {
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
    );
    await model.load();

    await model.setRememberAgentActivity(false);
    await model.setGroupRepeatedAgentSessions(false);
    await model.setAgentActivityPolicy(maxItems: 350, countHours: 72);

    expect(model.settings.rememberAgentActivity, isFalse);
    expect(model.settings.groupRepeatedAgentSessions, isFalse);
    expect(model.settings.agentActivityMaxItems, 350);
    expect(model.settings.agentActivityCountHours, 72);
    expect(backend.values['dingdong.agentActivity.remember'], isFalse);
    expect(
      backend.values['dingdong.agentActivity.groupRepeatedSessions'],
      isFalse,
    );
    expect(backend.values['dingdong.agentActivity.maxItems'], 350);
    expect(backend.values['dingdong.agentActivity.countHours'], 72);
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

  test('selected system data is cleared and usage is loaded again', () async {
    final _SystemUsageSource source = _SystemUsageSource();
    final _SystemDataCleaner cleaner = _SystemDataCleaner(source);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      systemUsageSource: source,
      systemDataCleaner: cleaner,
    );
    await model.load();

    final bool cleared = await model.clearSystemData(<SystemDataCategory>{
      SystemDataCategory.clipboardHistory,
      SystemDataCategory.resourceLibrary,
    });

    expect(cleared, isTrue);
    expect(cleaner.categories, <SystemDataCategory>{
      SystemDataCategory.clipboardHistory,
    });
    expect(source.loadCount, 2);
    expect(model.systemUsage?.storageBytes, 2 * 1024 * 1024);
    expect(model.isClearingSystemData, isFalse);
  });
}

final class _SystemUsageSource implements SystemUsageSource {
  int loadCount = 0;
  bool cleared = false;

  @override
  Future<SystemUsageSnapshot> load() async {
    loadCount += 1;
    return SystemUsageSnapshot(
      residentMemoryBytes: 64 * 1024 * 1024,
      storageBytes: (cleared ? 2 : 12) * 1024 * 1024,
      storageByCategory: <SystemDataCategory, int>{
        SystemDataCategory.clipboardHistory: (cleared ? 0 : 10) * 1024 * 1024,
        SystemDataCategory.resourceLibrary: 2 * 1024 * 1024,
      },
    );
  }
}

final class _SystemDataCleaner implements SystemDataCleaner {
  _SystemDataCleaner(this.source);

  final _SystemUsageSource source;
  Set<SystemDataCategory> categories = const <SystemDataCategory>{};

  @override
  Future<void> clear(Set<SystemDataCategory> categories) async {
    this.categories = Set<SystemDataCategory>.of(categories);
    source.cleared = true;
  }
}

final class _FakeApplicationUpdater implements ApplicationUpdater {
  int installCount = 0;
  ApplicationUpdateStatus status = const ApplicationUpdateStatus();

  @override
  Future<void> installLatest() async {
    installCount += 1;
    status = const ApplicationUpdateStatus(
      phase: ApplicationUpdatePhase.downloading,
      progress: 0.42,
      targetVersion: '1.1.1',
    );
  }

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<ApplicationUpdateStatus> readStatus() async => status;
}

final class _FakeQuickPastePermission implements QuickPastePermissionGateway {
  bool granted = false;
  int openCount = 0;
  int inspectCount = 0;

  @override
  Future<bool> isGranted() async {
    inspectCount += 1;
    return granted;
  }

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

final class _DelayedOpacityPreferencesBackend implements PreferencesBackend {
  final Map<String, Object> values = <String, Object>{};

  @override
  Future<Object?> read(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> write(String key, Object value) async {
    if (key == 'dingdong.panel.backgroundOpacity' && value == 0.83) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    values[key] = value;
  }
}
