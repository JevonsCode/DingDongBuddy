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
  }) : _source = source,
       _captureService = captureService;

  final ClipboardChangeSource _source;
  final ClipboardCaptureService _captureService;
  StreamSubscription<void>? _subscription;
  bool _capturing = false;

  @override
  bool get isRunning => _subscription != null;

  @override
  Future<void> start() async {
    if (isRunning) {
      return;
    }
    _subscription = _source.changes.listen((_) => _capture());
    await _source.start();
  }

  @override
  Future<void> stop() async {
    final StreamSubscription<void>? subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    await _source.stop();
  }

  Future<void> _capture() async {
    if (!isRunning || _capturing) {
      return;
    }
    _capturing = true;
    try {
      await _captureService.capture();
    } finally {
      _capturing = false;
    }
  }
}
