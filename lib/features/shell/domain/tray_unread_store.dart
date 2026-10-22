/// Durable monotonic state for the tray unread counter.
final class TrayUnreadState {
  const TrayUnreadState({
    required this.latestEventId,
    required this.acknowledgedEventId,
    this.latestAttentionEventId = 0,
  });

  const TrayUnreadState.empty()
    : latestEventId = 0,
      acknowledgedEventId = 0,
      latestAttentionEventId = 0;

  final int latestEventId;
  final int acknowledgedEventId;
  final int latestAttentionEventId;
}

abstract interface class TrayUnreadStore {
  Future<TrayUnreadState> load();

  Future<void> save(TrayUnreadState state);
}
