import 'dart:async';
import 'dart:math';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/activity/domain/agent_task_run.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;

const int defaultAgentActivityMaxItems = 500;
const int defaultAgentActivityCountHours = 24;
const int maximumAgentActivityCountHours = 24 * 365;

/// The durable activity plus the unique lifecycle event used for notification
/// de-duplication on linked devices.
final class AgentCompletionRecord {
  const AgentCompletionRecord({
    required this.activity,
    required this.notificationId,
  });

  final AgentActivity activity;
  final String notificationId;
}

/// Bounded, durable Agent update feed and recent-count state.
final class ActivityController extends ChangeNotifier {
  ActivityController({
    AgentActivityStore? store,
    String Function()? idGenerator,
    DateTime Function()? now,
    int maxItems = defaultAgentActivityMaxItems,
    int countWindowHours = defaultAgentActivityCountHours,
    bool groupRepeatedAgentSessions = true,
    DingDongLocalizations Function()? localizations,
    this._rememberAcrossRestarts = true,
  }) : _store = store ?? InMemoryAgentActivityStore(),
       _idGenerator = idGenerator ?? _generateId,
       _now = now ?? DateTime.now,
       _localizations =
           localizations ??
           (() => lookupDingDongLocalizations(const Locale('en'))),
       _maxItems = _sanitizeMaxItems(maxItems),
       _countWindowHours = _sanitizeCountHours(countWindowHours),
       _groupRepeatedAgentSessions = true {
    _groupRepeatedAgentSessions = groupRepeatedAgentSessions;
  }

  final AgentActivityStore _store;
  final String Function() _idGenerator;
  final DateTime Function() _now;
  final DingDongLocalizations Function() _localizations;
  List<AgentActivity> _activities = const <AgentActivity>[];
  List<AgentTaskRun> _activeRuns = const <AgentTaskRun>[];
  List<DateTime> _completionTimes = const <DateTime>[];
  int _revealRevision = 0;
  bool _revealActive = false;
  int _maxItems;
  int _countWindowHours;
  bool _groupRepeatedAgentSessions;
  bool _rememberAcrossRestarts;
  bool _loaded = false;
  Timer? _recentCountTimer;

  List<AgentActivity> get activities =>
      List<AgentActivity>.unmodifiable(_activities);

  List<AgentTaskRun> get activeRuns =>
      List<AgentTaskRun>.unmodifiable(_activeRuns);

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
  bool get revealActive => _revealActive;
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

  AgentTaskRun recordTaskStarted({
    required String source,
    required String task,
    required DateTime startedAt,
    String? workspacePath,
    String? repositoryUrl,
    String? conversationId,
  }) {
    final String normalizedSource = _normalizedSource(source);
    final String normalizedTask = task.trim().isEmpty
        ? _localizations().currentTask
        : task.trim();
    final String? normalizedWorkspace = _trimmed(workspacePath);
    final String? normalizedConversationId = _trimmed(conversationId);
    final AgentConversationTarget? target =
        normalizedConversationId == null && normalizedWorkspace == null
        ? null
        : AgentConversationTarget(
            client: AgentClient.fromSource(normalizedSource),
            conversationId: normalizedConversationId,
            workspacePath: normalizedWorkspace,
          );
    final AgentTaskRun run = AgentTaskRun(
      id: _idGenerator(),
      source: normalizedSource,
      task: normalizedTask,
      startedAt: startedAt.toUtc(),
      repositoryUrl: _trimmed(repositoryUrl),
      conversationTarget: target,
    );
    _activeRuns = <AgentTaskRun>[
      run,
      ..._activeRuns.where(
        (AgentTaskRun existing) =>
            !_sameRunningConversation(existing.conversationTarget, target),
      ),
    ].take(50).toList(growable: false);
    notifyListeners();
    return run;
  }

  AgentCompletionRecord record({
    required String source,
    required String message,
    String? detail,
    DateTime? completedAt,
    AgentConversationTarget? conversationTarget,
    AgentNotificationKind notificationKind = AgentNotificationKind.completion,
    ConversationTokenUsage? tokenUsage,
  }) {
    final DateTime resolvedCompletedAt = (completedAt ?? _now()).toUtc();
    final String normalizedSource = _normalizedSource(source);
    final String normalizedMessage = message.trim().isEmpty
        ? 'Task complete'
        : message.trim();
    final String normalizedDetail = detail?.trim().isNotEmpty == true
        ? detail!.trim()
        : normalizedMessage;
    final int runIndex = _matchingRunIndex(
      source: normalizedSource,
      target: conversationTarget,
    );
    final AgentTaskRun? run = runIndex < 0 ? null : _activeRuns[runIndex];
    if (runIndex >= 0) {
      _activeRuns = _activeRuns
          .asMap()
          .entries
          .where((MapEntry<int, AgentTaskRun> entry) => entry.key != runIndex)
          .map((MapEntry<int, AgentTaskRun> entry) => entry.value)
          .toList(growable: false);
    }
    final AgentConversationTarget? resolvedTarget = _completionTarget(
      source: normalizedSource,
      run: run,
      completionTarget: conversationTarget,
    );
    final int repeatedIndex = _groupRepeatedAgentSessions
        ? _conversationIndex(resolvedTarget)
        : -1;
    if (repeatedIndex >= 0) {
      final AgentActivity previous = _activities[repeatedIndex];
      final AgentActivity repeated = previous.repeated(
        source: normalizedSource,
        message: normalizedMessage,
        task: run?.task,
        detail: normalizedDetail,
        startedAt: run?.startedAt,
        completedAt: resolvedCompletedAt,
        conversationTarget: resolvedTarget,
        notificationKind: notificationKind,
        tokenUsage: tokenUsage,
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
      return AgentCompletionRecord(
        activity: repeated,
        notificationId: run?.id ?? _generateId(),
      );
    }
    final AgentActivity activity = AgentActivity(
      id: run?.id ?? _idGenerator(),
      source: normalizedSource,
      message: normalizedMessage,
      task: run?.task,
      detail: normalizedDetail,
      startedAt: run?.startedAt,
      completedAt: resolvedCompletedAt,
      unseen: true,
      notificationKind: notificationKind,
      conversationTarget: resolvedTarget,
      tokenUsage: tokenUsage,
    );
    _activities = <AgentActivity>[activity, ..._activities.take(_maxItems - 1)];
    if (notificationKind == AgentNotificationKind.completion) {
      _completionTimes = <DateTime>[resolvedCompletedAt, ..._completionTimes];
      _trimCompletionTimes();
    }
    _loaded = true;
    _persist();
    _scheduleRecentCountRefresh();
    notifyListeners();
    return AgentCompletionRecord(
      activity: activity,
      notificationId: run?.id ?? activity.id,
    );
  }

  /// Removes a running lifecycle item when its completion is intentionally
  /// filtered, without creating history, unread state, or a completion count.
  bool discardActiveRun({
    required String source,
    required AgentConversationTarget target,
  }) {
    final AgentConversationTarget matchTarget = _targetForSource(
      source: source,
      target: target,
    )!;
    final String? conversationId = _trimmed(matchTarget.conversationId);
    if (conversationId == null) {
      return false;
    }
    final int index = _activeRuns.indexWhere((AgentTaskRun run) {
      final AgentConversationTarget? runTarget = run.conversationTarget;
      return _trimmed(runTarget?.conversationId) == conversationId &&
          runTarget?.client == matchTarget.client;
    });
    if (index < 0) {
      return false;
    }
    _activeRuns = _activeRuns
        .asMap()
        .entries
        .where((MapEntry<int, AgentTaskRun> entry) => entry.key != index)
        .map((MapEntry<int, AgentTaskRun> entry) => entry.value)
        .toList(growable: false);
    notifyListeners();
    return true;
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
    AgentNotificationKind notificationKind = AgentNotificationKind.completion,
    ConversationTokenUsage? tokenUsage,
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
        notificationKind: notificationKind,
        tokenUsage: tokenUsage,
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
      notificationKind: notificationKind,
      tokenUsage: tokenUsage,
      preserveLifecycle: true,
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

  int _matchingRunIndex({
    required String source,
    required AgentConversationTarget? target,
  }) {
    if (_activeRuns.isEmpty) {
      return -1;
    }
    final AgentConversationTarget? matchTarget = _targetForSource(
      source: source,
      target: target,
    );
    final String? conversationId = _trimmed(matchTarget?.conversationId);
    if (conversationId != null) {
      final int exact = _activeRuns.indexWhere(
        (AgentTaskRun run) =>
            _sameConversation(run.conversationTarget, matchTarget),
      );
      if (exact >= 0) {
        return exact;
      }
    }

    final String? workspace = _normalizedPath(target?.workspacePath);
    final List<int> candidates = <int>[
      for (var index = 0; index < _activeRuns.length; index += 1)
        if (workspace == null ||
            _normalizedPath(
                  _activeRuns[index].conversationTarget?.workspacePath,
                ) ==
                workspace)
          index,
    ];
    if (candidates.isEmpty) {
      return -1;
    }
    final String sourceKey = source.trim().toLowerCase();
    final List<int> exactSource = candidates
        .where(
          (int index) =>
              _activeRuns[index].source.trim().toLowerCase() == sourceKey,
        )
        .toList(growable: false);
    if (exactSource.length == 1) {
      return exactSource.single;
    }
    final List<int> compatibleSource = candidates
        .where((int index) {
          final String candidate = _activeRuns[index].source
              .trim()
              .toLowerCase();
          return candidate == sourceKey ||
              candidate == 'agent' ||
              sourceKey == 'agent';
        })
        .toList(growable: false);
    if (compatibleSource.length == 1) {
      return compatibleSource.single;
    }
    return candidates.length == 1 ? candidates.single : -1;
  }

  AgentConversationTarget? _targetForSource({
    required String source,
    required AgentConversationTarget? target,
  }) {
    if (target == null) {
      return null;
    }
    return AgentConversationTarget(
      client: target.client == AgentClient.unknown
          ? AgentClient.fromSource(source)
          : target.client,
      conversationId: target.conversationId,
      workspacePath: target.workspacePath,
    );
  }

  AgentConversationTarget? _completionTarget({
    required String source,
    required AgentTaskRun? run,
    required AgentConversationTarget? completionTarget,
  }) {
    final AgentConversationTarget? startedTarget = run?.conversationTarget;
    final AgentConversationTarget? merged = startedTarget == null
        ? completionTarget
        : completionTarget == null
        ? startedTarget
        : startedTarget.merge(completionTarget);
    if (merged == null) {
      return null;
    }
    final AgentClient sourceClient = AgentClient.fromSource(source);
    return AgentConversationTarget(
      client: merged.client == AgentClient.unknown
          ? sourceClient
          : merged.client,
      conversationId: merged.conversationId,
      workspacePath: merged.workspacePath,
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

  bool _sameRunningConversation(
    AgentConversationTarget? left,
    AgentConversationTarget? right,
  ) {
    if (_sameConversation(left, right)) {
      return true;
    }
    final String? leftConversationId = _trimmed(left?.conversationId);
    final String? rightConversationId = _trimmed(right?.conversationId);
    if (leftConversationId != null && rightConversationId != null) {
      return false;
    }
    final String? leftWorkspace = _normalizedPath(left?.workspacePath);
    final String? rightWorkspace = _normalizedPath(right?.workspacePath);
    if (leftWorkspace == null ||
        rightWorkspace == null ||
        leftWorkspace != rightWorkspace) {
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
    _revealActive = true;
    notifyListeners();
  }

  void markAllSeen() {
    if (unseenCount == 0) {
      _revealActive = false;
      return;
    }
    _activities = _activities
        .map((AgentActivity item) => item.unseen ? item.seen() : item)
        .toList(growable: false);
    _revealActive = false;
    _persist();
    notifyListeners();
  }

  void clear() {
    _recentCountTimer?.cancel();
    _activities = const <AgentActivity>[];
    _activeRuns = const <AgentTaskRun>[];
    _completionTimes = const <DateTime>[];
    _revealActive = false;
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

String _normalizedSource(String value) =>
    value.trim().isEmpty ? 'Agent' : value.trim();

String? _trimmed(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String? _normalizedPath(String? value) => _trimmed(
  value,
)?.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '').toLowerCase();

int _sanitizeMaxItems(int value) => value.clamp(1, 5000);

int _sanitizeCountHours(int value) =>
    value.clamp(1, maximumAgentActivityCountHours);

String _generateId() {
  final Random random = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-'
      '${random.nextInt(1 << 32).toRadixString(36)}';
}
