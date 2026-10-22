import 'package:dingdong/features/settings/domain/notification_rules.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';
import 'package:dingdong/features/settings/domain/tray_reminder_style.dart';
import 'package:dingdong/features/shell/domain/tray_reminder_order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'active reminder array order promotes the first type and restores completion',
    () {
      const rules = NotificationRules(
        profiles: [
          ReminderProfile(
            id: 'a',
            name: 'A',
            color: TrayNotificationColor.orange,
          ),
          ReminderProfile(
            id: 'b',
            name: 'B',
            color: TrayNotificationColor.pink,
          ),
        ],
      );
      List<ReminderProfile> order(List<String> ids) =>
          orderedUnreadReminderProfiles(
            rules: rules,
            completionColor: TrayNotificationColor.purple,
            unreadIds: ids,
          );
      expect(order(['b', 'a']).map((p) => p.id), ['a', 'b']);
      expect(order(['b', 'completion', 'a']).map((p) => p.id), [
        'completion',
        'a',
        'b',
      ]);
      expect(order(['b']).first.id, 'b');
      expect(order(['missing']), isEmpty);
      final reordered = rules.copyWith(
        profiles: rules.profiles.reversed.toList(),
      );
      expect(
        orderedUnreadReminderProfiles(
          rules: reordered,
          completionColor: TrayNotificationColor.purple,
          unreadIds: ['a', 'b'],
        ).map((p) => p.id),
        ['b', 'a'],
      );
    },
  );
}
