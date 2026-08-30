import 'package:dingdong/features/selection/domain/selection_plugin_configuration.dart';
import 'package:dingdong/features/selection/domain/selection_plugin_gateway.dart';
import 'package:flutter/services.dart';

/// Calls the lightweight selection controller hosted by DingDong's macOS app.
final class NativeSelectionPluginGateway implements SelectionPluginGateway {
  const NativeSelectionPluginGateway([
    this._channel = const MethodChannel('dingdong/selection_plugin'),
  ]);

  final MethodChannel _channel;

  @override
  Future<SelectionPluginRuntimeStatus> apply(
    SelectionPluginConfiguration configuration,
  ) async {
    final Object? value = await _channel.invokeMethod<Object?>(
      'applyConfiguration',
      configuration.sanitized().toPlatformArguments(),
    );
    return SelectionPluginRuntimeStatus.fromPlatform(value);
  }

  @override
  Future<SelectionPluginRuntimeStatus> status() async {
    return SelectionPluginRuntimeStatus.fromPlatform(
      await _channel.invokeMethod<Object?>('status'),
    );
  }

  @override
  Future<void> openAccessibilitySettings() {
    return _channel.invokeMethod<void>('openAccessibilitySettings');
  }

  @override
  Future<void> saveToken(String token) {
    return _channel.invokeMethod<void>('saveToken', <String, String>{
      'token': token,
    });
  }

  @override
  Future<void> clearToken() {
    return _channel.invokeMethod<void>('clearToken');
  }
}
