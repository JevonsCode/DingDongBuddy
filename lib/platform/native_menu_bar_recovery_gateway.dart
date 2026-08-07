import 'package:flutter/services.dart';

/// Opens the native macOS assistant for recovering a notch-hidden status item.
final class NativeMenuBarRecoveryGateway {
  const NativeMenuBarRecoveryGateway();

  static const MethodChannel _channel = MethodChannel(
    'dingdong/system_actions',
  );

  Future<void> show() => _channel.invokeMethod<void>('showMenuBarRecovery');
}
