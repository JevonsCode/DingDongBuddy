/// Durable monotonic state for the tray unread counter.
final class TrayUnreadState {
  const TrayUnreadState({
    required this.latestEventId,
    required this.acknowledgedEventId,
  });

  const TrayUnreadState.empty() : latestEventId = 0, acknowledgedEventId = 0;

  final int latestEventId;
  final int acknowledgedEventId;
}

abstract interface class TrayUnreadStore {
  Future<TrayUnreadState> load();

  Future<void> save(TrayUnreadState state);
}
