/// Restores focus to the application active before DingDong's global shortcut.
abstract interface class QuickPasteGateway {
  Future<bool> pasteIntoPreviousApplication();
}
