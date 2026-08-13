import 'package:dingdong/features/agent_api/domain/agent_setup_revision.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses expanded clipboard and recent Agent defaults', () async {
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
    final AppSettings settings = await SettingsRepository(backend).load();

    expect(settings.clipboardMaxItems, 5000);
    expect(settings.clipboardMaxAgeDays, 120);
    expect(settings.allowAgentClipboardContent, isFalse);
    expect(settings.notifySubagentActivity, isFalse);
    expect(settings.groupRepeatedAgentSessions, isTrue);
    expect(settings.lifecycleTelemetryEnabled, isTrue);
    expect(settings.agentActivityMaxItems, 500);
    expect(settings.agentActivityCountHours, 24);
    expect(settings.hideDockIcon, isFalse);
    expect(settings.trayNotificationColor, TrayNotificationColor.orange);
    expect(settings.globalHotKey, GlobalHotKey.defaultValue);
    expect(settings.workspaceShortcuts, WorkspaceShortcuts.defaultValue);
    expect(
      settings.conversationFooterSymbols,
      ConversationFooterSymbols.defaultValue,
    );
    expect(settings.agentSetupAcknowledgedRevision, currentAgentSetupRevision);
    expect(settings.requiresAgentSetupUpdate, isFalse);
    expect(
      backend.values['dingdong.agentApi.acknowledgedSetupRevision'],
      currentAgentSetupRevision,
    );
  });

  test('setup revision migration preserves legacy connected installs', () {
    expect(
      resolveAcknowledgedAgentSetupRevision(
        storedValue: null,
        hasSeenAgentAccess: false,
        requiredRevision: 3,
      ),
      3,
    );
    expect(
      resolveAcknowledgedAgentSetupRevision(
        storedValue: null,
        hasSeenAgentAccess: true,
        requiredRevision: 3,
      ),
      firstTrackedAgentSetupRevision,
    );
    expect(
      resolveAcknowledgedAgentSetupRevision(
        storedValue: 2,
        hasSeenAgentAccess: true,
        requiredRevision: 3,
      ),
      2,
    );
  });

  test('subagent notification preference survives copyWith and sanitizing', () {
    final AppSettings enabled = const AppSettings().copyWith(
      notifySubagentActivity: true,
    );

    expect(enabled.notifySubagentActivity, isTrue);
    expect(enabled.sanitized().notifySubagentActivity, isTrue);
    expect(
      enabled.copyWith(notifySubagentActivity: false).notifySubagentActivity,
      isFalse,
    );
  });

  test('supports a build-specific default tray notification color', () async {
    final AppSettings settings = await SettingsRepository(
      MemoryPreferencesBackend(),
      defaultTrayNotificationColor: TrayNotificationColor.pink,
    ).load();

    expect(settings.trayNotificationColor, TrayNotificationColor.pink);
  });

  test('invalid conversation footer symbols fall back to defaults', () async {
    final AppSettings settings = await SettingsRepository(
      MemoryPreferencesBackend(<String, Object>{
        'dingdong.agentApi.conversationFooterSymbols':
            '{"prompt":"|","skill":"*","mcp":"two"}',
      }),
    ).load();

    expect(
      settings.conversationFooterSymbols,
      ConversationFooterSymbols.defaultValue,
    );
  });

  test(
    'preserves legacy telemetry opt-outs during default-on migration',
    () async {
      final AppSettings undecided = await SettingsRepository(
        MemoryPreferencesBackend(<String, Object>{
          'dingdong.telemetry.lifecycleConsent': 'undecided',
        }),
      ).load();
      final AppSettings disabled = await SettingsRepository(
        MemoryPreferencesBackend(<String, Object>{
          'dingdong.telemetry.lifecycleConsent': 'disabled',
        }),
      ).load();

      expect(undecided.lifecycleTelemetryEnabled, isTrue);
      expect(disabled.lifecycleTelemetryEnabled, isFalse);
    },
  );

  test('loads persisted preferences and sanitizes unsafe limits', () async {
    final MemoryPreferencesBackend backend =
        MemoryPreferencesBackend(<String, Object>{
          'dingdong.clipboard.monitoring': true,
          'dingdong.language': 'zh',
          'dingdong.panel.themeMode': 'dark',
          'dingdong.panel.backgroundOpacity': 0.75,
          'dingdong.panel.defaultTab': 'clipboard',
          'dingdong.clipboard.maxItems': 9000,
          'dingdong.clipboard.maxAgeDays': 0,
          'dingdong.agentApi.allowClipboardContent': true,
          'dingdong.selectedSound': 'dingBright',
          'dingdong.customSoundPath': '/tmp/chime.wav',
          'dingdong.onboarding.mcpAccessSeen': true,
          'dingdong.api.port': 70000,
          'dingdong.agentActivity.remember': false,
          'dingdong.agentActivity.notifySubagents': true,
          'dingdong.agentActivity.groupRepeatedSessions': false,
          'dingdong.agentActivity.maxItems': 9000,
          'dingdong.agentActivity.countHours': 0,
          'dingdong.telemetry.lifecycleConsent': 'enabled',
          'dingdong.macos.hideDockIcon': true,
          'dingdong.macos.trayNotificationColor': 'purple',
          'dingdong.shortcut.openClipboard': const GlobalHotKey(
            key: 'K',
            primary: true,
            shift: false,
            alt: true,
          ).encode(),
          'dingdong.shortcut.workspaces': const WorkspaceShortcuts(
            today: WorkspaceShortcut(key: 'T', primary: true),
            library: WorkspaceShortcut(key: 'L', primary: true),
            clipboard: WorkspaceShortcut(key: 'C', primary: true),
          ).encode(),
          'dingdong.agentApi.conversationFooterSymbols':
              const ConversationFooterSymbols(
                prompt: '◆',
                skill: '●',
                mcp: '▲',
              ).encode(),
        });

    final settings = await SettingsRepository(backend).load();

    expect(settings.clipboardMonitoring, isTrue);
    expect(settings.language, AppLanguagePreference.chinese);
    expect(settings.themeMode, AppThemePreference.dark);
    expect(settings.backgroundOpacity, 0.82);
    expect(settings.defaultWorkspace, DefaultWorkspace.clipboard);
    expect(settings.clipboardMaxItems, 5000);
    expect(settings.clipboardMaxAgeDays, 1);
    expect(settings.allowAgentClipboardContent, isTrue);
    expect(settings.selectedSound, 'dingBright');
    expect(settings.customSoundPath, '/tmp/chime.wav');
    expect(settings.mcpAccessSeen, isTrue);
    expect(settings.apiPort, 2333);
    expect(settings.rememberAgentActivity, isFalse);
    expect(settings.notifySubagentActivity, isTrue);
    expect(settings.groupRepeatedAgentSessions, isFalse);
    expect(settings.agentActivityMaxItems, 5000);
    expect(settings.agentActivityCountHours, 1);
    expect(settings.lifecycleTelemetryEnabled, isTrue);
    expect(settings.hideDockIcon, isTrue);
    expect(settings.trayNotificationColor, TrayNotificationColor.purple);
    expect(
      settings.globalHotKey,
      const GlobalHotKey(key: 'K', primary: true, shift: false, alt: true),
    );
    expect(
      settings.workspaceShortcuts,
      const WorkspaceShortcuts(
        today: WorkspaceShortcut(key: 'T', primary: true),
        library: WorkspaceShortcut(key: 'L', primary: true),
        clipboard: WorkspaceShortcut(key: 'C', primary: true),
      ),
    );
    expect(
      settings.conversationFooterSymbols,
      const ConversationFooterSymbols(prompt: '◆', skill: '●', mcp: '▲'),
    );
  });

  test('saves settings with the native app preference contract', () async {
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
    final SettingsRepository repository = SettingsRepository(backend);
    const AppSettings settings = AppSettings(
      clipboardMonitoring: true,
      language: AppLanguagePreference.english,
      themeMode: AppThemePreference.system,
      backgroundOpacity: 0.88,
      defaultWorkspace: DefaultWorkspace.library,
      clipboardMaxItems: 600,
      clipboardMaxAgeDays: 30,
      allowAgentClipboardContent: true,
      lifecycleTelemetryEnabled: false,
      rememberAgentActivity: false,
      notifySubagentActivity: true,
      groupRepeatedAgentSessions: false,
      agentActivityMaxItems: 320,
      agentActivityCountHours: 48,
      hideDockIcon: true,
      trayNotificationColor: TrayNotificationColor.green,
      globalHotKey: GlobalHotKey(key: 'SPACE', primary: true, shift: false),
      workspaceShortcuts: WorkspaceShortcuts(
        today: WorkspaceShortcut(key: 'T', secondary: true),
        library: WorkspaceShortcut(key: 'L', secondary: true),
        clipboard: WorkspaceShortcut(key: 'C', secondary: true),
      ),
      selectedSound: 'muted',
      customSoundPath: '/tmp/quiet.wav',
      mcpAccessSeen: true,
      agentSetupAcknowledgedRevision: 0,
      apiPort: 2444,
      conversationFooterSymbols: ConversationFooterSymbols(
        prompt: '◇',
        skill: '○',
        mcp: '▽',
      ),
    );

    await repository.save(settings);

    expect(backend.values['dingdong.clipboard.monitoring'], isTrue);
    expect(backend.values['dingdong.language'], 'en');
    expect(backend.values['dingdong.panel.themeMode'], 'system');
    expect(backend.values['dingdong.panel.backgroundOpacity'], 0.88);
    expect(backend.values['dingdong.panel.defaultTab'], 'library');
    expect(backend.values['dingdong.clipboard.maxItems'], 600);
    expect(backend.values['dingdong.clipboard.maxAgeDays'], 30);
    expect(backend.values['dingdong.agentApi.allowClipboardContent'], isTrue);
    expect(backend.values['dingdong.telemetry.lifecycleConsent'], 'disabled');
    expect(backend.values['dingdong.agentActivity.remember'], isFalse);
    expect(backend.values['dingdong.agentActivity.notifySubagents'], isTrue);
    expect(
      backend.values['dingdong.agentActivity.groupRepeatedSessions'],
      isFalse,
    );
    expect(backend.values['dingdong.agentActivity.maxItems'], 320);
    expect(backend.values['dingdong.agentActivity.countHours'], 48);
    expect(backend.values['dingdong.macos.hideDockIcon'], isTrue);
    expect(backend.values['dingdong.macos.trayNotificationColor'], 'green');
    expect(
      GlobalHotKey.parse(backend.values['dingdong.shortcut.openClipboard']),
      const GlobalHotKey(key: 'SPACE', primary: true, shift: false),
    );
    expect(
      WorkspaceShortcuts.parse(backend.values['dingdong.shortcut.workspaces']),
      settings.workspaceShortcuts,
    );
    expect(backend.values['dingdong.selectedSound'], 'muted');
    expect(backend.values['dingdong.customSoundPath'], '/tmp/quiet.wav');
    expect(backend.values['dingdong.onboarding.mcpAccessSeen'], isTrue);
    expect(backend.values['dingdong.agentApi.acknowledgedSetupRevision'], 0);
    expect(backend.values['dingdong.api.port'], 2444);
    expect(
      ConversationFooterSymbols.parse(
        backend.values['dingdong.agentApi.conversationFooterSymbols'],
      ),
      settings.conversationFooterSymbols,
    );
  });
}
