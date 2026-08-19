import 'package:dingdong/app/app_localizations.dart';

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
  return switch (visualState) {
    WindowsTrayIconState.normal =>
      'windows/runner/resources/tray_icon_on_$surface.ico',
    WindowsTrayIconState.reminder =>
      'windows/runner/resources/tray_icon_adaptive_unread$frame.ico',
    WindowsTrayIconState.resting =>
      'windows/runner/resources/tray_icon_on_${surface}_rest$frame.ico',
    WindowsTrayIconState.sleeping =>
      'windows/runner/resources/tray_icon_on_${surface}_sleeping$frame.ico',
  };
}

/// Returns the localized Windows notification-area hover text.
String windowsTrayTooltip({
  required int unreadCount,
  required DingDongLocalizations strings,
}) {
  final int count = unreadCount.clamp(0, 999);
  if (count == 0) {
    return 'DingDong';
  }
  return strings.dingDongUnreadCount(count);
}
