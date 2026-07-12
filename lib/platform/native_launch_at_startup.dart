import 'package:dingdong/features/settings/domain/launch_at_startup.dart';
import 'package:flutter/services.dart';

/// Uses the host runner to register DingDong for the current user at sign-in.
final class NativeLaunchAtStartup implements LaunchAtStartup {
  static const MethodChannel _channel = MethodChannel(
    'dingdong/launch_at_startup',
  );

  @override
  Future<bool> isEnabled() async {
    return await _channel.invokeMethod<bool>('isEnabled') ?? false;
  }

  @override
  Future<void> setEnabled(bool value) {
    return _channel.invokeMethod<void>('setEnabled', <String, Object?>{
      'enabled': value,
    });
  }
}
