import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';

/// One localized snapshot shared by the native hover card and its tooltip.
/// It only describes reminders; hovering must never acknowledge them.
final class WindowsTrayReminderPreview {
  WindowsTrayReminderPreview({
    required int unreadCount,
    required bool needsInput,
    required DingDongLocalizations strings,
    required List<ReminderProfile> profiles,
    required Map<String, int?> counts,
  }) : totalCount = unreadCount.clamp(0, 999),
       title = needsInput ? strings.trayBuddyWaiting : strings.trayBuddyReady,
       subtitle = strings.trayBuddyUnread,
       footer = strings.trayBuddyOpen,
       rows = [
         for (final profile in profiles)
           <String, Object>{
             'name': switch (profile.id) {
               'attention' => strings.needsYourInput,
               'completion' => strings.agentCompletionNotifications,
               _ => profile.name,
             },
             'colorRgb': profile.color.rgbValue,
             if (counts[profile.id] != null)
               'count': counts[profile.id]!.clamp(0, 999),
           },
       ];

  final int totalCount;
  final String title;
  final String subtitle;
  final String footer;
  final List<Map<String, Object>> rows;

  String tooltip(DingDongLocalizations strings) {
    if (totalCount == 0) return 'DingDong';
    // Windows limits szTip to 127 UTF-16 code units. Keep the total first and
    // leave room for a useful subset of the breakdown, without splitting text.
    var result = strings.dingDongUnreadCount(totalCount);
    for (final row in rows) {
      final next = '\n${row['name']} · ${row['count'] ?? '?'}';
      if ((result + next).length > 126) break;
      result += next;
    }
    return result;
  }
}
