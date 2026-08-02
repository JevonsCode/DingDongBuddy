import 'dart:async';
import 'dart:math';

import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:flutter/foundation.dart';

const int defaultAgentActivityMaxItems = 500;
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
    bool groupRepeatedAgentSessions = true,
    this._rememberAcrossRestarts = true,
  }) : _store = store ?? InMemoryAgentActivityStore(),
       _idGenerator = idGenerator ?? _generateId,
       _now = now ?? DateTime.now,
       _maxItems = _sanitizeMaxItems(maxItems),
       _countWindowHours = _sanitizeCountHours(countWindowHours),
       _groupRepeatedAgentSessions = true {
    _groupRepeatedAgentSessions = groupRepeatedAgentSessions;
  }

  final AgentActivityStore _store;
  final String Function() _idGenerator;
  final DateTime Function() _now;
  List<AgentActivity> _activities = const <AgentActivity>[];
  List<DateTime> _completionTimes = const <DateTime>[];
  int _revealRevision = 0;
  int _maxItems;
  int _countWindowHours;
  bool _groupRepeatedAgentSessions;
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
  bool get groupRepeatedAgentSessions => _groupRepeatedAgentSessions;

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
    bool? groupRepeatedAgentSessions,
  }) {
    final int sanitizedMaxItems = _sanitizeMaxItems(maxItems);
    final int sanitizedCountHours = _sanitizeCountHours(countWindowHours);
    final bool resolvedGroupRepeatedAgentSessions =
        groupRepeatedAgentSessions ?? _groupRepeatedAgentSessions;
    final bool changed =
        _rememberAcrossRestarts != rememberAcrossRestarts ||
        _maxItems != sanitizedMaxItems ||
        _countWindowHours != sanitizedCountHours ||
        _groupRepeatedAgentSessions != resolvedGroupRepeatedAgentSessions;
    if (!changed) {
      return;
    }
    _rememberAcrossRestarts = rememberAcrossRestarts;
    _maxItems = sanitizedMaxItems;
    _countWindowHours = sanitizedCountHours;
    _groupRepeatedAgentSessions = resolvedGroupRepeatedAgentSessions;
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
    final String normalizedSource = source.trim().isEmpty
        ? 'Agent'
        : source.trim();
    final String normalizedMessage = message.trim().isEmpty
        ? 'Task complete'
        : message.trim();
    final int repeatedIndex = _groupRepeatedAgentSessions
        ? _conversationIndex(conversationTarget)
        : -1;
    if (repeatedIndex >= 0) {
      final AgentActivity previous = _activities[repeatedIndex];
      final AgentActivity repeated = previous.repeated(
        source: normalizedSource,
        message: normalizedMessage,
        completedAt: completedAt,
        conversationTarget: conversationTarget,
      );
      _activities = <AgentActivity>[
        repeated,
        ..._activities
            .asMap()
            .entries
            .where(
              (MapEntry<int, AgentActivity> entry) =>
                  entry.key != repeatedIndex,
            )
            .map((MapEntry<int, AgentActivity> entry) => entry.value),
      ];
      _loaded = true;
      _persist();
      notifyListeners();
      return;
    }
    final AgentActivity activity = AgentActivity(
      id: _idGenerator(),
      source: normalizedSource,
      message: normalizedMessage,
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

  /// Records a completion hook that was deduplicated at the transport layer.
  ///
  /// When grouping is enabled, it updates the matching conversation item
  /// without adding a new recent completion timestamp. If the primary
  /// notification did not have a conversation target yet, the source-only
  /// item is enriched here. When grouping is disabled, it records an
  /// independent item instead.
  void recordRepeat({
    required String source,
    required String message,
    AgentConversationTarget? target,
  }) {
    final String normalizedSource = source.trim().isEmpty
        ? 'Agent'
        : source.trim();
    final String normalizedMessage = message.trim().isEmpty
        ? 'Task complete'
        : message.trim();
    if (!_groupRepeatedAgentSessions) {
      record(
        source: normalizedSource,
        message: normalizedMessage,
        conversationTarget: target,
      );
      return;
    }
    if (target == null) {
      return;
    }
    final DateTime completedAt = _now().toUtc();
    int index = _conversationIndex(target);
    if (index < 0) {
      final String normalizedSourceKey = normalizedSource.toLowerCase();
      index = _activities.indexWhere(
        (AgentActivity item) =>
            item.conversationTarget == null &&
            item.source.trim().toLowerCase() == normalizedSourceKey,
      );
    }
    if (index < 0) {
      return;
    }
    final AgentActivity repeated = _activities[index].repeated(
      source: normalizedSource,
      message: normalizedMessage,
      completedAt: completedAt,
      conversationTarget: target,
    );
    _activities = <AgentActivity>[
      repeated,
      ..._activities
          .asMap()
          .entries
          .where((MapEntry<int, AgentActivity> entry) => entry.key != index)
          .map((MapEntry<int, AgentActivity> entry) => entry.value),
    ];
    _loaded = true;
    _persist();
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

  int _conversationIndex(AgentConversationTarget? target) {
    final String? conversationId = target?.conversationId;
    if (conversationId == null) {
      return -1;
    }
    return _activities.indexWhere(
      (AgentActivity item) =>
          _sameConversation(item.conversationTarget, target),
    );
  }

  bool _sameConversation(
    AgentConversationTarget? left,
    AgentConversationTarget? right,
  ) {
    final String? leftId = left?.conversationId;
    final String? rightId = right?.conversationId;
    if (leftId == null || rightId == null || leftId != rightId) {
      return false;
    }
    return left!.client == AgentClient.unknown ||
        right!.client == AgentClient.unknown ||
        left.client == right.client;
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

  void clear() {
    _recentCountTimer?.cancel();
    _activities = const <AgentActivity>[];
    _completionTimes = const <DateTime>[];
    _loaded = true;
    _store.clear();
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
