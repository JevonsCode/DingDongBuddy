import 'package:dingdong/features/agent_api/domain/agent_setup_revision.dart';
import 'package:dingdong/features/agent_api/domain/conversation_footer_symbols.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:dingdong/features/settings/domain/workspace_shortcuts.dart';
import 'package:flutter/foundation.dart';

export 'package:dingdong/features/agent_api/domain/conversation_footer_symbols.dart';
export 'package:dingdong/features/settings/domain/app_settings.dart';
export 'package:dingdong/features/settings/domain/global_hot_key.dart';
export 'package:dingdong/features/settings/domain/workspace_shortcuts.dart';

/// Loads and saves settings using the native DingDong preference key contract.
final class SettingsRepository {
  const SettingsRepository(
    this._backend, {
    this.defaultTrayNotificationColor = TrayNotificationColor.orange,
  });

  final PreferencesBackend _backend;
  final TrayNotificationColor defaultTrayNotificationColor;

  Future<AppSettings> load() async {
    final List<Object?> values = await Future.wait(<Future<Object?>>[
      _backend.read(_monitoringKey),
      _backend.read(_languageKey),
      _backend.read(_themeKey),
      _backend.read(_launchAtStartupKey),
      _backend.read(_opacityKey),
      _backend.read(_defaultWorkspaceKey),
      _backend.read(_maxItemsKey),
      _backend.read(_maxAgeKey),
      _backend.read(_selectedSoundKey),
      _backend.read(_customSoundPathKey),
      _backend.read(_apiPortKey),
      _backend.read(_mcpAccessSeenKey),
      _backend.read(_rememberAgentActivityKey),
      _backend.read(_agentActivityMaxItemsKey),
      _backend.read(_agentActivityCountHoursKey),
      _backend.read(_hideDockIconKey),
      _backend.read(_trayNotificationColorKey),
      _backend.read(_globalHotKeyKey),
      _backend.read(_allowAgentClipboardContentKey),
      _backend.read(_workspaceShortcutsKey),
      _backend.read(_groupRepeatedAgentSessionsKey),
      _backend.read(_lifecycleTelemetryPreferenceKey),
      _backend.read(_notifySubagentActivityKey),
      _backend.read(_conversationFooterSymbolsKey),
      _backend.read(_agentSetupAcknowledgedRevisionKey),
      _backend.read(_notifyAgentCompletionKey),
      _backend.read(_notifyAgentAttentionKey),
      _backend.read(_notifyCodexVoiceActivityKey),
      _backend.read(_showConversationTokenUsageKey),
      _backend.read(_conversationTokenUsageDefaultOnMigrationKey),
    ]);
    final bool mcpAccessSeen = values[11] is bool ? values[11]! as bool : false;
    final int agentSetupAcknowledgedRevision =
        resolveAcknowledgedAgentSetupRevision(
          storedValue: values[24],
          hasSeenAgentAccess: mcpAccessSeen,
        );
    if (values[24] is! int) {
      await _backend.write(
        _agentSetupAcknowledgedRevisionKey,
        agentSetupAcknowledgedRevision,
      );
    }
    final bool conversationTokenUsageDefaultOnMigrated = values[29] == true;
    final bool showConversationTokenUsage =
        conversationTokenUsageDefaultOnMigrated
        ? (values[28] is bool ? values[28]! as bool : true)
        : true;
    if (!conversationTokenUsageDefaultOnMigrated) {
      await Future.wait(<Future<void>>[
        _backend.write(_showConversationTokenUsageKey, true),
        _backend.write(_conversationTokenUsageDefaultOnMigrationKey, true),
      ]);
    }
    return AppSettings(
      clipboardMonitoring: values[0] is bool ? values[0]! as bool : false,
      language: AppLanguagePreference.parse(values[1]),
      themeMode: AppThemePreference.parse(values[2]),
      launchAtStartup: values[3] is bool ? values[3]! as bool : false,
      backgroundOpacity: values[4] is num
          ? (values[4]! as num).toDouble()
          : 0.90,
      defaultWorkspace: DefaultWorkspace.parse(values[5]),
      clipboardMaxItems: values[6] is int ? values[6]! as int : 5000,
      clipboardMaxAgeDays: values[7] is int ? values[7]! as int : 120,
      selectedSound: values[8] is String ? values[8]! as String : 'default',
      customSoundPath: values[9] as String?,
      apiPort: values[10] is int ? values[10]! as int : 2333,
      mcpAccessSeen: mcpAccessSeen,
      agentSetupAcknowledgedRevision: agentSetupAcknowledgedRevision,
      rememberAgentActivity: values[12] is bool ? values[12]! as bool : true,
      notifyAgentCompletion: values[25] is bool ? values[25]! as bool : true,
      notifyAgentAttention: values[26] is bool ? values[26]! as bool : true,
      notifyCodexVoiceActivity: values[27] is bool
          ? values[27]! as bool
          : false,
      showConversationTokenUsage: showConversationTokenUsage,
      notifySubagentActivity: values[22] is bool ? values[22]! as bool : false,
      conversationFooterSymbols: ConversationFooterSymbols.parse(values[23]),
      agentActivityMaxItems: values[13] is int ? values[13]! as int : 500,
      agentActivityCountHours: values[14] is int ? values[14]! as int : 24,
      hideDockIcon: values[15] is bool ? values[15]! as bool : false,
      trayNotificationColor: TrayNotificationColor.parse(
        values[16],
        fallback: defaultTrayNotificationColor,
      ),
      globalHotKey: GlobalHotKey.parse(values[17]),
      allowAgentClipboardContent: values[18] is bool
          ? values[18]! as bool
          : false,
      workspaceShortcuts: WorkspaceShortcuts.parse(
        values[19],
        platform: defaultTargetPlatform,
      ),
      groupRepeatedAgentSessions: values[20] is bool
          ? values[20]! as bool
          : true,
      lifecycleTelemetryEnabled: _parseLifecycleTelemetryEnabled(values[21]),
    ).sanitized();
  }

  Future<void> save(AppSettings value) async {
    final AppSettings settings = value.sanitized();
    await Future.wait(<Future<void>>[
      _backend.write(_monitoringKey, settings.clipboardMonitoring),
      settings.language.storageValue == null
          ? _backend.remove(_languageKey)
          : _backend.write(_languageKey, settings.language.storageValue!),
      _backend.write(_themeKey, settings.themeMode.name),
      _backend.write(_launchAtStartupKey, settings.launchAtStartup),
      _backend.write(_opacityKey, settings.backgroundOpacity),
      _backend.write(_defaultWorkspaceKey, settings.defaultWorkspace.name),
      _backend.write(_maxItemsKey, settings.clipboardMaxItems),
      _backend.write(_maxAgeKey, settings.clipboardMaxAgeDays),
      _backend.write(
        _allowAgentClipboardContentKey,
        settings.allowAgentClipboardContent,
      ),
      _backend.write(_selectedSoundKey, settings.selectedSound),
      settings.customSoundPath == null
          ? _backend.remove(_customSoundPathKey)
          : _backend.write(_customSoundPathKey, settings.customSoundPath!),
      _backend.write(_apiPortKey, settings.apiPort),
      _backend.write(_mcpAccessSeenKey, settings.mcpAccessSeen),
      _backend.write(
        _agentSetupAcknowledgedRevisionKey,
        settings.agentSetupAcknowledgedRevision,
      ),
      _backend.write(_rememberAgentActivityKey, settings.rememberAgentActivity),
      _backend.write(_notifyAgentCompletionKey, settings.notifyAgentCompletion),
      _backend.write(_notifyAgentAttentionKey, settings.notifyAgentAttention),
      _backend.write(
        _notifyCodexVoiceActivityKey,
        settings.notifyCodexVoiceActivity,
      ),
      _backend.write(
        _notifySubagentActivityKey,
        settings.notifySubagentActivity,
      ),
      _backend.write(
        _conversationFooterSymbolsKey,
        settings.conversationFooterSymbols.encode(),
      ),
      _backend.write(
        _showConversationTokenUsageKey,
        settings.showConversationTokenUsage,
      ),
      _backend.write(_conversationTokenUsageDefaultOnMigrationKey, true),
      _backend.write(_agentActivityMaxItemsKey, settings.agentActivityMaxItems),
      _backend.write(
        _agentActivityCountHoursKey,
        settings.agentActivityCountHours,
      ),
      _backend.write(_hideDockIconKey, settings.hideDockIcon),
      _backend.write(
        _trayNotificationColorKey,
        settings.trayNotificationColor.name,
      ),
      _backend.write(_globalHotKeyKey, settings.globalHotKey.encode()),
      _backend.write(
        _workspaceShortcutsKey,
        settings.workspaceShortcuts.encode(),
      ),
      _backend.write(
        _groupRepeatedAgentSessionsKey,
        settings.groupRepeatedAgentSessions,
      ),
      _backend.write(
        _lifecycleTelemetryPreferenceKey,
        settings.lifecycleTelemetryEnabled ? 'enabled' : 'disabled',
      ),
    ]);
  }
}

const String _monitoringKey = 'dingdong.clipboard.monitoring';
const String _languageKey = 'dingdong.language';
const String _themeKey = 'dingdong.panel.themeMode';
const String _launchAtStartupKey = 'dingdong.launchAtLogin';
const String _opacityKey = 'dingdong.panel.backgroundOpacity';
const String _defaultWorkspaceKey = 'dingdong.panel.defaultTab';
const String _maxItemsKey = 'dingdong.clipboard.maxItems';
const String _maxAgeKey = 'dingdong.clipboard.maxAgeDays';
const String _allowAgentClipboardContentKey =
    'dingdong.agentApi.allowClipboardContent';
const String _selectedSoundKey = 'dingdong.selectedSound';
const String _customSoundPathKey = 'dingdong.customSoundPath';
const String _apiPortKey = 'dingdong.api.port';
const String _mcpAccessSeenKey = 'dingdong.onboarding.mcpAccessSeen';
const String _agentSetupAcknowledgedRevisionKey =
    'dingdong.agentApi.acknowledgedSetupRevision';
const String _rememberAgentActivityKey = 'dingdong.agentActivity.remember';
const String _notifyAgentCompletionKey =
    'dingdong.agentActivity.notifyCompletions';
const String _notifyAgentAttentionKey =
    'dingdong.agentActivity.notifyAttention';
const String _notifyCodexVoiceActivityKey =
    'dingdong.agentActivity.notifyCodexVoice';
const String _notifySubagentActivityKey =
    'dingdong.agentActivity.notifySubagents';
const String _conversationFooterSymbolsKey =
    'dingdong.agentApi.conversationFooterSymbols';
const String _showConversationTokenUsageKey =
    'dingdong.agentApi.showConversationTokenUsage';
const String _conversationTokenUsageDefaultOnMigrationKey =
    'dingdong.migrations.conversationTokenUsageDefaultOn.v1';
const String _agentActivityMaxItemsKey = 'dingdong.agentActivity.maxItems';
const String _agentActivityCountHoursKey = 'dingdong.agentActivity.countHours';
const String _hideDockIconKey = 'dingdong.macos.hideDockIcon';
const String _trayNotificationColorKey = 'dingdong.macos.trayNotificationColor';
const String _globalHotKeyKey = 'dingdong.shortcut.openClipboard';
const String _workspaceShortcutsKey = 'dingdong.shortcut.workspaces';
const String _groupRepeatedAgentSessionsKey =
    'dingdong.agentActivity.groupRepeatedSessions';
// Keep the original key so existing opt-outs survive this default-on migration.
const String _lifecycleTelemetryPreferenceKey =
    'dingdong.telemetry.lifecycleConsent';

bool _parseLifecycleTelemetryEnabled(Object? value) => value != 'disabled';
