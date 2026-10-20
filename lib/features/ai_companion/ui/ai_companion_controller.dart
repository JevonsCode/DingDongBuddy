import 'package:dingdong/features/ai_companion/data/ai_companion_client.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_store.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_analyzer.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_models.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_privacy.dart';
import 'package:flutter/foundation.dart';

export 'package:dingdong/features/ai_companion/domain/ai_companion_models.dart';

/// Suggestions are read-only. No resource, clipboard, tool or file mutation is
/// available to the model, and chat history never enters persistent settings.
final class AiCompanionController extends ChangeNotifier {
  AiCompanionController({
    required AiCompanionStore store,
    required AiCompanionMetadataLoader loadMetadata,
    AiCompanionClient? client,
    DateTime Function()? now,
    // Preserve public injectable argument names while keeping fields private.
    // ignore: prefer_initializing_formals
  }) : _store = store,
       // ignore: prefer_initializing_formals
       _loadMetadata = loadMetadata,
       _client = client ?? AiCompanionClient(),
       _now = now ?? DateTime.now;

  final AiCompanionStore _store;
  final AiCompanionMetadataLoader _loadMetadata;
  final AiCompanionClient _client;
  final DateTime Function() _now;
  AiCompanionSettings _settings = const AiCompanionSettings();
  AiCompanionReport? _report;
  final List<AiChatMessage> _messages = <AiChatMessage>[];
  AiCompanionError? _error;
  bool _isLoading = false;
  bool _hasStoredApiKey = false;
  bool _connectionVerified = false;
  bool _disposed = false;
  int _generation = 0;
  DateTime? _lastCheckIn;

  AiCompanionSettings get settings => _settings;
  AiCompanionReport? get report => _report;
  List<AiChatMessage> get messages =>
      List<AiChatMessage>.unmodifiable(_messages);
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
    final String? key = await _store.readApiKey();
    if (!_current(generation)) return;
    _settings = loaded;
    _hasStoredApiKey = key?.isNotEmpty ?? false;
    _report = _visibleReport(report, loaded);
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
      // Never send the old provider's credential to a newly entered endpoint.
      if (clearApiKey || endpointChanged || replacement != null) {
        await _store.writeApiKey(clearApiKey ? null : replacement);
      }
      await _store.saveSettings(sanitized);
      final String? storedKey = await _store.readApiKey();
      if (!_current(generation)) return;
      _settings = sanitized;
      _hasStoredApiKey = storedKey?.isNotEmpty ?? false;
      _connectionVerified = false;
      if (!sanitized.emotionalSupport || endpointChanged) _messages.clear();
      _report = _visibleReport(_report, sanitized);
      await _store.saveReport(_report);
    });
  }

  Future<void> analyze() => _run((generation) async {
    final AiCompanionSettings activeSettings = _settings;
    if (!activeSettings.analysisEnabled) {
      throw const AiCompanionException(AiCompanionError.disabled);
    }
    final AiCompanionMetadata metadata = await _loadMetadata();
    if (!_current(generation)) return;
    final AiCompanionReport localReport = await const AiCompanionAnalyzer()
        .analyze(activeSettings, metadata, _now());
    if (!_current(generation)) return;
    _report = localReport;
    await _store.saveReport(localReport);
    if (!_current(generation) || !activeSettings.cloudAnalysis) return;
    final String? key = await _store.readApiKey();
    if (!_current(generation)) return;
    final String summary = await _client.analyze(activeSettings, key, metadata);
    if (!_current(generation)) return;
    _report = AiCompanionReport(
      createdAt: localReport.createdAt,
      suggestions: localReport.suggestions,
      cloudSummary: summary,
      localOnly: false,
    );
    await _store.saveReport(_report);
  });

  Future<void> sendMessage(String text) => _run((generation) async {
    if (!_settings.emotionalSupport) {
      throw const AiCompanionException(AiCompanionError.disabled);
    }
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw const AiCompanionException(AiCompanionError.emptyMessage);
    }
    if (trimmed.length > 4000) {
      throw const AiCompanionException(AiCompanionError.messageTooLong);
    }
    final String? key = await _store.readApiKey();
    if (!_current(generation)) return;
    if (!const AiCompanionPrivacy().isSafeText(trimmed, providerKey: key)) {
      throw const AiCompanionException(AiCompanionError.sensitiveInput);
    }
    final AiChatMessage user = AiChatMessage(role: 'user', text: trimmed);
    final String response = await _client.chat(_settings, key, <AiChatMessage>[
      ..._messages,
      user,
    ]);
    if (!_current(generation)) return;
    _messages.addAll(<AiChatMessage>[
      user,
      AiChatMessage(role: 'assistant', text: response),
    ]);
    if (_messages.length > 20) {
      _messages.removeRange(0, _messages.length - 20);
    }
  });

  Future<void> testConnection() => _run((generation) async {
    _connectionVerified = false;
    final String? key = await _store.readApiKey();
    if (!_current(generation)) return;
    await _client.testConnection(_settings, key);
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

  void clearConversation() {
    if (_disposed) return;
    _generation++;
    _client.dispose();
    _isLoading = false;
    _messages.clear();
    _error = null;
    notifyListeners();
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
    _generation++;
    _client.dispose();
    _messages.clear();
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
