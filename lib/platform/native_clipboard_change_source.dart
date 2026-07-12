import 'dart:async';

import 'package:dingdong/core/platform/clipboard_change_source.dart';
import 'package:flutter/services.dart';

typedef ClipboardSequenceReader = Future<int> Function();

/// Efficient cross-platform watcher backed by a native integer sequence.
final class NativeClipboardChangeSource implements ClipboardChangeSource {
  NativeClipboardChangeSource({
    ClipboardSequenceReader? sequenceReader,
    this.interval = const Duration(milliseconds: 250),
  }) : _sequenceReader = sequenceReader ?? _readNativeSequence;

  static const MethodChannel _channel = MethodChannel(
    'dingdong/clipboard_monitor',
  );

  final ClipboardSequenceReader _sequenceReader;
  final Duration interval;
  final StreamController<void> _changes = StreamController<void>.broadcast();
  Timer? _timer;
  int? _lastSequence;
  bool _polling = false;

  @override
  Stream<void> get changes => _changes.stream;

  bool get isRunning => _timer != null;

  @override
  Future<void> start() async {
    if (isRunning) {
      return;
    }
    _lastSequence = await _sequenceReader();
    _timer = Timer.periodic(interval, (_) => unawaited(poll()));
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  /// Performs one poll; public to keep timing behavior deterministic in tests.
  Future<void> poll() async {
    if (!isRunning || _polling) {
      return;
    }
    _polling = true;
    try {
      final int current = await _sequenceReader();
      if (current != _lastSequence) {
        _lastSequence = current;
        _changes.add(null);
      }
    } finally {
      _polling = false;
    }
  }

  static Future<int> _readNativeSequence() async {
    return await _channel.invokeMethod<int>('changeCount') ?? 0;
  }
}
