import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/shell/domain/tray_unread_controller.dart';
import 'package:dingdong/platform/preferences_tray_unread_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TrayUnreadController controller(PreferencesTrayUnreadStore store) =>
      TrayUnreadController(
        store: store,
        apply:
            ({
              required bool hot,
              required String title,
              required int iconSize,
              required int unreadCount,
            }) async {},
      );

  test(
    'attention stays primary after a later completion and across restart',
    () async {
      final store = PreferencesTrayUnreadStore(MemoryPreferencesBackend());
      final tray = controller(store);
      await tray.markUnread(kind: AgentNotificationKind.attention);
      await tray.markUnread();
      expect(tray.primaryKind, AgentNotificationKind.attention);
      final restored = controller(store);
      await restored.restore();
      expect(restored.primaryKind, AgentNotificationKind.attention);
      expect(restored.count, 2);
      await restored.acknowledgeCount(1);
      expect(restored.primaryKind, AgentNotificationKind.completion);
      expect(restored.count, 1);
    },
  );

  test(
    'acknowledging an older snapshot does not clear a newer attention',
    () async {
      final tray = controller(
        PreferencesTrayUnreadStore(MemoryPreferencesBackend()),
      );
      await tray.markUnread();
      final visible = tray.snapshot();
      await tray.markUnread(kind: AgentNotificationKind.attention);
      await tray.acknowledge(visible);
      expect(tray.count, 1);
      expect(tray.primaryKind, AgentNotificationKind.attention);
      await tray.clear();
      expect(tray.primaryKind, AgentNotificationKind.completion);
    },
  );
}
