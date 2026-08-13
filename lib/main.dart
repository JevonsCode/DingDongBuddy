import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/app/app_dependencies.dart';
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
  final ActivityController activityController = ActivityController(
    store: FileAgentActivityStore(appDataPaths.agentActivityFile),
  );
  late final NativeAgentConversationLauncher agentConversationLauncher;
  late final AppDependencies dependencies;
  late final SettingsViewModel settingsViewModel;
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
    useChineseLabels: () =>
        _usesChineseLabels(settingsViewModel.settings.language),
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
    onNotification: (request) async {
      final AgentCompletionRecord completion = activityController.record(
        source: request.source ?? 'Agent',
        message: request.message,
        detail: request.detail,
        completedAt: request.receivedAt,
        conversationTarget: request.conversationTarget,
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
    agentStateProvider: () => (
      activities: activityController.activities,
      activeRuns: activityController.activeRuns,
    ),
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
  final AppSettings startupSettings = await dependencies.settingsRepository
      .load();
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
    mcpCommandPath: _mcpCommandPath(),
    systemUsageSource: IoSystemUsageSource(
      dependencies.paths.applicationSupportDirectory,
    ),
  );
  await settingsViewModel.load();
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
    lastClipboardActivity: _latestClipboardCapture(dependencies.clipboardStore),
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

bool _usesChineseLabels(AppLanguagePreference language) {
  return switch (language) {
    AppLanguagePreference.chinese => true,
    AppLanguagePreference.english => false,
    AppLanguagePreference.system =>
      Platform.localeName.toLowerCase().startsWith('zh'),
  };
}

Uri? _configuredUri(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final Uri? uri = Uri.tryParse(trimmed);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty ? uri : null;
}

String _lifecycleTelemetryArchitecture() {
  final String abi = ffi.Abi.current().toString().toLowerCase();
  if (abi.contains('arm64')) return 'arm64';
  if (abi.contains('x64')) return 'x64';
  if (abi.contains('ia32')) return 'x86';
  return 'other';
}

DateTime? _latestClipboardCapture(ClipboardStore store) {
  DateTime? latest;
  for (final ClipboardRecord record in store.list(
    limit: 5000,
    includeProtectedBeyondLimit: true,
  )) {
    if (latest == null || record.updatedAt.isAfter(latest)) {
      latest = record.updatedAt;
    }
  }
  return latest;
}

Future<void> _clearClipboardHistory(AppDependencies dependencies) async {
  dependencies.clipboardStore.deleteAll();
  final Directory imageDirectory = dependencies.paths.clipboardImagesDirectory;
  await imageDirectory.create(recursive: true);
  pruneUnreferencedManagedClipboardImages(
    dependencies.clipboardStore.listArchives().map(
      (ClipboardArchiveEntry entry) => entry.record,
    ),
    imageDirectory,
  );
}

Future<void> _clearSelectedSystemData({
  required Set<SystemDataCategory> categories,
  required AppDependencies dependencies,
  required ActivityController activityController,
  required ShellController shellController,
}) async {
  final Set<ClipboardKind> clipboardKinds = <ClipboardKind>{
    if (categories.contains(SystemDataCategory.clipboardImages))
      ClipboardKind.image,
    if (categories.contains(SystemDataCategory.clipboardFiles))
      ClipboardKind.file,
    if (categories.contains(SystemDataCategory.clipboardText))
      ...ClipboardKind.values.where(
        (ClipboardKind kind) =>
            kind != ClipboardKind.image && kind != ClipboardKind.file,
      ),
  };
  if (clipboardKinds.isNotEmpty) {
    dependencies.clipboardStore.deleteHistoryKinds(clipboardKinds);
    final List<ClipboardRecord> preserved = <ClipboardRecord>[
      ...dependencies.clipboardStore.list(
        limit: 5000,
        includeProtectedBeyondLimit: true,
      ),
      ...dependencies.clipboardStore.listArchives().map(
        (ClipboardArchiveEntry entry) => entry.record,
      ),
    ];
    pruneUnreferencedManagedClipboardImages(
      preserved,
      dependencies.paths.clipboardImagesDirectory,
    );
    shellController.requestClipboardRefresh();
  }
  if (categories.contains(SystemDataCategory.agentActivity)) {
    activityController.clear();
  }
  if (categories.contains(SystemDataCategory.adapterHistory)) {
    final Directory history = dependencies.paths.agentAdapterHistoryDirectory;
    if (await history.exists()) {
      await history.delete(recursive: true);
    }
    await history.create(recursive: true);
  }
}

Future<void> _runDeviceLinkManagerWindow(
  WindowController windowController,
  Map<String, Object?> arguments,
) async {
  final String parentWindowId = arguments['parentWindowId']! as String;
  final RemoteDeviceLinkManagement controller = RemoteDeviceLinkManagement(
    parentController: WindowController.fromWindowId(parentWindowId),
  );
  await controller.reload();
  final AppSettings settings = await SettingsRepository(
    SharedPreferencesBackend(),
  ).load();
  final bool chinese = _usesChineseLabels(settings.language);

  await windowManager.ensureInitialized();
  await preventWindowsAuxiliaryWindowClose();
  final WindowOptions options = WindowOptions(
    size: const Size(820, 720),
    minimumSize: const Size(620, 580),
    center: true,
    skipTaskbar: desktopWindowSkipsTaskbar(
      defaultTargetPlatform,
      hideDockIcon: settings.hideDockIcon,
      fallback: false,
    ),
    title: chinese ? 'DingDong · 连接设备' : 'DingDong · Connected Devices',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options);
  runApp(
    DeviceLinkManagerApp(
      controller: controller,
      settings: settings,
      windowController: windowController,
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  await windowManager.show();
  await windowManager.focus();
}

Future<void> _runSettingsWindow(
  WindowController windowController,
  Map<String, Object?> arguments,
) async {
  final AppDataPaths paths = AppDataPaths.current();
  final String parentWindowId = arguments['parentWindowId']! as String;
  final MultiWindowSettingsHostBridge hostBridge =
      MultiWindowSettingsHostBridge(parentWindowId);
  final SettingsRepository settingsRepository = SettingsRepository(
    SharedPreferencesBackend(),
    defaultTrayNotificationColor: paths.development
        ? TrayNotificationColor.pink
        : TrayNotificationColor.orange,
  );
  final AppSettings windowSettings = await settingsRepository.load();
  final SettingsViewModel viewModel = SettingsViewModel(
    settingsRepository,
    clipboardMonitoring: hostBridge,
    launchAtStartup: hostBridge,
    onWindowOpacityChanged: hostBridge.setOpacity,
    onDockIconHiddenChanged: hostBridge.setDockIconHidden,
    onShowMenuBarRecovery: const NativeMenuBarRecoveryGateway().show,
    onTrayNotificationColorChanged: hostBridge.setTrayNotificationColor,
    onGlobalHotKeyChanged: hostBridge.setGlobalHotKey,
    releaseMetadataSource: HttpReleaseMetadataSource(),
    externalLinkGateway: UrlLauncherExternalLinkGateway(),
    applicationUpdater: hostBridge,
    quickPastePermissionGateway: hostBridge,
    mcpCommandPath: _mcpCommandPath(),
    systemUsageSource: IoSystemUsageSource(paths.applicationSupportDirectory),
    systemDataCleaner: hostBridge,
  );

  await windowManager.ensureInitialized();
  await preventWindowsAuxiliaryWindowClose();
  final WindowOptions options = WindowOptions(
    size: const Size(620, 680),
    minimumSize: const Size(620, 560),
    center: true,
    skipTaskbar: desktopWindowSkipsTaskbar(
      defaultTargetPlatform,
      hideDockIcon: windowSettings.hideDockIcon,
      fallback: false,
    ),
    title: 'DingDong · 设置',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
  runApp(
    SettingsWindowApp(
      viewModel: viewModel,
      windowController: windowController,
      initialDestination: SettingsWindowDestination.fromValue(
        arguments['destination'],
      ),
      onSettingsChanged: hostBridge.notifyChanged,
      soundFileGateway: FileSelectorSoundGateway(),
      soundPreviewGateway: hostBridge,
      onRestartApplication: hostBridge.restartApplication,
    ),
  );
}

Future<void> _runDevelopmentTestPanelWindow(
  WindowController windowController,
  Map<String, Object?> arguments,
) async {
  final AppDataPaths paths = AppDataPaths.current();
  await windowManager.ensureInitialized();
  await preventWindowsAuxiliaryWindowClose();
  if (!paths.development) {
    await windowManager.destroy();
    return;
  }

  final String parentWindowId = arguments['parentWindowId']! as String;
  final WindowController parent = WindowController.fromWindowId(parentWindowId);
  final AppSettings settings = await SettingsRepository(
    SharedPreferencesBackend(),
    defaultTrayNotificationColor: TrayNotificationColor.pink,
  ).load();
  final bool chinese = _usesChineseLabels(settings.language);
  const Size size = Size(780, 720);
  final WindowOptions options = WindowOptions(
    size: size,
    minimumSize: const Size(620, 560),
    center: true,
    skipTaskbar: desktopWindowSkipsTaskbar(
      defaultTargetPlatform,
      hideDockIcon: settings.hideDockIcon,
      fallback: false,
    ),
    title: chinese ? 'DingDong DEV · 测试面板' : 'DingDong DEV · Test Panel',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options);
  runApp(
    DevelopmentTestPanelApp(
      settings: settings,
      animationsSupported: Platform.isMacOS,
      onRun: (DevelopmentTestAction action) => parent.invokeMethod<void>(
        developmentTestRunMethod,
        <String, Object?>{'action': action.id},
      ),
      windowController: windowController,
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  await windowManager.show();
  await windowManager.focus();
}

Future<void> _runDevelopmentTestAction({
  required DevelopmentTestAction action,
  required AppDependencies dependencies,
  required PluginDesktopShellGateway shellGateway,
  required ShellController shellController,
  required TrayBuddyController trayBuddyController,
  required DeviceLinkController deviceLinkController,
  required MultiWindowDeviceLinkManagerLauncher deviceLinkManagerLauncher,
  required MultiWindowResourceManagerLauncher resourceManagerLauncher,
}) async {
  switch (action) {
    case DevelopmentTestAction.traySleeping:
      await shellGateway.previewTrayBuddyState(TrayBuddyState.sleeping);
      return;
    case DevelopmentTestAction.trayNudge:
      await shellGateway.nudgeTrayIcon();
      return;
    case DevelopmentTestAction.agentCompletion:
      await _postDevelopmentDing(
        dependencies,
        message: 'DEV 测试：Agent 已完成本轮任务',
        detail: '这是测试面板生成的基础完成提醒，不代表真实 Agent 任务结果。',
      );
      return;
    case DevelopmentTestAction.agentRichCompletion:
      await _postDevelopmentDing(
        dependencies,
        message: 'DEV 测试：跨设备任务已完成',
        detail: '这是测试面板生成的模拟完成说明，用来检查手机卡片的长描述、来源、完成时间与震动开关。它不代表真实 Agent 任务结果。',
      );
      return;
    case DevelopmentTestAction.agentBurst:
      for (var index = 1; index <= 3; index += 1) {
        await _postDevelopmentDing(
          dependencies,
          message: 'DEV 测试：连续提醒 $index/3',
          detail: '用于检查未读数字、时间顺序和手机端连续接收；这是模拟测试数据。',
          source: 'DingDong DEV $index',
          sound: index == 1 ? 'default' : 'muted',
        );
        if (index < 3) {
          await Future<void>.delayed(const Duration(milliseconds: 220));
        }
      }
      return;
    case DevelopmentTestAction.phoneClipboardText:
      final ClipboardRecord phoneTextRecord = _developmentTextRecord(
        action: action,
        title: 'DEV 手机文字样例',
        content: 'DingDong DEV 测试：这段文字模拟用户在手机输入框粘贴内容并主动点击“发送”。',
        source: '来自 DEV 测试手机',
        additionalTags: const <String>['device-origin:dev-test-mobile'],
      );
      await _saveDevelopmentClipboardRecord(
        record: phoneTextRecord,
        dependencies: dependencies,
        shellController: shellController,
        trayBuddyController: trayBuddyController,
        resourceManagerLauncher: resourceManagerLauncher,
      );
      return;
    case DevelopmentTestAction.phoneClipboardFile:
      final ClipboardRecord phoneFileRecord = await _developmentPhoneFileRecord(
        action: action,
        dependencies: dependencies,
      );
      await _saveDevelopmentClipboardRecord(
        record: phoneFileRecord,
        dependencies: dependencies,
        shellController: shellController,
        trayBuddyController: trayBuddyController,
        resourceManagerLauncher: resourceManagerLauncher,
      );
      return;
    case DevelopmentTestAction.autoSendClipboard:
      final ClipboardRecord autoSendRecord = _developmentTextRecord(
        action: action,
        title: 'DEV 电脑自动同步样例',
        content: 'DingDong DEV 测试：由电脑创建，仅发送给开启“自动同步”的已连接设备。',
        source: 'DingDong DEV 测试面板',
      );
      await _saveDevelopmentClipboardRecord(
        record: autoSendRecord,
        dependencies: dependencies,
        shellController: shellController,
        trayBuddyController: trayBuddyController,
        resourceManagerLauncher: resourceManagerLauncher,
      );
      await deviceLinkController.handleLocalClipboard(autoSendRecord);
      return;
    case DevelopmentTestAction.manualDeviceShare:
      final ClipboardRecord manualShareRecord = _developmentTextRecord(
        action: action,
        title: 'DEV 主动发送样例',
        content: 'DingDong DEV 测试：请选择一个已连接设备主动发送这条内容。',
        source: 'DingDong DEV 测试面板',
      );
      await _saveDevelopmentClipboardRecord(
        record: manualShareRecord,
        dependencies: dependencies,
        shellController: shellController,
        trayBuddyController: trayBuddyController,
        resourceManagerLauncher: resourceManagerLauncher,
      );
      await shellGateway.showAndFocus();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      deviceLinkController.requestShare(manualShareRecord);
      return;
    case DevelopmentTestAction.openDeviceManager:
      await deviceLinkManagerLauncher.show();
      return;
  }
}

Future<void> _postDevelopmentDing(
  AppDependencies dependencies, {
  required String message,
  required String detail,
  String source = 'DingDong DEV',
  String sound = 'default',
}) async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3);
  try {
    final HttpClientRequest request = await client.postUrl(
      dependencies.agentHttpServer.baseUri.resolve('/ding'),
    );
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode(<String, Object?>{
        'message': message,
        'detail': detail,
        'source': source,
        'sound': sound,
        'flashCount': 4,
      }),
    );
    final HttpClientResponse response = await request.close();
    await response.drain<void>();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'DEV notification returned HTTP ${response.statusCode}.',
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
  } finally {
    client.close(force: true);
  }
}

ClipboardRecord _developmentTextRecord({
  required DevelopmentTestAction action,
  required String title,
  required String content,
  required String source,
  List<String> additionalTags = const <String>[],
}) {
  final DateTime now = DateTime.now().toUtc();
  final ClipboardClassification classification = ClipboardClassifier.classify(
    content,
  );
  return ClipboardRecord(
    id: 'DEV-TEST-${action.id}-${now.microsecondsSinceEpoch}',
    group: classification.group,
    title: title,
    content: content,
    tags: <String>[...classification.tags, 'dev-test', ...additionalTags],
    source: source,
    pinned: false,
    enabled: true,
    activation: 'taskMatch',
    createdAt: now,
    updatedAt: now,
  );
}

Future<ClipboardRecord> _developmentPhoneFileRecord({
  required DevelopmentTestAction action,
  required AppDependencies dependencies,
}) async {
  final DateTime now = DateTime.now().toUtc();
  await dependencies.paths.deviceTransferDirectory.create(recursive: true);
  final File file = File(
    path.join(
      dependencies.paths.deviceTransferDirectory.path,
      'dingdong-dev-phone-${now.microsecondsSinceEpoch}.txt',
    ),
  );
  await file.writeAsString(
    'DingDong DEV 测试文件\n\n'
    '这是一份由测试面板创建的本地样例，用于模拟手机主动选择文件并点击发送。\n'
    '它不是来自真实手机，也不包含真实用户内容。\n',
    flush: true,
  );
  return ClipboardRecord(
    id: 'DEV-TEST-${action.id}-${now.microsecondsSinceEpoch}',
    group: '',
    title: 'DingDong DEV 手机文件样例.txt',
    content: file.path,
    tags: const <String>[
      'clipboard',
      'file',
      'file-url',
      'dev-test',
      'device-origin:dev-test-mobile',
    ],
    source: '来自 DEV 测试手机',
    pinned: false,
    enabled: true,
    activation: 'taskMatch',
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> _saveDevelopmentClipboardRecord({
  required ClipboardRecord record,
  required AppDependencies dependencies,
  required ShellController shellController,
  required TrayBuddyController trayBuddyController,
  required MultiWindowResourceManagerLauncher resourceManagerLauncher,
}) async {
  dependencies.clipboardStore.save(record);
  trayBuddyController.recordClipboardActivity(record.updatedAt);
  shellController.requestClipboardRefresh();
  await resourceManagerLauncher.refreshClipboard();
}

Future<void> _restartApplication({
  required AppDependencies dependencies,
  required DesktopShellService desktopShellService,
  required SettingsViewModel settingsViewModel,
}) async {
  await settingsViewModel.shutdown();
  await desktopShellService.stop();
  await dependencies.agentHttpServer.stop();

  if (Platform.isMacOS) {
    final Directory appBundle = File(
      Platform.resolvedExecutable,
    ).parent.parent.parent;
    await Process.start('/usr/bin/open', <String>[
      '-n',
      appBundle.path,
    ], mode: ProcessStartMode.detached);
  } else {
    await Process.start(
      Platform.resolvedExecutable,
      const <String>[],
      mode: ProcessStartMode.detached,
    );
  }
  exit(0);
}

String _mcpCommandPath() {
  final String executableDirectory = File(
    Platform.resolvedExecutable,
  ).parent.path;
  return path.normalize(
    Platform.isWindows
        ? path.join(
            executableDirectory,
            'mcp',
            'bundle',
            'bin',
            'dingdong_mcp.exe',
          )
        : path.join(
            executableDirectory,
            '..',
            'MCP',
            'bundle',
            'bin',
            'dingdong_mcp',
          ),
  );
}

Future<void> _runClipboardPreviewWindow(
  WindowController windowController,
  Map<String, Object?> arguments,
) async {
  final Map<Object?, Object?> recordValues =
      arguments['record']! as Map<Object?, Object?>;
  final ClipboardRecord record = clipboardRecordFromWindowJson(recordValues);
  final String parentWindowId = arguments['parentWindowId']! as String;
  final Offset position = Offset(
    (arguments['x']! as num).toDouble(),
    (arguments['y']! as num).toDouble(),
  );
  final AppSettings windowSettings = await SettingsRepository(
    SharedPreferencesBackend(),
  ).load();
  await windowManager.ensureInitialized();
  final WindowOptions options = WindowOptions(
    size: clipboardPreviewWindowSize,
    minimumSize: clipboardPreviewWindowSize,
    maximumSize: clipboardPreviewWindowSize,
    skipTaskbar: desktopWindowSkipsTaskbar(
      defaultTargetPlatform,
      hideDockIcon: windowSettings.hideDockIcon,
      fallback: true,
    ),
    alwaysOnTop: true,
    backgroundColor: const Color(0x00000000),
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options);
  await windowManager.setAsFrameless();
  await windowManager.setPosition(position);
  await windowManager.setHasShadow(true);
  runApp(
    ClipboardPreviewApp(
      initialRecord: record,
      windowController: windowController,
      clipboardGateway: DesktopClipboardGateway(),
      contentLauncher: UrlLauncherClipboardContentLauncher(),
      shareGateway: _ParentDeviceClipboardShareGateway(parentWindowId),
      settings: windowSettings,
    ),
  );
  await windowController.showInactive();
}

final class _ParentDeviceClipboardShareGateway
    implements ClipboardShareGateway {
  const _ParentDeviceClipboardShareGateway(this.parentWindowId);

  final String parentWindowId;

  @override
  Future<void> share(ClipboardRecord record) {
    return WindowController.fromWindowId(parentWindowId).invokeMethod<void>(
      deviceLinkShareRecordMethod,
      <String, Object?>{'record': clipboardRecordToWindowJson(record)},
    );
  }
}

Future<void> _runClipboardQrPreviewWindow(
  WindowController windowController,
  Map<String, Object?> arguments,
) async {
  final Map<Object?, Object?> recordValues =
      arguments['record']! as Map<Object?, Object?>;
  final ClipboardRecord record = clipboardRecordFromWindowJson(recordValues);
  final String parentWindowId = arguments['parentWindowId']! as String;
  final AppSettings windowSettings = await SettingsRepository(
    SharedPreferencesBackend(),
  ).load();
  await windowManager.ensureInitialized();
  final WindowOptions options = WindowOptions(
    size: clipboardQrPreviewWindowSize,
    minimumSize: clipboardQrPreviewMinimumSize,
    skipTaskbar: desktopWindowSkipsTaskbar(
      defaultTargetPlatform,
      hideDockIcon: windowSettings.hideDockIcon,
      fallback: true,
    ),
    alwaysOnTop: true,
    backgroundColor: const Color(0x00000000),
    titleBarStyle: TitleBarStyle.hidden,
  );
  await windowManager.waitUntilReadyToShow(options);
  await windowManager.setAsFrameless();
  await windowManager.setResizable(true);
  await windowManager.center();
  await windowManager.setHasShadow(true);
  runApp(
    ClipboardQrPreviewApp(
      initialRecord: record,
      parentWindowId: parentWindowId,
      windowController: windowController,
      settings: windowSettings,
    ),
  );
  await windowController.show();
}

Future<void> _runResourceManagerWindow(
  WindowController windowController,
  Map<String, Object?> arguments,
) async {
  final AppDataPaths paths = AppDataPaths.current();
  final IssueCenterController issueCenterController = IssueCenterController();
  final String? parentWindowId = arguments['parentWindowId'] as String?;
  WindowController? parent;
  Future<List<AppIssue>> loadHostIssues() async {
    final WindowController? host = parent;
    if (host == null) {
      return const <AppIssue>[];
    }
    final Object? response = await host.invokeMethod<Object?>(
      agentResourceIssuesRequestedMethod,
    );
    if (response is! List) {
      return const <AppIssue>[];
    }
    return response
        .whereType<Map<Object?, Object?>>()
        .map(AppIssue.fromJson)
        .toList(growable: false);
  }

  if (parentWindowId != null) {
    parent = WindowController.fromWindowId(parentWindowId);
    issueCenterController.replaceSource(
      agentResourceSyncIssueSource,
      await loadHostIssues(),
    );
    issueCenterController.addListener(() {
      unawaited(
        parent!
            .invokeMethod<void>(
              agentResourceIssuesChangedMethod,
              issueCenterController.issues
                  .map((AppIssue issue) => issue.toJson())
                  .toList(growable: false),
            )
            .catchError((Object _) {}),
      );
    });
  }
  final ResourceRepository baseResourceStore = ResourceRepository(
    ResourceFileService(paths.resourceLibraryFile),
  );
  final DataRevisionBus dataRevisions = DataRevisionBus();
  final String homeDirectory =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!;
  final CodexThreadInspector codexThreadInspector = CodexThreadInspector(
    connectionFactory: NativeCodexAppServerConnectionFactory(
      homeDirectory: homeDirectory,
    ),
  );
  final AgentAdapterRepository agentAdapterRepository = AgentAdapterRepository(
    userDirectory: paths.agentAdaptersDirectory,
    historyDirectory: paths.agentAdapterHistoryDirectory,
    homeDirectory: homeDirectory,
    loadBuiltIns: loadBundledAgentAdapterDocuments,
  );
  final TriggerGroupStore baseTriggerGroupStore = TriggerGroupRepository(
    TriggerGroupFileService(paths.triggerGroupsFile),
  );
  final AgentResourceSynchronizer resourceSynchronizer =
      await AgentResourceSynchronizer.currentUser(
        paths.skillPackagesDirectory,
        loadAdapters: agentAdapterRepository.loadEffectiveAdapters,
        triggerGroupStore: baseTriggerGroupStore,
      );
  issueCenterController.setInspector(
    () async => resourceSynchronizer.inspect(await baseResourceStore.load()),
  );
  final ResourceStore resourceStore = SynchronizedResourceStore(
    baseResourceStore,
    resourceSynchronizer,
    issueCenter: issueCenterController,
    onChanged: () {
      final WindowController? host = parent;
      if (host == null) {
        return;
      }
      unawaited(
        host
            .invokeMethod<void>(resourceLibraryChangedMethod)
            .catchError((Object _) {}),
      );
    },
  );
  final AgentAdapterController agentAdapterController = AgentAdapterController(
    repository: agentAdapterRepository,
    codexCompletionHookGateway: CodexAppServerCompletionHookGateway(
      connectionFactory: NativeCodexAppServerConnectionFactory(
        homeDirectory: homeDirectory,
      ),
      homeDirectory: homeDirectory,
      dingDongMcpCommandPath: _mcpCommandPath(),
    ),
    onAdaptersChanged: () async {
      await resourceStore.save(await resourceStore.load());
    },
  );
  await agentAdapterController.load();
  final TriggerGroupStore triggerGroupStore = SynchronizedTriggerGroupStore(
    baseTriggerGroupStore,
    resourceStore,
    resourceSynchronizer,
    issueCenter: issueCenterController,
  );
  final LibraryViewModel viewModel = createDesktopLibraryViewModel(
    resourceStore,
    triggerGroupStore: triggerGroupStore,
    revisions: dataRevisions,
  );
  await viewModel.load();
  final ClipboardRepository clipboardRepository = ClipboardRepository.open(
    paths.clipboardDatabaseFile.path,
  );
  final ClipboardViewModel clipboardViewModel = ClipboardViewModel(
    clipboardRepository,
    archiveStore: clipboardRepository,
    gateway: DesktopClipboardGateway(),
    resourceStore: resourceStore,
    revisions: dataRevisions,
    managedImageDirectory: paths.clipboardImagesDirectory,
    categoryRuleStore: FileClipboardCategoryRuleStore(
      paths.clipboardCategoryRulesFile,
    ),
    groupOrderStore: FileClipboardGroupOrderStore(
      paths.clipboardGroupOrderFile,
    ),
  )..load();
  final String? editingResourceId = arguments['editingResourceId'] as String?;
  final ResourceManagerDestination initialDestination =
      ResourceManagerDestination.parse(arguments['destination']);
  final ResourceManagerCreateRequest? createRequest =
      ResourceManagerCreateRequest.fromJson(arguments['createRequest']);
  if (editingResourceId != null) {
    for (final resource in viewModel.allResources) {
      if (resource.id == editingResourceId) {
        viewModel.selectResource(resource);
        break;
      }
    }
  }
  if (createRequest != null) {
    viewModel.startCreating(
      type: createRequest.type,
      title: createRequest.title,
      content: createRequest.content,
    );
  }
  final settings = await SettingsRepository(SharedPreferencesBackend()).load();
  final ActivityController activityController =
      ActivityController(store: FileAgentActivityStore(paths.agentActivityFile))
        ..configure(
          rememberAcrossRestarts: settings.rememberAgentActivity,
          maxItems: settings.agentActivityMaxItems,
          countWindowHours: settings.agentActivityCountHours,
          groupRepeatedAgentSessions: settings.groupRepeatedAgentSessions,
        )
        ..load();
  final NativeAgentConversationLauncher agentConversationLauncher =
      NativeAgentConversationLauncher(
        codexConversationPreflightBatch: codexThreadInspector.inspectThreadIds,
        configurationLoader: FileAgentLauncherConfigurationStore(
          paths.agentLaunchersFile,
        ).load,
      );
  unawaited(
    agentConversationLauncher.preflight(
      activityController.activities
          .map((AgentActivity activity) => activity.conversationTarget)
          .whereType<AgentConversationTarget>(),
    ),
  );

  await windowManager.ensureInitialized();
  await preventWindowsAuxiliaryWindowClose();
  final WindowOptions options = WindowOptions(
    size: const Size(1080, 752),
    minimumSize: const Size(980, 680),
    center: true,
    skipTaskbar: desktopWindowSkipsTaskbar(
      defaultTargetPlatform,
      hideDockIcon: settings.hideDockIcon,
      fallback: false,
    ),
    title: '资源管理',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options);
  runApp(
    ResourceManagerApp(
      viewModel: viewModel,
      clipboardViewModel: clipboardViewModel,
      activityController: activityController,
      agentAdapterController: agentAdapterController,
      issueCenterController: issueCenterController,
      settings: settings,
      windowController: windowController,
      initialDestination: initialDestination,
      openClipboardCategoriesOnLaunch:
          arguments['openClipboardCategories'] == true,
      resourceManagerLauncher: MultiWindowResourceManagerLauncher(
        parentWindowId: parentWindowId ?? windowController.windowId,
      ),
      agentConversationLauncher: agentConversationLauncher,
      onLoadHostIssues: parent == null ? null : loadHostIssues,
      desktopContextMenuGateway: Platform.isMacOS
          ? NativeDesktopContextMenuGateway()
          : null,
      onOpenExternalLink: UrlLauncherExternalLinkGateway().open,
    ),
  );
  await WidgetsBinding.instance.endOfFrame;
  await windowManager.show();
  await windowManager.focus();
}
