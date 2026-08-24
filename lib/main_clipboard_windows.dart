part of 'main.dart';

// Clipboard preview and QR auxiliary-engine bootstrap paths.
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
