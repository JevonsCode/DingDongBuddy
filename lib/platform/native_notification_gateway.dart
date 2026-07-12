import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/settings/domain/sound_preview_gateway.dart';
import 'package:flutter/services.dart';

/// Triggers attention and sound through the macOS or Windows host runner.
final class NativeNotificationGateway implements SoundPreviewGateway {
  static const MethodChannel _channel = MethodChannel('dingdong/notification');

  Future<void> trigger(DingRequest request, {String? customSoundPath}) {
    return _channel.invokeMethod<void>('notify', <String, Object?>{
      'message': request.message,
      'source': request.source,
      'sound': request.sound.apiValue,
      'flashCount': request.flashCount,
      'customSoundPath': ?customSoundPath,
    });
  }

  @override
  Future<void> preview({required String sound, String? customSoundPath}) {
    return _channel.invokeMethod<void>('preview', <String, Object?>{
      'sound': sound,
      'customSoundPath': ?customSoundPath,
    });
  }
}
