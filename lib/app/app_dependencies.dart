import 'dart:async';
import 'dart:io';

import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:dingdong/features/agent_api/data/agent_bridge.dart';
import 'package:dingdong/features/agent_api/data/agent_http_server.dart';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/clipboard/data/clipboard_category_rule_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_group_order_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_monitor_service.dart';
import 'package:dingdong/features/clipboard/domain/managed_clipboard_images.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/library/data/agent_resource_synchronizer.dart';
import 'package:dingdong/features/library/data/resource_file_service.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_file_service.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resource_installer.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
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
    void Function(AgentBridgeTaskStart start)? onAgentTaskStarted,
    NotificationDeliveryFailureObserver? onNotificationDeliveryFailure,
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
    final AgentRouter router = AgentRouter(
      onAgentTaskStarted: onAgentTaskStarted,
      onDing: (request) => unawaited(() async {
        final AppSettings settings = await settingsRepository.load();
        final resolvedRequest = request.sound == DingSound.defaultSound
            ? request.copyWith(sound: DingSound.parse(settings.selectedSound))
            : request;
        await deliverNotificationIndependently(
          nativeDelivery: () => notificationGateway.trigger(
            resolvedRequest,
            customSoundPath: settings.customSoundPath,
          ),
          companionDelivery: onNotification == null
              ? null
              : () => onNotification(resolvedRequest),
          onFailure: onNotificationDeliveryFailure,
        );
      }()),
      onSuppressedDing: (request) => unawaited(() async {
        final AppSettings settings = await settingsRepository.load();
        final resolvedRequest = request.sound == DingSound.defaultSound
            ? request.copyWith(sound: DingSound.parse(settings.selectedSound))
            : request;
        await deliverNotificationIndependently(
          nativeDelivery: () => notificationGateway.trigger(
            resolvedRequest,
            customSoundPath: settings.customSoundPath,
          ),
          companionDelivery: onSuppressedNotification == null
              ? null
              : () => onSuppressedNotification(resolvedRequest),
          onFailure: onNotificationDeliveryFailure,
        );
      }()),
      clipboardCaptureService: clipboardCaptureService,
      clipboardGateway: clipboardGateway,
      clipboardStore: clipboardStore,
      allowAgentClipboardContent: () async =>
          (await settingsRepository.load()).allowAgentClipboardContent,
      resourceStore: resourceStore,
      triggerGroupStore: triggerGroupStore,
      skillPackageInstaller: skillPackageInstaller,
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
    );
    return AppDependencies._(
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
