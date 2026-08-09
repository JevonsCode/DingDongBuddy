import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:dingdong/features/settings/domain/workspace_shortcuts.dart';
import 'package:flutter/foundation.dart';

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

/// Preset background colors used by the macOS unread notification capsule.
enum TrayNotificationColor {
  orange(0xDB7333),
  pink(0xE85991),
  blue(0x3B7DDD),
  green(0x2F9D68),
  purple(0x8C5BD6);

  const TrayNotificationColor(this.rgbValue);

  final int rgbValue;

  static TrayNotificationColor parse(
    Object? value, {
    TrayNotificationColor fallback = TrayNotificationColor.orange,
  }) {
    return values.firstWhere(
      (TrayNotificationColor item) => item.name == value,
      orElse: () => fallback,
    );
  }
}

/// User-editable settings with bounded, release-ready defaults.
final class AppSettings {
  const AppSettings({
    this.clipboardMonitoring = false,
    this.language = AppLanguagePreference.system,
    this.themeMode = AppThemePreference.light,
    this.launchAtStartup = false,
    this.hideDockIcon = false,
    this.trayNotificationColor = TrayNotificationColor.orange,
    this.globalHotKey = GlobalHotKey.defaultValue,
    this.workspaceShortcuts = WorkspaceShortcuts.defaultValue,
    this.backgroundOpacity = 0.90,
    this.defaultWorkspace = DefaultWorkspace.today,
    this.clipboardMaxItems = 5000,
    this.clipboardMaxAgeDays = 120,
    this.allowAgentClipboardContent = false,
    this.lifecycleTelemetryEnabled = true,
    this.rememberAgentActivity = true,
    this.groupRepeatedAgentSessions = true,
    this.agentActivityMaxItems = 500,
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
  final bool hideDockIcon;
  final TrayNotificationColor trayNotificationColor;
  final GlobalHotKey globalHotKey;
  final WorkspaceShortcuts workspaceShortcuts;
  final double backgroundOpacity;
  final DefaultWorkspace defaultWorkspace;
  final int clipboardMaxItems;
  final int clipboardMaxAgeDays;
  final bool allowAgentClipboardContent;
  final bool lifecycleTelemetryEnabled;
  final bool rememberAgentActivity;
  final bool groupRepeatedAgentSessions;
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
      hideDockIcon: hideDockIcon,
      trayNotificationColor: trayNotificationColor,
      globalHotKey: globalHotKey.sanitized(),
      workspaceShortcuts: workspaceShortcuts.sanitized(defaultTargetPlatform),
      backgroundOpacity: backgroundOpacity.clamp(0.82, 0.96),
      defaultWorkspace: defaultWorkspace,
      clipboardMaxItems: clipboardMaxItems.clamp(20, 5000),
      clipboardMaxAgeDays: clipboardMaxAgeDays.clamp(1, 730),
      allowAgentClipboardContent: allowAgentClipboardContent,
      lifecycleTelemetryEnabled: lifecycleTelemetryEnabled,
      rememberAgentActivity: rememberAgentActivity,
      groupRepeatedAgentSessions: groupRepeatedAgentSessions,
      agentActivityMaxItems: agentActivityMaxItems.clamp(1, 5000),
      agentActivityCountHours: agentActivityCountHours.clamp(1, 24 * 365),
      selectedSound: _preferenceSoundValues.contains(selectedSound)
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
    bool? hideDockIcon,
    TrayNotificationColor? trayNotificationColor,
    GlobalHotKey? globalHotKey,
    WorkspaceShortcuts? workspaceShortcuts,
    double? backgroundOpacity,
    DefaultWorkspace? defaultWorkspace,
    int? clipboardMaxItems,
    int? clipboardMaxAgeDays,
    bool? allowAgentClipboardContent,
    bool? lifecycleTelemetryEnabled,
    bool? rememberAgentActivity,
    bool? groupRepeatedAgentSessions,
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
      hideDockIcon: hideDockIcon ?? this.hideDockIcon,
      trayNotificationColor:
          trayNotificationColor ?? this.trayNotificationColor,
      globalHotKey: globalHotKey ?? this.globalHotKey,
      workspaceShortcuts: workspaceShortcuts ?? this.workspaceShortcuts,
      backgroundOpacity: backgroundOpacity ?? this.backgroundOpacity,
      defaultWorkspace: defaultWorkspace ?? this.defaultWorkspace,
      clipboardMaxItems: clipboardMaxItems ?? this.clipboardMaxItems,
      clipboardMaxAgeDays: clipboardMaxAgeDays ?? this.clipboardMaxAgeDays,
      allowAgentClipboardContent:
          allowAgentClipboardContent ?? this.allowAgentClipboardContent,
      lifecycleTelemetryEnabled:
          lifecycleTelemetryEnabled ?? this.lifecycleTelemetryEnabled,
      rememberAgentActivity:
          rememberAgentActivity ?? this.rememberAgentActivity,
      groupRepeatedAgentSessions:
          groupRepeatedAgentSessions ?? this.groupRepeatedAgentSessions,
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
