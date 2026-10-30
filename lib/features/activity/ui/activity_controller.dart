import 'dart:async';
import 'dart:math';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/date_filter_range.dart';
import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/activity/domain/agent_task_run.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;
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
    this.persistHistory = true,
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

  /// Auxiliary engines forward mutations to the host instead of saving a
  /// potentially stale copy of its activity file.
  final bool persistHistory;
  List<AgentActivity> _activities = const <AgentActivity>[];
  List<AgentTaskRun> _activeRuns = const <AgentTaskRun>[];
  List<DateTime> _completionTimes = const <DateTime>[];
  int _recentPageSize = 21;
  int get recentPageSize => _recentPageSize;
  int _revealRevision = 0;
  bool _revealActive = false;
  int _maxItems;
  int _countWindowHours;
  bool _groupRepeatedAgentSessions;
  bool _rememberAcrossRestarts;
  bool _loaded = false;
  int _latestSequence = 0;
  int? _lastViewedSequence;
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
  int get latestSequence => _latestSequence;
  int? get lastViewedSequence => _lastViewedSequence;

  /// Loads the previous session. The primary app passes [resetPreviousSession]
  /// so a user who disabled remembering starts clean after relaunch.
  void load({bool resetPreviousSession = false}) {
    if (resetPreviousSession && !_rememberAcrossRestarts) {
      if (persistHistory) _store.clear();
      _activities = const <AgentActivity>[];
      _completionTimes = const <DateTime>[];
      _latestSequence = 0;
      _lastViewedSequence = null;
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
    ReminderProfile? reminder,
    bool countAsReminder = true,
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
        sequence: ++_latestSequence,
        source: normalizedSource,
        message: normalizedMessage,
        task: run?.task,
        detail: normalizedDetail,
        startedAt: run?.startedAt,
        completedAt: resolvedCompletedAt,
        conversationTarget: resolvedTarget,
        notificationKind: notificationKind,
        tokenUsage: tokenUsage,
        reminder: reminder,
        countAsReminder: countAsReminder,
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
      sequence: ++_latestSequence,
      id: run?.id ?? _idGenerator(),
      source: normalizedSource,
      message: normalizedMessage,
      task: run?.task,
      detail: normalizedDetail,
      startedAt: run?.startedAt,
      completedAt: resolvedCompletedAt,
      unseen: countAsReminder,
      unseenReminderCount: countAsReminder ? 1 : 0,
      notificationKind: notificationKind,
      conversationTarget: resolvedTarget,
      tokenUsage: tokenUsage,
      reminder: reminder,
    );
    _activities = <AgentActivity>[activity, ..._activities];
    _trim();
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

  /// When the running task that a completion would close was observed to
  /// start, without changing any state.
  DateTime? activeRunStartedAt({
    required String source,
    AgentConversationTarget? target,
  }) {
    final int index = _matchingRunIndex(source: source, target: target);
    return index < 0 ? null : _activeRuns[index].startedAt;
  }

  /// Removes a running lifecycle item when its completion is intentionally
  /// filtered, without creating history, unread state, or a completion count.
  bool discardActiveRun({
    required String source,
    AgentConversationTarget? target,
  }) {
    final AgentConversationTarget? matchTarget = _targetForSource(
      source: source,
      target: target,
    );
    final String? conversationId = _trimmed(matchTarget?.conversationId);
    final String? workspace = _normalizedPath(matchTarget?.workspacePath);
    final String sourceKey = _normalizedSource(source).toLowerCase();
    final List<AgentTaskRun> matches = _activeRuns
        .where((AgentTaskRun run) {
          final AgentConversationTarget? runTarget = run.conversationTarget;
          if (conversationId != null) {
            return _trimmed(runTarget?.conversationId) == conversationId &&
                runTarget?.client == matchTarget?.client;
          }
          return run.source.trim().toLowerCase() == sourceKey &&
              (matchTarget == null ||
                  matchTarget.client == AgentClient.unknown ||
                  AgentClient.fromSource(run.source) == matchTarget.client) &&
              (workspace == null ||
                  _normalizedPath(runTarget?.workspacePath) == workspace);
        })
        .toList(growable: false);
    // A hook without a conversation id must never guess between active tasks.
    if (matches.length != 1) {
      return false;
    }
    _activeRuns = _activeRuns
        .where((AgentTaskRun run) => !identical(run, matches.single))
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
    ReminderProfile? reminder,
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
        reminder: reminder,
        countAsReminder: false,
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
    final previous = _activities[index];
    final AgentActivity repeated = previous.repeated(
      source: normalizedSource,
      message: normalizedMessage,
      completedAt: completedAt,
      conversationTarget: target,
      notificationKind: notificationKind,
      tokenUsage: tokenUsage,
      reminder: reminder,
      preserveLifecycle: true,
      countAsReminder: false,
    );
    _activities = <AgentActivity>[
      previous.opened ? repeated.withOpened() : repeated,
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
        if ((conversationId == null ||
                _trimmed(
                      _activeRuns[index].conversationTarget?.conversationId,
                    ) ==
                    null) &&
            (workspace == null ||
                _normalizedPath(
                      _activeRuns[index].conversationTarget?.workspacePath,
                    ) ==
                    workspace))
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
    return -1;
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
      hostSessionId: target.hostSessionId,
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
      hostSessionId: merged.hostSessionId,
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

  /// Marks only the activities that a trusted linked device has displayed.
  ///
  /// Unknown and already-seen ids are ignored so delayed mobile receipts
  /// cannot affect newer activity.
  /// Returns the number of reminders to acknowledge in the desktop tray,
  /// including unread repeats grouped into one activity.
  int markSeen(Iterable<String> activityIds) {
    final Set<String> ids = activityIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) return 0;

    var acknowledged = 0;
    _activities = _activities
        .map((AgentActivity item) {
          if (!item.unseen || !ids.contains(item.id)) return item;
          acknowledged += item.unseenReminderCount;
          return item.seen();
        })
        .toList(growable: false);
    if (acknowledged == 0) return 0;

    if (unseenCount == 0) {
      _revealActive = false;
    }
    _persist();
    notifyListeners();
    return acknowledged;
  }

  /// Marks the unseen activities for one Agent conversation as seen.
  ///
  /// The returned count lets the desktop shell reduce its independent durable
  /// unread badge by exactly the number of reminders that were acknowledged.
  int markConversationSeen(AgentConversationTarget target) {
    final String? conversationId = _trimmed(target.conversationId);
    if (conversationId == null) {
      return 0;
    }
    final AgentConversationTarget normalizedTarget = AgentConversationTarget(
      client: target.client,
      conversationId: conversationId,
      workspacePath: _trimmed(target.workspacePath),
    );
    return markSeen(
      _activities
          .where(
            (AgentActivity item) =>
                _sameConversation(item.conversationTarget, normalizedTarget),
          )
          .map((AgentActivity item) => item.id),
    );
  }

  List<String> get sources =>
      (_activities.map((e) => e.source).toSet().toList()..sort());

  /// Advances the durable visit checkpoint without changing a mounted feed's
  /// captured boundary or acknowledging individual conversation openings.
  void markFeedViewed(int throughSequence) {
    if (!_loaded ||
        throughSequence < 0 ||
        throughSequence > _latestSequence ||
        (_lastViewedSequence != null &&
            throughSequence <= _lastViewedSequence!)) {
      return;
    }
    _lastViewedSequence = throughSequence;
    _persist();
    notifyListeners();
  }

  /// A launch acknowledges only the revision captured before it started.
  void markOpened(AgentActivity activity) {
    final index = _activities.indexWhere((item) => item.id == activity.id);
    if (index < 0) return;
    final current = _activities[index];
    if (current.opened || current.sequence != activity.sequence) return;
    _activities = List.of(_activities)..[index] = current.withOpened();
    _persist();
    notifyListeners();
  }

  void setRecentPageSize(int size) {
    final next = size.clamp(1, 500);
    if (_recentPageSize == next) return;
    _recentPageSize = next;
    _loaded = true;
    _persist();
    notifyListeners();
  }

  void setPinned(String id, bool pinned) {
    final index = _activities.indexWhere((e) => e.id == id);
    if (index < 0 || _activities[index].pinned == pinned) return;
    _activities = List.of(_activities)
      ..[index] = _activities[index].withPinned(pinned);
    _persist();
    notifyListeners();
  }

  /// Asynchronous local pages: filtering and pin order happen before slicing.
  /// The widget only builds visible rows from the requested pages.
  Future<AgentActivityPage> queryPage({
    int offset = 0,
    int? limit,
    Set<String>? sources,
    DateTimeRange? range,
    int? newerThanSequence,
  }) async {
    final matches =
        _activities
            .where(
              (e) =>
                  (sources == null || sources.contains(e.source)) &&
                  dateWithinFilter(e.completedAt, range),
            )
            .toList()
          ..sort((a, b) {
            if (newerThanSequence != null) {
              final aNew = a.sequence > newerThanSequence;
              final bNew = b.sequence > newerThanSequence;
              if (aNew != bNew) return aNew ? -1 : 1;
            }
            return _feedOrder(a, b);
          });
    final start = offset.clamp(0, matches.length);
    return AgentActivityPage(
      items: List.unmodifiable(
        matches
            .skip(start)
            .take((limit ?? _recentPageSize).clamp(1, _maxItems)),
      ),
      total: matches.length,
    );
  }

  static int _feedOrder(AgentActivity a, AgentActivity b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    final time = b.completedAt.compareTo(a.completedAt);
    return time == 0 ? a.id.compareTo(b.id) : time;
  }

  void clear() {
    _recentCountTimer?.cancel();
    _activities = const <AgentActivity>[];
    _activeRuns = const <AgentTaskRun>[];
    _completionTimes = const <DateTime>[];
    _latestSequence = 0;
    _lastViewedSequence = null;
    _revealActive = false;
    _loaded = true;
    if (persistHistory) _store.clear();
    notifyListeners();
  }

  void _replaceWith(AgentActivityHistory history) {
    _lastViewedSequence = history.lastViewedSequence;
    _latestSequence = history.activities.fold(
      max(history.latestSequence, _lastViewedSequence ?? 0),
      (sequence, activity) => max(sequence, activity.sequence),
    );
    _recentPageSize = history.recentPageSize.clamp(1, 500);
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
      // Keep pins when the bounded local history evicts its oldest items.
      final ranked = [
        ..._activities.where((e) => e.pinned),
        ..._activities.where((e) => !e.pinned),
      ];
      final retained = ranked.take(_maxItems).map((e) => e.id).toSet();
      _activities = _activities
          .where((e) => retained.contains(e.id))
          .toList(growable: false);
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
    if (!_loaded || !persistHistory) {
      return;
    }
    _store.save(
      AgentActivityHistory(
        latestSequence: _latestSequence,
        lastViewedSequence: _lastViewedSequence,
        recentPageSize: _recentPageSize,
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

final class AgentActivityPage {
  const AgentActivityPage({required this.items, required this.total});
  final List<AgentActivity> items;
  final int total;
}
