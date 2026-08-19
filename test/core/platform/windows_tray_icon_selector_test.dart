import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/windows_tray_icon_selector.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selects a contrasting Windows tray icon for every state', () {
    expect(
      windowsTrayIconPath(taskbarIsLight: false, unread: false),
      'windows/runner/resources/tray_icon_on_dark.ico',
    );
    expect(
      windowsTrayIconPath(taskbarIsLight: false, unread: true),
      'windows/runner/resources/tray_icon_adaptive_unread.ico',
    );
    expect(
      windowsTrayIconPath(taskbarIsLight: true, unread: false),
      'windows/runner/resources/tray_icon_on_light.ico',
    );
    expect(
      windowsTrayIconPath(taskbarIsLight: true, unread: true),
      'windows/runner/resources/tray_icon_adaptive_unread.ico',
    );
    expect(
      windowsTrayIconPath(
        taskbarIsLight: false,
        unread: false,
        state: WindowsTrayIconState.resting,
        alternateFrame: true,
      ),
      'windows/runner/resources/tray_icon_on_dark_rest2.ico',
    );
    expect(
      windowsTrayIconPath(
        taskbarIsLight: true,
        unread: false,
        state: WindowsTrayIconState.sleeping,
      ),
      'windows/runner/resources/tray_icon_on_light_sleeping.ico',
    );
    expect(
      windowsTrayIconPath(
        taskbarIsLight: true,
        unread: true,
        state: WindowsTrayIconState.sleeping,
        alternateFrame: true,
      ),
      'windows/runner/resources/tray_icon_adaptive_unread2.ico',
    );
  });

  test('formats the Windows unread count for the hover tooltip', () {
    final DingDongLocalizations chinese = lookupDingDongLocalizations(
      const Locale('zh'),
    );
    final DingDongLocalizations english = lookupDingDongLocalizations(
      const Locale('en'),
    );
    final DingDongLocalizations spanish = lookupDingDongLocalizations(
      const Locale('es'),
    );
    expect(windowsTrayTooltip(unreadCount: 0, strings: chinese), 'DingDong');
    expect(
      windowsTrayTooltip(unreadCount: 3, strings: chinese),
      'DingDong · 3 条未读内容',
    );
    expect(
      windowsTrayTooltip(unreadCount: 3, strings: english),
      'DingDong · 3 unread',
    );
    expect(
      windowsTrayTooltip(unreadCount: 1001, strings: chinese),
      'DingDong · 999 条未读内容',
    );
    expect(
      windowsTrayTooltip(unreadCount: 3, strings: spanish),
      'DingDong · 3 sin leer',
    );
  });
}
