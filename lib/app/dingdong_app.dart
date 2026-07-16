import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/data/data_revision_bus.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/clipboard/data/clipboard_category_rule_store.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_monitor_service.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_preview_launcher.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_share_gateway.dart';
import 'package:dingdong/features/clipboard/domain/quick_paste_gateway.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/library_transfer_gateway.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/library/domain/resource_update_fetcher.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/library_view_model_factory.dart';
import 'package:dingdong/features/settings/data/http_release_metadata_source.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/launch_at_startup.dart';
import 'package:dingdong/features/settings/domain/quick_paste_permission.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/settings/domain/sound_file_gateway.dart';
import 'package:dingdong/features/settings/domain/system_usage.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
import 'package:dingdong/features/shell/ui/shell_screen.dart';
import 'package:dingdong/platform/file_selector_library_transfer_gateway.dart';
import 'package:dingdong/platform/file_selector_sound_gateway.dart';
import 'package:dingdong/platform/url_launcher_external_link_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Root widget for the DingDong desktop application.
class DingDongApp extends StatefulWidget {
  const DingDongApp({
    this.activityController,
    this.agentBaseUri,
    this.clipboardCaptureService,
    this.clipboardCategoryRuleStore,
    this.clipboardGateway,
    this.desktopContextMenuGateway,
    this.clipboardMonitoring,
    this.clipboardStore,
    this.clipboardPreviewLauncher,
    this.clipboardShareGateway,
    this.quickPasteGateway,
    this.quickPastePermissionGateway,
    this.resourceStore,
    this.triggerGroupStore,
    this.libraryTransferGateway,
    this.resourceUpdateFetcher,
    this.resourceManagerLauncher,
    this.settingsWindowLauncher,
    this.settingsRepository,
    this.settingsViewModel,
    this.launchAtStartup,
    this.onWindowOpacityChanged,
    this.soundFileGateway,
    this.releaseMetadataSource,
    this.externalLinkGateway,
    this.mcpCommandPath = 'dingdong-mcp',
    this.systemUsageSource,
    this.onStartDragging,
    this.onHideWindow,
    this.shortcutHints,
    this.shellController,
    this.now,
    super.key,
  });

  final ActivityController? activityController;
  final Uri? agentBaseUri;
  final ClipboardCaptureService? clipboardCaptureService;
  final ClipboardCategoryRuleStore? clipboardCategoryRuleStore;
  final ClipboardGateway? clipboardGateway;
  final DesktopContextMenuGateway? desktopContextMenuGateway;
  final ClipboardMonitoring? clipboardMonitoring;
  final ClipboardStore? clipboardStore;
  final ClipboardPreviewLauncher? clipboardPreviewLauncher;
  final ClipboardShareGateway? clipboardShareGateway;
  final QuickPasteGateway? quickPasteGateway;
  final QuickPastePermissionGateway? quickPastePermissionGateway;
  final ResourceStore? resourceStore;
  final TriggerGroupStore? triggerGroupStore;
  final LibraryTransferGateway? libraryTransferGateway;
  final ResourceUpdateFetcher? resourceUpdateFetcher;
  final ResourceManagerLauncher? resourceManagerLauncher;
  final SettingsWindowLauncher? settingsWindowLauncher;
  final SettingsRepository? settingsRepository;
  final SettingsViewModel? settingsViewModel;
  final LaunchAtStartup? launchAtStartup;
  final Future<void> Function(double value)? onWindowOpacityChanged;
  final SoundFileGateway? soundFileGateway;
  final ReleaseMetadataSource? releaseMetadataSource;
  final ExternalLinkGateway? externalLinkGateway;
  final String mcpCommandPath;
  final SystemUsageSource? systemUsageSource;
  final Future<void> Function()? onStartDragging;
  final Future<void> Function()? onHideWindow;
  final ValueListenable<bool>? shortcutHints;
  final ShellController? shellController;
  final DateTime Function()? now;

  @override
  State<DingDongApp> createState() => _DingDongAppState();
}

class _DingDongAppState extends State<DingDongApp> {
  late final ClipboardViewModel _clipboardViewModel;
  late final DataRevisionBus _dataRevisions;
  late final ActivityController _activityController;
  late final LibraryViewModel _libraryViewModel;
  late final SettingsViewModel _settingsViewModel;
  late final ShellController _shellController;
  late final bool _ownsSettingsViewModel;
  late final bool _ownsActivityController;

  @override
  void initState() {
    super.initState();
    _ownsActivityController = widget.activityController == null;
    _activityController = widget.activityController ?? ActivityController();
    _dataRevisions = DataRevisionBus();
    _clipboardViewModel = ClipboardViewModel(
      widget.clipboardStore ?? InMemoryClipboardStore(),
      captureService: widget.clipboardCaptureService,
      gateway: widget.clipboardGateway,
      resourceStore: widget.resourceStore,
      quickPasteGateway: widget.quickPasteGateway,
      revisions: _dataRevisions,
      categoryRuleStore: widget.clipboardCategoryRuleStore,
    );
    _libraryViewModel = createDesktopLibraryViewModel(
      widget.resourceStore ?? InMemoryResourceStore(),
      updateFetcher: widget.resourceUpdateFetcher,
      triggerGroupStore: widget.triggerGroupStore,
      revisions: _dataRevisions,
    );
    _ownsSettingsViewModel = widget.settingsViewModel == null;
    _settingsViewModel =
        widget.settingsViewModel ??
        SettingsViewModel(
          widget.settingsRepository ??
              SettingsRepository(MemoryPreferencesBackend()),
          clipboardMonitoring: widget.clipboardMonitoring,
          launchAtStartup: widget.launchAtStartup,
          onWindowOpacityChanged: widget.onWindowOpacityChanged,
          releaseMetadataSource:
              widget.releaseMetadataSource ?? HttpReleaseMetadataSource(),
          externalLinkGateway:
              widget.externalLinkGateway ?? UrlLauncherExternalLinkGateway(),
          quickPastePermissionGateway: widget.quickPastePermissionGateway,
          mcpCommandPath: widget.mcpCommandPath,
          systemUsageSource: widget.systemUsageSource,
        );
    _shellController = widget.shellController ?? ShellController();
    unawaited(_settingsViewModel.load());
  }

  @override
  void dispose() {
    _clipboardViewModel.dispose();
    _libraryViewModel.dispose();
    unawaited(_dataRevisions.dispose());
    if (_ownsActivityController) {
      _activityController.dispose();
    }
    if (_ownsSettingsViewModel) {
      unawaited(_settingsViewModel.shutdown());
      _settingsViewModel.dispose();
    }
    if (widget.shellController == null) {
      _shellController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _settingsViewModel,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          title: 'DingDong',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: switch (_settingsViewModel.settings.themeMode) {
            AppThemePreference.system => ThemeMode.system,
            AppThemePreference.light => ThemeMode.light,
            AppThemePreference.dark => ThemeMode.dark,
          },
          locale: switch (_settingsViewModel.settings.language) {
            AppLanguagePreference.system => null,
            AppLanguagePreference.english => const Locale('en'),
            AppLanguagePreference.chinese => const Locale('zh'),
          },
          supportedLocales: const <Locale>[Locale('en'), Locale('zh')],
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            DingDongLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ShellScreen(
            activityController: _activityController,
            clipboardViewModel: _clipboardViewModel,
            clipboardGateway: widget.clipboardGateway,
            desktopContextMenuGateway: widget.desktopContextMenuGateway,
            clipboardPreviewLauncher: widget.clipboardPreviewLauncher,
            clipboardShareGateway: widget.clipboardShareGateway,
            libraryViewModel: _libraryViewModel,
            settingsViewModel: _settingsViewModel,
            controller: _shellController,
            agentBaseUri: widget.agentBaseUri,
            libraryTransferGateway:
                widget.libraryTransferGateway ??
                FileSelectorLibraryTransferGateway(),
            resourceManagerLauncher: widget.resourceManagerLauncher,
            settingsWindowLauncher: widget.settingsWindowLauncher,
            soundFileGateway:
                widget.soundFileGateway ?? FileSelectorSoundGateway(),
            onStartDragging: widget.onStartDragging,
            onHideWindow: widget.onHideWindow,
            shortcutHints: widget.shortcutHints,
            now: widget.now,
          ),
        );
      },
    );
  }
}
