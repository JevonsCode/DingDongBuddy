import 'dart:async';

import 'package:dingdong/features/token_usage/data/local_token_usage_repository.dart';

/// Imports numeric usage independently of whether the history page is open.
/// The repository streams files, commits small batches and resumes from offsets.
final class TokenUsageBackgroundService {
  TokenUsageBackgroundService(
    this.repository, {
    this.interval = const Duration(minutes: 5),
  });

  final LocalTokenUsageRepository repository;
  final Duration interval;
  Timer? _timer;
  bool _closed = false;

  void start() {
    if (_closed || _timer != null) return;
    _timer = Timer.periodic(interval, (_) => unawaited(_refresh()));
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    if (_closed) return;
    try {
      await repository.refresh();
    } on Object {
      // A busy or unavailable usage DB must not interrupt Agent notifications.
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _timer = null;
    await repository.close();
  }
}
