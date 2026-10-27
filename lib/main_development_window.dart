part of 'main.dart';

// Development panel actions and deterministic fixture generation.
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
  final DingDongLocalizations strings = appLocalizationsFor(settings.language);
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
    title: strings.developmentTestPanelWindowTitle,
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
  required DingDongLocalizations strings,
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
    case DevelopmentTestAction.trayOrange:
      await shellGateway.previewReminderColor(TrayNotificationColor.orange);
      return;
    case DevelopmentTestAction.trayPink:
      await shellGateway.previewReminderColor(TrayNotificationColor.pink);
      return;
    case DevelopmentTestAction.trayBlue:
      await shellGateway.previewReminderColor(TrayNotificationColor.blue);
      return;
    case DevelopmentTestAction.trayGreen:
      await shellGateway.previewReminderColor(TrayNotificationColor.green);
      return;
    case DevelopmentTestAction.trayPurple:
      await shellGateway.previewReminderColor(TrayNotificationColor.purple);
      return;
    case DevelopmentTestAction.trayAmber:
      await shellGateway.previewReminderColor(TrayNotificationColor.amber);
      return;
    case DevelopmentTestAction.trayClearColors:
      await shellGateway.previewReminderColor(null);
      return;
    case DevelopmentTestAction.agentCompletion:
      await _postDevelopmentDing(
        dependencies,
        message: strings.devAgentCompletedMessage,
        detail: strings.devAgentCompletedDetail,
      );
      return;
    case DevelopmentTestAction.agentAttention:
      await _postDevelopmentDing(
        dependencies,
        message: 'DEV · ${strings.needsYourInput}',
        detail: strings.devAttentionDescription,
        notificationKind: 'attention',
      );
      return;
    case DevelopmentTestAction.agentRichCompletion:
      await _postDevelopmentDing(
        dependencies,
        message: strings.devCrossDeviceTaskCompletedMessage,
        detail: strings.devCrossDeviceTaskCompletedDetail,
      );
      return;
    case DevelopmentTestAction.agentTemporary:
      await _postDevelopmentDing(
        dependencies,
        message: 'DEV · ${strings.devTemporaryNotification}',
        detail: strings.devTemporaryNotificationDescription,
        notificationKind: 'attention',
        temporaryReminder: {
          'id': 'dev-temporary-${DateTime.now().microsecondsSinceEpoch}',
          'name': strings.devTemporaryNotification,
          'description': strings.devTemporaryNotificationDescription,
          'temporary': true,
          'kind': 'attention',
          'color': 'green',
          'sound': 'dingBright',
          'toPhone': false,
        },
      );
      return;
    case DevelopmentTestAction.agentBurst:
      for (var index = 1; index <= 3; index += 1) {
        await _postDevelopmentDing(
          dependencies,
          message: strings.devRepeatedAlertMessage(index),
          detail: strings.devRepeatedAlertDetail,
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
        title: strings.devPhoneTextSampleTitle,
        content: strings.devPhoneTextSampleContent,
        source: strings.devTestPhoneSource,
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
        strings: strings,
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
        title: strings.devAutoSyncSampleTitle,
        content: strings.devAutoSyncSampleContent,
        source: strings.devTestPanelSource,
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
        title: strings.devManualSendSampleTitle,
        content: strings.devManualSendSampleContent,
        source: strings.devTestPanelSource,
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
  String notificationKind = 'completion',
  Map<String, Object?>? temporaryReminder,
}) async {
  final HttpClient client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3);
  Future<void> post(String path, Map<String, Object?> body) async {
    final HttpClientRequest request = await client.postUrl(
      dependencies.agentHttpServer.baseUri.resolve(path),
    );
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final HttpClientResponse response = await request.close();
    await response.drain<void>();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('DEV $path returned HTTP ${response.statusCode}.');
    }
  }

  try {
    if (temporaryReminder != null) {
      await post('/settings/reminders', {
        ...temporaryReminder,
        'action': 'upsert',
      });
    }
    await post('/ding', <String, Object?>{
      'message': message,
      'detail': detail,
      'source': source,
      'sound': sound,
      'notificationKind': notificationKind,
      'flashCount': 4,
      if (temporaryReminder != null) 'reminderId': temporaryReminder['id'],
    });
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
  required DingDongLocalizations strings,
}) async {
  final DateTime now = DateTime.now().toUtc();
  await dependencies.paths.deviceTransferDirectory.create(recursive: true);
  final File file = File(
    path.join(
      dependencies.paths.deviceTransferDirectory.path,
      'dingdong-dev-phone-${now.microsecondsSinceEpoch}.txt',
    ),
  );
  await file.writeAsString(strings.devPhoneFileBody, flush: true);
  return ClipboardRecord(
    id: 'DEV-TEST-${action.id}-${now.microsecondsSinceEpoch}',
    group: '',
    title: strings.devPhoneFileSampleTitle,
    content: file.path,
    tags: const <String>[
      'clipboard',
      'file',
      'file-url',
      'dev-test',
      'device-origin:dev-test-mobile',
    ],
    source: strings.devTestPhoneSource,
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

String _mcpCommandPath() => resolveMcpCommandPath(
  executablePath: Platform.resolvedExecutable,
  isWindows: Platform.isWindows,
);
