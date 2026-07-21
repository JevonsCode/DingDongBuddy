/// Language choice persisted independently from the current system locale.
enum AppLanguagePreference {
  system(null),
  english('en'),
  chinese('zh');

  const AppLanguagePreference(this.storageValue);

  final String? storageValue;

  static AppLanguagePreference parse(Object? value) {
    return AppLanguagePreference.values.firstWhere(
      (AppLanguagePreference item) => item.storageValue == value,
      orElse: () => AppLanguagePreference.system,
    );
  }
}

/// Cross-platform application appearance preference.
enum AppThemePreference {
  system,
  light,
  dark;

  static AppThemePreference parse(Object? value) {
    return AppThemePreference.values.firstWhere(
      (AppThemePreference item) => item.name == value,
      orElse: () => AppThemePreference.light,
    );
  }
}

/// Row spacing used by long desktop lists.
enum PanelDensityPreference {
  comfortable,
  compact;

  static PanelDensityPreference parse(Object? value) {
    return values.firstWhere(
      (PanelDensityPreference item) => item.name == value,
      orElse: () => PanelDensityPreference.comfortable,
    );
  }
}

/// Workspace opened when DingDong starts.
enum DefaultWorkspace {
  today,
  library,
  clipboard;

  static DefaultWorkspace parse(Object? value) {
    return values.firstWhere(
      (DefaultWorkspace item) => item.name == value,
      orElse: () => DefaultWorkspace.today,
    );
  }
}

/// User-editable settings with legacy-compatible defaults and bounds.
final class AppSettings {
  const AppSettings({
    this.clipboardMonitoring = false,
    this.language = AppLanguagePreference.system,
    this.themeMode = AppThemePreference.light,
    this.launchAtStartup = false,
    this.backgroundOpacity = 0.90,
    this.density = PanelDensityPreference.comfortable,
    this.defaultWorkspace = DefaultWorkspace.today,
    this.clipboardMaxItems = 1000,
    this.clipboardMaxAgeDays = 90,
    this.rememberAgentActivity = true,
    this.agentActivityMaxItems = 200,
    this.agentActivityCountHours = 24,
    this.selectedSound = 'default',
    this.customSoundPath,
    this.mcpAccessSeen = false,
    this.apiPort = 2333,
  });

  final bool clipboardMonitoring;
  final AppLanguagePreference language;
  final AppThemePreference themeMode;
  final bool launchAtStartup;
  final double backgroundOpacity;
  final PanelDensityPreference density;
  final DefaultWorkspace defaultWorkspace;
  final int clipboardMaxItems;
  final int clipboardMaxAgeDays;
  final bool rememberAgentActivity;
  final int agentActivityMaxItems;
  final int agentActivityCountHours;
  final String selectedSound;
  final String? customSoundPath;
  final bool mcpAccessSeen;
  final int apiPort;

  AppSettings sanitized() {
    return AppSettings(
      clipboardMonitoring: clipboardMonitoring,
      language: language,
      themeMode: themeMode,
      launchAtStartup: launchAtStartup,
      backgroundOpacity: backgroundOpacity.clamp(0.82, 0.96),
      density: density,
      defaultWorkspace: defaultWorkspace,
      clipboardMaxItems: clipboardMaxItems.clamp(20, 5000),
      clipboardMaxAgeDays: clipboardMaxAgeDays.clamp(1, 730),
      rememberAgentActivity: rememberAgentActivity,
      agentActivityMaxItems: agentActivityMaxItems.clamp(1, 5000),
      agentActivityCountHours: agentActivityCountHours.clamp(1, 24 * 365),
      selectedSound: selectedSound == 'dingWood'
          ? 'default'
          : _preferenceSoundValues.contains(selectedSound)
          ? selectedSound
          : 'default',
      customSoundPath: _trimmedOrNull(customSoundPath),
      mcpAccessSeen: mcpAccessSeen,
      apiPort: apiPort >= 1024 && apiPort <= 65535 ? apiPort : 2333,
    );
  }

  AppSettings copyWith({
    bool? clipboardMonitoring,
    AppLanguagePreference? language,
    AppThemePreference? themeMode,
    bool? launchAtStartup,
    double? backgroundOpacity,
    PanelDensityPreference? density,
    DefaultWorkspace? defaultWorkspace,
    int? clipboardMaxItems,
    int? clipboardMaxAgeDays,
    bool? rememberAgentActivity,
    int? agentActivityMaxItems,
    int? agentActivityCountHours,
    String? selectedSound,
    Object? customSoundPath = _notSet,
    bool? mcpAccessSeen,
    int? apiPort,
  }) {
    return AppSettings(
      clipboardMonitoring: clipboardMonitoring ?? this.clipboardMonitoring,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      density: density ?? this.density,
      defaultWorkspace: defaultWorkspace ?? this.defaultWorkspace,
      clipboardMaxItems: clipboardMaxItems ?? this.clipboardMaxItems,
      clipboardMaxAgeDays: clipboardMaxAgeDays ?? this.clipboardMaxAgeDays,
      rememberAgentActivity:
          rememberAgentActivity ?? this.rememberAgentActivity,
      agentActivityMaxItems:
          agentActivityMaxItems ?? this.agentActivityMaxItems,
      agentActivityCountHours:
          agentActivityCountHours ?? this.agentActivityCountHours,
      selectedSound: selectedSound ?? this.selectedSound,
      customSoundPath: identical(customSoundPath, _notSet)
          ? this.customSoundPath
          : customSoundPath as String?,
      mcpAccessSeen: mcpAccessSeen ?? this.mcpAccessSeen,
      apiPort: apiPort ?? this.apiPort,
    ).sanitized();
  }
}

String? _trimmedOrNull(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

const Set<String> _preferenceSoundValues = <String>{
  'default',
  'dingSoft',
  'dingBright',
  'dingCrisp',
  'dingDeep',
  'custom',
  'system',
  'muted',
};

const Object _notSet = Object();
