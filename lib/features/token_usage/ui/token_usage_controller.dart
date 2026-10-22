import 'package:dingdong/features/token_usage/data/local_token_usage_repository.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';
import 'package:flutter/foundation.dart';

/// Keeps the last readable local history visible while a refresh is running.
class TokenUsageController extends ChangeNotifier {
  TokenUsageController({
    required Future<TokenUsageSnapshot> Function() loadSnapshot,
    VoidCallback? cancelRefresh,
    TokenUsageSnapshot? initialSnapshot,
    this.readInternalInclusion,
    this.saveInternalInclusion,
  }) : // Preserve the public argument name without exposing a callback that
       // callers could use to bypass the refresh lifecycle guards.
       // ignore: prefer_initializing_formals
       _loadSnapshot = loadSnapshot,
       // Keep the callback private so cancellation always updates the UI state.
       // ignore: prefer_initializing_formals
       _cancelRefresh = cancelRefresh,
       _snapshot = initialSnapshot ?? const TokenUsageSnapshot(),
       _hasLoaded = initialSnapshot != null;

  TokenUsageController.fromRepository(
    LocalTokenUsageRepository repository, {
    Future<bool> Function()? includeInternal,
    Future<void> Function(bool)? saveInternalInclusion,
  }) : this(
         loadSnapshot: () async {
           await repository.refresh();
           return repository.readSnapshot(includeInternal: true);
         },
         cancelRefresh: repository.cancelRefresh,
         readInternalInclusion: includeInternal,
         saveInternalInclusion: saveInternalInclusion,
       );

  TokenUsageController.preview(TokenUsageSnapshot snapshot)
    : this(loadSnapshot: () async => snapshot, initialSnapshot: snapshot);

  final Future<TokenUsageSnapshot> Function() _loadSnapshot;
  final VoidCallback? _cancelRefresh;
  TokenUsageSnapshot _snapshot;
  bool _hasLoaded;
  bool _isLoading = false;
  bool _isCancelling = false;
  bool _disposed = false;
  int _revision = 0;
  int _inclusionRevision = 0;
  Object? _error;

  final Future<bool> Function()? readInternalInclusion;
  final Future<void> Function(bool)? saveInternalInclusion;
  bool includeInternal = false;
  bool savingInclusion = false;
  Object? inclusionError;
  TokenUsageSnapshot get allSnapshot => _snapshot;
  TokenUsageSnapshot get snapshot => includeInternal
      ? _snapshot
      : _snapshot.forSources({
          ...ConversationTokenUsageSource.values.where(
            (source) => source != ConversationTokenUsageSource.dingdong,
          ),
        });

  Future<void> setIncludeInternal(bool value) async {
    if (_disposed || savingInclusion) return;
    _inclusionRevision++;
    savingInclusion = true;
    inclusionError = null;
    notifyListeners();
    try {
      await saveInternalInclusion?.call(value);
      if (!_disposed) includeInternal = value;
    } on Object catch (error) {
      inclusionError = error;
    } finally {
      if (!_disposed) {
        savingInclusion = false;
        notifyListeners();
      }
    }
  }

  bool get hasLoaded => _hasLoaded;
  bool get isLoading => _isLoading;
  bool get canCancel => _isLoading && _cancelRefresh != null;
  bool get isCancelling => _isCancelling;
  Object? get error => _error;

  void invalidate() {
    if (_disposed) return;
    _revision++;
    _hasLoaded = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    if (_disposed || _isLoading) return;
    final revision = _revision;
    final inclusionRevision = _inclusionRevision;
    _isLoading = true;
    _isCancelling = false;
    _error = null;
    notifyListeners();
    try {
      final TokenUsageSnapshot snapshot = await _loadSnapshot();
      final inclusion = await readInternalInclusion?.call();
      if (_disposed) return;
      _snapshot = snapshot;
      if (inclusion != null &&
          !savingInclusion &&
          inclusionRevision == _inclusionRevision) {
        includeInternal = inclusion;
      }
      _hasLoaded = revision == _revision;
    } on Object catch (error) {
      if (_disposed) return;
      _error = error;
    } finally {
      if (!_disposed) {
        _isLoading = false;
        _isCancelling = false;
        notifyListeners();
      }
    }
  }

  /// Stops this import operation; the background refresh schedule is unchanged.
  void cancelRefresh() {
    if (_disposed || !canCancel || _isCancelling) return;
    _isCancelling = true;
    _cancelRefresh!();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
