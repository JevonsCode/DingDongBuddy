import 'dart:async';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_client.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_store.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_analyzer.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_models.dart';
import 'package:flutter/foundation.dart';

import '../../token_usage/data/local_token_usage_repository.dart';
import '../../token_usage/domain/token_usage_models.dart';
import '../data/ai_insight_history.dart';
import '../domain/ai_companion_usage.dart';

export 'package:dingdong/features/ai_companion/domain/ai_companion_models.dart';

/// Suggestions are read-only. No resource, clipboard, tool or file mutation is
/// available to the model.
final class AiCompanionController extends ChangeNotifier {
  AiCompanionController({
    required AiCompanionStore store,
    required AiCompanionMetadataLoader loadMetadata,
    AiCompanionClient? client,
    this.usageRepository,
    this.history,
    this.onUsageChanged,
    DateTime Function()? now,
    // Preserve public injectable argument names while keeping fields private.
    // ignore: prefer_initializing_formals
  }) : _store = store,
       // ignore: prefer_initializing_formals
       _loadMetadata = loadMetadata,
       _client = client ?? AiCompanionClient(),
       _now = now ?? DateTime.now;

  final AiInsightHistory? history;
  Timer? _automaticTimer;
  Timer? _settingsAnalysisTimer;
  String? _lastFingerprint;
  DateTime? _lastAutomaticAttempt;
  List<AiInsightEntry> historyEntries = const [];
  int historyPage = 0;
  int historyCount = 0;
  static const historyPageSize = 20;

  void startAutomaticAnalysis() {
    _automaticTimer?.cancel();
    _automaticTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      unawaited(analyze(automatic: true));
    });
    unawaited(analyze(automatic: true));
  }

  Future<void> loadHistoryPage(int page) async {
    if (_disposed || history == null) return;
    try {
      historyCount = history!.count;
      historyPage = page.clamp(
        0,
        ((historyCount - 1) ~/ historyPageSize).clamp(0, 1000000),
      );
      historyEntries = history!.page(
        offset: historyPage * historyPageSize,
        limit: historyPageSize,
      );
    } on Object {
      _error = AiCompanionError.storageUnavailable;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _saveAnalysis(
    AiCompanionReport report, {
    required bool automatic,
    String? fingerprint,
  }) async {
    await _store.saveReport(report);
    history?.save(report, automatic: automatic, fingerprint: fingerprint);
    await loadHistoryPage(0);
  }

  final LocalTokenUsageRepository? usageRepository;
  final VoidCallback? onUsageChanged;
  TokenUsageSnapshot internalUsage = const TokenUsageSnapshot();
  AiCompanionUsageRecord? lastUsage;
  bool usageStorageAvailable = true;
  bool _usageWriteFailed = false;

  Future<void> _loadUsage() async {
    if (usageRepository == null) return;
    internalUsage = await usageRepository!.readInternalSnapshot();
    usageStorageAvailable =
        internalUsage.storageAvailable && !_usageWriteFailed;
  }

  /// Reads receipts written by the background selector without calling a model.
  Future<void> refreshInternalUsage() async {
    if (_disposed || usageRepository == null) return;
    try {
      await _loadUsage();
    } on Object {
      usageStorageAvailable = false;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _recordUsage(AiCompanionUsageRecord record) async {
    lastUsage = record;
    if (usageRepository == null) return;
    try {
      await usageRepository!.recordInternalUsage(record);
      await _loadUsage();
      onUsageChanged?.call();
    } on Object {
      _usageWriteFailed = true;
      usageStorageAvailable = false;
    }
    if (!_disposed) notifyListeners();
  }

  final AiCompanionStore _store;
  final AiCompanionMetadataLoader _loadMetadata;
  final AiCompanionClient _client;
  final DateTime Function() _now;
  AiCompanionSettings _settings = const AiCompanionSettings();
  AiCompanionReport? _report;
  AiCompanionError? _error;
  bool _isLoading = false;
  bool _hasStoredApiKey = false;
  bool _connectionVerified = false;
  bool _disposed = false;
  int _generation = 0;
  DateTime? _lastCheckIn;

  AiCompanionSettings get settings => _settings;
  AiCompanionReport? get report => _report;
  AiCompanionError? get error => _error;
  bool get isLoading => _isLoading;
  bool get loading => _isLoading;
  bool get hasStoredApiKey => _hasStoredApiKey;
  bool get connectionVerified => _connectionVerified;
  bool get isConfigured {
    try {
      final endpoint = AiCompanionClient.validateProvider(_settings);
      return AiCompanionClient.isLoopback(endpoint) || _hasStoredApiKey;
    } on AiCompanionException {
      return false;
    }
  }

  Future<void> load() => _run((generation) async {
    final AiCompanionSettings loaded = await _store.loadSettings();
    final AiCompanionReport? report = await _store.loadReport();
    if (!_current(generation)) return;
    _settings = loaded;
    _report = _visibleReport(report, loaded);
    _lastFingerprint = history?.fingerprint;
    if (report != null && history != null && history!.count == 0) {
      history!.save(report, automatic: false);
    }
    await loadHistoryPage(0);
    await _loadUsage();
    // Local settings and insights remain available when Keychain access fails.
    if (loaded.providerEndpoint.isNotEmpty) {
      final String? key = await _store.readApiKey();
      if (_current(generation)) _hasStoredApiKey = key?.isNotEmpty ?? false;
    }
  });

  Future<void> saveSettings(
    AiCompanionSettings value, {
    String? apiKey,
    bool clearApiKey = false,
  }) async {
    if (_disposed) return;
    // Revoking permission aborts pending traffic and discards stale results.
    _generation++;
    _client.dispose();
    _isLoading = false;
    await _run((generation) async {
      final AiCompanionSettings sanitized = value.copyWith(
        providerEndpoint: value.providerEndpoint.trim(),
        model: value.model.trim(),
      );
      if (sanitized.providerEndpoint.isNotEmpty || sanitized.model.isNotEmpty) {
        AiCompanionClient.validateProvider(sanitized);
      }
      final String? replacement = apiKey?.trim();
      if (replacement != null &&
          (replacement.length > 512 || RegExp(r'\s').hasMatch(replacement))) {
        throw const AiCompanionException(AiCompanionError.invalidProvider);
      }
      final bool endpointChanged =
          sanitized.providerEndpoint != _settings.providerEndpoint;
      final bool cloudContextChanged =
          endpointChanged ||
          sanitized.protocol != _settings.protocol ||
          sanitized.model != _settings.model ||
          sanitized.clipboardAnalysis != _settings.clipboardAnalysis ||
          sanitized.usageOptimization != _settings.usageOptimization ||
          sanitized.progressiveDisclosure != _settings.progressiveDisclosure ||
          sanitized.tokenOptimization != _settings.tokenOptimization;
      // Never send the old provider's credential to a newly entered endpoint.
      final credentialChanged =
          clearApiKey || endpointChanged || replacement != null;
      if (credentialChanged) {
        await _store.writeApiKey(clearApiKey ? null : replacement);
      }
      await _store.saveSettings(sanitized);
      if (!_current(generation)) return;
      final inclusionChanged =
          sanitized.includeInternalInGlobal !=
          _settings.includeInternalInGlobal;
      _settings = sanitized;
      if (inclusionChanged) onUsageChanged?.call();
      if (credentialChanged) {
        _hasStoredApiKey = !clearApiKey && (replacement?.isNotEmpty ?? false);
      }
      _connectionVerified = false;
      _report = _visibleReport(_report, sanitized);
      // Free-form text cannot be reliably separated back into capability
      // categories. Keep only filtered local suggestions after a context change.
      if (cloudContextChanged && _report != null) {
        _report = AiCompanionReport(
          createdAt: _report!.createdAt,
          suggestions: _report!.suggestions,
        );
      }
      await _store.saveReport(_report);
      if (_automaticTimer != null) {
        _settingsAnalysisTimer?.cancel();
        _settingsAnalysisTimer = Timer(const Duration(seconds: 5), () {
          if (_disposed) return;
          _lastAutomaticAttempt = null;
          unawaited(analyze(automatic: true));
        });
      }
    });
  }

  Future<void> setInternalInclusion(bool value) async {
    final updated = _settings.copyWith(includeInternalInGlobal: value);
    await _store.saveSettings(updated);
    if (_disposed) return;
    _settings = updated;
    onUsageChanged?.call();
    notifyListeners();
  }

  Future<void> analyze({bool automatic = false}) async {
    if (automatic &&
        (!_settings.automaticAnalysis ||
            !_settings.analysisEnabled ||
            _isLoading ||
            (_lastAutomaticAttempt != null &&
                _now().difference(_lastAutomaticAttempt!) <
                    const Duration(minutes: 30)))) {
      return;
    }
    if (automatic) _lastAutomaticAttempt = _now();
    await _run((generation) async {
      final AiCompanionSettings activeSettings = _settings;
      if (!activeSettings.analysisEnabled) {
        throw const AiCompanionException(AiCompanionError.disabled);
      }
      final AiCompanionMetadata metadata = await _loadMetadata();
      if (!_current(generation)) return;
      final AiCompanionReport localReport = await const AiCompanionAnalyzer()
          .analyze(activeSettings, metadata, _now());
      if (!_current(generation)) return;
      final fingerprint = base64Encode(
        (await Sha256().hash(
          utf8.encode(
            jsonEncode({
              'settings': activeSettings.toJson(),
              'suggestions': localReport.suggestions
                  .map((s) => s.toJson())
                  .toList(),
              'metadata': const AiCompanionAnalyzer().cloudMetadata(
                activeSettings,
                metadata,
              ),
            }),
          ),
        )).bytes,
      );
      if (!_current(generation)) return;
      if (automatic && fingerprint == _lastFingerprint) return;
      _report = localReport;
      await _saveAnalysis(
        localReport,
        automatic: automatic,
        fingerprint: activeSettings.cloudAnalysis ? null : fingerprint,
      );
      if (!activeSettings.cloudAnalysis) _lastFingerprint = fingerprint;
      if (!_current(generation) || !activeSettings.cloudAnalysis) return;
      final String? key = await _store.readApiKey();
      if (!_current(generation)) return;
      final String summary = await _client.analyze(
        activeSettings,
        key,
        metadata,
        onUsage: _recordUsage,
      );
      if (!_current(generation)) return;
      _report = AiCompanionReport(
        createdAt: localReport.createdAt,
        suggestions: localReport.suggestions,
        cloudSummary: summary,
        localOnly: false,
      );
      await _saveAnalysis(
        _report!,
        automatic: automatic,
        fingerprint: fingerprint,
      );
      _lastFingerprint = fingerprint;
    });
  }

  Future<void> testConnection() => _run((generation) async {
    _connectionVerified = false;
    final String? key = await _store.readApiKey();
    if (!_current(generation)) return;
    await _client.testConnection(_settings, key, onUsage: _recordUsage);
    if (_current(generation)) _connectionVerified = true;
  });

  /// Local and rate-limited. Callers may drive this from an in-app timer; it
  /// never invokes the provider or loads clipboard/resource data.
  Future<void> checkIn({int activeMinutes = 0}) async {
    if (_disposed ||
        !_settings.proactiveCheckIns ||
        activeMinutes < 60 ||
        _isLoading ||
        (_lastCheckIn != null &&
            _now().difference(_lastCheckIn!) < const Duration(hours: 2))) {
      return;
    }
    _lastCheckIn = _now();
    _report = AiCompanionReport(
      createdAt: _now(),
      suggestions: <AiSuggestion>[
        ...?_report?.suggestions.where(
          (item) => item.code != AiSuggestionCode.takeBreak,
        ),
        AiSuggestion(code: AiSuggestionCode.takeBreak, count: activeMinutes),
      ],
      cloudSummary: _report?.cloudSummary,
      localOnly: _report?.localOnly ?? true,
    );
    try {
      await _store.saveReport(_report);
    } on Object {
      _error = AiCompanionError.storageUnavailable;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _run(Future<void> Function(int) action) async {
    if (_disposed || _isLoading) return;
    final int generation = _generation;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await action(generation);
    } on AiCompanionException catch (error) {
      if (_current(generation)) _error = error.code;
    } on Object {
      if (_current(generation)) _error = AiCompanionError.storageUnavailable;
    } finally {
      if (_current(generation)) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  bool _current(int generation) => !_disposed && _generation == generation;

  @override
  void dispose() {
    _disposed = true;
    _automaticTimer?.cancel();
    _settingsAnalysisTimer?.cancel();
    _generation++;
    _client.dispose();
    super.dispose();
  }
}

AiCompanionReport? _visibleReport(
  AiCompanionReport? report,
  AiCompanionSettings settings,
) {
  if (report == null ||
      (!settings.analysisEnabled && !settings.proactiveCheckIns)) {
    return null;
  }
  return AiCompanionReport(
    createdAt: report.createdAt,
    suggestions: report.suggestions
        .where(
          (item) => switch (item.code) {
            AiSuggestionCode.frequentClipboard ||
            AiSuggestionCode.repeatedClipboard ||
            AiSuggestionCode.ungroupedClipboard => settings.clipboardAnalysis,
            AiSuggestionCode.candidateWithoutUse ||
            AiSuggestionCode.alwaysOnUnused => settings.usageOptimization,
            AiSuggestionCode.progressivePrompt ||
            AiSuggestionCode.progressiveMcp => settings.progressiveDisclosure,
            AiSuggestionCode.largeAlwaysOnPrompt ||
            AiSuggestionCode.highInputTokens ||
            AiSuggestionCode.lowCacheReuse ||
            AiSuggestionCode.incompleteTokenData => settings.tokenOptimization,
            AiSuggestionCode.takeBreak => settings.proactiveCheckIns,
          },
        )
        .toList(growable: false),
    cloudSummary: settings.cloudAnalysis ? report.cloudSummary : null,
    localOnly: !settings.cloudAnalysis || report.localOnly,
  );
}
