import 'package:dingdong/features/clipboard/domain/quick_paste_gateway.dart';
import 'package:dingdong/features/settings/domain/quick_paste_permission.dart';
import 'package:flutter/services.dart';

/// Delegates accessibility-aware paste simulation to the desktop host runner.
final class NativeQuickPasteGateway
    implements QuickPasteGateway, QuickPastePermissionGateway {
  static const MethodChannel _channel = MethodChannel('dingdong/global_hotkey');

  @override
  Future<bool> pasteIntoPreviousApplication() async {
    return await _channel.invokeMethod<bool>('pasteToPrevious') ?? false;
  }

  @override
  Future<bool> isGranted() async {
    return await _channel.invokeMethod<bool>('isPastePermissionGranted') ??
        false;
  }

  @override
  Future<void> openSettings() async {
    await _channel.invokeMethod<void>('openPastePermissionSettings');
  }
}
