// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:dingdong/core/platform/clipboard_change_source.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';

/// Lifecycle contract consumed by settings without exposing platform events.
abstract interface class ClipboardMonitoring {
  bool get isRunning;

  Future<void> start();

  Future<void> stop();
}

/// Captures clipboard history only while native change notifications are active.
final class ClipboardMonitorService implements ClipboardMonitoring {
  ClipboardMonitorService({
    required ClipboardChangeSource source,
    required ClipboardCaptureService captureService,
    void Function()? onCopyDetected,
  }) : _source = source,
       _captureService = captureService,
       _onCopyDetected = onCopyDetected;

  final ClipboardChangeSource _source;
  final ClipboardCaptureService _captureService;
  final void Function()? _onCopyDetected;
  StreamSubscription<void>? _subscription;
  bool _capturing = false;
  bool _capturePending = false;

  @override
  bool get isRunning => _subscription != null;

  @override
  Future<void> start() async {
    if (isRunning) {
      return;
    }
    _subscription = _source.changes.listen((_) {
      _capturePending = true;
      unawaited(_capture());
      _onCopyDetected?.call();
    });
    await _source.start();
  }

  @override
  Future<void> stop() async {
    final StreamSubscription<void>? subscription = _subscription;
    _subscription = null;
    _capturePending = false;
    await subscription?.cancel();
    await _source.stop();
  }

  Future<void> _capture() async {
    if (!isRunning || _capturing) {
      return;
    }
    _capturing = true;
    try {
      // A platform change is acknowledged before this asynchronous read ends.
      // Read again when a newer change arrived instead of dropping it forever.
      while (isRunning && _capturePending) {
        _capturePending = false;
        await _captureService.capture();
      }
    } finally {
      _capturing = false;
    }
  }
}
