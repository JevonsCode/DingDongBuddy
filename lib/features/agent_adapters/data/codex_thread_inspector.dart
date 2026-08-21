import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/agent_adapters/data/codex_completion_hook_gateway.dart';

/// Read-only Codex thread metadata used before opening a saved conversation.
///
/// Codex exposes subagent ancestry through [parentThreadId] and, for
/// AgentControl-created workers, through [agentRole]/[agentNickname]. A
/// missing thread is also treated as non-openable: opening its deep link only
/// produces Codex's "no rollout found" error.
final class CodexThreadInspector {
  CodexThreadInspector({required this.connectionFactory});

  final CodexAppServerConnectionFactory connectionFactory;
  final Map<String, CodexThreadInspection> _threadReadCache =
      <String, CodexThreadInspection>{};
  final Map<String, Future<CodexThreadInspection>> _threadReadRequests =
      <String, Future<CodexThreadInspection>>{};

  /// Reads one exact Codex thread, including background workers that are
  /// intentionally absent from the default `thread/list` result.
  ///
  /// Thread identity metadata is stable once Codex can read the thread, so
  /// successful results are cached. Concurrent reads for the same id also
  /// share one App Server request. Unavailable or malformed results are not
  /// cached, allowing a later request to recover.
  Future<CodexThreadInspection> inspectThreadId(String threadId) async {
    final String normalizedId = threadId.trim();
    if (normalizedId.isEmpty) {
      return const CodexThreadInspection.unavailable();
    }

    final CodexThreadInspection? cached = _threadReadCache[normalizedId];
    if (cached != null) {
      return cached;
    }
    final Future<CodexThreadInspection>? pending =
        _threadReadRequests[normalizedId];
    if (pending != null) {
      return pending;
    }

    final Future<CodexThreadInspection> request = _readThread(normalizedId);
    _threadReadRequests[normalizedId] = request;
    try {
      final CodexThreadInspection result = await request;
      if (result.exists) {
        _threadReadCache[normalizedId] = result;
      }
      return result;
    } finally {
      if (identical(_threadReadRequests[normalizedId], request)) {
        _threadReadRequests.removeWhere(
          (String id, Future<CodexThreadInspection> value) =>
              id == normalizedId && identical(value, request),
        );
      }
    }
  }

  Future<bool> isOpenable(String threadId) async {
    final String normalizedId = threadId.trim();
    if (normalizedId.isEmpty) {
      return false;
    }

    final AgentConversationPreflightResult result = await inspectThreadIds(
      <String>[normalizedId],
    );
    return result.openableConversationIds.contains(normalizedId);
  }

  Future<Set<String>> openableThreadIds(Iterable<String> threadIds) async {
    final AgentConversationPreflightResult result = await inspectThreadIds(
      threadIds,
    );
    return result.openableConversationIds;
  }

  Future<AgentConversationPreflightResult> inspectThreadIds(
    Iterable<String> threadIds,
  ) async {
    final Set<String> requestedIds = threadIds
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toSet();
    if (requestedIds.isEmpty) {
      return const AgentConversationPreflightResult();
    }

    CodexAppServerConnection? connection;
    try {
      connection = await connectionFactory.open();
      final Set<String> remaining = <String>{...requestedIds};
      final Set<String> openable = <String>{};
      final Set<String> subagents = <String>{};
      String? cursor;
      for (int page = 0; page < 64; page += 1) {
        final Map<String, Object?> response = await connection.request(
          'thread/list',
          <String, Object?>{'limit': 200, 'cursor': ?cursor},
        );
        final Object? data = response['data'];
        if (data is List<Object?>) {
          for (final Object? item in data) {
            if (item is! Map<Object?, Object?>) {
              continue;
            }
            final Object? rawId = item['id'];
            if (rawId is! String || !remaining.remove(rawId)) {
              continue;
            }
            if (_isBackgroundThread(item)) {
              subagents.add(rawId);
            } else {
              openable.add(rawId);
            }
          }
        }

        if (remaining.isEmpty) {
          return AgentConversationPreflightResult(
            openableConversationIds: openable,
            subagentConversationIds: subagents,
          );
        }

        final Object? nextCursor = response['nextCursor'];
        if (nextCursor is! String || nextCursor.trim().isEmpty) {
          return AgentConversationPreflightResult(
            openableConversationIds: openable,
            subagentConversationIds: subagents,
          );
        }
        cursor = nextCursor;
      }
      return AgentConversationPreflightResult(
        openableConversationIds: openable,
        subagentConversationIds: subagents,
      );
    } on Object {
      // Fail closed. The launcher must not create a deep link that is likely
      // to surface a broken Codex recovery screen when metadata is unknown.
      return const AgentConversationPreflightResult();
    } finally {
      await connection?.close();
    }
  }

  Future<CodexThreadInspection> _readThread(String threadId) async {
    CodexAppServerConnection? connection;
    try {
      connection = await connectionFactory.open();
      final Map<String, Object?> response = await connection.request(
        'thread/read',
        <String, Object?>{'threadId': threadId, 'includeTurns': false},
      );
      final Map<Object?, Object?>? thread = _threadReadPayload(response);
      if (thread == null) {
        return const CodexThreadInspection.unavailable();
      }
      final Object? rawId = thread['id'];
      if (rawId != null && (rawId is! String || rawId.trim() != threadId)) {
        return const CodexThreadInspection.unavailable();
      }
      return CodexThreadInspection(
        threadId: threadId,
        exists: true,
        isSubagent: _isBackgroundThread(thread),
        isRealtimeVoice: _isRealtimeVoiceThread(thread),
      );
    } on CodexAppServerProtocolException catch (error) {
      if (_isNonPersistedThreadError(error)) {
        // Ephemeral Codex jobs disappear from a fresh App Server as soon as
        // they stop. Treat that exact outcome as background activity so
        // ambient suggestions and other internal jobs do not become ordinary
        // completion reminders. Other lookup failures remain fail-open below.
        return CodexThreadInspection.nonPersisted(threadId);
      }
      return const CodexThreadInspection.unavailable();
    } on Object {
      // Fail open for notification delivery. Unknown metadata must not hide a
      // user-thread reminder, and failures remain retryable because they are
      // not placed in the successful-read cache.
      return const CodexThreadInspection.unavailable();
    } finally {
      await connection?.close();
    }
  }
}

/// Result of an exact Codex `thread/read` lookup.
final class CodexThreadInspection {
  const CodexThreadInspection({
    required this.threadId,
    required this.exists,
    required this.isSubagent,
    required this.isRealtimeVoice,
  });

  const CodexThreadInspection.unavailable()
    : threadId = '',
      exists = false,
      isSubagent = false,
      isRealtimeVoice = false;

  const CodexThreadInspection.nonPersisted(this.threadId)
    : exists = false,
      isSubagent = true,
      isRealtimeVoice = false;

  final String threadId;
  final bool exists;
  final bool isSubagent;
  final bool isRealtimeVoice;

  bool get isOpenable => exists && !isSubagent;
}

Map<Object?, Object?>? _threadReadPayload(Map<String, Object?> response) {
  final Object? wrapped = response['thread'];
  if (wrapped is Map<Object?, Object?> && wrapped.isNotEmpty) {
    return wrapped;
  }
  if (response['id'] is String) {
    return response;
  }
  return null;
}

bool _isBackgroundThread(Map<Object?, Object?> thread) {
  return _hasText(thread['parentThreadId']) ||
      _hasText(thread['agentRole']) ||
      _hasText(thread['agentNickname']) ||
      thread['ephemeral'] == true ||
      _isSubagentThreadSource(thread['threadSource']);
}

bool _isRealtimeVoiceThread(Map<Object?, Object?> thread) {
  final Object? preview = thread['preview'];
  if (preview is! String) {
    return false;
  }
  return preview.trimLeft().toLowerCase().startsWith('<realtime_delegation>');
}

bool _hasText(Object? value) => value is String && value.trim().isNotEmpty;

bool _isSubagentThreadSource(Object? value) =>
    value is String && value.trim().toLowerCase().startsWith('subagent');

bool _isNonPersistedThreadError(CodexAppServerProtocolException error) =>
    error.message.trimLeft().toLowerCase().startsWith('thread not loaded:');
