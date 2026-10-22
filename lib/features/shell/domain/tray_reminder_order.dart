import 'package:dingdong/features/settings/domain/tray_reminder_style.dart';
import '../../activity/domain/agent_notification_kind.dart';
import '../../settings/domain/notification_rules.dart';
import '../../settings/domain/reminder_profile.dart';

/// Same order as Settings' reminder array, independent of arrival or priority.
List<ReminderProfile> orderedUnreadReminderProfiles({
  required NotificationRules rules,
  required TrayNotificationColor completionColor,
  required Iterable<String> unreadIds,
}) {
  final ids = unreadIds.toSet();
  return [
    for (final kind in AgentNotificationKind.values)
      ReminderProfile(
        id: kind.apiValue,
        name: kind.apiValue,
        kind: kind,
        color: rules.trayColorFor(kind, legacyCompletionColor: completionColor),
        style: rules.trayStyleFor(kind),
      ),
    ...rules.profiles,
  ].where((p) => ids.contains(p.id)).toList();
}
