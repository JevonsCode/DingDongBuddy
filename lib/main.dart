import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/app/app_dependencies.dart';
import 'package:dingdong/app/app_locale.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/data/data_revision_bus.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/desktop_window_policy.dart';
import 'package:dingdong/core/platform/windows_auxiliary_window_close_behavior.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/data/agent_launcher_configuration_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:dingdong/features/agent_adapters/data/codex_completion_hook_gateway.dart';
import 'package:dingdong/features/agent_adapters/data/codex_thread_inspector.dart';
import 'package:dingdong/features/agent_adapters/ui/agent_adapter_controller.dart';
import 'package:dingdong/features/agent_api/data/agent_bridge.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/clipboard/data/clipboard_category_rule_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_group_order_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_classifier.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_share_gateway.dart';
import 'package:dingdong/features/clipboard/domain/managed_clipboard_images.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_preview_app.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/device_link/data/device_link_store.dart';
import 'package:dingdong/features/device_link/ui/device_link_controller.dart';
import 'package:dingdong/features/device_link/ui/device_link_manager_app.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/library/data/agent_resource_synchronizer.dart';
import 'package:dingdong/features/library/data/resource_file_service.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_file_service.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/library_view_model_factory.dart';
import 'package:dingdong/features/library/ui/resource_manager_app.dart';
import 'package:dingdong/features/settings/data/http_release_metadata_source.dart';
import 'package:dingdong/features/settings/data/io_system_data_location_gateway.dart';
import 'package:dingdong/features/settings/data/io_system_usage_source.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/settings/domain/system_usage.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:dingdong/features/settings/ui/settings_window_app.dart';
import 'package:dingdong/features/shell/domain/desktop_shell_service.dart';
import 'package:dingdong/features/shell/domain/development_test_action.dart';
import 'package:dingdong/features/shell/domain/tray_buddy_controller.dart';
import 'package:dingdong/features/shell/ui/development_test_panel_app.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
import 'package:dingdong/features/telemetry/data/http_lifecycle_telemetry_gateway.dart';
import 'package:dingdong/features/telemetry/data/lifecycle_telemetry_controller.dart';
import 'package:dingdong/platform/desktop_clipboard_gateway.dart';
import 'package:dingdong/platform/file_selector_sound_gateway.dart';
import 'package:dingdong/platform/multi_window_clipboard_preview_launcher.dart';
import 'package:dingdong/platform/multi_window_development_test_panel_launcher.dart';
import 'package:dingdong/platform/multi_window_device_link_manager.dart';
import 'package:dingdong/platform/multi_window_resource_manager_launcher.dart';
import 'package:dingdong/platform/multi_window_settings_host_bridge.dart';
import 'package:dingdong/platform/multi_window_settings_launcher.dart';
import 'package:dingdong/platform/native_agent_conversation_launcher.dart';
import 'package:dingdong/platform/native_application_updater.dart';
import 'package:dingdong/platform/native_desktop_context_menu_gateway.dart';
import 'package:dingdong/platform/native_launch_at_startup.dart';
import 'package:dingdong/platform/native_menu_bar_recovery_gateway.dart';
import 'package:dingdong/platform/native_notification_gateway.dart';
import 'package:dingdong/platform/native_quick_paste_gateway.dart';
import 'package:dingdong/platform/native_selection_plugin_gateway.dart';
import 'package:dingdong/platform/plugin_desktop_shell_gateway.dart';
import 'package:dingdong/platform/preferences_tray_unread_store.dart';
import 'package:dingdong/platform/shared_preferences_backend.dart';
import 'package:dingdong/platform/url_launcher_clipboard_content_launcher.dart';
import 'package:dingdong/platform/url_launcher_external_link_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as path;
import 'package:window_manager/window_manager.dart';

// Auxiliary engines have independent setup paths. Parts keep those platform
// entry points private while leaving the primary startup sequence readable.
part 'main_clipboard_windows.dart';
part 'main_development_window.dart';
part 'main_resource_window.dart';
part 'main_settings_windows.dart';
part 'main_system_maintenance.dart';

Future<void> main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  final WindowController windowController =
      await WindowController.fromCurrentEngine();
  final Map<String, Object?> windowArguments = decodeDesktopWindowArguments(
    windowController.arguments,
  );
  if (windowArguments['kind'] == deviceLinkManagerWindowKind) {
    await _runDeviceLinkManagerWindow(windowController, windowArguments);
    return;
  }
  if (windowArguments['kind'] == resourceManagerWindowKind) {
    await _runResourceManagerWindow(windowController, windowArguments);
    return;
  }
  if (windowArguments['kind'] == clipboardPreviewWindowKind) {
    await _runClipboardPreviewWindow(windowController, windowArguments);
    return;
  }
  if (windowArguments['kind'] == clipboardQrPreviewWindowKind) {
    await _runClipboardQrPreviewWindow(windowController, windowArguments);
    return;
  }
  if (windowArguments['kind'] == settingsWindowKind) {
    await _runSettingsWindow(windowController, windowArguments);
    return;
  }
  if (windowArguments['kind'] == developmentTestPanelWindowKind) {
    await _runDevelopmentTestPanelWindow(windowController, windowArguments);
    return;
  }

  final AppDataPaths appDataPaths = AppDataPaths.current();
  final bool hadExistingApplicationData = appDataPaths
      .applicationSupportDirectory
      .existsSync();
  final String homeDirectory =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
  final CodexThreadInspector codexThreadInspector = CodexThreadInspector(
    connectionFactory: NativeCodexAppServerConnectionFactory(
      homeDirectory: homeDirectory,
    ),
  );
  final ShellController shellController = ShellController();
  final MultiWindowClipboardPreviewLauncher clipboardPreviewLauncher =
      MultiWindowClipboardPreviewLauncher(
        parentWindowId: windowController.windowId,
      );
  final DesktopContextMenuController desktopContextMenuController =
      DesktopContextMenuController();
  final MultiWindowSettingsLauncher settingsWindowLauncher =
      MultiWindowSettingsLauncher(parentWindowId: windowController.windowId);
  final MultiWindowResourceManagerLauncher resourceManagerLauncher =
      MultiWindowResourceManagerLauncher(
        parentWindowId: windowController.windowId,
      );
  final MultiWindowDeviceLinkManagerLauncher deviceLinkManagerLauncher =
      MultiWindowDeviceLinkManagerLauncher(
        parentWindowId: windowController.windowId,
      );
  final MultiWindowDevelopmentTestPanelLauncher testPanelLauncher =
      MultiWindowDevelopmentTestPanelLauncher(
        parentWindowId: windowController.windowId,
      );
  final SharedPreferencesBackend preferencesBackend =
      SharedPreferencesBackend();
  late final SettingsViewModel settingsViewModel;
  var startupLanguage = AppLanguagePreference.system;
  var settingsViewModelReady = false;
  DingDongLocalizations currentLocalizations() => appLocalizationsFor(
    settingsViewModelReady
        ? settingsViewModel.settings.language
        : startupLanguage,
  );
  final ActivityController activityController = ActivityController(
    store: FileAgentActivityStore(appDataPaths.agentActivityFile),
    localizations: currentLocalizations,
  );
  late final NativeAgentConversationLauncher agentConversationLauncher;
  late final AppDependencies dependencies;
  late final TrayBuddyController trayBuddyController;
  late final DeviceLinkController deviceLinkController;
  final PluginDesktopShellGateway shellGateway = PluginDesktopShellGateway(
    onHideAuxiliaryWindows: () async {
      await desktopContextMenuController.dismissActiveMenu();
      await clipboardPreviewLauncher.hide();
    },
    unreadStore: PreferencesTrayUnreadStore(preferencesBackend),
    clipboardMonitoringState: () =>
        dependencies.clipboardMonitorService.isRunning,
    localizations: currentLocalizations,
    developmentBuild: appDataPaths.development,
  );
  dependencies = await AppDependencies.production(
    preferencesBackend: preferencesBackend,
    onResourceLibraryChanged: shellController.requestLibraryRefresh,
    onCopyDetected: () => unawaited(shellGateway.shakeTrayIcon()),
    onClipboardCaptured: (ClipboardRecord record) {
      trayBuddyController.recordClipboardActivity(record.updatedAt);
      shellController.requestClipboardRefresh();
      unawaited(resourceManagerLauncher.refreshClipboard());
      unawaited(deviceLinkController.handleLocalClipboard(record));
    },
    onAgentTaskStarted: (AgentBridgeTaskStart start) {
      activityController.recordTaskStarted(
        source: start.source,
        task: start.task,
        startedAt: start.startedAt,
        workspacePath: start.workspacePath,
        repositoryUrl: start.repositoryUrl,
        conversationId: start.conversationId,
      );
    },
    onAgentConversationOpened: (AgentConversationTarget target) async {
      final int acknowledged = activityController.markConversationSeen(target);
      await shellGateway.acknowledgeUnreadCount(acknowledged);
      return acknowledged;
    },
    isSubagentConversation: (AgentConversationTarget target) async {
      if (target.client != AgentClient.codex) {
        return false;
      }
      final String threadId = target.conversationId?.trim() ?? '';
      if (threadId.isEmpty) {
        return false;
      }
      return (await codexThreadInspector.inspectThreadId(threadId)).isSubagent;
    },
    isCodexVoiceNotification: (DingRequest request) async {
      final AgentConversationTarget? target = request.conversationTarget;
      if (target == null || target.client != AgentClient.codex) {
        return false;
      }
      final String threadId = target.conversationId?.trim() ?? '';
      if (threadId.isEmpty) {
        return false;
      }
      return (await codexThreadInspector.inspectThreadId(
        threadId,
      )).isRealtimeVoice;
    },
    isSubagentNotification: (DingRequest request) async {
      final AgentConversationTarget? target = request.conversationTarget;
      if (target == null || target.client != AgentClient.codex) {
        return false;
      }
      final String threadId = target.conversationId?.trim() ?? '';
      if (threadId.isEmpty) {
        return false;
      }
      return (await codexThreadInspector.inspectThreadId(threadId)).isSubagent;
    },
    onFilteredNotification: (DingRequest request) async {
      activityController.discardActiveRun(
        source: request.source ?? 'Agent',
        target: request.conversationTarget,
      );
    },
    onNotification: (request) async {
      final AgentCompletionRecord completion = activityController.record(
        source: request.source ?? 'Agent',
        message: request.message,
        detail: request.detail,
        completedAt: request.receivedAt,
        conversationTarget: request.conversationTarget,
        notificationKind: request.notificationKind,
        tokenUsage: request.tokenUsage,
      );
      final target = request.conversationTarget;
      if (target != null) {
        unawaited(
          agentConversationLauncher.preflight(<AgentConversationTarget>[
            target,
          ]),
        );
      }
      await shellGateway.markUnread();
      await deviceLinkController.sendAgentCompleted(
        request,
        activity: completion.activity,
        notificationId: completion.notificationId,
      );
    },
    onSuppressedNotification: (request) async {
      final target = request.conversationTarget;
      if (target != null || !activityController.groupRepeatedAgentSessions) {
        activityController.recordRepeat(
          source: request.source ?? 'Agent',
          message: request.message,
          target: target,
          notificationKind: request.notificationKind,
          tokenUsage: request.tokenUsage,
        );
      }
      if (target != null) {
        unawaited(
          agentConversationLauncher.preflight(<AgentConversationTarget>[
            target,
          ]),
        );
      }
    },
    onShowUi: (int index) {
      shellController.requestLibraryRefresh();
      if (index == 4) {
        unawaited(settingsWindowLauncher.show());
        return;
      }
      shellController.open(index);
      unawaited(shellGateway.showAndFocus());
    },
  );
  final AppSettings startupSettings = dependencies.initialSettings;
  startupLanguage = startupSettings.language;
  deviceLinkController = DeviceLinkController(
    store: FileDeviceLinkStore(appDataPaths.deviceLinksFile),
    clipboardStore: dependencies.clipboardStore,
    transferDirectory: appDataPaths.deviceTransferDirectory,
    pwaBaseUrl: _configuredUri(
      const String.fromEnvironment(
        'DINGDONG_PWA_BASE_URL',
        defaultValue: 'https://dingdong.xn--m8txu.com/app/',
      ),
    ),
    relayBaseUrl: _configuredUri(
      const String.fromEnvironment(
        'DINGDONG_RELAY_URL',
        defaultValue: 'https://dingdong.xn--m8txu.com',
      ),
    ),
    systemClipboard: dependencies.clipboardGateway,
    localizations: currentLocalizations,
    agentStateProvider: () => (
      activities: activityController.activities,
      activeRuns: activityController.activeRuns,
    ),
    onAgentSeen: (List<String> activityIds) {
      final int acknowledged = activityController.markSeen(activityIds);
      unawaited(shellGateway.acknowledgeUnreadCount(acknowledged));
    },
    onClipboardReceived: () {
      shellController.requestClipboardRefresh();
      unawaited(resourceManagerLauncher.refreshClipboard());
    },
  );
  await deviceLinkController.start();
  activityController.addListener(() {
    unawaited(deviceLinkController.syncAgentState());
  });
  deviceLinkController.addListener(() {
    unawaited(deviceLinkManagerLauncher.refresh());
  });
  final LifecycleTelemetryController lifecycleTelemetryController =
      LifecycleTelemetryController(
        preferences: preferencesBackend,
        gateway: HttpLifecycleTelemetryGateway(),
        currentVersion: currentAppVersion,
        currentBuild: currentAppBuild,
        platform: Platform.isMacOS ? 'macos' : 'windows',
        architecture: _lifecycleTelemetryArchitecture(),
        hadExistingApplicationData: hadExistingApplicationData,
        disabled: appDataPaths.development,
      );
  agentConversationLauncher = NativeAgentConversationLauncher(
    codexConversationPreflightBatch: codexThreadInspector.inspectThreadIds,
    configurationLoader: FileAgentLauncherConfigurationStore(
      dependencies.paths.agentLaunchersFile,
    ).load,
  );
  activityController.configure(
    rememberAcrossRestarts: startupSettings.rememberAgentActivity,
    maxItems: startupSettings.agentActivityMaxItems,
    countWindowHours: startupSettings.agentActivityCountHours,
    groupRepeatedAgentSessions: startupSettings.groupRepeatedAgentSessions,
  );
  activityController.load(resetPreviousSession: true);
  trayBuddyController = TrayBuddyController(
    activityController: activityController,
    onStateChanged: (TrayBuddyState state) async {
      shellController.setMascotState(state);
      await shellGateway.setTrayBuddyState(state);
    },
    onReminderNudge: shellGateway.nudgeTrayIcon,
  );
  unawaited(
    agentConversationLauncher.preflight(
      activityController.activities
          .map((AgentActivity activity) => activity.conversationTarget)
          .whereType<AgentConversationTarget>(),
    ),
  );
  await dependencies.start();
  shellController.open(dependencies.initialSettings.defaultWorkspace.index);
  final NativeQuickPasteGateway quickPasteGateway = NativeQuickPasteGateway();
  const NativeSelectionPluginGateway selectionPluginGateway =
      NativeSelectionPluginGateway();
  final NativeLaunchAtStartup launchAtStartup = NativeLaunchAtStartup();
  final NativeNotificationGateway notificationGateway =
      NativeNotificationGateway();
  const NativeApplicationUpdater applicationUpdater =
      NativeApplicationUpdater();
  settingsViewModel = SettingsViewModel(
    dependencies.settingsRepository,
    clipboardMonitoring: dependencies.clipboardMonitorService,
    launchAtStartup: launchAtStartup,
    onWindowOpacityChanged: shellGateway.setOpacity,
    onDockIconHiddenChanged: shellGateway.setDockIconHidden,
    onShowMenuBarRecovery: const NativeMenuBarRecoveryGateway().show,
    onTrayNotificationColorChanged: shellGateway.setTrayNotificationColor,
    onGlobalHotKeyChanged: shellGateway.setGlobalHotKey,
    onLifecycleTelemetryChanged: lifecycleTelemetryController.setEnabled,
    releaseMetadataSource: HttpReleaseMetadataSource(),
    externalLinkGateway: UrlLauncherExternalLinkGateway(),
    applicationUpdater: applicationUpdater,
    quickPastePermissionGateway: quickPasteGateway,
    selectionPluginGateway: Platform.isMacOS ? selectionPluginGateway : null,
    mcpCommandPath: _mcpCommandPath(),
    systemUsageSource: IoSystemUsageSource(
      dependencies.paths.applicationSupportDirectory,
    ),
    systemDataLocationGateway: IoSystemDataLocationGateway(
      dependencies.paths.applicationSupportDirectory,
    ),
  );
  await settingsViewModel.load();
  settingsViewModelReady = true;
  settingsViewModel.startBackgroundReleaseUpdateChecks();
  unawaited(settingsViewModel.checkForUpdates());
  final DesktopShellService desktopShellService = DesktopShellService(
    gateway: shellGateway,
    controller: shellController,
    activityController: activityController,
    defaultWorkspaceIndex: () =>
        settingsViewModel.settings.defaultWorkspace.index,
    onClipboardMonitoringChanged: settingsViewModel.setClipboardMonitoring,
    onClearClipboardHistory: () => _clearClipboardHistory(dependencies),
    onShowResourceManager: () async {
      await shellGateway.hide();
      await resourceManagerLauncher.show();
    },
    onShowSettings: () async {
      await shellGateway.hide();
      await settingsWindowLauncher.show();
    },
    onShowAbout: () async {
      await shellGateway.hide();
      await settingsWindowLauncher.show(
        destination: SettingsWindowDestination.version,
      );
    },
    onShowDeviceLinks: () async {
      await shellGateway.hide();
      await deviceLinkManagerLauncher.show();
    },
    onShowTestPanel: appDataPaths.development
        ? () async {
            await shellGateway.hide();
            await testPanelLauncher.show();
          }
        : null,
    onHideDockIcon: () => settingsViewModel.setHideDockIcon(true),
    onQuickPastePermissionGrantPresentationStarted:
        settingsViewModel.beginQuickPastePermissionGrantPresentation,
    onQuickPastePermissionGranted: () async {
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await settingsViewModel.completeQuickPastePermissionGrantPresentation();
    },
  );
  await desktopShellService.start();
  trayBuddyController.start(
    lastClipboardActivity: dependencies.clipboardStore.latestUpdatedAt(),
  );
  Future<Object?> handleChildWindowCall(MethodCall call) async {
    if (isDeviceLinkManagerHostMethod(call.method)) {
      return handleDeviceLinkManagerHostCall(deviceLinkController, call);
    }
    switch (call.method) {
      case 'settings_launch_is_enabled':
        return await launchAtStartup.isEnabled();
      case 'settings_launch_set':
        final Map<Object?, Object?> values = call.arguments! as Map;
        await launchAtStartup.setEnabled(values['enabled']! as bool);
        return null;
      case 'settings_quick_is_granted':
        return await quickPasteGateway.isGranted();
      case 'settings_quick_open':
        await quickPasteGateway.openSettings();
        return null;
      case 'settings_selection_apply':
        final Map<Object?, Object?> values = call.arguments! as Map;
        return (await selectionPluginGateway.apply(
          SelectionPluginConfiguration(
            enabled: values['enabled'] == true,
            provider: SelectionModelProvider.parse(values['provider']),
            endpoint: values['endpoint']! as String,
            model: values['model']! as String,
            targetLanguage: values['targetLanguage']! as String,
            unloadLocalModelAfterResponse:
                values['unloadLocalModelAfterResponse'] == true,
          ),
        )).toPlatformResult();
      case 'settings_selection_status':
        return (await selectionPluginGateway.status()).toPlatformResult();
      case 'settings_selection_open_accessibility':
        await selectionPluginGateway.openAccessibilitySettings();
        return null;
      case 'settings_selection_token_save':
        final Map<Object?, Object?> values = call.arguments! as Map;
        await selectionPluginGateway.saveToken(values['token']! as String);
        return null;
      case 'settings_selection_token_clear':
        await selectionPluginGateway.clearToken();
        return null;
      case 'settings_clipboard_start':
        await dependencies.clipboardMonitorService.start();
        return null;
      case 'settings_clipboard_stop':
        await dependencies.clipboardMonitorService.stop();
        return null;
      case 'settings_opacity_set':
        final Map<Object?, Object?> values = call.arguments! as Map;
        await shellGateway.setOpacity((values['value']! as num).toDouble());
        return null;
      case 'settings_dock_icon_set':
        final Map<Object?, Object?> values = call.arguments! as Map;
        await shellGateway.setDockIconHidden(values['hidden']! as bool);
        return null;
      case 'settings_tray_notification_color_set':
        final Map<Object?, Object?> values = call.arguments! as Map;
        await shellGateway.setTrayNotificationColor(
          TrayNotificationColor.parse(values['color']),
        );
        return null;
      case 'settings_global_hot_key_set':
        final Map<Object?, Object?> values = call.arguments! as Map;
        return shellGateway.setGlobalHotKey(
          GlobalHotKey(
            key: values['key']! as String,
            primary: values['primary']! as bool,
            shift: values['shift']! as bool,
            alt: values['alt']! as bool,
            secondary: values['secondary']! as bool,
          ),
        );
      case 'settings_changed':
        await settingsViewModel.reload();
        unawaited(
          lifecycleTelemetryController.setEnabled(
            settingsViewModel.settings.lifecycleTelemetryEnabled,
          ),
        );
        dependencies.applyClipboardRetention(settingsViewModel.settings);
        activityController.configure(
          rememberAcrossRestarts:
              settingsViewModel.settings.rememberAgentActivity,
          maxItems: settingsViewModel.settings.agentActivityMaxItems,
          countWindowHours: settingsViewModel.settings.agentActivityCountHours,
          groupRepeatedAgentSessions:
              settingsViewModel.settings.groupRepeatedAgentSessions,
        );
        return null;
      case 'settings_sound_preview':
        final Map<Object?, Object?> values = call.arguments! as Map;
        await notificationGateway.preview(
          sound: values['sound']! as String,
          customSoundPath: values['customSoundPath'] as String?,
        );
        return null;
      case 'settings_restart':
        unawaited(
          _restartApplication(
            dependencies: dependencies,
            desktopShellService: desktopShellService,
            settingsViewModel: settingsViewModel,
          ),
        );
        return null;
      case 'settings_update_supported':
        return applicationUpdater.isSupported();
      case 'settings_update_state':
        return (await applicationUpdater.readStatus()).toJson();
      case 'settings_update_install':
        await applicationUpdater.installLatest();
        return null;
      case developmentTestRunMethod:
        if (!appDataPaths.development) {
          throw UnsupportedError('DEV test panel is unavailable.');
        }
        final Map<Object?, Object?> values = call.arguments! as Map;
        final DevelopmentTestAction? action = DevelopmentTestAction.fromId(
          values['action'],
        );
        if (action == null) {
          throw ArgumentError.value(values['action'], 'action');
        }
        await _runDevelopmentTestAction(
          action: action,
          strings: appLocalizationsFor(settingsViewModel.settings.language),
          dependencies: dependencies,
          shellGateway: shellGateway,
          shellController: shellController,
          trayBuddyController: trayBuddyController,
          deviceLinkController: deviceLinkController,
          deviceLinkManagerLauncher: deviceLinkManagerLauncher,
          resourceManagerLauncher: resourceManagerLauncher,
        );
        return null;
      case developmentTestTraySleepingMethod:
        if (!appDataPaths.development) {
          throw UnsupportedError('DEV test panel is unavailable.');
        }
        await shellGateway.previewTrayBuddyState(TrayBuddyState.sleeping);
        return null;
      case developmentTestTrayNudgeMethod:
        if (!appDataPaths.development) {
          throw UnsupportedError('DEV test panel is unavailable.');
        }
        await shellGateway.nudgeTrayIcon();
        return null;
      case 'settings_system_data_clear':
        final Map<Object?, Object?> values = call.arguments! as Map;
        final List<String> requested = (values['categories']! as List)
            .whereType<String>()
            .toList(growable: false);
        final Set<SystemDataCategory> categories = requested
            .map(systemDataCategoryFromId)
            .whereType<SystemDataCategory>()
            .toSet();
        if (categories.length != requested.length ||
            categories.any(
              (SystemDataCategory category) => !category.canClear,
            )) {
          throw ArgumentError.value(requested, 'categories');
        }
        await _clearSelectedSystemData(
          categories: categories,
          dependencies: dependencies,
          activityController: activityController,
          shellController: shellController,
        );
        return null;
      case agentResourceIssuesChangedMethod:
        final List<Object?> values =
            (call.arguments as List<Object?>?) ?? const <Object?>[];
        dependencies.issueCenterController.replaceSource(
          agentResourceSyncIssueSource,
          values.whereType<Map<Object?, Object?>>().map(AppIssue.fromJson),
        );
        return null;
      case agentResourceIssuesRequestedMethod:
        return dependencies.issueCenterController.issues
            .map((AppIssue issue) => issue.toJson())
            .toList(growable: false);
      case resourceLibraryChangedMethod:
        shellController.requestLibraryRefresh();
        return null;
      case deviceLinkShareRecordMethod:
        final Map<Object?, Object?> values = call.arguments! as Map;
        deviceLinkController.requestShare(
          clipboardRecordFromWindowJson(
            values['record']! as Map<Object?, Object?>,
          ),
        );
        await clipboardPreviewLauncher.hide();
        await shellGateway.showAndFocus();
        return null;
      default:
        break;
    }
    return null;
  }

  await windowController.setWindowMethodHandler(handleChildWindowCall);
  runApp(
    DingDongApp(
      activityController: activityController,
      developmentBuild: appDataPaths.development,
      agentConversationLauncher: agentConversationLauncher,
      agentBaseUri: dependencies.agentHttpServer.baseUri,
      clipboardCaptureService: dependencies.clipboardCaptureService,
      clipboardCategoryRuleStore: dependencies.clipboardCategoryRuleStore,
      clipboardGroupOrderStore: dependencies.clipboardGroupOrderStore,
      clipboardGateway: dependencies.clipboardGateway,
      desktopContextMenuGateway: Platform.isMacOS
          ? NativeDesktopContextMenuGateway()
          : null,
      desktopContextMenuController: desktopContextMenuController,
      clipboardImageStoreDirectory: dependencies.paths.clipboardImagesDirectory,
      clipboardMonitoring: dependencies.clipboardMonitorService,
      clipboardStore: dependencies.clipboardStore,
      clipboardArchiveStore: dependencies.clipboardStore,
      clipboardPreviewLauncher: clipboardPreviewLauncher,
      clipboardShareGateway: DeviceClipboardShareGateway(deviceLinkController),
      deviceLinkController: deviceLinkController,
      deviceLinkManagerLauncher: deviceLinkManagerLauncher,
      quickPasteGateway: quickPasteGateway,
      quickPastePermissionGateway: quickPasteGateway,
      resourceStore: dependencies.resourceStore,
      issueCenterController: dependencies.issueCenterController,
      triggerGroupStore: dependencies.triggerGroupStore,
      resourceManagerLauncher: resourceManagerLauncher,
      settingsWindowLauncher: settingsWindowLauncher,
      settingsViewModel: settingsViewModel,
      soundPreviewGateway: notificationGateway,
      onStartDragging: shellGateway.startDragging,
      onHideWindow: shellGateway.hide,
      shortcutHints: shellGateway.shortcutHints,
      windowVisible: shellGateway.windowVisible,
      shellController: shellController,
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  unawaited(
    lifecycleTelemetryController.setEnabled(
      startupSettings.lifecycleTelemetryEnabled,
    ),
  );
}
