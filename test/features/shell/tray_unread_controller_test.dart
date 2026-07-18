import 'package:dingdong/features/shell/domain/tray_unread_controller.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Appearance = ({bool hot, String title, int iconSize, int unreadCount});

void main() {
  test(
    'new unread events, refresh, and clear expose the current unread count',
    () async {
      final List<_Appearance> appearances = <_Appearance>[];
      final TrayUnreadController controller = TrayUnreadController(
        apply:
            ({
              required bool hot,
              required String title,
              required int iconSize,
              required int unreadCount,
            }) async {
              appearances.add((
                hot: hot,
                title: title,
                iconSize: iconSize,
                unreadCount: unreadCount,
              ));
            },
      );

      await controller.markUnread();
      await controller.markUnread();
      expect(appearances, <_Appearance>[
        (hot: true, title: ' 1', iconSize: 22, unreadCount: 1),
        (hot: true, title: ' 2', iconSize: 22, unreadCount: 2),
      ]);

      appearances.clear();
      await controller.refresh();
      expect(appearances.single, (
        hot: true,
        title: ' 2',
        iconSize: 22,
        unreadCount: 2,
      ));

      await controller.clear();
      expect(appearances.last, (
        hot: false,
        title: '',
        iconSize: 22,
        unreadCount: 0,
      ));
    },
  );

  test(
    'the actual unread count stays clamped independently of display labels',
    () async {
      late int lastUnreadCount;
      late String lastTitle;
      final TrayUnreadController controller = TrayUnreadController(
        apply:
            ({
              required bool hot,
              required String title,
              required int iconSize,
              required int unreadCount,
            }) async {
              lastTitle = title;
              lastUnreadCount = unreadCount;
            },
      );

      for (int index = 0; index < 1001; index += 1) {
        await controller.markUnread();
      }

      expect(controller.count, 999);
      expect(lastUnreadCount, 999);
      expect(lastTitle, ' 99+');
    },
  );
}
