import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:dingdong/features/settings/domain/workspace_shortcuts.dart';
import 'package:flutter/foundation.dart';

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
      _backend.read(_densityKey),
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
    ]);
    return AppSettings(
      clipboardMonitoring: values[0] is bool ? values[0]! as bool : false,
      language: AppLanguagePreference.parse(values[1]),
      themeMode: AppThemePreference.parse(values[2]),
      launchAtStartup: values[3] is bool ? values[3]! as bool : false,
      backgroundOpacity: values[4] is num
          ? (values[4]! as num).toDouble()
          : 0.90,
      density: PanelDensityPreference.parse(values[5]),
      defaultWorkspace: DefaultWorkspace.parse(values[6]),
      clipboardMaxItems: values[7] is int ? values[7]! as int : 5000,
      clipboardMaxAgeDays: values[8] is int ? values[8]! as int : 120,
      selectedSound: values[9] is String ? values[9]! as String : 'default',
      customSoundPath: values[10] as String?,
      apiPort: values[11] is int ? values[11]! as int : 2333,
      mcpAccessSeen: values[12] is bool ? values[12]! as bool : false,
      rememberAgentActivity: values[13] is bool ? values[13]! as bool : true,
      agentActivityMaxItems: values[14] is int ? values[14]! as int : 500,
      agentActivityCountHours: values[15] is int ? values[15]! as int : 24,
      hideDockIcon: values[16] is bool ? values[16]! as bool : false,
      trayNotificationColor: TrayNotificationColor.parse(
        values[17],
        fallback: defaultTrayNotificationColor,
      ),
      globalHotKey: GlobalHotKey.parse(values[18]),
      allowAgentClipboardContent: values[19] is bool
          ? values[19]! as bool
          : false,
      workspaceShortcuts: WorkspaceShortcuts.parse(
        values[20],
        platform: defaultTargetPlatform,
      ),
      groupRepeatedAgentSessions: values[21] is bool
          ? values[21]! as bool
          : true,
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
      _backend.write(_densityKey, settings.density.name),
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
      _backend.write(_rememberAgentActivityKey, settings.rememberAgentActivity),
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
    ]);
  }
}

const String _monitoringKey = 'dingdong.clipboard.monitoring';
const String _languageKey = 'dingdong.language';
const String _themeKey = 'dingdong.panel.themeMode';
const String _launchAtStartupKey = 'dingdong.launchAtLogin';
const String _opacityKey = 'dingdong.panel.backgroundOpacity';
const String _densityKey = 'dingdong.panel.density';
const String _defaultWorkspaceKey = 'dingdong.panel.defaultTab';
const String _maxItemsKey = 'dingdong.clipboard.maxItems';
const String _maxAgeKey = 'dingdong.clipboard.maxAgeDays';
const String _allowAgentClipboardContentKey =
    'dingdong.agentApi.allowClipboardContent';
const String _selectedSoundKey = 'dingdong.selectedSound';
const String _customSoundPathKey = 'dingdong.customSoundPath';
const String _apiPortKey = 'dingdong.api.port';
const String _mcpAccessSeenKey = 'dingdong.onboarding.mcpAccessSeen';
const String _rememberAgentActivityKey = 'dingdong.agentActivity.remember';
const String _agentActivityMaxItemsKey = 'dingdong.agentActivity.maxItems';
const String _agentActivityCountHoursKey = 'dingdong.agentActivity.countHours';
const String _hideDockIconKey = 'dingdong.macos.hideDockIcon';
const String _trayNotificationColorKey = 'dingdong.macos.trayNotificationColor';
const String _globalHotKeyKey = 'dingdong.shortcut.openClipboard';
const String _workspaceShortcutsKey = 'dingdong.shortcut.workspaces';
const String _groupRepeatedAgentSessionsKey =
    'dingdong.agentActivity.groupRepeatedSessions';
