import 'package:dingdong/features/settings/domain/reminder_profile.dart';

/// Durable monotonic state for the tray unread counter.
final class TrayUnreadState {
  const TrayUnreadState({
    required this.latestEventId,
    required this.acknowledgedEventId,
    this.latestAttentionEventId = 0,
    this.latestReminderId,
    this.latestAttentionReminderId,
    this.reminderEvents = const {},
    this.reminderSnapshots = const {},
    this.reminderEventHistory = const {},
  });

  const TrayUnreadState.empty()
    : latestEventId = 0,
      acknowledgedEventId = 0,
      latestAttentionEventId = 0,
      latestReminderId = null,
      latestAttentionReminderId = null,
      reminderEvents = const {},
      reminderSnapshots = const {},
      reminderEventHistory = const {};

  /// Last event for each reminder type; counts still use the monotonic cursor.
  final Map<String, int> reminderEvents;
  final Map<String, ReminderProfile> reminderSnapshots;

  /// Positive event IDs; a negative ID marks unknown legacy history through that ID.
  final Map<String, List<int>> reminderEventHistory;
  final int latestEventId;
  final int acknowledgedEventId;
  final int latestAttentionEventId;
  final String? latestReminderId;
  final String? latestAttentionReminderId;
}

abstract interface class TrayUnreadStore {
  Future<TrayUnreadState> load();

  Future<void> save(TrayUnreadState state);
}
