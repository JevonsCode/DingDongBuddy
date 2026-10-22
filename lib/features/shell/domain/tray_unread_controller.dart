import 'dart:math' as math;

import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
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
  int _latestAttentionEventId = 0;
  final Map<String, int> _reminderEvents = {};
  List<String> get unreadReminderIds {
    final entries =
        _reminderEvents.entries
            .where((e) => e.value > _acknowledgedEventId)
            .toList()
          ..sort((a, b) => a.value.compareTo(b.value));
    return entries.map((e) => e.key).toList(growable: false);
  }

  String? _latestReminderId;
  String? _latestAttentionReminderId;
  String? get primaryReminderId =>
      primaryKind == AgentNotificationKind.attention
      ? _latestAttentionReminderId
      : _latestReminderId;

  AgentNotificationKind get primaryKind =>
      _latestAttentionEventId > _acknowledgedEventId
      ? AgentNotificationKind.attention
      : AgentNotificationKind.completion;

  int get count => (_latestEventId - _acknowledgedEventId).clamp(0, 999);

  TrayUnreadSnapshot snapshot() => TrayUnreadSnapshot(_latestEventId);

  Future<void> restore() {
    return _enqueue(() async {
      final TrayUnreadState state =
          await store?.load() ?? const TrayUnreadState.empty();
      _latestReminderId = state.latestReminderId;
      _latestAttentionReminderId = state.latestAttentionReminderId;
      _latestEventId = math.max(0, state.latestEventId);
      _acknowledgedEventId = state.acknowledgedEventId.clamp(0, _latestEventId);
      _latestAttentionEventId = state.latestAttentionEventId.clamp(
        0,
        _latestEventId,
      );
      _reminderEvents.clear();
      _reminderEvents.addAll(state.reminderEvents);
      // Older installations only persisted the latest event and attention event.
      if (_reminderEvents.isEmpty && count > 0) {
        _reminderEvents[_latestReminderId ??
                (_latestAttentionEventId == _latestEventId
                    ? 'attention'
                    : 'completion')] =
            _latestEventId;
        if (_latestAttentionEventId > _acknowledgedEventId) {
          _reminderEvents[_latestAttentionReminderId ?? 'attention'] =
              _latestAttentionEventId;
        }
      }
      _pruneReminderEvents();
      await _apply();
    });
  }

  Future<void> markUnread({
    AgentNotificationKind kind = AgentNotificationKind.completion,
    String? reminderId,
  }) {
    return _enqueue(() async {
      _latestEventId += 1;
      _latestReminderId = reminderId;
      _reminderEvents[reminderId ?? kind.apiValue] = _latestEventId;
      if (kind == AgentNotificationKind.attention) {
        _latestAttentionEventId = _latestEventId;
        _latestAttentionReminderId = reminderId;
      }
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

  /// Acknowledges a known number of reminders without clearing newer events.
  Future<void> acknowledgeCount(int count) {
    if (count <= 0) {
      return Future<void>.value();
    }
    return _enqueue(() async {
      final int next = math.min(_latestEventId, _acknowledgedEventId + count);
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

  void _pruneReminderEvents() {
    _reminderEvents.removeWhere(
      (id, event) => event <= _acknowledgedEventId || event > _latestEventId,
    );
    // Profiles may be deleted and recreated between acknowledgements.
    while (_reminderEvents.length > 64) {
      final oldest = _reminderEvents.entries.reduce(
        (a, b) => a.value < b.value ? a : b,
      );
      _reminderEvents.remove(oldest.key);
    }
  }

  Future<void> _persist() async {
    _pruneReminderEvents();
    await store?.save(
      TrayUnreadState(
        reminderEvents: Map.unmodifiable(_reminderEvents),
        latestEventId: _latestEventId,
        acknowledgedEventId: _acknowledgedEventId,
        latestAttentionEventId: _latestAttentionEventId,
        latestReminderId: _latestReminderId,
        latestAttentionReminderId: _latestAttentionReminderId,
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
