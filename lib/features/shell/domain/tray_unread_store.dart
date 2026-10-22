/// Durable monotonic state for the tray unread counter.
final class TrayUnreadState {
  const TrayUnreadState({
    required this.latestEventId,
    required this.acknowledgedEventId,
    this.latestAttentionEventId = 0,
    this.latestReminderId,
    this.latestAttentionReminderId,
  });

  const TrayUnreadState.empty()
    : latestEventId = 0,
      acknowledgedEventId = 0,
      latestAttentionEventId = 0,
      latestReminderId = null,
      latestAttentionReminderId = null;

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
