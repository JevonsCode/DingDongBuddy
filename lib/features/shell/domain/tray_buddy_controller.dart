import 'dart:async';

import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';

const Duration trayBuddyReminderDelay = Duration(minutes: 5);
const Duration trayBuddyReminderRepeatInterval = Duration(minutes: 1);
const Duration trayBuddyAgentRestDelay = Duration(minutes: 5);
const Duration trayBuddyClipboardIdleDelay = Duration(minutes: 30);

/// Visual states shared by the popup mascot and the macOS menu-bar mascot.
enum TrayBuddyState { normal, reminder, resting, sleeping }

/// Turns Agent and clipboard activity into a single, prioritized mascot state.
final class TrayBuddyController {
  factory TrayBuddyController({
    required ActivityController activityController,
    required Future<void> Function(TrayBuddyState state) onStateChanged,
    required Future<void> Function() onReminderNudge,
    DateTime Function()? now,
    Duration reminderDelay = trayBuddyReminderDelay,
    Duration reminderRepeatInterval = trayBuddyReminderRepeatInterval,
    Duration agentRestDelay = trayBuddyAgentRestDelay,
    Duration clipboardIdleDelay = trayBuddyClipboardIdleDelay,
  }) => TrayBuddyController._(
    activityController,
    onStateChanged,
    onReminderNudge,
    now ?? DateTime.now,
    reminderDelay,
    reminderRepeatInterval,
    agentRestDelay,
    clipboardIdleDelay,
  );

  TrayBuddyController._(
    this._activityController,
    this._onStateChanged,
    this._onReminderNudge,
    this._now,
    this._reminderDelay,
    this._reminderRepeatInterval,
    this._agentRestDelay,
    this._clipboardIdleDelay,
  );

  final ActivityController _activityController;
  final Future<void> Function(TrayBuddyState state) _onStateChanged;
  final Future<void> Function() _onReminderNudge;
  final DateTime Function() _now;
  final Duration _reminderDelay;
  final Duration _reminderRepeatInterval;
  final Duration _agentRestDelay;
  final Duration _clipboardIdleDelay;

  Timer? _reminderNudgeTimer;
  Timer? _agentRestTimer;
  Timer? _clipboardIdleTimer;
  DateTime? _latestAgentActivity;
  DateTime? _latestClipboardActivity;
  DateTime? _lastReminderNudgeAt;
  TrayBuddyState? _announcedState;
  bool _hasUnseenReminder = false;
  bool _started = false;

  TrayBuddyState get state => _announcedState ?? TrayBuddyState.normal;

  void start({DateTime? lastClipboardActivity}) {
    final DateTime now = _now().toUtc();
    if (_started) {
      if (lastClipboardActivity != null) {
        recordClipboardActivity(lastClipboardActivity);
      }
      return;
    }
    _started = true;
    _latestClipboardActivity = lastClipboardActivity?.toUtc() ?? now;
    _latestAgentActivity = _latestActivityAt() ?? now;
    _activityController.addListener(_syncAgentState);
    _syncAgentState();
    _scheduleClipboardIdleState();
    _refreshState();
  }

  /// Resets clipboard inactivity after every successful capture.
  void recordClipboardActivity(DateTime capturedAt) {
    final DateTime value = capturedAt.toUtc();
    if (_latestClipboardActivity == null ||
        value.isAfter(_latestClipboardActivity!)) {
      _latestClipboardActivity = value;
    }
    if (_started) {
      _scheduleClipboardIdleState();
      _refreshState();
    }
  }

  void _syncAgentState() {
    final DateTime? latest = _latestActivityAt();
    if (latest != null &&
        (_latestAgentActivity == null ||
            latest.isAfter(_latestAgentActivity!))) {
      _latestAgentActivity = latest;
    }
    _hasUnseenReminder = _activityController.activities.any(
      (AgentActivity activity) => activity.unseen,
    );
    if (_hasUnseenReminder) {
      _agentRestTimer?.cancel();
      _scheduleReminderNudge();
    } else {
      _reminderNudgeTimer?.cancel();
      _lastReminderNudgeAt = null;
      _scheduleAgentRestState();
    }
    _refreshState();
  }

  DateTime? _latestActivityAt() {
    DateTime? latest;
    for (final AgentActivity activity in _activityController.activities) {
      final DateTime completedAt = activity.completedAt.toUtc();
      if (latest == null || completedAt.isAfter(latest)) {
        latest = completedAt;
      }
    }
    return latest;
  }

  DateTime? _oldestUnseenActivityAt() {
    DateTime? oldest;
    for (final AgentActivity activity in _activityController.activities) {
      if (!activity.unseen) {
        continue;
      }
      final DateTime completedAt = activity.completedAt.toUtc();
      if (oldest == null || completedAt.isBefore(oldest)) {
        oldest = completedAt;
      }
    }
    return oldest;
  }

  void _scheduleReminderNudge() {
    _reminderNudgeTimer?.cancel();
    final DateTime? oldestReminder = _oldestUnseenActivityAt();
    if (!_hasUnseenReminder || oldestReminder == null) {
      return;
    }
    final DateTime now = _now().toUtc();
    final DateTime nextNudge = _lastReminderNudgeAt == null
        ? oldestReminder.add(_reminderDelay)
        : _lastReminderNudgeAt!.add(_reminderRepeatInterval);
    if (nextNudge.isAfter(now)) {
      _reminderNudgeTimer = Timer(
        nextNudge.difference(now) + const Duration(milliseconds: 1),
        _syncAgentState,
      );
      return;
    }
    _lastReminderNudgeAt = now;
    _runCallback(_onReminderNudge);
    _reminderNudgeTimer = Timer(_reminderRepeatInterval, _syncAgentState);
  }

  void _scheduleAgentRestState() {
    _agentRestTimer?.cancel();
    if (_hasUnseenReminder) {
      return;
    }
    final DateTime now = _now().toUtc();
    final DateTime lastActivity = _latestAgentActivity ?? now;
    final DateTime deadline = lastActivity.add(_agentRestDelay);
    if (!deadline.isAfter(now)) {
      return;
    }
    _agentRestTimer = Timer(
      deadline.difference(now) + const Duration(milliseconds: 1),
      _refreshState,
    );
  }

  void _scheduleClipboardIdleState() {
    _clipboardIdleTimer?.cancel();
    final DateTime now = _now().toUtc();
    final DateTime lastActivity = _latestClipboardActivity ?? now;
    final DateTime deadline = lastActivity.add(_clipboardIdleDelay);
    if (!deadline.isAfter(now)) {
      return;
    }
    _clipboardIdleTimer = Timer(
      deadline.difference(now) + const Duration(milliseconds: 1),
      _refreshState,
    );
  }

  void _refreshState() {
    final DateTime now = _now().toUtc();
    final DateTime clipboardActivity = _latestClipboardActivity ?? now;
    final DateTime agentActivity = _latestAgentActivity ?? now;
    final TrayBuddyState next = _hasUnseenReminder
        ? TrayBuddyState.reminder
        : !clipboardActivity.add(_clipboardIdleDelay).isAfter(now)
        ? TrayBuddyState.sleeping
        : !agentActivity.add(_agentRestDelay).isAfter(now)
        ? TrayBuddyState.resting
        : TrayBuddyState.normal;
    if (_announcedState == next) {
      return;
    }
    _announcedState = next;
    _runStateCallback(next);
  }

  void _runStateCallback(TrayBuddyState state) {
    try {
      unawaited(_onStateChanged(state).onError((Object _, StackTrace _) {}));
    } on Object {
      // Mascot visuals are decorative and must never interrupt app state.
    }
  }

  void _runCallback(Future<void> Function() callback) {
    try {
      unawaited(callback().onError((Object _, StackTrace _) {}));
    } on Object {
      // Mascot gestures are decorative and must never interrupt app state.
    }
  }

  void dispose() {
    _reminderNudgeTimer?.cancel();
    _agentRestTimer?.cancel();
    _clipboardIdleTimer?.cancel();
    if (_started) {
      _activityController.removeListener(_syncAgentState);
    }
    _started = false;
  }
}
