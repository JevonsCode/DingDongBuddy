import 'package:flutter/foundation.dart';

/// Minimal settings contract consumed by the clipboard workspace.
abstract interface class ClipboardSettingsController implements Listenable {
  bool get clipboardMonitoring;
  bool? get quickPastePermissionGranted;

  Future<void> setClipboardMonitoring(bool enabled);
  Future<void> refreshQuickPastePermission();
  Future<void> openQuickPastePermissionSettings();
}
