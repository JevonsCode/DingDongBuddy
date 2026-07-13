/// Actions emitted by tray items and the global clipboard shortcut.
enum DesktopShellCommand {
  openTray,
  showToday,
  showClipboard,
  toggleClipboard,
  toggleClipboardFilters,
  focusClipboardSearch,
  showSettings,
  startClipboardMonitoring,
  stopClipboardMonitoring,
  clearClipboardHistory,
  quit,
}

/// Native desktop lifecycle boundary shared by macOS and Windows.
abstract interface class DesktopShellGateway {
  Stream<DesktopShellCommand> get commands;

  Future<void> start();

  Future<void> showAndFocus();

  Future<void> toggleAndFocus();

  Future<void> quit();

  Future<void> stop();
}
