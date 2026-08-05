/// Actions emitted by tray items and the global clipboard shortcut.
enum DesktopShellCommand {
  openApplication,
  openTray,
  showToday,
  showClipboard,
  toggleClipboard,
  quickPastePermissionGranted,
  toggleClipboardFilters,
  focusClipboardSearch,
  showResourceManager,
  showSettings,
  showAbout,
  hideDockIcon,
  startClipboardMonitoring,
  stopClipboardMonitoring,
  clearClipboardHistory,
  quit,
}

/// Native desktop lifecycle boundary shared by macOS and Windows.
abstract interface class DesktopShellGateway {
  Stream<DesktopShellCommand> get commands;

  Future<void> start();

  Future<void> showAndFocus({bool acknowledgeUnread = false});

  Future<void> toggleAndFocus({bool acknowledgeUnread = false});

  Future<void> quit();

  Future<void> stop();
}
