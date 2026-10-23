import 'dart:convert';
import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:dingdong/features/screenshot/domain/screenshot_plugin.dart';
import 'package:flutter/services.dart';

final class NativeScreenshotPluginGateway implements ScreenshotPluginGateway {
  NativeScreenshotPluginGateway({required this.labels});
  static const _channel = MethodChannel('dingdong/screenshot_plugin');
  final Map<String, String> Function() labels;
  static const editorChannel = WindowMethodChannel(
    'dingdong/screenshot-editor',
    mode: ChannelMode.unidirectional,
  );
  static const editorWindowKind = 'screenshot-editor';
  WindowController? _editor;
  Uint8List? _pending;
  int _session = 0;
  bool _initialized = false;

  Future<void> _initialize() async {
    if (_initialized || !Platform.isWindows) return;
    await editorChannel.setMethodCallHandler((call) async {
      if (call.arguments != _session) return null;
      if (call.method == 'read') return _pending;
      if (call.method == 'finish') {
        _pending = null;
        await _invoke('finish');
      }
      return null;
    });
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'edit') throw MissingPluginException();
      final bytes = call.arguments;
      if (bytes is! Uint8List || bytes.isEmpty) {
        throw PlatformException(code: 'invalid_image');
      }
      _pending = bytes;
      final session = ++_session;
      try {
        final windows = await WindowController.getAll();
        if (_editor != null &&
            !windows.any((w) => w.windowId == _editor!.windowId)) {
          _editor = null;
        }
        if (_editor == null) {
          _editor = await WindowController.create(
            WindowConfiguration(
              hiddenAtLaunch: true,
              arguments: jsonEncode({
                'kind': editorWindowKind,
                'session': session,
              }),
            ),
          );
        } else {
          await _editor!.invokeMethod<void>('load', session);
        }
      } catch (_) {
        _pending = null;
        await _invoke('finish');
        rethrow;
      }
    });
    _initialized = true;
  }

  Future<void> _dismiss() async {
    _pending = null;
    ++_session; // Invalidate in-flight reads from the previous capture.
    final editor = _editor;
    if (editor != null) {
      try {
        await editor.invokeMethod<void>('dismiss');
      } catch (_) {
        _editor = null;
      }
    }
  }

  Future<Object?> _invoke(String method, [Object? arguments]) async {
    if (!Platform.isWindows) {
      if (method == 'capture') {
        throw const ScreenshotPluginException('unsupported');
      }
      return {'supported': false, 'running': false, 'capturing': false};
    }
    try {
      return await _channel.invokeMethod<Object?>(method, arguments);
    } on PlatformException catch (error) {
      const known = {
        'shortcut_conflict',
        'invalid_shortcut',
        'capture_failed',
        'disabled',
        'capture_busy',
      };
      throw ScreenshotPluginException(
        known.contains(error.code) ? error.code : 'unavailable',
      );
    } on MissingPluginException {
      throw const ScreenshotPluginException('unavailable');
    }
  }

  @override
  Future<ScreenshotRuntimeStatus> apply(
    ScreenshotConfiguration configuration,
  ) async {
    await _initialize();
    final result = ScreenshotRuntimeStatus.fromPlatform(
      await _invoke('configure', {
        ...configuration.toArguments(),
        'labels': labels(),
      }),
    );
    if (!configuration.enabled) await _dismiss();
    return result;
  }

  @override
  Future<ScreenshotRuntimeStatus> status() async =>
      ScreenshotRuntimeStatus.fromPlatform(await _invoke('status'));
  @override
  Future<void> capture() async {
    await _initialize();
    await _invoke('capture');
  }
}
