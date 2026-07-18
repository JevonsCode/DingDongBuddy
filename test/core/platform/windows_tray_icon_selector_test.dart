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
}
