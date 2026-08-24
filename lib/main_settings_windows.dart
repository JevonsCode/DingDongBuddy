part of 'main.dart';

// Device Link and Settings auxiliary-engine bootstrap paths.
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
  final DingDongLocalizations strings = appLocalizationsFor(settings.language);

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
    title: strings.connectedDevicesWindowTitle,
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
  final DingDongLocalizations strings = appLocalizationsFor(
    windowSettings.language,
  );
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
    systemDataLocationGateway: IoSystemDataLocationGateway(
      paths.applicationSupportDirectory,
    ),
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
    title: strings.settingsWindowTitle,
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
      soundFileGateway: FileSelectorSoundGateway(
        () => appLocalizationsFor(viewModel.settings.language),
      ),
      soundPreviewGateway: hostBridge,
      onRestartApplication: hostBridge.restartApplication,
    ),
  );
}
