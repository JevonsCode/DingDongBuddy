import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/shell/domain/tray_unread_store.dart';
import 'package:dingdong/platform/preferences_tray_unread_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
