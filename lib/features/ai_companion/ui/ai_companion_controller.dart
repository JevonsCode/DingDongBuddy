import 'package:dingdong/features/ai_companion/data/ai_companion_client.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_store.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_models.dart';
import 'package:flutter/foundation.dart';
import '../../token_usage/data/local_token_usage_repository.dart';
import '../../token_usage/domain/token_usage_models.dart';
import '../domain/ai_companion_usage.dart';
export 'package:dingdong/features/ai_companion/domain/ai_companion_models.dart';

/// Configures request-driven Agent routing. Never schedules analysis or reads
/// clipboard/resource data when a window opens or settings change.
final class AiCompanionController extends ChangeNotifier {
  AiCompanionController({
    required AiCompanionStore store,
    AiCompanionClient? client,
    this.usageRepository,
    this.onUsageChanged,
    // Keep the public injectable store argument.
    // ignore: prefer_initializing_formals
  }) : _store = store,
       _client = client ?? AiCompanionClient();
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
  final AiCompanionClient _client;
  AiCompanionSettings _settings = const AiCompanionSettings();
  AiCompanionError? _error;
  bool _isLoading = false;
  bool _isTestingConnection = false;
  bool _hasStoredApiKey = false;
  bool _connectionVerified = false;
  bool _disposed = false;
  int _generation = 0;
  AiCompanionSettings get settings => _settings;
  AiCompanionError? get error => _error;
  bool get isLoading => _isLoading;
  bool get loading => _isLoading;
  bool get isTestingConnection => _isTestingConnection;
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
    final settings = await _store.loadSettings();
    if (!_current(generation)) return;
    _settings = settings;
    await _loadUsage();
    if (settings.providerEndpoint.isNotEmpty) {
      final key = await _store.readApiKey();
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
    _isTestingConnection = false;
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
      final bool providerChanged =
          endpointChanged ||
          sanitized.protocol != _settings.protocol ||
          sanitized.model != _settings.model;
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
      if (credentialChanged || providerChanged) _connectionVerified = false;
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

  Future<void> testConnection() => _run((generation) async {
    _connectionVerified = false;
    final key = await _store.readApiKey();
    if (!_current(generation)) return;
    await _client.testConnection(_settings, key, onUsage: _recordUsage);
    if (_current(generation)) _connectionVerified = true;
  }, connectionTest: true);
  Future<void> _run(
    Future<void> Function(int) action, {
    bool connectionTest = false,
  }) async {
    if (_disposed || _isLoading) return;
    final int generation = _generation;
    _isLoading = true;
    _isTestingConnection = connectionTest;
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
        _isTestingConnection = false;
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
    super.dispose();
  }
}
