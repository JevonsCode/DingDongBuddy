/// Desktop permission required to paste back into the previously focused app.
abstract interface class QuickPastePermissionGateway {
  Future<bool> isGranted();

  Future<void> openSettings();
}
