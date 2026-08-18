// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:dingdong/features/agent_api/domain/agent_setup_revision.dart';
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
    Future<void> Function(bool value)? onDockIconHiddenChanged,
    Future<void> Function()? onShowMenuBarRecovery,
    Future<void> Function(TrayNotificationColor value)?
    onTrayNotificationColorChanged,
    Future<bool> Function(GlobalHotKey value)? onGlobalHotKeyChanged,
    Future<void> Function(bool enabled)? onLifecycleTelemetryChanged,
    ReleaseMetadataSource? releaseMetadataSource,
    ExternalLinkGateway? externalLinkGateway,
    ApplicationUpdater? applicationUpdater,
    DateTime Function()? now,
    QuickPastePermissionGateway? quickPastePermissionGateway,
    this.mcpCommandPath = 'dingdong-mcp',
    this.systemUsageSource,
    this.systemDataCleaner,
  }) : _clipboardMonitoring = clipboardMonitoring,
       _launchAtStartup = launchAtStartup,
       _onWindowOpacityChanged = onWindowOpacityChanged,
       _onDockIconHiddenChanged = onDockIconHiddenChanged,
       _onShowMenuBarRecovery = onShowMenuBarRecovery,
       _onTrayNotificationColorChanged = onTrayNotificationColorChanged,
       _onGlobalHotKeyChanged = onGlobalHotKeyChanged,
       _onLifecycleTelemetryChanged = onLifecycleTelemetryChanged,
       _releaseMetadataSource = releaseMetadataSource,
       _externalLinkGateway = externalLinkGateway,
       _applicationUpdater = applicationUpdater,
       _quickPastePermissionGateway = quickPastePermissionGateway,
       _now = now ?? DateTime.now;

  final SettingsRepository _repository;
  final ClipboardMonitoring? _clipboardMonitoring;
  final LaunchAtStartup? _launchAtStartup;
  final Future<void> Function(double value)? _onWindowOpacityChanged;
  final Future<void> Function(bool value)? _onDockIconHiddenChanged;
  final Future<void> Function()? _onShowMenuBarRecovery;
  final Future<void> Function(TrayNotificationColor value)?
  _onTrayNotificationColorChanged;
  final Future<bool> Function(GlobalHotKey value)? _onGlobalHotKeyChanged;
  final Future<void> Function(bool enabled)? _onLifecycleTelemetryChanged;
  final ReleaseMetadataSource? _releaseMetadataSource;
  final ExternalLinkGateway? _externalLinkGateway;
  final ApplicationUpdater? _applicationUpdater;
  final DateTime Function() _now;
  final QuickPastePermissionGateway? _quickPastePermissionGateway;
  final String mcpCommandPath;
  final SystemUsageSource? systemUsageSource;
  final SystemDataCleaner? systemDataCleaner;
  AppSettings _settings = const AppSettings();
  bool _loaded = false;
  String? _errorMessage;
  ReleaseStatus _releaseStatus = const ReleaseStatus();
  ApplicationUpdateStatus _applicationUpdateStatus =
      const ApplicationUpdateStatus();
  bool _applicationUpdaterSupported = false;
  bool _isPollingApplicationUpdater = false;
  Timer? _applicationUpdatePollTimer;
  Timer? _backgroundReleaseUpdateCheckTimer;
  bool? _isQuickPastePermissionGranted;
  bool _isPresentingQuickPastePermissionGrant = false;
  SystemUsageSnapshot? _systemUsage;
  bool _isClearingSystemData = false;
  int _loadedApiPort = 2333;
  bool _savePending = false;
  Future<void>? _saveInFlight;
  bool _disposed = false;

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
  bool get canClearSystemData => systemDataCleaner != null;
  bool get isClearingSystemData => _isClearingSystemData;
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
      await _onDockIconHiddenChanged?.call(_settings.hideDockIcon);
      await _onTrayNotificationColorChanged?.call(
        _settings.trayNotificationColor,
      );
      String? loadWarning;
      final Future<bool> Function(GlobalHotKey value)? updateGlobalHotKey =
          _onGlobalHotKeyChanged;
      if (updateGlobalHotKey != null &&
          !await updateGlobalHotKey(_settings.globalHotKey)) {
        _settings = _settings.copyWith(globalHotKey: GlobalHotKey.defaultValue);
        await _repository.save(_settings);
        loadWarning = _globalHotKeyRegistrationError;
      }
      if (_settings.clipboardMonitoring) {
        await _clipboardMonitoring?.start();
      }
      _isQuickPastePermissionGranted = await _quickPastePermissionGateway
          ?.isGranted();
      await _loadSystemUsage();
      await _loadApplicationUpdater();
      _loaded = true;
      _errorMessage = loadWarning;
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

  Future<void> setHideDockIcon(bool value) async {
    _settings = _settings.copyWith(hideDockIcon: value);
    notifyListeners();
    try {
      await _onDockIconHiddenChanged?.call(value);
      await _save();
    } on Object {
      _errorMessage = 'Dock icon visibility could not be updated.';
      notifyListeners();
    }
  }

  Future<void> showMenuBarRecovery() async {
    try {
      await _onShowMenuBarRecovery?.call();
    } on Object {
      _errorMessage = 'Menu bar recovery could not be opened.';
      notifyListeners();
    }
  }

  Future<void> setTrayNotificationColor(TrayNotificationColor value) async {
    _settings = _settings.copyWith(trayNotificationColor: value);
    notifyListeners();
    try {
      await _onTrayNotificationColorChanged?.call(value);
      await _save();
    } on Object {
      _errorMessage = 'Menu bar notification color could not be updated.';
      notifyListeners();
    }
  }

  Future<void> setGlobalHotKey(GlobalHotKey value) async {
    final GlobalHotKey previous = _settings.globalHotKey;
    final GlobalHotKey candidate = value.sanitized();
    if (_settings.workspaceShortcuts.values.any(
      (WorkspaceShortcut shortcut) => _globalHotKeyConflictsWithWorkspace(
        candidate,
        shortcut,
        defaultTargetPlatform,
      ),
    )) {
      _errorMessage = _workspaceHotKeyConflictError;
      notifyListeners();
      return;
    }
    _settings = _settings.copyWith(globalHotKey: candidate);
    notifyListeners();
    try {
      final bool registered =
          await _onGlobalHotKeyChanged?.call(candidate) ?? true;
      if (!registered) {
        throw StateError('Global hot key is unavailable.');
      }
      await _save();
    } on Object {
      _settings = _settings.copyWith(globalHotKey: previous);
      _errorMessage = _globalHotKeyRegistrationError;
      notifyListeners();
    }
  }

  Future<bool> setWorkspaceShortcut(
    int workspaceIndex,
    WorkspaceShortcut value,
  ) async {
    final WorkspaceShortcut fallback = WorkspaceShortcuts.defaultValue.at(
      workspaceIndex,
    );
    final WorkspaceShortcut candidate = value.sanitized(fallback);
    final TargetPlatform platform = defaultTargetPlatform;
    final WorkspaceShortcuts shortcuts = _settings.workspaceShortcuts.replace(
      workspaceIndex,
      candidate,
    );
    final bool duplicatesAnotherWorkspace = shortcuts.values
        .asMap()
        .entries
        .where((MapEntry<int, WorkspaceShortcut> entry) {
          return entry.key != workspaceIndex;
        })
        .any((MapEntry<int, WorkspaceShortcut> entry) {
          return candidate.conflictsWith(entry.value, platform);
        });
    if (duplicatesAnotherWorkspace ||
        _globalHotKeyConflictsWithWorkspace(
          _settings.globalHotKey,
          candidate,
          platform,
        ) ||
        _workspaceShortcutIsReserved(candidate, platform)) {
      _errorMessage = _workspaceHotKeyConflictError;
      notifyListeners();
      return false;
    }
    _settings = _settings.copyWith(workspaceShortcuts: shortcuts);
    notifyListeners();
    await _save();
    return true;
  }

  Future<void> setBackgroundOpacity(double value) async {
    _settings = _settings.copyWith(backgroundOpacity: value);
    notifyListeners();
    await _onWindowOpacityChanged?.call(_settings.backgroundOpacity);
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

  Future<void> setAllowAgentClipboardContent(bool value) async {
    _settings = _settings.copyWith(allowAgentClipboardContent: value);
    notifyListeners();
    await _save();
  }

  Future<void> setLifecycleTelemetryEnabled(bool enabled) async {
    _settings = _settings.copyWith(lifecycleTelemetryEnabled: enabled);
    notifyListeners();
    await _save();
    try {
      await _onLifecycleTelemetryChanged?.call(enabled);
    } on Object {
      _errorMessage = 'Anonymous lifecycle statistics could not be updated.';
      notifyListeners();
    }
  }

  Future<void> setRememberAgentActivity(bool value) async {
    _settings = _settings.copyWith(rememberAgentActivity: value);
    notifyListeners();
    await _save();
  }

  Future<void> setNotifyAgentCompletion(bool value) async {
    _settings = _settings.copyWith(notifyAgentCompletion: value);
    notifyListeners();
    await _save();
  }

  Future<void> setNotifyAgentAttention(bool value) async {
    _settings = _settings.copyWith(notifyAgentAttention: value);
    notifyListeners();
    await _save();
  }

  Future<void> setNotifyCodexVoiceActivity(bool value) async {
    _settings = _settings.copyWith(notifyCodexVoiceActivity: value);
    notifyListeners();
    await _save();
  }

  Future<void> setNotifySubagentActivity(bool value) async {
    _settings = _settings.copyWith(notifySubagentActivity: value);
    notifyListeners();
    await _save();
  }

  Future<void> setGroupRepeatedAgentSessions(bool value) async {
    _settings = _settings.copyWith(groupRepeatedAgentSessions: value);
    notifyListeners();
    await _save();
  }

  Future<void> setShowConversationTokenUsage(bool value) async {
    _settings = _settings.copyWith(showConversationTokenUsage: value);
    notifyListeners();
    await _save();
  }

  Future<void> setConversationFooterSymbols(
    ConversationFooterSymbols value,
  ) async {
    _settings = _settings.copyWith(conversationFooterSymbols: value);
    notifyListeners();
    await _save();
  }

  Future<void> setConversationFooterSymbol({
    String? prompt,
    String? skill,
    String? mcp,
  }) {
    return setConversationFooterSymbols(
      _settings.conversationFooterSymbols.copyWith(
        prompt: prompt,
        skill: skill,
        mcp: mcp,
      ),
    );
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

  Future<void> markAgentSetupUpdated() async {
    if (!_settings.requiresAgentSetupUpdate) return;
    _settings = _settings.copyWith(
      agentSetupAcknowledgedRevision: currentAgentSetupRevision,
    );
    notifyListeners();
    await _save();
  }

  Future<void> checkForUpdates() async {
    final ReleaseMetadataSource? source = _releaseMetadataSource;
    if (_disposed || source == null || _releaseStatus.isChecking) {
      return;
    }
    _releaseStatus = _releaseStatus.checking();
    notifyListeners();
    try {
      _releaseStatus = _releaseStatus.resolved(await source.fetch(), _now());
    } on Object catch (error) {
      _releaseStatus = _releaseStatus.failed(error.toString(), _now());
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  /// Keeps the main popup's version indicator fresh while the app is hidden.
  ///
  /// The first check is still performed by the application startup flow. This
  /// timer only retries in the background, so a temporary network failure does
  /// not leave the update dot stale until the next restart or settings visit.
  void startBackgroundReleaseUpdateChecks() {
    if (_disposed ||
        _releaseMetadataSource == null ||
        _backgroundReleaseUpdateCheckTimer != null) {
      return;
    }
    _backgroundReleaseUpdateCheckTimer = Timer.periodic(
      backgroundReleaseUpdateCheckInterval,
      (_) => unawaited(checkForUpdates()),
    );
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
    if (_isPresentingQuickPastePermissionGrant) {
      return;
    }
    _isQuickPastePermissionGranted = await _quickPastePermissionGateway
        ?.isGranted();
    notifyListeners();
  }

  /// Keeps lifecycle refreshes from racing the visible grant animation.
  void beginQuickPastePermissionGrantPresentation() {
    _isPresentingQuickPastePermissionGrant = true;
  }

  Future<void> completeQuickPastePermissionGrantPresentation() async {
    _isPresentingQuickPastePermissionGrant = false;
    await refreshQuickPastePermission();
  }

  @override
  Future<void> openQuickPastePermissionSettings() async {
    await _quickPastePermissionGateway?.openSettings();
  }

  Future<void> refreshSystemUsage() async {
    await _loadSystemUsage();
    notifyListeners();
  }

  Future<bool> clearSystemData(Set<SystemDataCategory> categories) async {
    final SystemDataCleaner? cleaner = systemDataCleaner;
    final Set<SystemDataCategory> clearable = categories
        .where((SystemDataCategory category) => category.canClear)
        .toSet();
    if (cleaner == null || clearable.isEmpty || _isClearingSystemData) {
      return false;
    }
    _isClearingSystemData = true;
    notifyListeners();
    var cleared = false;
    try {
      await cleaner.clear(clearable);
      await _loadSystemUsage();
      cleared = true;
    } on Object {
      _errorMessage = 'Selected local data could not be cleared.';
    } finally {
      _isClearingSystemData = false;
      notifyListeners();
    }
    return cleared;
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
    _backgroundReleaseUpdateCheckTimer?.cancel();
    _backgroundReleaseUpdateCheckTimer = null;
    await _clipboardMonitoring?.stop();
  }

  @override
  void dispose() {
    _disposed = true;
    _applicationUpdatePollTimer?.cancel();
    _backgroundReleaseUpdateCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _save() {
    _savePending = true;
    return _saveInFlight ??= _drainSaves();
  }

  Future<void> _drainSaves() async {
    do {
      _savePending = false;
      final AppSettings snapshot = _settings;
      try {
        await _repository.save(snapshot);
        _errorMessage = null;
      } on Object {
        _errorMessage = 'Settings could not be saved.';
      }
    } while (_savePending);
    _saveInFlight = null;
    if (!_disposed) {
      notifyListeners();
    }
  }
}

const String _globalHotKeyRegistrationError =
    'Shortcut could not be registered. It may already be used by another app.';
const String _workspaceHotKeyConflictError =
    'Shortcut conflicts with another DingDong or system action.';

bool _globalHotKeyConflictsWithWorkspace(
  GlobalHotKey globalHotKey,
  WorkspaceShortcut workspaceShortcut,
  TargetPlatform platform,
) {
  return globalHotKey.key == workspaceShortcut.key &&
      globalHotKeyModifiers(globalHotKey, platform) ==
          workspaceShortcut.modifiers(platform);
}

bool _workspaceShortcutIsReserved(
  WorkspaceShortcut shortcut,
  TargetPlatform platform,
) {
  final DesktopShortcutModifiers modifiers = shortcut.modifiers(platform);
  final bool primaryPressed = platform == TargetPlatform.macOS
      ? modifiers.meta
      : modifiers.control;
  final bool primaryOnly =
      primaryPressed &&
      !modifiers.alt &&
      !modifiers.shift &&
      (platform != TargetPlatform.macOS || !modifiers.control) &&
      (platform == TargetPlatform.macOS || !modifiers.meta);
  if (primaryOnly && (shortcut.key == 'F' || shortcut.key == 'R')) {
    return true;
  }
  if (primaryPressed && RegExp(r'^[1-9]$').hasMatch(shortcut.key)) {
    return true;
  }
  if (<String>{'UP', 'DOWN', 'SPACE', 'RETURN'}.contains(shortcut.key)) {
    return true;
  }
  if (platform == TargetPlatform.macOS &&
      primaryOnly &&
      (shortcut.key == 'Q' || shortcut.key == 'W')) {
    return true;
  }
  return platform == TargetPlatform.windows &&
      modifiers.alt &&
      !modifiers.control &&
      !modifiers.meta &&
      !modifiers.shift &&
      shortcut.key == 'F4';
}
