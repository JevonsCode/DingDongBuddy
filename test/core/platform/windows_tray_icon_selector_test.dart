import 'package:dingdong/core/platform/windows_tray_icon_selector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects a contrasting Windows tray icon for every state', () {
    expect(
      windowsTrayIconPath(taskbarIsLight: false, unread: false),
      'windows/runner/resources/tray_icon_on_dark.ico',
    );
    expect(
      windowsTrayIconPath(taskbarIsLight: false, unread: true),
      'windows/runner/resources/tray_icon_on_dark_unread.ico',
    );
    expect(
      windowsTrayIconPath(taskbarIsLight: true, unread: false),
      'windows/runner/resources/tray_icon_on_light.ico',
    );
    expect(
      windowsTrayIconPath(taskbarIsLight: true, unread: true),
      'windows/runner/resources/tray_icon_on_light_unread.ico',
    );
  });

  test('formats the Windows unread count for the hover tooltip', () {
    expect(
      windowsTrayTooltip(unreadCount: 0, useChineseLabels: true),
      'DingDong',
    );
    expect(
      windowsTrayTooltip(unreadCount: 3, useChineseLabels: true),
      'DingDong · 3 条未读内容',
    );
    expect(
      windowsTrayTooltip(unreadCount: 3, useChineseLabels: false),
      'DingDong · 3 unread',
    );
    expect(
      windowsTrayTooltip(unreadCount: 1001, useChineseLabels: true),
      'DingDong · 999 条未读内容',
    );
  });
}
