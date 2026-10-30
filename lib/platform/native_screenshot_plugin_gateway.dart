import 'package:dingdong/features/screenshot/domain/screenshot_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers a shortcut and delegates capture to the operating system.
final class NativeScreenshotPluginGateway implements ScreenshotPluginGateway {
  NativeScreenshotPluginGateway({required this.labels});
  static const _channel = MethodChannel('dingdong/screenshot_plugin');
  final Map<String, String> Function() labels;

  bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS);

  Future<Object?> _invoke(String method, [Object? arguments]) async {
    if (!_supported) {
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
  ) async => ScreenshotRuntimeStatus.fromPlatform(
    await _invoke('configure', {
      ...configuration.toArguments(),
      'labels': labels(),
    }),
  );

  @override
  Future<ScreenshotRuntimeStatus> status() async =>
      ScreenshotRuntimeStatus.fromPlatform(await _invoke('status'));

  @override
  Future<void> capture() async {
    await _invoke('capture');
  }
}
