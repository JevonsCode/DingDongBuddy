import 'package:dingdong/features/shell/domain/tray_unread_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'agent notifications show the hot icon and unread count until opened',
    () async {
      final List<(bool, String, int)> appearances = <(bool, String, int)>[];
      final TrayUnreadController controller = TrayUnreadController(
        apply: ({
          required bool hot,
          required String title,
          required int iconSize,
        }) async {
          appearances.add((hot, title, iconSize));
        },
      );

      await controller.markUnread();
      await controller.markUnread();

      expect(controller.count, 2);
      expect(appearances, <(bool, String, int)>[
        (true, ' 1', 22),
        (true, ' 2', 22),
      ]);

      await controller.clear();

      expect(controller.count, 0);
      expect(appearances.last, (false, '', 22));
    },
  );
}
