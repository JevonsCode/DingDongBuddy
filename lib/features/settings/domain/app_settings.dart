import 'package:dingdong/core/utils/text.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/agent_api/domain/agent_setup_revision.dart';
import 'package:dingdong/features/agent_api/domain/conversation_footer_symbols.dart';
import 'package:dingdong/features/selection/domain/selection_plugin_configuration.dart';
import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:dingdong/features/settings/domain/notification_rules.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';
import 'package:dingdong/features/settings/domain/tray_reminder_style.dart';
import 'package:dingdong/features/settings/domain/workspace_shortcuts.dart';
import 'package:flutter/foundation.dart';

export 'package:dingdong/features/settings/domain/reminder_profile.dart';

export 'package:dingdong/features/settings/domain/tray_reminder_style.dart';

/// Language choice persisted independently from the current system locale.
enum AppLanguagePreference {
  system(null),
  english('en'),
  chinese('zh'),
  spanish('es');

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

/// How a hidden macOS menu-bar badge emerges from the camera housing.
enum NotchBubbleDirection {
  off,
  down,
  left;

  static NotchBubbleDirection parse(Object? value) =>
      value == 'off' ? NotchBubbleDirection.off : NotchBubbleDirection.left;
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

/// User-editable settings with bounded, release-ready defaults.
final class AppSettings {
  const AppSettings({
    this.clipboardMonitoring = false,
    this.language = AppLanguagePreference.system,
    this.themeMode = AppThemePreference.light,
    this.launchAtStartup = false,
    this.hideDockIcon = false,
    this.notchBubbleDirection = NotchBubbleDirection.left,
    this.trayNotificationColor = TrayNotificationColor.orange,
    this.globalHotKey = GlobalHotKey.defaultValue,
    this.workspaceShortcuts = WorkspaceShortcuts.defaultValue,
    this.backgroundOpacity = 0.90,
    this.defaultWorkspace = DefaultWorkspace.today,
    this.clipboardMaxItems = 5000,
    this.clipboardMaxAgeDays = 120,
    this.allowAgentClipboardContent = false,
    this.lifecycleTelemetryEnabled = true,
    this.allowBetaUpdates = false,
    this.rememberAgentActivity = true,
    this.notifyAgentCompletion = true,
    this.notifyAgentAttention = true,
    this.notifyCodexVoiceActivity = false,
    this.notifySubagentActivity = false,
    this.notificationRules = NotificationRules.defaultValue,
    this.groupRepeatedAgentSessions = true,
    this.showConversationTokenUsage = true,
    this.agentActivityMaxItems = 500,
    this.agentActivityCountHours = 24,
    this.quickPanelAgentCount = 21,
    this.conversationFooterSymbols = ConversationFooterSymbols.defaultValue,
    this.selectedSound = 'default',
    this.customSoundPath,
    this.mcpAccessSeen = false,
    this.agentSetupAcknowledgedRevision = currentAgentSetupRevision,
    this.apiPort = 2333,
    this.selectionPlugin = const SelectionPluginConfiguration(),
  });

  final bool clipboardMonitoring;
  final AppLanguagePreference language;
  final AppThemePreference themeMode;
  final bool launchAtStartup;
  final bool hideDockIcon;
  final NotchBubbleDirection notchBubbleDirection;
  final TrayNotificationColor trayNotificationColor;
  final GlobalHotKey globalHotKey;
  final WorkspaceShortcuts workspaceShortcuts;
  final double backgroundOpacity;
  final DefaultWorkspace defaultWorkspace;
  final int clipboardMaxItems;
  final int clipboardMaxAgeDays;
  final bool allowAgentClipboardContent;
  final bool lifecycleTelemetryEnabled;

  /// Lets the updater offer beta releases newer than the latest stable one.
  final bool allowBetaUpdates;
  final bool rememberAgentActivity;
  final bool notifyAgentCompletion;
  final bool notifyAgentAttention;
  final bool notifyCodexVoiceActivity;
  final bool notifySubagentActivity;
  final NotificationRules notificationRules;
  final bool groupRepeatedAgentSessions;
  final bool showConversationTokenUsage;
  final int agentActivityMaxItems;
  final int agentActivityCountHours;
  final int quickPanelAgentCount;
  final ConversationFooterSymbols conversationFooterSymbols;
  final String selectedSound;
  final String? customSoundPath;
  final bool mcpAccessSeen;
  final int agentSetupAcknowledgedRevision;
  final int apiPort;
  final SelectionPluginConfiguration selectionPlugin;

  /// Legacy settings stay authoritative for the two built-ins, so upgrades
  /// and older integrations preserve existing preferences without duplication.
  List<ReminderProfile> get reminderProfiles =>
      notificationRules.orderProfiles([
        for (final kind in AgentNotificationKind.values)
          ReminderProfile(
            id: kind.apiValue,
            name: kind.apiValue,
            enabled: kind == AgentNotificationKind.attention
                ? notifyAgentAttention
                : notifyAgentCompletion,
            kind: kind,
            style: notificationRules.trayStyleFor(kind),
            color: notificationRules.trayColorFor(
              kind,
              legacyCompletionColor: trayNotificationColor,
            ),
            sound: soundFor(kind),
            customSoundPath: customSoundPathFor(kind),
            toPhone: kind == AgentNotificationKind.attention
                ? notificationRules.attentionToPhone
                : notificationRules.completionToPhone,
          ),
        ...notificationRules.profiles,
      ]);
  ReminderProfile? reminderProfile(String? id) {
    for (final profile in reminderProfiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  AppSettings withReminderProfile(ReminderProfile profile) {
    if (profile.builtIn) {
      final attention = profile.id == 'attention';
      return copyWith(
        notifyAgentAttention: attention ? profile.enabled : null,
        notifyAgentCompletion: attention ? null : profile.enabled,
        selectedSound: attention ? null : profile.sound,
        customSoundPath: attention ? customSoundPath : profile.customSoundPath,
        notificationRules: attention
            ? notificationRules.copyWith(
                attentionSound:
                    notificationRules.attentionSound == sameAsCompletionSound &&
                        profile.sound == selectedSound &&
                        profile.customSoundPath == customSoundPath
                    ? sameAsCompletionSound
                    : profile.sound,
                attentionCustomSoundPath: profile.customSoundPath,
                attentionTrayStyle: profile.style,
                attentionTrayColor: profile.color,
                attentionToPhone: profile.toPhone,
              )
            : notificationRules.copyWith(
                completionTrayStyle: profile.style,
                completionTrayColor: profile.color,
                completionToPhone: profile.toPhone,
              ),
      );
    }
    final profiles = [...notificationRules.profiles];
    final index = profiles.indexWhere((x) => x.id == profile.id);
    if (index < 0) {
      if (profiles.length >= 32) {
        throw const FormatException('Maximum 32 custom reminders.');
      }
      profiles.add(profile);
    } else {
      profiles[index] = profile;
    }
    return copyWith(
      notificationRules: notificationRules.copyWith(profiles: profiles),
    );
  }

  AppSettings withoutReminderProfile(String id) {
    if (id == 'completion' || id == 'attention') {
      throw const FormatException(
        'Disable built-in reminders instead of deleting them.',
      );
    }
    return copyWith(
      notificationRules: notificationRules.copyWith(
        profiles: notificationRules.profiles.where((x) => x.id != id).toList(),
      ),
    );
  }

  /// Saved sound for one reminder kind, before any API-supplied override.
  String soundFor(AgentNotificationKind kind) =>
      kind == AgentNotificationKind.attention &&
          notificationRules.attentionSound != sameAsCompletionSound
      ? notificationRules.attentionSound
      : selectedSound;

  String? customSoundPathFor(AgentNotificationKind kind) =>
      kind == AgentNotificationKind.attention &&
          notificationRules.attentionSound != sameAsCompletionSound
      ? notificationRules.attentionCustomSoundPath
      : customSoundPath;

  /// Applies sounds an Agent saved because the user asked it to, for example
  /// "ring X when you finish and Y when you need me". [attention] also
  /// accepts [sameAsCompletionSound]. Throws [FormatException] for anything
  /// outside [agentSelectableSoundValues].
  AppSettings withReminderSounds({String? completion, String? attention}) {
    if (completion != null &&
        !agentSelectableSoundValues.contains(completion)) {
      throw FormatException('Unsupported completion sound: $completion');
    }
    if (attention != null &&
        attention != sameAsCompletionSound &&
        !agentSelectableSoundValues.contains(attention)) {
      throw FormatException('Unsupported attention sound: $attention');
    }
    return copyWith(
      selectedSound: completion,
      notificationRules: attention == null
          ? null
          : notificationRules.copyWith(attentionSound: attention),
    );
  }

  bool get requiresAgentSetupUpdate =>
      agentSetupAcknowledgedRevision < currentAgentSetupRevision;

  AppSettings sanitized() {
    return AppSettings(
      clipboardMonitoring: clipboardMonitoring,
      language: language,
      themeMode: themeMode,
      launchAtStartup: launchAtStartup,
      hideDockIcon: hideDockIcon,
      notchBubbleDirection: notchBubbleDirection,
      trayNotificationColor: trayNotificationColor,
      globalHotKey: globalHotKey.sanitized(),
      workspaceShortcuts: workspaceShortcuts.sanitized(defaultTargetPlatform),
      backgroundOpacity: backgroundOpacity.clamp(0.82, 0.96),
      defaultWorkspace: defaultWorkspace,
      clipboardMaxItems: clipboardMaxItems.clamp(20, 5000),
      clipboardMaxAgeDays: clipboardMaxAgeDays.clamp(1, 730),
      allowAgentClipboardContent: allowAgentClipboardContent,
      lifecycleTelemetryEnabled: lifecycleTelemetryEnabled,
      allowBetaUpdates: allowBetaUpdates,
      rememberAgentActivity: rememberAgentActivity,
      notifyAgentCompletion: notifyAgentCompletion,
      notifyAgentAttention: notifyAgentAttention,
      notifyCodexVoiceActivity: notifyCodexVoiceActivity,
      notifySubagentActivity: notifySubagentActivity,
      notificationRules: notificationRules.sanitized(),
      groupRepeatedAgentSessions: groupRepeatedAgentSessions,
      showConversationTokenUsage: showConversationTokenUsage,
      agentActivityMaxItems: agentActivityMaxItems.clamp(1, 5000),
      agentActivityCountHours: agentActivityCountHours.clamp(1, 24 * 365),
      quickPanelAgentCount: quickPanelAgentCount.clamp(1, 500),
      conversationFooterSymbols: conversationFooterSymbols.sanitized(),
      selectedSound: notificationSoundValues.contains(selectedSound)
          ? selectedSound
          : 'default',
      customSoundPath: trimmedOrNull(customSoundPath),
      mcpAccessSeen: mcpAccessSeen,
      agentSetupAcknowledgedRevision: agentSetupAcknowledgedRevision < 0
          ? 0
          : agentSetupAcknowledgedRevision,
      apiPort: apiPort >= 1024 && apiPort <= 65535 ? apiPort : 2333,
      selectionPlugin: selectionPlugin.sanitized(),
    );
  }

  AppSettings copyWith({
    bool? clipboardMonitoring,
    AppLanguagePreference? language,
    AppThemePreference? themeMode,
    bool? launchAtStartup,
    bool? hideDockIcon,
    NotchBubbleDirection? notchBubbleDirection,
    TrayNotificationColor? trayNotificationColor,
    GlobalHotKey? globalHotKey,
    WorkspaceShortcuts? workspaceShortcuts,
    double? backgroundOpacity,
    DefaultWorkspace? defaultWorkspace,
    int? clipboardMaxItems,
    int? clipboardMaxAgeDays,
    bool? allowAgentClipboardContent,
    bool? lifecycleTelemetryEnabled,
    bool? allowBetaUpdates,
    bool? rememberAgentActivity,
    bool? notifyAgentCompletion,
    bool? notifyAgentAttention,
    bool? notifyCodexVoiceActivity,
    bool? notifySubagentActivity,
    NotificationRules? notificationRules,
    bool? groupRepeatedAgentSessions,
    bool? showConversationTokenUsage,
    int? agentActivityMaxItems,
    int? agentActivityCountHours,
    int? quickPanelAgentCount,
    ConversationFooterSymbols? conversationFooterSymbols,
    String? selectedSound,
    Object? customSoundPath = _notSet,
    bool? mcpAccessSeen,
    int? agentSetupAcknowledgedRevision,
    int? apiPort,
    SelectionPluginConfiguration? selectionPlugin,
  }) {
    return AppSettings(
      clipboardMonitoring: clipboardMonitoring ?? this.clipboardMonitoring,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      launchAtStartup: launchAtStartup ?? this.launchAtStartup,
      hideDockIcon: hideDockIcon ?? this.hideDockIcon,
      notchBubbleDirection: notchBubbleDirection ?? this.notchBubbleDirection,
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
      allowBetaUpdates: allowBetaUpdates ?? this.allowBetaUpdates,
      rememberAgentActivity:
          rememberAgentActivity ?? this.rememberAgentActivity,
      notifyAgentCompletion:
          notifyAgentCompletion ?? this.notifyAgentCompletion,
      notifyAgentAttention: notifyAgentAttention ?? this.notifyAgentAttention,
      notifyCodexVoiceActivity:
          notifyCodexVoiceActivity ?? this.notifyCodexVoiceActivity,
      notifySubagentActivity:
          notifySubagentActivity ?? this.notifySubagentActivity,
      notificationRules: notificationRules ?? this.notificationRules,
      groupRepeatedAgentSessions:
          groupRepeatedAgentSessions ?? this.groupRepeatedAgentSessions,
      showConversationTokenUsage:
          showConversationTokenUsage ?? this.showConversationTokenUsage,
      agentActivityMaxItems:
          agentActivityMaxItems ?? this.agentActivityMaxItems,
      agentActivityCountHours:
          agentActivityCountHours ?? this.agentActivityCountHours,
      quickPanelAgentCount: quickPanelAgentCount ?? this.quickPanelAgentCount,
      conversationFooterSymbols:
          conversationFooterSymbols ?? this.conversationFooterSymbols,
      selectedSound: selectedSound ?? this.selectedSound,
      customSoundPath: identical(customSoundPath, _notSet)
          ? this.customSoundPath
          : customSoundPath as String?,
      mcpAccessSeen: mcpAccessSeen ?? this.mcpAccessSeen,
      agentSetupAcknowledgedRevision:
          agentSetupAcknowledgedRevision ?? this.agentSetupAcknowledgedRevision,
      apiPort: apiPort ?? this.apiPort,
      selectionPlugin: selectionPlugin ?? this.selectionPlugin,
    ).sanitized();
  }
}

const Object _notSet = Object();
