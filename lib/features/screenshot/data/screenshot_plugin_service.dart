import 'dart:async';

import 'package:dingdong/features/screenshot/domain/screenshot_plugin.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/domain/global_hot_key.dart';

/// The primary engine alone owns registration and preference writes. Secondary
/// windows proxy actions here instead of replaying persisted enablement.
final class ScreenshotPluginService {
  ScreenshotPluginService(
    this._preferences,
    this._gateway, {
    this.conflictsWithShortcut,
  });
  static const preferenceKey = 'dingdong.screenshot.configuration';
  final PreferencesBackend _preferences;
  final ScreenshotPluginGateway _gateway;
  final Future<bool> Function(GlobalHotKey)? conflictsWithShortcut;
  ScreenshotConfiguration configuration = const ScreenshotConfiguration();
  ScreenshotRuntimeStatus _runtime =
      const ScreenshotRuntimeStatus.unavailable();
  String? _error;
  Future<void> _operations = Future<void>.value();

  Future<T> _serialize<T>(Future<T> Function() action) {
    final result = _operations.then((_) => action());
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  Future<void> load() => _serialize(() async {
    try {
      configuration = ScreenshotConfiguration.parse(
        await _preferences.read(preferenceKey),
      );
      if (configuration.enabled && await _conflicts(configuration.shortcut)) {
        throw const ScreenshotPluginException('shortcut_conflict');
      }
      _runtime = await _gateway.apply(configuration);
      _error = null;
    } on Object catch (error) {
      _error = error is ScreenshotPluginException ? error.code : 'unavailable';
      // The preference can remain enabled when the host could not register it.
      _runtime = const ScreenshotRuntimeStatus.unavailable();
    }
  });

  Future<bool> _conflicts(GlobalHotKey key) async =>
      await conflictsWithShortcut?.call(key) ?? false;

  Future<Map<String, Object?>> manage(
    String action,
    Map<String, Object?> values,
  ) => _serialize(() async {
    switch (action) {
      case 'status':
        try {
          _runtime = await _gateway.status();
          // Refresh may recover a missing channel, but cannot silently clear a
          // failed startup registration while the feature remains enabled.
          if (_error != 'rollback_failed' &&
              (!configuration.enabled || _runtime.running)) {
            _error = null;
          }
        } on Object {
          _runtime = const ScreenshotRuntimeStatus.unavailable();
          if (_error != 'rollback_failed') {
            _error = 'unavailable';
          }
        }
      case 'configure':
        final next = ScreenshotConfiguration.fromArguments({
          ...configuration.toArguments(),
          ...values,
        });
        // Disabling must always release the hotkey, even if another setting
        // has since claimed the same combination.
        if (next.enabled && await _conflicts(next.shortcut)) {
          throw const ScreenshotPluginException('shortcut_conflict');
        }
        final previous = configuration;
        final runtime = await _gateway.apply(next);
        if (next.enabled && (!runtime.supported || !runtime.running)) {
          throw const ScreenshotPluginException('unavailable');
        }
        try {
          await _preferences.write(preferenceKey, next.encode());
        } on Object {
          try {
            _runtime = await _gateway.apply(previous);
          } on Object {
            _runtime = const ScreenshotRuntimeStatus.unavailable();
            _error = 'rollback_failed';
            throw const ScreenshotPluginException('rollback_failed');
          }
          throw const ScreenshotPluginException('persistence_failed');
        }
        configuration = next;
        _runtime = runtime;
        _error = null;
      case 'capture':
        if (!configuration.enabled) {
          throw const ScreenshotPluginException('disabled');
        }
        await _gateway.capture();
        _runtime = await _gateway.status();
      default:
        throw const ScreenshotPluginException('unsupported_action');
    }
    return _snapshot();
  });

  Map<String, Object?> _snapshot() => {
    ...configuration.toArguments(),
    'supported': _runtime.supported,
    // A failed rollback can leave a different shortcut registered. Never label
    // the persisted shortcut ready until a successful apply reconciles them.
    'running': _runtime.running && _error != 'rollback_failed',
    'capturing': _runtime.capturing,
    if (_error != null) 'error': _error,
  };
}
