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
    'legacy counts remain unknown until acknowledged, then new events are exact',
    () async {
      final prefs = MemoryPreferencesBackend({
        'dingdong.tray.unreadState':
            '{"latestEventId":7,"acknowledgedEventId":0,"reminderEvents":{"completion":7}}',
      });
      final store = PreferencesTrayUnreadStore(prefs);
      final tray = controller(store);
      await tray.restore();
      expect(tray.unreadReminderCounts['completion'], isNull);
      final old = tray.snapshot();
      await tray.markUnread();
      expect(tray.unreadReminderCounts['completion'], isNull);
      final restored = controller(store);
      await restored.restore();
      await restored.acknowledge(old);
      expect(restored.unreadReminderCounts, {'completion': 1});
    },
  );

  test(
    'bubbles retain distinct reminder types through restart and partial acknowledgement',
    () async {
      final store = PreferencesTrayUnreadStore(MemoryPreferencesBackend());
      final tray = controller(store);
      await tray.markUnread(reminderId: 'build');
      await tray.markUnread(
        kind: AgentNotificationKind.attention,
        reminderId: 'review',
      );
      final old = tray.snapshot();
      await tray.markUnread(reminderId: 'build');
      await tray.markUnread();
      expect(tray.unreadReminderIds, ['review', 'build', 'completion']);
      expect(tray.unreadReminderCounts, {
        'review': 1,
        'build': 2,
        'completion': 1,
      });
      final restored = controller(store);
      await restored.restore();
      expect(restored.unreadReminderIds, tray.unreadReminderIds);
      expect(restored.unreadReminderCounts, tray.unreadReminderCounts);
      await restored.acknowledge(old);
      expect(restored.unreadReminderIds, ['build', 'completion']);
      expect(restored.unreadReminderCounts, {'build': 1, 'completion': 1});
      await restored.acknowledgeCount(1);
      expect(restored.unreadReminderIds, ['completion']);
      await restored.clear();
      expect(restored.unreadReminderIds, isEmpty);
    },
  );

  test(
    'attention stays primary after a later completion and across restart',
    () async {
      final store = PreferencesTrayUnreadStore(MemoryPreferencesBackend());
      final tray = controller(store);
      await tray.markUnread(
        kind: AgentNotificationKind.attention,
        reminderId: 'error',
      );
      await tray.markUnread();
      expect(tray.primaryKind, AgentNotificationKind.attention);
      final restored = controller(store);
      await restored.restore();
      expect(restored.primaryKind, AgentNotificationKind.attention);
      expect(restored.primaryReminderId, 'error');
      expect(restored.count, 2);
      await restored.acknowledgeCount(1);
      expect(restored.primaryKind, AgentNotificationKind.completion);
      expect(restored.primaryReminderId, isNull);
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
