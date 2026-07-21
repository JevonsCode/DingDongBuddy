import 'dart:async';

import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/agent_api/data/agent_http_server.dart';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/clipboard/data/clipboard_category_rule_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_group_order_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_monitor_service.dart';
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
import 'package:flutter/services.dart';

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
    required this.settingsRepository,
    required this.agentHttpServer,
  });

  factory AppDependencies.production({
    void Function(int index)? onShowUi,
    Future<void> Function(DingRequest request)? onNotification,
    PreferencesBackend? preferencesBackend,
  }) {
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
        );
    final ClipboardMonitorService clipboardMonitorService =
        ClipboardMonitorService(
          source: NativeClipboardChangeSource(),
          captureService: clipboardCaptureService,
        );
    final ResourceStore baseResourceStore = ResourceRepository(
      ResourceFileService(paths.resourceLibraryFile),
    );
    final SkillPackageInstaller skillPackageInstaller =
        GitHubSkillPackageInstaller(paths.skillPackagesDirectory);
    final ResourceStore resourceStore = SynchronizedResourceStore(
      baseResourceStore,
      AgentResourceSynchronizer.currentUser(
        paths.skillPackagesDirectory,
        skillPackageInstaller: skillPackageInstaller,
      ),
    );
    final TriggerGroupStore triggerGroupStore = TriggerGroupRepository(
      TriggerGroupFileService(paths.triggerGroupsFile),
    );
    final PreferencesBackend preferences =
        preferencesBackend ?? SharedPreferencesBackend();
    final SettingsRepository settingsRepository = SettingsRepository(
      preferences,
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
      onDing: (request) => unawaited(() async {
        final AppSettings settings = await settingsRepository.load();
        final resolvedRequest = request.sound == DingSound.defaultSound
            ? request.copyWith(sound: DingSound.parse(settings.selectedSound))
            : request;
        await notificationGateway.trigger(
          resolvedRequest,
          customSoundPath: settings.customSoundPath,
        );
        await onNotification?.call(resolvedRequest);
      }()),
      clipboardCaptureService: clipboardCaptureService,
      clipboardGateway: clipboardGateway,
      clipboardStore: clipboardStore,
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
  final SettingsRepository settingsRepository;
  final AgentHttpServer agentHttpServer;
  AppSettings initialSettings = const AppSettings();

  Future<void> start() async {
    await paths.applicationSupportDirectory.create(recursive: true);
    await builtInResourceInstaller.install();
    try {
      await resourceStore.save(await resourceStore.load());
    } on Object {
      // An invalid external Agent config must not prevent DingDong from opening.
      // The next user-initiated resource save will surface the sync error.
    }
    initialSettings = await settingsRepository.load();
    await agentHttpServer.start(port: initialSettings.apiPort);
    await paths.activePortFile.writeAsString(
      agentHttpServer.baseUri.port.toString(),
      flush: true,
    );
  }
}
