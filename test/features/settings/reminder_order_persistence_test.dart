import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:dingdong/features/shell/domain/tray_reminder_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'built-in and custom order survives reload and controls unread promotion',
    () async {
      final repository = SettingsRepository(MemoryPreferencesBackend());
      final applied = <NotificationRules>[];
      final model = SettingsViewModel(
        repository,
        onNotificationRulesChanged: (rules) async => applied.add(rules),
      );
      addTearDown(model.dispose);
      await model.load();
      await model.saveReminderProfile(
        const ReminderProfile(id: 'failure', name: 'Build failed'),
      );
      await model.reorderReminderProfile('failure', 0);
      await model.reorderReminderProfile('attention', 1);
      final saved = await repository.load();
      expect(saved.reminderProfiles.map((p) => p.id), [
        'failure',
        'attention',
        'completion',
      ]);
      expect(applied.last.profileOrder, ['failure', 'attention', 'completion']);
      expect(
        orderedUnreadReminderProfiles(
          rules: saved.notificationRules,
          completionColor: saved.trayNotificationColor,
          unreadIds: ['completion', 'failure', 'attention'],
        ).map((p) => p.id),
        ['failure', 'attention', 'completion'],
      );
      expect(
        orderedUnreadReminderProfiles(
          rules: saved.notificationRules,
          completionColor: saved.trayNotificationColor,
          unreadIds: ['completion', 'attention'],
        ).first.id,
        'attention',
      );
      await model.saveReminderProfile(
        const ReminderProfile(id: 'next', name: 'Next'),
      );
      expect(model.settings.reminderProfiles.last.id, 'next');
      await model.deleteReminderProfile('failure');
      expect((await repository.load()).notificationRules.profileOrder, [
        'attention',
        'completion',
      ]);
    },
  );

  test('legacy and invalid saved order preserve all valid reminders once', () {
    const profiles = [ReminderProfile(id: 'a', name: 'A')];
    final rules = NotificationRules.parse(
      const NotificationRules(
        profiles: profiles,
        profileOrder: ['missing', 'a', 'a', 'attention'],
      ).encode(),
    );
    expect(rules.profileOrder, ['a', 'attention']);
    expect(
      AppSettings(notificationRules: rules).reminderProfiles.map((p) => p.id),
      ['a', 'attention', 'completion'],
    );
    expect(
      const AppSettings(
        notificationRules: NotificationRules(profiles: profiles),
      ).reminderProfiles.map((p) => p.id),
      ['completion', 'attention', 'a'],
    );
  });
}
