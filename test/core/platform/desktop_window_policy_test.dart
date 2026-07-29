import 'package:dingdong/core/platform/desktop_window_policy.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('macOS taskbar policy follows the Dock icon preference', () {
    expect(
      desktopWindowSkipsTaskbar(
        TargetPlatform.macOS,
        hideDockIcon: true,
        fallback: false,
      ),
      isTrue,
    );
    expect(
      desktopWindowSkipsTaskbar(
        TargetPlatform.macOS,
        hideDockIcon: false,
        fallback: true,
      ),
      isFalse,
    );
  });

  test('other platforms preserve their window-specific fallback', () {
    expect(
      desktopWindowSkipsTaskbar(
        TargetPlatform.windows,
        hideDockIcon: true,
        fallback: false,
      ),
      isFalse,
    );
    expect(
      desktopWindowSkipsTaskbar(
        TargetPlatform.linux,
        hideDockIcon: false,
        fallback: true,
      ),
      isTrue,
    );
  });
}
