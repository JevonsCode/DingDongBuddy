// ignore_for_file: prefer_initializing_formals

import 'package:dingdong/features/settings/domain/application_updater.dart';
import 'package:flutter/services.dart';

/// Delegates secure download, replacement, cleanup, and relaunch to the
/// platform updater embedded in the desktop host.
final class NativeApplicationUpdater implements ApplicationUpdater {
  const NativeApplicationUpdater({
    MethodChannel channel = const MethodChannel('dingdong/updater'),
  }) : _channel = channel;

  final MethodChannel _channel;

  @override
  Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<ApplicationUpdateStatus> readStatus() async {
    try {
      final Map<Object?, Object?>? values = await _channel
          .invokeMapMethod<Object?, Object?>('state');
      return values == null
          ? const ApplicationUpdateStatus(
              phase: ApplicationUpdatePhase.unsupported,
            )
          : ApplicationUpdateStatus.fromJson(values);
    } on MissingPluginException {
      return const ApplicationUpdateStatus(
        phase: ApplicationUpdatePhase.unsupported,
      );
    }
  }

  @override
  Future<void> installLatest() async {
    await _channel.invokeMethod<void>('installLatest');
  }
}
