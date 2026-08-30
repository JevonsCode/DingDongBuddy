// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:dingdong/features/agent_api/domain/agent_setup_revision.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_monitor_service.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_settings_controller.dart';
import 'package:dingdong/features/selection/domain/selection_plugin_gateway.dart';
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
    SelectionPluginGateway? selectionPluginGateway,
    bool restoreSelectionPluginOnLoad = true,
    Future<void> Function()? onSettingsSaved,
    this.mcpCommandPath = 'dingdong-mcp',
    this.systemUsageSource,
    this.systemDataCleaner,
    this.systemDataLocationGateway,
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
       _selectionPluginGateway = selectionPluginGateway,
       _restoreSelectionPluginOnLoad = restoreSelectionPluginOnLoad,
       _onSettingsSaved = onSettingsSaved,
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
  final SelectionPluginGateway? _selectionPluginGateway;
  final bool _restoreSelectionPluginOnLoad;
  final Future<void> Function()? _onSettingsSaved;
  final String mcpCommandPath;
  final SystemUsageSource? systemUsageSource;
  final SystemDataCleaner? systemDataCleaner;
  final SystemDataLocationGateway? systemDataLocationGateway;
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
  SelectionPluginRuntimeStatus _selectionPluginStatus =
      const SelectionPluginRuntimeStatus.disabled();
  SelectionPluginError? _selectionPluginConfigurationError;
  Future<void> _selectionOperation = Future<void>.value();
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
  bool get isSelectionPluginRunning => _selectionPluginStatus.running;
  bool get isSelectionPluginPermissionGranted =>
      _selectionPluginStatus.permissionGranted;
  bool get isSelectionPluginTokenConfigured =>
      _selectionPluginStatus.tokenConfigured;
  SelectionPluginError? get selectionPluginConfigurationError =>
      _selectionPluginConfigurationError;
  @override
  bool? get quickPastePermissionGranted => _isQuickPastePermissionGranted;
  String get mcpSetupPrompt => defaultMcpSetupPrompt(
    language: _settings.language,
    commandPath: mcpCommandPath,
  );
  SystemUsageSnapshot? get systemUsage => _systemUsage;
  bool get canClearSystemData => systemDataCleaner != null;
  bool get canOpenSystemDataLocation => systemDataLocationGateway != null;
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
    if (_disposed || (_loaded && !force)) {
      return;
    }
    try {
      final AppSettings loadedSettings = await _repository.load();
      if (_disposed) return;
      if (!_loaded) {
        _loadedApiPort = loadedSettings.apiPort;
      }
      _settings = loadedSettings;
      final LaunchAtStartup? launchAtStartup = _launchAtStartup;
      if (launchAtStartup != null) {
        final bool launchAtStartupEnabled = await launchAtStartup.isEnabled();
        if (_disposed) return;
        _settings = _settings.copyWith(launchAtStartup: launchAtStartupEnabled);
      }
      await _onWindowOpacityChanged?.call(_settings.backgroundOpacity);
      if (_disposed) return;
      await _onDockIconHiddenChanged?.call(_settings.hideDockIcon);
      if (_disposed) return;
      await _onTrayNotificationColorChanged?.call(
        _settings.trayNotificationColor,
      );
      if (_disposed) return;
      String? loadWarning;
      final Future<bool> Function(GlobalHotKey value)? updateGlobalHotKey =
          _onGlobalHotKeyChanged;
      if (updateGlobalHotKey != null) {
        final bool registered = await updateGlobalHotKey(
          _settings.globalHotKey,
        );
        if (_disposed) return;
        if (!registered) {
          _settings = _settings.copyWith(
            globalHotKey: GlobalHotKey.defaultValue,
          );
          await _repository.save(_settings);
          if (_disposed) return;
          loadWarning = _globalHotKeyRegistrationError;
        }
      }
      if (_settings.clipboardMonitoring) {
        await _clipboardMonitoring?.start();
        if (_disposed) return;
      }
      final bool? quickPastePermissionGranted =
          await _quickPastePermissionGateway?.isGranted();
      if (_disposed) return;
      _isQuickPastePermissionGranted = quickPastePermissionGranted;
      if (!_loaded && _restoreSelectionPluginOnLoad) {
        await _applySelectionPluginConfiguration(_settings.selectionPlugin);
      } else {
        await refreshSelectionPluginStatus();
      }
      if (_disposed) return;
      await _loadSystemUsage();
      if (_disposed) return;
      await _loadApplicationUpdater();
      if (_disposed) return;
      _loaded = true;
      _errorMessage = loadWarning;
    } on Object {
      if (_disposed) return;
      _loaded = true;
      _errorMessage = 'Settings could not be loaded.';
    }
    if (!_disposed) {
      notifyListeners();
    }
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

  /// Applies the user-controlled lifecycle before persisting it. This order is
  /// important when disabling: native observers and model work stop first.
  Future<void> setSelectionPluginEnabled(bool enabled) {
    return _queueSelectionOperation(
      () => _setSelectionPluginConfiguration(
        _settings.selectionPlugin.copyWith(enabled: enabled),
      ),
    );
  }

  Future<void> setSelectionPluginConfiguration(
    SelectionPluginConfiguration value,
  ) => _queueSelectionOperation(() => _setSelectionPluginConfiguration(value));

  Future<void> _queueSelectionOperation(Future<void> Function() operation) {
    if (_disposed) return Future<void>.value();
    final Future<void> next = _selectionOperation.then<void>((_) async {
      if (_disposed) return;
      await operation();
    });
    _selectionOperation = next.catchError((Object _) {});
    return next;
  }

  Future<void> _setSelectionPluginConfiguration(
    SelectionPluginConfiguration value,
  ) async {
    if (_disposed) return;
    final SelectionPluginError? validationError = value.validationError;
    if (validationError != null) {
      _selectionPluginConfigurationError = validationError;
      notifyListeners();
      return;
    }
    final SelectionPluginConfiguration candidate = value.sanitized();
    var applied = false;
    try {
      applied = await _applySelectionPluginConfiguration(
        candidate,
        rethrowErrors: true,
      );
      if (!applied) return;
      _settings = _settings.copyWith(selectionPlugin: candidate);
      _selectionPluginConfigurationError = null;
      if (!_disposed) {
        notifyListeners();
      }
      await _save();
      if (_disposed) return;
      if (_errorMessage != null) {
        _selectionPluginConfigurationError =
            SelectionPluginError.persistenceFailed;
        notifyListeners();
      }
    } on Object {
      if (_disposed) return;
      // Keep the actual native state visible if only persistence failed.
      // In particular, a failed disk write must never re-enable the plugin.
      _selectionPluginConfigurationError = applied
          ? SelectionPluginError.persistenceFailed
          : SelectionPluginError.updateFailed;
      notifyListeners();
    }
  }

  Future<void> refreshSelectionPluginStatus() =>
      _queueSelectionOperation(_refreshSelectionPluginStatus);

  Future<void> _refreshSelectionPluginStatus() async {
    final SelectionPluginGateway? gateway = _selectionPluginGateway;
    if (_disposed || gateway == null) return;
    try {
      final SelectionPluginRuntimeStatus status = await gateway.status();
      if (_disposed) return;
      _selectionPluginStatus = status;
      // A refresh observes the host; replaying persisted settings could undo
      // an in-flight change made by the dedicated settings window.
      _settings = _settings.copyWith(
        selectionPlugin: _settings.selectionPlugin.copyWith(
          enabled: _selectionPluginStatus.enabled,
        ),
      );
      _selectionPluginConfigurationError = null;
    } on Object {
      if (_disposed) return;
      _selectionPluginConfigurationError =
          SelectionPluginError.statusUnavailable;
    }
    if (!_disposed) {
      notifyListeners();
    }
  }

  Future<void> openSelectionPluginAccessibilitySettings() async {
    if (_disposed) return;
    try {
      await _requireSelectionGateway().openAccessibilitySettings();
    } on Object {
      if (_disposed) return;
      _selectionPluginConfigurationError =
          SelectionPluginError.permissionSettingsUnavailable;
      notifyListeners();
    }
  }

  Future<void> saveSelectionPluginToken(
    String value, {
    SelectionPluginConfiguration? configuration,
  }) => _queueSelectionOperation(() async {
    if (_disposed) return;
    if (configuration != null) {
      await _setSelectionPluginConfiguration(configuration);
      if (_disposed) return;
      if (_selectionPluginConfigurationError != null) return;
    }
    final String token = value.trim();
    if (token.isEmpty) {
      _selectionPluginConfigurationError = SelectionPluginError.tokenRequired;
      notifyListeners();
      return;
    }
    try {
      await _requireSelectionGateway().saveToken(token);
      if (_disposed) return;
      _selectionPluginStatus = SelectionPluginRuntimeStatus(
        enabled: _selectionPluginStatus.enabled,
        running: _selectionPluginStatus.running,
        permissionGranted: _selectionPluginStatus.permissionGranted,
        tokenConfigured: true,
      );
      _selectionPluginConfigurationError = null;
    } on Object {
      if (_disposed) return;
      _selectionPluginConfigurationError = SelectionPluginError.tokenSaveFailed;
    }
    if (!_disposed) {
      notifyListeners();
    }
  });

  Future<void> clearSelectionPluginToken() =>
      _queueSelectionOperation(() async {
        if (_disposed) return;
        try {
          await _requireSelectionGateway().clearToken();
          if (_disposed) return;
          _selectionPluginStatus = SelectionPluginRuntimeStatus(
            enabled: _selectionPluginStatus.enabled,
            running: _selectionPluginStatus.running,
            permissionGranted: _selectionPluginStatus.permissionGranted,
            tokenConfigured: false,
          );
          _selectionPluginConfigurationError = null;
        } on Object {
          if (_disposed) return;
          _selectionPluginConfigurationError =
              SelectionPluginError.tokenRemoveFailed;
        }
        if (!_disposed) {
          notifyListeners();
        }
      });

  SelectionPluginGateway _requireSelectionGateway() {
    final SelectionPluginGateway? gateway = _selectionPluginGateway;
    if (gateway == null) throw StateError('Selection host is unavailable.');
    return gateway;
  }

  Future<bool> _applySelectionPluginConfiguration(
    SelectionPluginConfiguration configuration, {
    bool rethrowErrors = false,
  }) async {
    final SelectionPluginGateway? gateway = _selectionPluginGateway;
    if (_disposed) return false;
    if (gateway == null) {
      if (rethrowErrors) {
        throw StateError('Selection host is unavailable.');
      }
      if (configuration.enabled) {
        _selectionPluginConfigurationError = SelectionPluginError.unavailable;
      }
      return false;
    }
    try {
      final SelectionPluginRuntimeStatus status = await gateway.apply(
        configuration,
      );
      if (!_disposed) {
        _selectionPluginStatus = status;
      }
      return true;
    } on Object {
      if (_disposed) return false;
      _selectionPluginConfigurationError = SelectionPluginError.unavailable;
      if (rethrowErrors) rethrow;
      return false;
    }
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
      final ReleaseMetadata metadata = await source.fetch();
      if (_disposed) return;
      _releaseStatus = _releaseStatus.resolved(metadata, _now());
    } on Object catch (error) {
      if (_disposed) return;
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
    if (_disposed ||
        updater == null ||
        !_applicationUpdaterSupported ||
        _applicationUpdateStatus.isBusy) {
      return;
    }
    try {
      await updater.installLatest();
      if (_disposed) return;
      await _refreshApplicationUpdater();
      if (_disposed) return;
      if (_applicationUpdateStatus.isBusy) {
        _startApplicationUpdatePolling();
      }
    } on Object catch (error) {
      if (_disposed) return;
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
    if (_disposed || _isPresentingQuickPastePermissionGrant) {
      return;
    }
    final bool? granted = await _quickPastePermissionGateway?.isGranted();
    if (_disposed) return;
    _isQuickPastePermissionGranted = granted;
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
    if (_disposed) return;
    await _loadSystemUsage();
    if (_disposed) return;
    notifyListeners();
  }

  Future<bool> clearSystemData(Set<SystemDataCategory> categories) async {
    final SystemDataCleaner? cleaner = systemDataCleaner;
    final Set<SystemDataCategory> clearable = categories
        .where((SystemDataCategory category) => category.canClear)
        .toSet();
    if (_disposed ||
        cleaner == null ||
        clearable.isEmpty ||
        _isClearingSystemData) {
      return false;
    }
    _isClearingSystemData = true;
    notifyListeners();
    var cleared = false;
    try {
      await cleaner.clear(clearable);
      if (_disposed) return false;
      await _loadSystemUsage();
      if (_disposed) return false;
      cleared = true;
    } on Object {
      if (_disposed) return false;
      _errorMessage = 'Selected local data could not be cleared.';
    } finally {
      _isClearingSystemData = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
    return cleared;
  }

  Future<bool> openSystemDataLocation(SystemDataCategory category) async {
    final SystemDataLocationGateway? gateway = systemDataLocationGateway;
    if (gateway == null) return false;
    try {
      await gateway.open(category);
      return true;
    } on Object {
      if (_disposed) return false;
      _errorMessage = 'The DingDong data folder could not be opened.';
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadSystemUsage() async {
    final SystemUsageSource? source = systemUsageSource;
    if (_disposed || source == null) {
      return;
    }
    try {
      final SystemUsageSnapshot snapshot = await source.load();
      if (_disposed) return;
      _systemUsage = snapshot;
    } on Object {
      if (!_disposed) {
        _systemUsage = null;
      }
    }
  }

  Future<void> _loadApplicationUpdater() async {
    final ApplicationUpdater? updater = _applicationUpdater;
    if (_disposed) return;
    if (updater == null) {
      _applicationUpdaterSupported = false;
      _applicationUpdateStatus = const ApplicationUpdateStatus(
        phase: ApplicationUpdatePhase.unsupported,
      );
      return;
    }
    try {
      final bool supported = await updater.isSupported();
      if (_disposed) return;
      final ApplicationUpdateStatus status = supported
          ? await updater.readStatus()
          : const ApplicationUpdateStatus(
              phase: ApplicationUpdatePhase.unsupported,
            );
      if (_disposed) return;
      _applicationUpdaterSupported = supported;
      _applicationUpdateStatus = status;
      if (status.isBusy) {
        _startApplicationUpdatePolling();
      }
    } on Object {
      if (_disposed) return;
      _applicationUpdaterSupported = false;
      _applicationUpdateStatus = const ApplicationUpdateStatus(
        phase: ApplicationUpdatePhase.unsupported,
      );
    }
  }

  void _startApplicationUpdatePolling() {
    if (_disposed) return;
    _applicationUpdatePollTimer?.cancel();
    _applicationUpdatePollTimer = Timer.periodic(
      const Duration(milliseconds: 250),
      (_) => unawaited(_refreshApplicationUpdater()),
    );
  }

  Future<void> _refreshApplicationUpdater() async {
    final ApplicationUpdater? updater = _applicationUpdater;
    if (_disposed || updater == null || _isPollingApplicationUpdater) {
      return;
    }
    _isPollingApplicationUpdater = true;
    try {
      final ApplicationUpdateStatus status = await updater.readStatus();
      if (_disposed) return;
      if (status != _applicationUpdateStatus) {
        _applicationUpdateStatus = status;
        notifyListeners();
      }
      if (!status.isBusy && status.phase != ApplicationUpdatePhase.idle) {
        _applicationUpdatePollTimer?.cancel();
      }
    } on Object catch (error) {
      if (_disposed) return;
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
    _applicationUpdatePollTimer = null;
    _backgroundReleaseUpdateCheckTimer?.cancel();
    _backgroundReleaseUpdateCheckTimer = null;
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
        await _onSettingsSaved?.call();
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
