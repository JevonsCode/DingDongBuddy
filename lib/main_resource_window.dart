part of 'main.dart';

// Resource Manager auxiliary-engine dependency assembly.
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
      ActivityController(
          store: FileAgentActivityStore(paths.agentActivityFile),
          localizations: () => appLocalizationsFor(settings.language),
        )
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
  final DingDongLocalizations strings = appLocalizationsFor(settings.language);
  final WindowOptions options = WindowOptions(
    size: const Size(1080, 752),
    minimumSize: const Size(980, 680),
    center: true,
    skipTaskbar: desktopWindowSkipsTaskbar(
      defaultTargetPlatform,
      hideDockIcon: settings.hideDockIcon,
      fallback: false,
    ),
    title: strings.resourceManagerWindowTitle,
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
