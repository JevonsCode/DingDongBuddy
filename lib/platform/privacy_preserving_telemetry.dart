import 'dart:async';
import 'dart:ui';

import 'package:aptabase_flutter/aptabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Optional, content-free product analytics backed by Aptabase.
///
/// The SDK sends nothing unless both the user enables diagnostics and a release
/// is compiled with `APTABASE_APP_KEY`. Event properties must never contain
/// user-entered text, clipboard data, paths, names, URLs, or stack traces.
final class PrivacyPreservingTelemetry {
  PrivacyPreservingTelemetry._();

  static final PrivacyPreservingTelemetry instance =
      PrivacyPreservingTelemetry._();

  static const String _appKey = String.fromEnvironment('APTABASE_APP_KEY');

  bool _enabled = false;
  bool _initialized = false;
  bool _handlersInstalled = false;

  Future<void> setEnabled(bool enabled) async {
    if (!enabled || _appKey.trim().isEmpty) {
      _enabled = false;
      return;
    }
    final bool wasEnabled = _enabled;
    try {
      if (!_initialized) {
        await Aptabase.init(_appKey);
        _initialized = true;
      }
      _enabled = true;
      _installErrorHandlers();
      if (!wasEnabled) {
        track('app_started');
      }
    } on Object {
      // Diagnostics must never prevent DingDong from starting.
      _enabled = false;
    }
  }

  void track(String eventName, [Map<String, Object>? properties]) {
    if (!_enabled || !_initialized) {
      return;
    }
    unawaited(
      Aptabase.instance
          .trackEvent(eventName, properties)
          .catchError((Object _) {}),
    );
  }

  void _installErrorHandlers() {
    if (_handlersInstalled) {
      return;
    }
    _handlersInstalled = true;

    final FlutterExceptionHandler? previousFlutterHandler =
        FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      track('flutter_error', <String, Object>{
        'error_type': details.exception.runtimeType.toString(),
      });
      if (previousFlutterHandler != null) {
        previousFlutterHandler(details);
      } else {
        FlutterError.presentError(details);
      }
    };

    final ErrorCallback? previousPlatformHandler =
        PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      track('platform_error', <String, Object>{
        'error_type': error.runtimeType.toString(),
      });
      return previousPlatformHandler?.call(error, stack) ?? false;
    };
  }
}
