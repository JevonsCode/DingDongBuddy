/// Returns the Windows tray icon that contrasts with the sampled taskbar.
String windowsTrayIconPath({
  required bool taskbarIsLight,
  required bool unread,
}) {
  final String surface = taskbarIsLight ? 'light' : 'dark';
  final String state = unread ? '_unread' : '';
  return 'windows/runner/resources/tray_icon_on_$surface$state.ico';
}

/// Returns the localized Windows notification-area hover text.
String windowsTrayTooltip({
  required int unreadCount,
  required bool useChineseLabels,
}) {
  final int count = unreadCount.clamp(0, 999);
  if (count == 0) {
    return 'DingDong';
  }
  return useChineseLabels
      ? 'DingDong · $count 条未读内容'
      : 'DingDong · $count unread';
}
