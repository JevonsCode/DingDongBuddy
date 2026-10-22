import 'package:dingdong/app/app_dependencies.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/settings/domain/notification_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const custom = ReminderProfile(
    id: 'error',
    name: 'Error',
    sound: 'dingDeep',
    color: TrayNotificationColor.pink,
  );
  test(
    'legacy preferences remain the built-in profiles without migration loss',
    () {
      const settings = AppSettings(
        notifyAgentCompletion: false,
        selectedSound: 'dingBright',
        trayNotificationColor: TrayNotificationColor.purple,
      );
      expect(settings.reminderProfile('completion')!.enabled, false);
      expect(
        settings.reminderProfile('completion')!.color,
        TrayNotificationColor.purple,
      );
      expect(settings.reminderProfile('attention')!.sound, 'dingBright');
      expect(settings.withReminderProfile(custom).selectedSound, 'dingBright');
    },
  );
  test(
    'profiles and shared sounds survive storage and independent removal',
    () {
      final settings = const AppSettings()
          .withReminderProfile(custom)
          .withReminderProfile(custom.copyWith(name: 'Oops'));
      final roundTrip = NotificationRules.parse(
        settings.notificationRules.encode(),
      );
      expect(roundTrip.profiles.single.name, 'Oops');
      expect(
        settings.withoutReminderProfile('error').notificationRules.profiles,
        isEmpty,
      );
      expect(
        () => settings.withoutReminderProfile('attention'),
        throwsFormatException,
      );
    },
  );
  test(
    'custom reminders stay independent of disabled built-in kinds',
    () async {
      final settings = const AppSettings(
        notifyAgentAttention: false,
        notifyAgentCompletion: false,
      ).withReminderProfile(custom);
      final delivered = <DingRequest>[];
      await deliverAgentNotification(
        request: DingRequest.parse('{"reminderId":"error"}'),
        settings: settings,
        nativeDelivery: (x) async {
          delivered.add(x);
        },
      );
      expect(delivered.single.sound, DingSound.dingDeep);
      expect(
        delivered.single.notificationKind,
        AgentNotificationKind.attention,
      );
      expect(delivered.single.reminderId, 'error');
    },
  );
  test('unknown or disabled profile never silently rings a default', () async {
    for (final settings in [
      const AppSettings(),
      const AppSettings().withReminderProfile(custom.copyWith(enabled: false)),
    ]) {
      expect(
        await shouldDeliverAgentNotification(
          request: DingRequest.parse('{"reminderId":"error"}'),
          settings: settings,
        ),
        false,
      );
    }
  });
  test(
    'short-task completion policy does not suppress explicit custom events',
    () async {
      final settings =
          const AppSettings(
            notificationRules: NotificationRules(completionMinimumMinutes: 30),
          ).withReminderProfile(
            custom.copyWith(kind: AgentNotificationKind.completion),
          );
      var delivered = false;
      await deliverAgentNotification(
        request: DingRequest.parse('{"reminderId":"error"}'),
        settings: settings,
        nativeDelivery: (_) async {
          delivered = true;
        },
        taskStartedAt: (_) => DateTime.now(),
      );
      expect(delivered, true);
    },
  );
}
