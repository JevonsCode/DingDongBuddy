/// Returns the Windows tray icon that contrasts with the sampled taskbar.
String windowsTrayIconPath({
  required bool taskbarIsLight,
  required bool unread,
}) {
  final String surface = taskbarIsLight ? 'light' : 'dark';
  final String state = unread ? '_unread' : '';
  return 'windows/runner/resources/tray_icon_on_$surface$state.ico';
}
