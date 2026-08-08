enum WindowsTrayIconState { normal, reminder, resting, sleeping }

/// Returns the Windows tray icon that contrasts with the sampled taskbar.
String windowsTrayIconPath({
  required bool taskbarIsLight,
  required bool unread,
  WindowsTrayIconState state = WindowsTrayIconState.normal,
  bool alternateFrame = false,
}) {
  final String surface = taskbarIsLight ? 'light' : 'dark';
  final WindowsTrayIconState visualState = unread
      ? WindowsTrayIconState.reminder
      : state;
  final String frame = alternateFrame ? '2' : '';
  final String suffix = switch (visualState) {
    WindowsTrayIconState.normal => '',
    WindowsTrayIconState.reminder => '_unread$frame',
    WindowsTrayIconState.resting => '_rest$frame',
    WindowsTrayIconState.sleeping => '_sleeping$frame',
  };
  return 'windows/runner/resources/tray_icon_on_$surface$suffix.ico';
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
