import 'dart:async';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/app/app_dependencies.dart';
import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/clipboard/data/clipboard_category_rule_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_preview_app.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/library/data/resource_file_service.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_file_service.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/library_view_model_factory.dart';
import 'package:dingdong/features/library/ui/resource_manager_app.dart';
import 'package:dingdong/features/settings/data/http_release_metadata_source.dart';
import 'package:dingdong/features/settings/data/io_system_usage_source.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
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
import 'package:dingdong/platform/native_clipboard_share_gateway.dart';
import 'package:dingdong/platform/native_desktop_context_menu_gateway.dart';
import 'package:dingdong/platform/native_launch_at_startup.dart';
import 'package:dingdong/platform/native_notification_gateway.dart';
import 'package:dingdong/platform/native_quick_paste_gateway.dart';
import 'package:dingdong/platform/plugin_desktop_shell_gateway.dart';
import 'package:dingdong/platform/shared_preferences_backend.dart';
import 'package:dingdong/platform/url_launcher_external_link_gateway.dart';
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

  final ShellController shellController = ShellController();
  final ActivityController activityController = ActivityController();
  final MultiWindowClipboardPreviewLauncher clipboardPreviewLauncher =
      MultiWindowClipboardPreviewLauncher();
  final MultiWindowSettingsLauncher settingsWindowLauncher =
      MultiWindowSettingsLauncher(parentWindowId: windowController.windowId);
  late final AppDependencies dependencies;
  late final SettingsViewModel settingsViewModel;
  final PluginDesktopShellGateway shellGateway = PluginDesktopShellGateway(
    onHideAuxiliaryWindows: clipboardPreviewLauncher.hide,
    clipboardMonitoringState: () =>
        dependencies.clipboardMonitorService.isRunning,
    useChineseLabels: () =>
        _usesChineseLabels(settingsViewModel.settings.language),
  );
  dependencies = AppDependencies.production(
    onNotification: (request) async {
      activityController.record(
        source: request.source ?? 'Agent',
        message: request.message,
      );
      await shellGateway.markUnread();
    },
    onShowUi: (int index) {
      if (index == 4) {
        unawaited(settingsWindowLauncher.show());
        return;
      }
      shellController.open(index);
      unawaited(shellGateway.showAndFocus());
    },
  );
  await dependencies.start();
  shellController.open(dependencies.initialSettings.defaultWorkspace.index);
  final NativeQuickPasteGateway quickPasteGateway = NativeQuickPasteGateway();
  final NativeLaunchAtStartup launchAtStartup = NativeLaunchAtStartup();
  final NativeNotificationGateway notificationGateway =
      NativeNotificationGateway();
  settingsViewModel = SettingsViewModel(
    dependencies.settingsRepository,
    clipboardMonitoring: dependencies.clipboardMonitorService,
    launchAtStartup: launchAtStartup,
    onWindowOpacityChanged: shellGateway.setOpacity,
    releaseMetadataSource: HttpReleaseMetadataSource(),
    externalLinkGateway: UrlLauncherExternalLinkGateway(),
    quickPastePermissionGateway: quickPasteGateway,
    mcpCommandPath: _mcpCommandPath(),
    systemUsageSource: IoSystemUsageSource(
      dependencies.paths.applicationSupportDirectory,
    ),
  );
  await settingsViewModel.load();
  final DesktopShellService desktopShellService = DesktopShellService(
    gateway: shellGateway,
    controller: shellController,
    activityController: activityController,
    defaultWorkspaceIndex: () =>
        settingsViewModel.settings.defaultWorkspace.index,
    onClipboardReveal: () async {
      await dependencies.clipboardCaptureService.capture();
    },
    onClipboardMonitoringChanged: settingsViewModel.setClipboardMonitoring,
    onClearClipboardHistory: () => _clearClipboardHistory(dependencies),
    onShowSettings: () async {
      await shellGateway.hide();
      await settingsWindowLauncher.show();
    },
  );
  await desktopShellService.start();
  Future<Object?> handleSettingsWindowCall(MethodCall call) async {
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
      case 'settings_changed':
        await settingsViewModel.reload();
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
      default:
        break;
    }
    return null;
  }

  await windowController.setWindowMethodHandler(handleSettingsWindowCall);
  runApp(
    DingDongApp(
      activityController: activityController,
      agentBaseUri: dependencies.agentHttpServer.baseUri,
      clipboardCaptureService: dependencies.clipboardCaptureService,
      clipboardCategoryRuleStore: dependencies.clipboardCategoryRuleStore,
      clipboardGateway: dependencies.clipboardGateway,
      desktopContextMenuGateway: Platform.isMacOS
          ? NativeDesktopContextMenuGateway()
          : null,
      clipboardMonitoring: dependencies.clipboardMonitorService,
      clipboardStore: dependencies.clipboardStore,
      clipboardPreviewLauncher: clipboardPreviewLauncher,
      clipboardShareGateway: NativeClipboardShareGateway(),
      quickPasteGateway: quickPasteGateway,
      quickPastePermissionGateway: quickPasteGateway,
      resourceStore: dependencies.resourceStore,
      triggerGroupStore: dependencies.triggerGroupStore,
      resourceManagerLauncher: MultiWindowResourceManagerLauncher(),
      settingsWindowLauncher: settingsWindowLauncher,
      settingsViewModel: settingsViewModel,
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
  final SettingsViewModel viewModel = SettingsViewModel(
    SettingsRepository(SharedPreferencesBackend()),
    clipboardMonitoring: hostBridge,
    launchAtStartup: hostBridge,
    onWindowOpacityChanged: hostBridge.setOpacity,
    releaseMetadataSource: HttpReleaseMetadataSource(),
    externalLinkGateway: UrlLauncherExternalLinkGateway(),
    quickPastePermissionGateway: hostBridge,
    mcpCommandPath: _mcpCommandPath(),
    systemUsageSource: IoSystemUsageSource(paths.applicationSupportDirectory),
  );

  await windowManager.ensureInitialized();
  const WindowOptions options = WindowOptions(
    size: Size(620, 680),
    minimumSize: Size(620, 560),
    center: true,
    skipTaskbar: false,
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
  await windowManager.ensureInitialized();
  const WindowOptions options = WindowOptions(
    size: clipboardPreviewWindowSize,
    minimumSize: clipboardPreviewWindowSize,
    maximumSize: clipboardPreviewWindowSize,
    skipTaskbar: true,
    alwaysOnTop: true,
    backgroundColor: Color(0x00000000),
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
      shareGateway: NativeClipboardShareGateway(),
    ),
  );
  await windowController.showInactive();
}

Future<void> _runResourceManagerWindow(
  WindowController windowController,
  Map<String, Object?> arguments,
) async {
  final AppDataPaths paths = AppDataPaths.current();
  final ResourceStore resourceStore = ResourceRepository(
    ResourceFileService(paths.resourceLibraryFile),
  );
  final TriggerGroupStore triggerGroupStore = TriggerGroupRepository(
    TriggerGroupFileService(paths.triggerGroupsFile),
  );
  final LibraryViewModel viewModel = createDesktopLibraryViewModel(
    resourceStore,
    triggerGroupStore: triggerGroupStore,
  );
  await viewModel.load();
  final ClipboardViewModel clipboardViewModel = ClipboardViewModel(
    ClipboardRepository.open(paths.clipboardDatabaseFile.path),
    gateway: DesktopClipboardGateway(),
    resourceStore: resourceStore,
    categoryRuleStore: FileClipboardCategoryRuleStore(
      paths.clipboardCategoryRulesFile,
    ),
  )..load();
  final String? editingResourceId = arguments['editingResourceId'] as String?;
  if (editingResourceId != null) {
    for (final resource in viewModel.allResources) {
      if (resource.id == editingResourceId) {
        viewModel.selectResource(resource);
        break;
      }
    }
  }
  final settings = await SettingsRepository(SharedPreferencesBackend()).load();

  await windowManager.ensureInitialized();
  const WindowOptions options = WindowOptions(
    size: Size(1080, 752),
    minimumSize: Size(980, 680),
    center: true,
    skipTaskbar: false,
    title: '资源管理',
    titleBarStyle: TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options);
  runApp(
    ResourceManagerApp(
      viewModel: viewModel,
      clipboardViewModel: clipboardViewModel,
      settings: settings,
      windowController: windowController,
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
