import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/app/app_dependencies.dart';
import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/data/data_revision_bus.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/desktop_window_policy.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/data/agent_launcher_configuration_store.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:dingdong/features/agent_adapters/ui/agent_adapter_controller.dart';
import 'package:dingdong/features/clipboard/data/clipboard_category_rule_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_group_order_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_preview_app.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
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
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:dingdong/features/settings/ui/settings_window_app.dart';
import 'package:dingdong/features/shell/domain/desktop_shell_service.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
import 'package:dingdong/platform/desktop_clipboard_gateway.dart';
import 'package:dingdong/platform/file_selector_sound_gateway.dart';
import 'package:dingdong/platform/multi_window_clipboard_preview_launcher.dart';
import 'package:dingdong/platform/multi_window_resource_manager_launcher.dart';
import 'package:dingdong/platform/multi_window_settings_host_bridge.dart';
import 'package:dingdong/platform/multi_window_settings_launcher.dart';
import 'package:dingdong/platform/native_agent_conversation_launcher.dart';
import 'package:dingdong/platform/native_application_updater.dart';
import 'package:dingdong/platform/native_clipboard_share_gateway.dart';
import 'package:dingdong/platform/native_desktop_context_menu_gateway.dart';
import 'package:dingdong/platform/native_launch_at_startup.dart';
import 'package:dingdong/platform/native_notification_gateway.dart';
import 'package:dingdong/platform/native_quick_paste_gateway.dart';
import 'package:dingdong/platform/plugin_desktop_shell_gateway.dart';
import 'package:dingdong/platform/preferences_tray_unread_store.dart';
import 'package:dingdong/platform/shared_preferences_backend.dart';
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
  if (windowArguments['kind'] == resourceManagerWindowKind) {
    await _runResourceManagerWindow(windowController, windowArguments);
    return;
  }
  if (windowArguments['kind'] == clipboardPreviewWindowKind) {
    await _runClipboardPreviewWindow(windowController, windowArguments);
    return;
  }
  if (windowArguments['kind'] == settingsWindowKind) {
    await _runSettingsWindow(windowController, windowArguments);
    return;
  }

  final AppDataPaths appDataPaths = AppDataPaths.current();
  final ShellController shellController = ShellController();
  final MultiWindowClipboardPreviewLauncher clipboardPreviewLauncher =
      MultiWindowClipboardPreviewLauncher();
  final DesktopContextMenuController desktopContextMenuController =
      DesktopContextMenuController();
  final MultiWindowSettingsLauncher settingsWindowLauncher =
      MultiWindowSettingsLauncher(parentWindowId: windowController.windowId);
  final SharedPreferencesBackend preferencesBackend =
      SharedPreferencesBackend();
  final ActivityController activityController = ActivityController(
    store: FileAgentActivityStore(appDataPaths.agentActivityFile),
  );
  late final AppDependencies dependencies;
  late final SettingsViewModel settingsViewModel;
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
    onNotification: (request) async {
      activityController.record(
        source: request.source ?? 'Agent',
        message: request.message,
        conversationTarget: request.conversationTarget,
      );
      await shellGateway.markUnread();
    },
    onSuppressedNotification: (request) async {
      final target = request.conversationTarget;
      if (target != null) {
        activityController.attachConversationTarget(
          source: request.source ?? 'Agent',
          target: target,
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
  final AppSettings startupSettings = await dependencies.settingsRepository
      .load();
  activityController.configure(
    rememberAcrossRestarts: startupSettings.rememberAgentActivity,
    maxItems: startupSettings.agentActivityMaxItems,
    countWindowHours: startupSettings.agentActivityCountHours,
  );
  activityController.load(resetPreviousSession: true);
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
    onTrayNotificationColorChanged: shellGateway.setTrayNotificationColor,
    onGlobalHotKeyChanged: shellGateway.setGlobalHotKey,
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
    onShowSettings: () async {
      await shellGateway.hide();
      await settingsWindowLauncher.show();
    },
    onHideDockIcon: () => settingsViewModel.setHideDockIcon(true),
  );
  await desktopShellService.start();
  Future<Object?> handleChildWindowCall(MethodCall call) async {
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
        dependencies.applyClipboardRetention(settingsViewModel.settings);
        activityController.configure(
          rememberAcrossRestarts:
              settingsViewModel.settings.rememberAgentActivity,
          maxItems: settingsViewModel.settings.agentActivityMaxItems,
          countWindowHours: settingsViewModel.settings.agentActivityCountHours,
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
      agentConversationLauncher: NativeAgentConversationLauncher(
        configurationLoader: FileAgentLauncherConfigurationStore(
          dependencies.paths.agentLaunchersFile,
        ).load,
      ),
      agentBaseUri: dependencies.agentHttpServer.baseUri,
      clipboardCaptureService: dependencies.clipboardCaptureService,
      clipboardCategoryRuleStore: dependencies.clipboardCategoryRuleStore,
      clipboardGroupOrderStore: dependencies.clipboardGroupOrderStore,
      clipboardGateway: dependencies.clipboardGateway,
      desktopContextMenuGateway: Platform.isMacOS
          ? NativeDesktopContextMenuGateway()
          : null,
      desktopContextMenuController: desktopContextMenuController,
      clipboardMonitoring: dependencies.clipboardMonitorService,
      clipboardStore: dependencies.clipboardStore,
      clipboardPreviewLauncher: clipboardPreviewLauncher,
      clipboardShareGateway: createNativeClipboardShareGateway(
        defaultTargetPlatform,
      ),
      quickPasteGateway: quickPasteGateway,
      quickPastePermissionGateway: quickPasteGateway,
      resourceStore: dependencies.resourceStore,
      issueCenterController: dependencies.issueCenterController,
      triggerGroupStore: dependencies.triggerGroupStore,
      resourceManagerLauncher: MultiWindowResourceManagerLauncher(
        parentWindowId: windowController.windowId,
      ),
      settingsWindowLauncher: settingsWindowLauncher,
      settingsViewModel: settingsViewModel,
      soundPreviewGateway: notificationGateway,
      onStartDragging: shellGateway.startDragging,
      onHideWindow: shellGateway.hide,
      shortcutHints: shellGateway.shortcutHints,
      shellController: shellController,
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

Future<void> _clearClipboardHistory(AppDependencies dependencies) async {
  for (final ClipboardRecord record in dependencies.clipboardStore.list(
    limit: 5000,
  )) {
    dependencies.clipboardStore.delete(record.id);
  }
  final Directory imageDirectory = dependencies.paths.clipboardImagesDirectory;
  if (await imageDirectory.exists()) {
    await imageDirectory.delete(recursive: true);
  }
  await imageDirectory.create(recursive: true);
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
    onTrayNotificationColorChanged: hostBridge.setTrayNotificationColor,
    onGlobalHotKeyChanged: hostBridge.setGlobalHotKey,
    releaseMetadataSource: HttpReleaseMetadataSource(),
    externalLinkGateway: UrlLauncherExternalLinkGateway(),
    applicationUpdater: hostBridge,
    quickPastePermissionGateway: hostBridge,
    mcpCommandPath: _mcpCommandPath(),
    systemUsageSource: IoSystemUsageSource(paths.applicationSupportDirectory),
  );

  await windowManager.ensureInitialized();
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
      shareGateway: createNativeClipboardShareGateway(defaultTargetPlatform),
    ),
  );
  await windowController.showInactive();
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
  final AgentAdapterRepository agentAdapterRepository = AgentAdapterRepository(
    userDirectory: paths.agentAdaptersDirectory,
    historyDirectory: paths.agentAdapterHistoryDirectory,
    homeDirectory:
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!,
    loadBuiltIns: loadBundledAgentAdapterDocuments,
  );
  final AgentResourceSynchronizer resourceSynchronizer =
      await AgentResourceSynchronizer.currentUser(
        paths.skillPackagesDirectory,
        loadAdapters: agentAdapterRepository.loadEffectiveAdapters,
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
    onAdaptersChanged: () async {
      await resourceStore.save(await resourceStore.load());
    },
  );
  await agentAdapterController.load();
  final TriggerGroupStore triggerGroupStore = TriggerGroupRepository(
    TriggerGroupFileService(paths.triggerGroupsFile),
  );
  final LibraryViewModel viewModel = createDesktopLibraryViewModel(
    resourceStore,
    triggerGroupStore: triggerGroupStore,
    revisions: dataRevisions,
  );
  await viewModel.load();
  final ClipboardViewModel clipboardViewModel = ClipboardViewModel(
    ClipboardRepository.open(paths.clipboardDatabaseFile.path),
    gateway: DesktopClipboardGateway(),
    resourceStore: resourceStore,
    revisions: dataRevisions,
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
  if (editingResourceId != null) {
    for (final resource in viewModel.allResources) {
      if (resource.id == editingResourceId) {
        viewModel.selectResource(resource);
        break;
      }
    }
  }
  final settings = await SettingsRepository(SharedPreferencesBackend()).load();
  final ActivityController activityController =
      ActivityController(store: FileAgentActivityStore(paths.agentActivityFile))
        ..configure(
          rememberAcrossRestarts: settings.rememberAgentActivity,
          maxItems: settings.agentActivityMaxItems,
          countWindowHours: settings.agentActivityCountHours,
        )
        ..load();

  await windowManager.ensureInitialized();
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
      agentConversationLauncher: NativeAgentConversationLauncher(
        configurationLoader: FileAgentLauncherConfigurationStore(
          paths.agentLaunchersFile,
        ).load,
      ),
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
