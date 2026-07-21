import 'dart:async';
import 'dart:math';

import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:flutter/foundation.dart';

const int defaultAgentActivityMaxItems = 200;
const int defaultAgentActivityCountHours = 24;
const int maximumAgentActivityCountHours = 24 * 365;

/// Bounded, durable Agent completion feed and recent-count state.
final class ActivityController extends ChangeNotifier {
  ActivityController({
    AgentActivityStore? store,
    String Function()? idGenerator,
    DateTime Function()? now,
    int maxItems = defaultAgentActivityMaxItems,
    int countWindowHours = defaultAgentActivityCountHours,
    this._rememberAcrossRestarts = true,
  }) : _store = store ?? InMemoryAgentActivityStore(),
       _idGenerator = idGenerator ?? _generateId,
       _now = now ?? DateTime.now,
       _maxItems = _sanitizeMaxItems(maxItems),
       _countWindowHours = _sanitizeCountHours(countWindowHours);

  final AgentActivityStore _store;
  final String Function() _idGenerator;
  final DateTime Function() _now;
  List<AgentActivity> _activities = const <AgentActivity>[];
  List<DateTime> _completionTimes = const <DateTime>[];
  int _revealRevision = 0;
  int _maxItems;
  int _countWindowHours;
  bool _rememberAcrossRestarts;
  bool _loaded = false;
  Timer? _recentCountTimer;

  List<AgentActivity> get activities =>
      List<AgentActivity>.unmodifiable(_activities);

  int get unseenCount =>
      _activities.where((AgentActivity item) => item.unseen).length;

  int get recentCount {
    final DateTime cutoff = _now().toUtc().subtract(
      Duration(hours: _countWindowHours),
    );
    return _completionTimes
        .where((DateTime value) => !value.isBefore(cutoff))
        .length;
  }

  int get revealRevision => _revealRevision;
  int get maxItems => _maxItems;
  int get countWindowHours => _countWindowHours;
  bool get rememberAcrossRestarts => _rememberAcrossRestarts;

  /// Loads the previous session. The primary app passes [resetPreviousSession]
  /// so a user who disabled remembering starts clean after relaunch.
  void load({bool resetPreviousSession = false}) {
    if (resetPreviousSession && !_rememberAcrossRestarts) {
      _store.clear();
      _activities = const <AgentActivity>[];
      _completionTimes = const <DateTime>[];
    } else {
      _replaceWith(_store.load());
    }
    _loaded = true;
    _trim();
    _persist();
    _scheduleRecentCountRefresh();
    notifyListeners();
  }

  /// Re-reads the shared file without applying session-reset behavior.
  void reload() {
    _replaceWith(_store.load());
    _loaded = true;
    _trim();
    _scheduleRecentCountRefresh();
    notifyListeners();
  }

  void configure({
    required bool rememberAcrossRestarts,
    required int maxItems,
    required int countWindowHours,
  }) {
    final int sanitizedMaxItems = _sanitizeMaxItems(maxItems);
    final int sanitizedCountHours = _sanitizeCountHours(countWindowHours);
    final bool changed =
        _rememberAcrossRestarts != rememberAcrossRestarts ||
        _maxItems != sanitizedMaxItems ||
        _countWindowHours != sanitizedCountHours;
    if (!changed) {
      return;
    }
    _rememberAcrossRestarts = rememberAcrossRestarts;
    _maxItems = sanitizedMaxItems;
    _countWindowHours = sanitizedCountHours;
    _trim();
    if (_loaded) {
      _persist();
    }
    _scheduleRecentCountRefresh();
    notifyListeners();
  }

  void record({
    required String source,
    required String message,
    AgentConversationTarget? conversationTarget,
  }) {
    final DateTime completedAt = _now().toUtc();
    final AgentActivity activity = AgentActivity(
      id: _idGenerator(),
      source: source.trim().isEmpty ? 'Agent' : source.trim(),
      message: message.trim().isEmpty ? 'Task complete' : message.trim(),
      completedAt: completedAt,
      unseen: true,
      conversationTarget: conversationTarget,
    );
    _activities = <AgentActivity>[activity, ..._activities.take(_maxItems - 1)];
    _completionTimes = <DateTime>[completedAt, ..._completionTimes];
    _trimCompletionTimes();
    _loaded = true;
    _persist();
    _scheduleRecentCountRefresh();
    notifyListeners();
  }

  /// Enriches the newest matching item when a native completion hook arrives
  /// after an MCP notification that was already shown and de-duplicated.
  void attachConversationTarget({
    required String source,
    required AgentConversationTarget target,
  }) {
    final String normalizedSource = source.trim().toLowerCase();
    final int index = _activities.indexWhere(
      (AgentActivity item) =>
          item.source.trim().toLowerCase() == normalizedSource,
    );
    if (index < 0) {
      return;
    }
    final List<AgentActivity> updated = List<AgentActivity>.of(_activities);
    updated[index] = updated[index].withConversationTarget(target);
    _activities = updated;
    _persist();
    notifyListeners();
  }

  void requestReveal() {
    if (unseenCount == 0) {
      return;
    }
    _revealRevision += 1;
    notifyListeners();
  }

  void markAllSeen() {
    if (unseenCount == 0) {
      return;
    }
    _activities = _activities
        .map((AgentActivity item) => item.unseen ? item.seen() : item)
        .toList(growable: false);
    _persist();
    notifyListeners();
  }

  void _replaceWith(AgentActivityHistory history) {
    _activities = List<AgentActivity>.of(history.activities)
      ..sort(
        (AgentActivity a, AgentActivity b) =>
            b.completedAt.compareTo(a.completedAt),
      );
    _completionTimes = List<DateTime>.of(
      history.completionTimes.isEmpty && history.activities.isNotEmpty
          ? history.activities.map(
              (AgentActivity item) => item.completedAt.toUtc(),
            )
          : history.completionTimes.map((DateTime value) => value.toUtc()),
    );
  }

  void _trim() {
    if (_activities.length > _maxItems) {
      _activities = _activities.take(_maxItems).toList(growable: false);
    }
    _trimCompletionTimes();
  }

  void _trimCompletionTimes() {
    final DateTime oldest = _now().toUtc().subtract(
      const Duration(hours: maximumAgentActivityCountHours),
    );
    _completionTimes = _completionTimes
        .where((DateTime value) => !value.isBefore(oldest))
        .toList(growable: false);
  }

  void _persist() {
    if (!_loaded) {
      return;
    }
    _store.save(
      AgentActivityHistory(
        activities: _activities,
        completionTimes: _completionTimes,
      ),
    );
  }

  void _scheduleRecentCountRefresh() {
    _recentCountTimer?.cancel();
    if (_completionTimes.isEmpty) {
      return;
    }
    final DateTime now = _now().toUtc();
    final Duration window = Duration(hours: _countWindowHours);
    DateTime? nextExpiry;
    for (final DateTime completedAt in _completionTimes) {
      final DateTime expiry = completedAt.add(window);
      if (expiry.isAfter(now) &&
          (nextExpiry == null || expiry.isBefore(nextExpiry))) {
        nextExpiry = expiry;
      }
    }
    if (nextExpiry == null) {
      return;
    }
    _recentCountTimer = Timer(
      nextExpiry.difference(now) + const Duration(milliseconds: 1),
      () {
        notifyListeners();
        _scheduleRecentCountRefresh();
      },
    );
  }

  @override
  void dispose() {
    _recentCountTimer?.cancel();
    super.dispose();
  }
}

int _sanitizeMaxItems(int value) => value.clamp(1, 5000);

int _sanitizeCountHours(int value) =>
    value.clamp(1, maximumAgentActivityCountHours);

String _generateId() {
  final Random random = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${random.nextInt(1 << 32).toRadixString(36)}';
}
