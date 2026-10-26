import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';
import 'package:dingdong/features/settings/domain/tray_reminder_style.dart';
import 'package:dingdong/features/shell/domain/tray_unread_controller.dart';
import 'package:dingdong/features/shell/domain/tray_unread_store.dart';
import 'package:dingdong/platform/preferences_tray_unread_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'temporary definitions survive restart and bounded history keeps the newest snapshot',
    () async {
      final store = PreferencesTrayUnreadStore(MemoryPreferencesBackend());
      Future<void> apply({
        required bool hot,
        required String title,
        required int iconSize,
        required int unreadCount,
      }) async {}
      final controller = TrayUnreadController(apply: apply, store: store);
      for (var i = 0; i < 65; i++) {
        final profile = ReminderProfile(
          id: 'once-$i',
          name: 'Once $i',
          temporary: true,
          color: TrayNotificationColor.green,
        );
        await controller.markUnread(reminderId: profile.id, reminder: profile);
      }
      expect(controller.reminderSnapshots.length, 64);
      final restored = TrayUnreadController(apply: apply, store: store);
      await restored.restore();
      expect(restored.reminderSnapshots['once-64']?.temporary, true);
      expect(
        restored.reminderSnapshots['once-64']?.color,
        TrayNotificationColor.green,
      );
      expect(restored.reminderSnapshots.containsKey('once-0'), false);
    },
  );
  test('persists unread event and acknowledgement ids atomically', () async {
    final MemoryPreferencesBackend preferences = MemoryPreferencesBackend();
    final PreferencesTrayUnreadStore store = PreferencesTrayUnreadStore(
      preferences,
    );

    await store.save(
      const TrayUnreadState(latestEventId: 8, acknowledgedEventId: 3),
    );

    final TrayUnreadState restored = await store.load();
    expect(restored.latestEventId, 8);
    expect(restored.acknowledgedEventId, 3);
    expect(preferences.values, hasLength(1));
  });

  test('invalid persisted state safely resets to empty', () async {
    final MemoryPreferencesBackend preferences = MemoryPreferencesBackend(
      <String, Object>{'dingdong.tray.unreadState': 'not-json'},
    );
    final PreferencesTrayUnreadStore store = PreferencesTrayUnreadStore(
      preferences,
    );

    final TrayUnreadState restored = await store.load();

    expect(restored.latestEventId, 0);
    expect(restored.acknowledgedEventId, 0);
  });
}
