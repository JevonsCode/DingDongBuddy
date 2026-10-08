import 'package:dingdong/features/token_usage/data/local_token_usage_repository.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';
import 'package:flutter/foundation.dart';

/// Keeps the last readable local history visible while a refresh is running.
class TokenUsageController extends ChangeNotifier {
  TokenUsageController({
    required Future<TokenUsageSnapshot> Function() loadSnapshot,
    TokenUsageSnapshot? initialSnapshot,
  }) : // Preserve the public argument name without exposing a callback that
       // callers could use to bypass the refresh lifecycle guards.
       // ignore: prefer_initializing_formals
       _loadSnapshot = loadSnapshot,
       _snapshot = initialSnapshot ?? const TokenUsageSnapshot(),
       _hasLoaded = initialSnapshot != null;

  TokenUsageController.fromRepository(LocalTokenUsageRepository repository)
    : this(
        loadSnapshot: () async {
          await repository.refresh();
          return repository.readSnapshot();
        },
      );

  TokenUsageController.preview(TokenUsageSnapshot snapshot)
    : this(loadSnapshot: () async => snapshot, initialSnapshot: snapshot);

  final Future<TokenUsageSnapshot> Function() _loadSnapshot;
  TokenUsageSnapshot _snapshot;
  bool _hasLoaded;
  bool _isLoading = false;
  bool _disposed = false;
  Object? _error;

  TokenUsageSnapshot get snapshot => _snapshot;
  bool get hasLoaded => _hasLoaded;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  Future<void> refresh() async {
    if (_disposed || _isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final TokenUsageSnapshot snapshot = await _loadSnapshot();
      if (_disposed) return;
      _snapshot = snapshot;
      _hasLoaded = true;
    } on Object catch (error) {
      if (_disposed) return;
      _error = error;
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
