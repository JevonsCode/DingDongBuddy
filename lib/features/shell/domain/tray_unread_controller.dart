import 'dart:math' as math;

import 'package:dingdong/features/shell/domain/tray_unread_store.dart';

/// Applies the visual state of the desktop tray icon.
typedef ApplyTrayUnreadAppearance =
    Future<void> Function({
      required bool hot,
      required String title,
      required int iconSize,
      required int unreadCount,
    });

/// Durable, serialized unread counter shown beside DingDong's hot tray icon.
final class TrayUnreadController {
  TrayUnreadController({required this.apply, this.store});

  final ApplyTrayUnreadAppearance apply;
  final TrayUnreadStore? store;
  Future<void> _tail = Future<void>.value();
  int _latestEventId = 0;
  int _acknowledgedEventId = 0;

  int get count => (_latestEventId - _acknowledgedEventId).clamp(0, 999);

  TrayUnreadSnapshot snapshot() => TrayUnreadSnapshot(_latestEventId);

  Future<void> restore() {
    return _enqueue(() async {
      final TrayUnreadState state =
          await store?.load() ?? const TrayUnreadState.empty();
      _latestEventId = math.max(0, state.latestEventId);
      _acknowledgedEventId = state.acknowledgedEventId.clamp(0, _latestEventId);
      await _apply();
    });
  }

  Future<void> markUnread() {
    return _enqueue(() async {
      _latestEventId += 1;
      await _persist();
      await _apply();
    });
  }

  Future<void> acknowledge(TrayUnreadSnapshot snapshot) {
    return _enqueue(() async {
      final int next = math.max(
        _acknowledgedEventId,
        math.min(snapshot.latestEventId, _latestEventId),
      );
      if (next == _acknowledgedEventId) {
        return;
      }
      _acknowledgedEventId = next;
      await _persist();
      await _apply();
    });
  }

  Future<void> clear() => acknowledge(snapshot());

  /// Reapplies the current visual state after the taskbar appearance changes.
  Future<void> refresh() => _enqueue(_apply);

  Future<void> _apply() async {
    final int unreadCount = count;
    final bool hot = unreadCount > 0;
    final String label = unreadCount > 99 ? '99+' : '$unreadCount';
    await apply(
      hot: hot,
      title: hot ? ' $label' : '',
      iconSize: 22,
      unreadCount: unreadCount,
    );
  }

  Future<void> _persist() async {
    await store?.save(
      TrayUnreadState(
        latestEventId: _latestEventId,
        acknowledgedEventId: _acknowledgedEventId,
      ),
    );
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final Future<void> result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}

final class TrayUnreadSnapshot {
  const TrayUnreadSnapshot(this.latestEventId);

  final int latestEventId;
}
