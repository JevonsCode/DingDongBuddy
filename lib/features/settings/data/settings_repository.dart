import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';

export 'package:dingdong/features/settings/domain/app_settings.dart';

/// Loads and saves settings using the native DingDong preference key contract.
final class SettingsRepository {
  const SettingsRepository(this._backend);

  final PreferencesBackend _backend;

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
      _backend.read(_mcpSetupPromptOverrideKey),
      _backend.read(_apiPortKey),
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
      clipboardMaxItems: values[7] is int ? values[7]! as int : 1000,
      clipboardMaxAgeDays: values[8] is int ? values[8]! as int : 90,
      selectedSound: values[9] is String ? values[9]! as String : 'default',
      customSoundPath: values[10] as String?,
      mcpSetupPromptOverride: values[11] as String?,
      apiPort: values[12] is int ? values[12]! as int : 2333,
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
      _backend.write(_selectedSoundKey, settings.selectedSound),
      settings.customSoundPath == null
          ? _backend.remove(_customSoundPathKey)
          : _backend.write(_customSoundPathKey, settings.customSoundPath!),
      settings.mcpSetupPromptOverride == null
          ? _backend.remove(_mcpSetupPromptOverrideKey)
          : _backend.write(
              _mcpSetupPromptOverrideKey,
              settings.mcpSetupPromptOverride!,
            ),
      _backend.write(_apiPortKey, settings.apiPort),
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
const String _selectedSoundKey = 'dingdong.selectedSound';
const String _customSoundPathKey = 'dingdong.customSoundPath';
const String _mcpSetupPromptOverrideKey = 'dingdong.mcpSetupPromptOverride';
const String _apiPortKey = 'dingdong.api.port';
