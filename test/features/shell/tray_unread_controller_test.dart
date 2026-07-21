import 'package:dingdong/features/shell/domain/tray_unread_controller.dart';
import 'package:dingdong/features/shell/domain/tray_unread_store.dart';
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

  test(
    'restores durable state and acknowledges only events visible in a snapshot',
    () async {
      final _MemoryTrayUnreadStore store = _MemoryTrayUnreadStore(
        const TrayUnreadState(latestEventId: 5, acknowledgedEventId: 2),
      );
      final List<int> appearances = <int>[];
      final TrayUnreadController controller = TrayUnreadController(
        store: store,
        apply:
            ({
              required bool hot,
              required String title,
              required int iconSize,
              required int unreadCount,
            }) async {
              appearances.add(unreadCount);
            },
      );

      await controller.restore();
      expect(controller.count, 3);
      expect(appearances, <int>[3]);
      final TrayUnreadSnapshot visible = controller.snapshot();

      final Future<void> newNotification = controller.markUnread();
      final Future<void> acknowledgement = controller.acknowledge(visible);
      await Future.wait(<Future<void>>[newNotification, acknowledgement]);

      expect(controller.count, 1);
      expect(appearances, <int>[3, 4, 1]);
      expect(store.state.latestEventId, 6);
      expect(store.state.acknowledgedEventId, 5);

      final TrayUnreadController restored = TrayUnreadController(
        store: store,
        apply:
            ({
              required bool hot,
              required String title,
              required int iconSize,
              required int unreadCount,
            }) async {},
      );
      await restored.restore();
      expect(restored.count, 1);
    },
  );
}

final class _MemoryTrayUnreadStore implements TrayUnreadStore {
  _MemoryTrayUnreadStore(this.state);

  TrayUnreadState state;

  @override
  Future<TrayUnreadState> load() async => state;

  @override
  Future<void> save(TrayUnreadState state) async {
    this.state = state;
  }
}
