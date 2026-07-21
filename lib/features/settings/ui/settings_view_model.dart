// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:dingdong/features/clipboard/domain/clipboard_monitor_service.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_settings_controller.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/application_updater.dart';
import 'package:dingdong/features/settings/domain/launch_at_startup.dart';
import 'package:dingdong/features/settings/domain/mcp_setup_prompt.dart';
import 'package:dingdong/features/settings/domain/quick_paste_permission.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:dingdong/features/settings/domain/system_usage.dart';
import 'package:flutter/foundation.dart';

/// Observable application settings with immediate durable persistence.
final class SettingsViewModel extends ChangeNotifier
    implements ClipboardSettingsController {
  SettingsViewModel(
    this._repository, {
    ClipboardMonitoring? clipboardMonitoring,
    LaunchAtStartup? launchAtStartup,
    Future<void> Function(double value)? onWindowOpacityChanged,
    ReleaseMetadataSource? releaseMetadataSource,
    ExternalLinkGateway? externalLinkGateway,
    ApplicationUpdater? applicationUpdater,
    DateTime Function()? now,
    QuickPastePermissionGateway? quickPastePermissionGateway,
    this.mcpCommandPath = 'dingdong-mcp',
    this.systemUsageSource,
  }) : _clipboardMonitoring = clipboardMonitoring,
       _launchAtStartup = launchAtStartup,
       _onWindowOpacityChanged = onWindowOpacityChanged,
       _releaseMetadataSource = releaseMetadataSource,
       _externalLinkGateway = externalLinkGateway,
       _applicationUpdater = applicationUpdater,
       _quickPastePermissionGateway = quickPastePermissionGateway,
       _now = now ?? DateTime.now;

  final SettingsRepository _repository;
  final ClipboardMonitoring? _clipboardMonitoring;
  final LaunchAtStartup? _launchAtStartup;
  final Future<void> Function(double value)? _onWindowOpacityChanged;
  final ReleaseMetadataSource? _releaseMetadataSource;
  final ExternalLinkGateway? _externalLinkGateway;
  final ApplicationUpdater? _applicationUpdater;
  final DateTime Function() _now;
  final QuickPastePermissionGateway? _quickPastePermissionGateway;
  final String mcpCommandPath;
  final SystemUsageSource? systemUsageSource;
  AppSettings _settings = const AppSettings();
  bool _loaded = false;
  String? _errorMessage;
  ReleaseStatus _releaseStatus = const ReleaseStatus();
  ApplicationUpdateStatus _applicationUpdateStatus =
      const ApplicationUpdateStatus();
  bool _applicationUpdaterSupported = false;
  bool _isPollingApplicationUpdater = false;
  Timer? _applicationUpdatePollTimer;
  bool? _isQuickPastePermissionGranted;
  SystemUsageSnapshot? _systemUsage;
  int _loadedApiPort = 2333;

  AppSettings get settings => _settings;
  @override
  bool get clipboardMonitoring => _settings.clipboardMonitoring;
  bool get isLoaded => _loaded;
  String? get errorMessage => _errorMessage;
  ReleaseStatus get releaseStatus => _releaseStatus;
  ApplicationUpdateStatus get applicationUpdateStatus =>
      _applicationUpdateStatus;
  bool get applicationUpdaterSupported => _applicationUpdaterSupported;
  bool? get isQuickPastePermissionGranted => _isQuickPastePermissionGranted;
  @override
  bool? get quickPastePermissionGranted => _isQuickPastePermissionGranted;
  String get mcpSetupPrompt => defaultMcpSetupPrompt(
    language: _settings.language,
    commandPath: mcpCommandPath,
  );
  SystemUsageSnapshot? get systemUsage => _systemUsage;
  bool get requiresRestart => _loaded && _settings.apiPort != _loadedApiPort;

  Future<void> load() async {
    await _load(force: false);
  }

  /// Re-reads settings saved by a dedicated desktop settings window.
  Future<void> reload() async {
    await _load(force: true);
  }

  Future<void> _load({required bool force}) async {
    if (_loaded && !force) {
      return;
    }
    try {
      final AppSettings loadedSettings = await _repository.load();
      if (!_loaded) {
        _loadedApiPort = loadedSettings.apiPort;
      }
      _settings = loadedSettings;
      final LaunchAtStartup? launchAtStartup = _launchAtStartup;
      if (launchAtStartup != null) {
        _settings = _settings.copyWith(
          launchAtStartup: await launchAtStartup.isEnabled(),
        );
      }
      await _onWindowOpacityChanged?.call(_settings.backgroundOpacity);
      if (_settings.clipboardMonitoring) {
        await _clipboardMonitoring?.start();
      }
      _isQuickPastePermissionGranted = await _quickPastePermissionGateway
          ?.isGranted();
      await _loadSystemUsage();
      await _loadApplicationUpdater();
      _loaded = true;
      _errorMessage = null;
    } on Object {
      _loaded = true;
      _errorMessage = 'Settings could not be loaded.';
    }
    notifyListeners();
  }

  @override
  Future<void> setClipboardMonitoring(bool enabled) async {
    _settings = _settings.copyWith(clipboardMonitoring: enabled);
    notifyListeners();
    try {
      if (enabled) {
        await _clipboardMonitoring?.start();
      } else {
        await _clipboardMonitoring?.stop();
      }
      await _save();
    } on Object {
      _errorMessage = 'Clipboard monitoring could not be updated.';
      notifyListeners();
    }
  }

  Future<void> setLanguage(AppLanguagePreference value) async {
    _settings = _settings.copyWith(language: value);
    notifyListeners();
    await _save();
  }

  Future<void> setThemeMode(AppThemePreference value) async {
    _settings = _settings.copyWith(themeMode: value);
    notifyListeners();
    await _save();
  }

  Future<void> setLaunchAtStartup(bool value) async {
    try {
      await _launchAtStartup?.setEnabled(value);
      _settings = _settings.copyWith(launchAtStartup: value);
      await _save();
    } on Object {
      _errorMessage = 'Launch at startup could not be updated.';
      notifyListeners();
    }
  }

  Future<void> setBackgroundOpacity(double value) async {
    _settings = _settings.copyWith(backgroundOpacity: value);
    notifyListeners();
    await _onWindowOpacityChanged?.call(_settings.backgroundOpacity);
    await _save();
  }

  Future<void> setDensity(PanelDensityPreference value) async {
    _settings = _settings.copyWith(density: value);
    notifyListeners();
    await _save();
  }

  Future<void> setDefaultWorkspace(DefaultWorkspace value) async {
    _settings = _settings.copyWith(defaultWorkspace: value);
    notifyListeners();
    await _save();
  }

  Future<void> setSelectedSound(String value) async {
    _settings = _settings.copyWith(selectedSound: value);
    notifyListeners();
    await _save();
  }

  Future<void> setCustomSoundPath(String? value) async {
    _settings = _settings.copyWith(
      customSoundPath: value,
      selectedSound: value == null ? 'default' : 'custom',
    );
    notifyListeners();
    await _save();
  }

  Future<void> setRetention({
    required int maxItems,
    required int maxAgeDays,
  }) async {
    _settings = _settings.copyWith(
      clipboardMaxItems: maxItems,
      clipboardMaxAgeDays: maxAgeDays,
    );
    notifyListeners();
    await _save();
  }

  Future<void> setRememberAgentActivity(bool value) async {
    _settings = _settings.copyWith(rememberAgentActivity: value);
    notifyListeners();
    await _save();
  }

  Future<void> setAgentActivityPolicy({
    required int maxItems,
    required int countHours,
  }) async {
    _settings = _settings.copyWith(
      agentActivityMaxItems: maxItems,
      agentActivityCountHours: countHours,
    );
    notifyListeners();
    await _save();
  }

  Future<void> setApiPort(int value) async {
    _settings = _settings.copyWith(apiPort: value);
    notifyListeners();
    await _save();
  }

  Future<void> markMcpAccessSeen() async {
    if (_settings.mcpAccessSeen) return;
    _settings = _settings.copyWith(mcpAccessSeen: true);
    notifyListeners();
    await _save();
  }

  Future<void> checkForUpdates() async {
    final ReleaseMetadataSource? source = _releaseMetadataSource;
    if (source == null || _releaseStatus.isChecking) {
      return;
    }
    _releaseStatus = _releaseStatus.checking();
    notifyListeners();
    try {
      _releaseStatus = _releaseStatus.resolved(await source.fetch(), _now());
    } on Object catch (error) {
      _releaseStatus = _releaseStatus.failed(error.toString(), _now());
    }
    notifyListeners();
  }

  /// Starts the native one-click flow. The native helper downloads, verifies,
  /// replaces the old application, removes obsolete files, and relaunches.
  Future<void> installLatestUpdate() async {
    final ApplicationUpdater? updater = _applicationUpdater;
    if (updater == null ||
        !_applicationUpdaterSupported ||
        _applicationUpdateStatus.isBusy) {
      return;
    }
    try {
      await updater.installLatest();
      await _refreshApplicationUpdater();
      if (_applicationUpdateStatus.isBusy) {
        _startApplicationUpdatePolling();
      }
    } on Object catch (error) {
      _applicationUpdateStatus = ApplicationUpdateStatus(
        phase: ApplicationUpdatePhase.failed,
        message: error.toString(),
      );
      notifyListeners();
    }
  }

  Future<void> openWebsite() async {
    await _externalLinkGateway?.open(_releaseStatus.website);
  }

  Future<void> openReleasePage() async {
    await _externalLinkGateway?.open(_releaseStatus.releasePage);
  }

  Future<void> reportProblem() async {
    await _externalLinkGateway?.open(defaultBugReportUri);
  }

  Future<void> requestFeature() async {
    await _externalLinkGateway?.open(defaultFeatureRequestUri);
  }

  @override
  Future<void> refreshQuickPastePermission() async {
    _isQuickPastePermissionGranted = await _quickPastePermissionGateway
        ?.isGranted();
    notifyListeners();
  }

  @override
  Future<void> openQuickPastePermissionSettings() async {
    await _quickPastePermissionGateway?.openSettings();
  }

  Future<void> refreshSystemUsage() async {
    await _loadSystemUsage();
    notifyListeners();
  }

  Future<void> _loadSystemUsage() async {
    final SystemUsageSource? source = systemUsageSource;
    if (source == null) {
      return;
    }
    try {
      _systemUsage = await source.load();
    } on Object {
      _systemUsage = null;
    }
  }

  Future<void> _loadApplicationUpdater() async {
    final ApplicationUpdater? updater = _applicationUpdater;
    if (updater == null) {
      _applicationUpdaterSupported = false;
      _applicationUpdateStatus = const ApplicationUpdateStatus(
        phase: ApplicationUpdatePhase.unsupported,
      );
      return;
    }
    try {
      _applicationUpdaterSupported = await updater.isSupported();
      _applicationUpdateStatus = _applicationUpdaterSupported
          ? await updater.readStatus()
          : const ApplicationUpdateStatus(
              phase: ApplicationUpdatePhase.unsupported,
            );
      if (_applicationUpdateStatus.isBusy) {
        _startApplicationUpdatePolling();
      }
    } on Object {
      _applicationUpdaterSupported = false;
      _applicationUpdateStatus = const ApplicationUpdateStatus(
        phase: ApplicationUpdatePhase.unsupported,
      );
    }
  }

  void _startApplicationUpdatePolling() {
    _applicationUpdatePollTimer?.cancel();
    _applicationUpdatePollTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => unawaited(_refreshApplicationUpdater()),
    );
  }

  Future<void> _refreshApplicationUpdater() async {
    final ApplicationUpdater? updater = _applicationUpdater;
    if (updater == null || _isPollingApplicationUpdater) {
      return;
    }
    _isPollingApplicationUpdater = true;
    try {
      final ApplicationUpdateStatus status = await updater.readStatus();
      if (status != _applicationUpdateStatus) {
        _applicationUpdateStatus = status;
        notifyListeners();
      }
      if (!status.isBusy && status.phase != ApplicationUpdatePhase.idle) {
        _applicationUpdatePollTimer?.cancel();
      }
    } on Object catch (error) {
      _applicationUpdateStatus = ApplicationUpdateStatus(
        phase: ApplicationUpdatePhase.failed,
        message: error.toString(),
      );
      _applicationUpdatePollTimer?.cancel();
      notifyListeners();
    } finally {
      _isPollingApplicationUpdater = false;
    }
  }

  Future<void> shutdown() async {
    _applicationUpdatePollTimer?.cancel();
    await _clipboardMonitoring?.stop();
  }

  @override
  void dispose() {
    _applicationUpdatePollTimer?.cancel();
    super.dispose();
  }

  Future<void> _save() async {
    try {
      await _repository.save(_settings);
      _errorMessage = null;
    } on Object {
      _errorMessage = 'Settings could not be saved.';
    }
    notifyListeners();
  }
}
