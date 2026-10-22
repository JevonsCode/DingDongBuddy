import 'dart:async';
import 'dart:io';
import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/app/app_locale.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:dingdong/features/agent_api/data/agent_bridge.dart';
import 'package:dingdong/features/agent_api/data/agent_http_server.dart';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/conversation_token_usage_resolver.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_store.dart';
import 'package:dingdong/features/ai_companion/data/ai_resource_selector.dart';
import 'package:dingdong/features/clipboard/data/clipboard_category_rule_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_group_order_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_monitor_service.dart';
import 'package:dingdong/features/clipboard/domain/managed_clipboard_images.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/jev/data/jev_factory.dart';
import 'package:dingdong/features/jev/data/jev_routes.dart';
import 'package:dingdong/features/jev/data/jev_service.dart';
import 'package:dingdong/features/library/data/agent_resource_synchronizer.dart';
import 'package:dingdong/features/library/data/resource_file_service.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_file_service.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resource_installer.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/reminder_audio_importer.dart';
import 'package:dingdong/features/settings/data/reminder_settings_service.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/token_usage/data/local_token_usage_repository.dart';
import 'package:dingdong/platform/desktop_clipboard_gateway.dart';
import 'package:dingdong/platform/native_clipboard_change_source.dart';
import 'package:dingdong/platform/native_notification_gateway.dart';
import 'package:dingdong/platform/shared_preferences_backend.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum NotificationDeliveryRoute { native, companion }

final class NotificationDeliveryFailure {
  const NotificationDeliveryFailure({
    required this.route,
    required this.error,
    required this.stackTrace,
  });

  final NotificationDeliveryRoute route;
  final Object error;
  final StackTrace stackTrace;
}

typedef NotificationDeliveryFailureObserver =
    void Function(NotificationDeliveryFailure failure);

typedef SubagentNotificationDetector =
    Future<bool> Function(DingRequest request);

typedef CodexVoiceNotificationDetector =
    Future<bool> Function(DingRequest request);

typedef SubagentConversationDetector =
    Future<bool> Function(AgentConversationTarget target);

/// Returns when DingDong observed the reminder's task start, if it did.
typedef AgentTaskStartLookup = DateTime? Function(DingRequest request);

/// Applies the user's reminder preferences before any delivery route can play
/// a sound, flash a window, record activity, or sync to a companion.
Future<bool> shouldDeliverAgentNotification({
  required DingRequest request,
  required AppSettings settings,
  CodexVoiceNotificationDetector? isCodexVoiceNotification,
  SubagentNotificationDetector? isSubagentNotification,
}) async {
  final profile = request.reminderId == null
      ? null
      : settings.reminderProfile(request.reminderId);
  if (request.reminderId != null
      ? profile?.enabled != true
      : !_isNotificationKindEnabled(request.notificationKind, settings)) {
    return false;
  }
  if (!settings.notifyCodexVoiceActivity && isCodexVoiceNotification != null) {
    try {
      if (await isCodexVoiceNotification(request)) {
        return false;
      }
    } on Object {
      // Unknown Codex metadata must not hide an ordinary completion. Only a
      // positively identified voice task is filtered.
    }
  }
  if (settings.notifySubagentActivity || isSubagentNotification == null) {
    return true;
  }
  try {
    return !await isSubagentNotification(request);
  } on Object {
    // An unavailable Agent metadata service must not hide a main-thread
    // completion. Only positively identified subagents are filtered.
    return true;
  }
}

bool _isNotificationKindEnabled(
  AgentNotificationKind kind,
  AppSettings settings,
) => switch (kind) {
  AgentNotificationKind.completion => settings.notifyAgentCompletion,
  AgentNotificationKind.attention => settings.notifyAgentAttention,
};

Future<bool> shouldRecordAgentTaskStart({
  required AgentBridgeTaskStart start,
  required AppSettings settings,
  SubagentConversationDetector? isSubagentConversation,
}) async {
  if (settings.notifySubagentActivity || isSubagentConversation == null) {
    return true;
  }
  final String? conversationId = start.conversationId?.trim();
  if (conversationId == null || conversationId.isEmpty) {
    return true;
  }
  final AgentConversationTarget target = AgentConversationTarget(
    client: AgentClient.fromSource(start.source),
    conversationId: conversationId,
    workspacePath: start.workspacePath,
  );
  try {
    return !await isSubagentConversation(target);
  } on Object {
    return true;
  }
}

/// Resolves the saved sound and fans out only notifications allowed by the
/// subagent preference. Both primary and deduplicated hook deliveries use this
/// same boundary so no reminder side effect can bypass the setting.
/// A deduplicated hook may enrich history but must not play or flash again.
///
/// Per-kind rules then decide how an allowed reminder is delivered: quiet
/// hours and the minimum task duration record it silently, and each kind has
/// its own sound and phone switch.
Future<void> deliverAgentNotification({
  required DingRequest request,
  required AppSettings settings,
  required Future<void> Function(DingRequest request) nativeDelivery,
  Future<void> Function(DingRequest request)? companionDelivery,
  Future<void> Function(DingRequest request)? onFiltered,
  bool suppressNativeNotification = false,
  CodexVoiceNotificationDetector? isCodexVoiceNotification,
  SubagentNotificationDetector? isSubagentNotification,
  NotificationDeliveryFailureObserver? onFailure,
  AgentTaskStartLookup? taskStartedAt,
  DateTime Function() now = DateTime.now,
}) async {
  if (!await shouldDeliverAgentNotification(
    request: request,
    settings: settings,
    isCodexVoiceNotification: isCodexVoiceNotification,
    isSubagentNotification: isSubagentNotification,
  )) {
    await onFiltered?.call(request);
    return;
  }
  final DateTime currentTime = now();
  DateTime? startedAt;
  try {
    startedAt = taskStartedAt?.call(request);
  } on Object {
    // An unknown start time never hides a reminder.
  }
  final profile = settings.reminderProfile(request.reminderId);
  final AgentNotificationPlan plan = planAgentNotification(
    kind: profile?.kind ?? request.notificationKind,
    completionSound: profile?.sound ?? settings.selectedSound,
    completionCustomSoundPath:
        profile?.customSoundPath ?? settings.customSoundPath,
    rules: profile == null
        ? settings.notificationRules
        : settings.notificationRules.copyWith(
            attentionSound: sameAsCompletionSound,
            completionToPhone: profile.toPhone,
            attentionToPhone: profile.toPhone,
            completionMinimumMinutes: profile.builtIn
                ? settings.notificationRules.completionMinimumMinutes
                : 0,
          ),
    now: currentTime,
    taskDuration: startedAt == null ? null : currentTime.difference(startedAt),
  );
  final DingRequest resolvedRequest =
      (request.sound == DingSound.defaultSound
              ? request.copyWith(sound: DingSound.parse(plan.sound))
              : request)
          .copyWith(
            alertPhone: plan.alertPhone,
            notificationKind: profile?.kind,
          );
  await deliverNotificationIndependently(
    nativeDelivery: () async {
      if (!suppressNativeNotification && plan.alertDesktop) {
        await nativeDelivery(resolvedRequest);
      }
    },
    companionDelivery: companionDelivery == null
        ? null
        : () => companionDelivery(resolvedRequest),
    onFailure: onFailure,
  );
}

/// Runs desktop attention and the companion/mobile callback independently.
/// A failure on either route is reported without cancelling the other route.
Future<void> deliverNotificationIndependently({
  required Future<void> Function() nativeDelivery,
  Future<void> Function()? companionDelivery,
  NotificationDeliveryFailureObserver? onFailure,
}) async {
  await Future.wait<void>(<Future<void>>[
    _observeNotificationDelivery(
      route: NotificationDeliveryRoute.native,
      delivery: nativeDelivery,
      onFailure: onFailure,
    ),
    if (companionDelivery != null)
      _observeNotificationDelivery(
        route: NotificationDeliveryRoute.companion,
        delivery: companionDelivery,
        onFailure: onFailure,
      ),
  ]);
}

Future<void> _observeNotificationDelivery({
  required NotificationDeliveryRoute route,
  required Future<void> Function() delivery,
  required NotificationDeliveryFailureObserver? onFailure,
}) async {
  try {
    await delivery();
  } on Object catch (error, stackTrace) {
    final NotificationDeliveryFailure failure = NotificationDeliveryFailure(
      route: route,
      error: error,
      stackTrace: stackTrace,
    );
    if (onFailure != null) {
      try {
        onFailure(failure);
      } on Object catch (observerError, observerStackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: observerError,
            stack: observerStackTrace,
            library: 'DingDong notification delivery',
            context: ErrorDescription(
              'while reporting a ${route.name} delivery failure',
            ),
          ),
        );
      }
      return;
    }
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'DingDong notification delivery',
        context: ErrorDescription('while delivering through ${route.name}'),
      ),
    );
  }
}

/// Composition root for production repositories and long-lived services.
final class AppDependencies {
  AppDependencies._({
    required this.jev,
    required this.clipboardStore,
    required this.clipboardGateway,
    required this.clipboardCaptureService,
    required this.clipboardCategoryRuleStore,
    required this.clipboardGroupOrderStore,
    required this.clipboardMonitorService,
    required this.paths,
    required this.resourceStore,
    required this.triggerGroupStore,
    required this.builtInResourceInstaller,
    required this.issueCenterController,
    required this.settingsRepository,
    required this.agentHttpServer,
  });

  static Future<AppDependencies> production({
    void Function(int index)? onShowUi,
    void Function()? onResourceLibraryChanged,
    void Function()? onCopyDetected,
    void Function(ClipboardRecord record)? onClipboardCaptured,
    Future<void> Function(DingRequest request)? onNotification,
    Future<void> Function(DingRequest request)? onSuppressedNotification,
    Future<void> Function(DingRequest request)? onFilteredNotification,
    void Function(AgentBridgeTaskStart start)? onAgentTaskStarted,
    FutureOr<int> Function(AgentConversationTarget target)?
    onAgentConversationOpened,
    NotificationDeliveryFailureObserver? onNotificationDeliveryFailure,
    CodexVoiceNotificationDetector? isCodexVoiceNotification,
    SubagentNotificationDetector? isSubagentNotification,
    SubagentConversationDetector? isSubagentConversation,
    AgentTaskStartLookup? agentTaskStartedAt,
    FutureOr<void> Function()? onSettingsChangedByAgent,
    PreferencesBackend? preferencesBackend,
  }) async {
    final AppDataPaths paths = AppDataPaths.current();
    paths.applicationSupportDirectory.createSync(recursive: true);
    final ClipboardRepository clipboardStore = ClipboardRepository.open(
      paths.clipboardDatabaseFile.path,
    );
    final ClipboardGateway clipboardGateway = DesktopClipboardGateway();
    final ClipboardCategoryRuleStore clipboardCategoryRuleStore =
        FileClipboardCategoryRuleStore(paths.clipboardCategoryRulesFile);
    final ClipboardGroupOrderStore clipboardGroupOrderStore =
        FileClipboardGroupOrderStore(paths.clipboardGroupOrderFile);
    final ClipboardCaptureService clipboardCaptureService =
        ClipboardCaptureService(
          gateway: clipboardGateway,
          store: clipboardStore,
          imageStoreDirectory: paths.clipboardImagesDirectory,
          onCaptured: onClipboardCaptured,
        );
    final ClipboardMonitorService clipboardMonitorService =
        ClipboardMonitorService(
          source: NativeClipboardChangeSource(),
          captureService: clipboardCaptureService,
          onCopyDetected: onCopyDetected,
        );
    final ResourceStore baseResourceStore = ResourceRepository(
      ResourceFileService(paths.resourceLibraryFile),
    );
    final SkillPackageInstaller skillPackageInstaller =
        GitHubSkillPackageInstaller(paths.skillPackagesDirectory);
    final IssueCenterController issueCenterController = IssueCenterController();
    final TriggerGroupStore baseTriggerGroupStore = TriggerGroupRepository(
      TriggerGroupFileService(paths.triggerGroupsFile),
    );
    final AgentAdapterRepository agentAdapterRepository =
        AgentAdapterRepository(
          userDirectory: paths.agentAdaptersDirectory,
          historyDirectory: paths.agentAdapterHistoryDirectory,
          homeDirectory:
              Platform.environment['HOME'] ??
              Platform.environment['USERPROFILE']!,
          loadBuiltIns: loadBundledAgentAdapterDocuments,
        );
    final AgentResourceSynchronizer resourceSynchronizer =
        await AgentResourceSynchronizer.currentUser(
          paths.skillPackagesDirectory,
          loadAdapters: agentAdapterRepository.loadEffectiveAdapters,
          skillPackageInstaller: skillPackageInstaller,
          triggerGroupStore: baseTriggerGroupStore,
        );
    issueCenterController.setInspector(
      () async => resourceSynchronizer.inspect(await baseResourceStore.load()),
    );
    final ResourceStore resourceStore = SynchronizedResourceStore(
      baseResourceStore,
      resourceSynchronizer,
      issueCenter: issueCenterController,
      onChanged: onResourceLibraryChanged,
    );
    final TriggerGroupStore triggerGroupStore = SynchronizedTriggerGroupStore(
      baseTriggerGroupStore,
      resourceStore,
      resourceSynchronizer,
      issueCenter: issueCenterController,
    );
    final PreferencesBackend preferences =
        preferencesBackend ?? SharedPreferencesBackend();
    final SettingsRepository settingsRepository = SettingsRepository(
      preferences,
      defaultTrayNotificationColor: paths.development
          ? TrayNotificationColor.pink
          : TrayNotificationColor.orange,
    );
    final BuiltInResourceInstaller builtInResourceInstaller =
        BuiltInResourceInstaller(
          resourceStore,
          preferences,
          skillDocumentLoader: () =>
              rootBundle.loadString('skills/dingdong-configure/SKILL.md'),
        );
    final NativeNotificationGateway notificationGateway =
        NativeNotificationGateway();
    final LocalConversationTokenUsageResolver tokenUsageResolver =
        LocalConversationTokenUsageResolver();
    final JevService jev = openJevService(paths);
    final aiResourceSelector = AiResourceSelector(
      store: AiCompanionPreferencesStore(
        preferences,
        development: paths.development,
      ),
      onUsage: (record) async {
        // Keep the host's background use in the same separate numeric ledger.
        // A short-lived connection observes writes from auxiliary engines too.
        final repository = LocalTokenUsageRepository(
          databasePath: paths.tokenUsageDatabaseFile.path,
        );
        try {
          await repository.recordInternalUsage(record);
        } finally {
          await repository.close();
        }
      },
    );
    final AgentRouter router = AgentRouter(
      selectBridgeResources: aiResourceSelector.select,
      jevRoutes: JevRoutes(jev),
      loadJevUsage: (request) async {
        final id = request.conversationId;
        if (!jev.store.installed || id == null || id.isEmpty) return null;
        final usage = jev.store.usage(source: request.source, conversation: id);
        return usage['requests'] == 0
            ? null
            : {...usage, 'scope': 'current_conversation'};
      },
      defaultDingMessage: (String source) async {
        final AppSettings settings = await settingsRepository.load();
        return appLocalizationsFor(
          settings.language,
        ).sourceCompletedCurrentTask(source);
      },
      onAgentTaskStarted: (AgentBridgeTaskStart start) async {
        final AppSettings settings = await settingsRepository.load();
        if (!await shouldRecordAgentTaskStart(
          start: start,
          settings: settings,
          isSubagentConversation: isSubagentConversation,
        )) {
          return;
        }
        onAgentTaskStarted?.call(start);
      },
      onAgentConversationOpened: onAgentConversationOpened,
      onDing: (request) => unawaited(() async {
        final AppSettings settings = await settingsRepository.load();
        await deliverAgentNotification(
          request: request,
          settings: settings,
          nativeDelivery: (DingRequest resolvedRequest) =>
              notificationGateway.trigger(
                resolvedRequest,
                flashCount:
                    (settings
                                .reminderProfile(resolvedRequest.reminderId)
                                ?.style ??
                            settings.notificationRules.trayStyleFor(
                              resolvedRequest.notificationKind,
                            )) ==
                        TrayReminderStyle.staticMarker
                    ? 0
                    : 8,
                customSoundPath:
                    settings
                        .reminderProfile(resolvedRequest.reminderId)
                        ?.customSoundPath ??
                    settings.customSoundPathFor(
                      resolvedRequest.notificationKind,
                    ),
              ),
          companionDelivery: onNotification,
          onFiltered: onFilteredNotification,
          isCodexVoiceNotification: isCodexVoiceNotification,
          isSubagentNotification: isSubagentNotification,
          onFailure: onNotificationDeliveryFailure,
          taskStartedAt: agentTaskStartedAt,
        );
      }()),
      onSuppressedDing: (request) => unawaited(() async {
        final AppSettings settings = await settingsRepository.load();
        await deliverAgentNotification(
          request: request,
          settings: settings,
          suppressNativeNotification: true,
          nativeDelivery: (DingRequest resolvedRequest) =>
              notificationGateway.trigger(
                resolvedRequest,
                flashCount:
                    (settings
                                .reminderProfile(resolvedRequest.reminderId)
                                ?.style ??
                            settings.notificationRules.trayStyleFor(
                              resolvedRequest.notificationKind,
                            )) ==
                        TrayReminderStyle.staticMarker
                    ? 0
                    : 8,
                customSoundPath:
                    settings
                        .reminderProfile(resolvedRequest.reminderId)
                        ?.customSoundPath ??
                    settings.customSoundPathFor(
                      resolvedRequest.notificationKind,
                    ),
              ),
          companionDelivery: onSuppressedNotification,
          onFiltered: onFilteredNotification,
          isCodexVoiceNotification: isCodexVoiceNotification,
          isSubagentNotification: isSubagentNotification,
          onFailure: onNotificationDeliveryFailure,
        );
      }()),
      clipboardCaptureService: clipboardCaptureService,
      clipboardGateway: clipboardGateway,
      clipboardStore: clipboardStore,
      allowAgentClipboardContent: () async =>
          (await settingsRepository.load()).allowAgentClipboardContent,
      loadConversationFooterSymbols: () async =>
          (await settingsRepository.load()).conversationFooterSymbols,
      loadShowConversationTokenUsage: () async =>
          (await settingsRepository.load()).showConversationTokenUsage,
      loadConversationTokenUsage: tokenUsageResolver.resolve,
      resourceStore: resourceStore,
      triggerGroupStore: triggerGroupStore,
      skillPackageInstaller: skillPackageInstaller,
      skillDeploymentStore: resourceSynchronizer.deploymentStore,
      onClipboardMonitoring: (bool enabled) => unawaited(() async {
        if (enabled) {
          await clipboardMonitorService.start();
        } else {
          await clipboardMonitorService.stop();
        }
        final AppSettings settings = await settingsRepository.load();
        await settingsRepository.save(
          settings.copyWith(clipboardMonitoring: enabled),
        );
      }()),
      onShowUi: onShowUi,
      reminderSettings: ReminderSettingsService(
        settingsRepository,
        ReminderAudioImporter(
          Directory(
            '${paths.applicationSupportDirectory.path}/Reminder Sounds',
          ),
        ),
        onChanged: () async {
          await onSettingsChangedByAgent?.call();
        },
      ).call,
      updateReminderSounds: ({String? completion, String? attention}) async {
        final AppSettings next = (await settingsRepository.load())
            .withReminderSounds(completion: completion, attention: attention);
        await settingsRepository.save(next);
        await onSettingsChangedByAgent?.call();
        return <String, Object?>{
          'completionSound': next.selectedSound,
          'attentionSound': next.notificationRules.attentionSound,
        };
      },
    );
    return AppDependencies._(
      jev: jev,
      clipboardStore: clipboardStore,
      clipboardGateway: clipboardGateway,
      clipboardCaptureService: clipboardCaptureService,
      clipboardCategoryRuleStore: clipboardCategoryRuleStore,
      clipboardGroupOrderStore: clipboardGroupOrderStore,
      clipboardMonitorService: clipboardMonitorService,
      paths: paths,
      resourceStore: resourceStore,
      triggerGroupStore: triggerGroupStore,
      builtInResourceInstaller: builtInResourceInstaller,
      issueCenterController: issueCenterController,
      settingsRepository: settingsRepository,
      agentHttpServer: AgentHttpServer(router),
    );
  }

  final JevService jev;
  final AppDataPaths paths;
  final ClipboardGateway clipboardGateway;
  final ClipboardCaptureService clipboardCaptureService;
  final ClipboardCategoryRuleStore clipboardCategoryRuleStore;
  final ClipboardGroupOrderStore clipboardGroupOrderStore;
  final ClipboardMonitorService clipboardMonitorService;
  final ClipboardRepository clipboardStore;
  final ResourceStore resourceStore;
  final TriggerGroupStore triggerGroupStore;
  final BuiltInResourceInstaller builtInResourceInstaller;
  final IssueCenterController issueCenterController;
  final SettingsRepository settingsRepository;
  final AgentHttpServer agentHttpServer;
  AppSettings initialSettings = const AppSettings();

  void applyClipboardRetention(AppSettings settings, {DateTime? now}) {
    final List<ClipboardRecord> deleted = clipboardStore.trim(
      maxItems: settings.clipboardMaxItems,
      maxAgeDays: settings.clipboardMaxAgeDays,
      now: now ?? DateTime.now().toUtc(),
    );
    final List<ClipboardRecord> archives = clipboardStore
        .listArchives()
        .map((ClipboardArchiveEntry entry) => entry.record)
        .toList(growable: false);
    final Set<String> archivedImagePaths = archives
        .where(
          (ClipboardRecord record) =>
              record.tags.contains('image') && record.tags.contains('file-url'),
        )
        .map((ClipboardRecord record) => record.content)
        .toSet();
    for (final ClipboardRecord record in deleted) {
      if (!archivedImagePaths.contains(record.content)) {
        deleteManagedClipboardImage(record, paths.clipboardImagesDirectory);
      }
    }
    pruneUnreferencedManagedClipboardImages(<ClipboardRecord>[
      ...clipboardStore.list(limit: 5000, includeProtectedBeyondLimit: true),
      ...archives,
    ], paths.clipboardImagesDirectory);
  }

  Future<void> start() async {
    await paths.applicationSupportDirectory.create(recursive: true);
    bool builtInInstallFailed = false;
    try {
      await builtInResourceInstaller.install();
    } on Object {
      builtInInstallFailed = true;
      // The synchronized store has already published a structured problem.
      // An external Agent conflict must not prevent DingDong from opening.
    }
    if (!builtInInstallFailed) {
      try {
        await resourceStore.save(await resourceStore.load());
      } on Object {
        // The synchronized store publishes the problem to the issue center.
      }
    }
    initialSettings = await settingsRepository.load();
    applyClipboardRetention(initialSettings);
    await agentHttpServer.start(port: initialSettings.apiPort);
    await paths.activePortFile.writeAsString(
      agentHttpServer.baseUri.port.toString(),
      flush: true,
    );
  }
}
