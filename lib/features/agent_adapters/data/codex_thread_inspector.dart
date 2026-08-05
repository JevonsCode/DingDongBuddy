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

  Future<bool> isOpenable(String threadId) async {
    final String normalizedId = threadId.trim();
    if (normalizedId.isEmpty) {
      return false;
    }

    CodexAppServerConnection? connection;
    try {
      connection = await connectionFactory.open();
      String? cursor;
      for (int page = 0; page < 64; page += 1) {
        final Map<String, Object?> response = await connection.request(
          'thread/list',
          <String, Object?>{'limit': 200, 'cursor': ?cursor},
        );
        final Object? data = response['data'];
        if (data is List<Object?>) {
          for (final Object? item in data) {
            if (item is! Map<Object?, Object?> || item['id'] != normalizedId) {
              continue;
            }
            return !_isBackgroundThread(item);
          }
        }

        final Object? nextCursor = response['nextCursor'];
        if (nextCursor is! String || nextCursor.trim().isEmpty) {
          return false;
        }
        cursor = nextCursor;
      }
      return false;
    } on Object {
      // Fail closed. The launcher must not create a deep link that is likely
      // to surface a broken Codex recovery screen when metadata is unknown.
      return false;
    } finally {
      await connection?.close();
    }
  }
}

bool _isBackgroundThread(Map<Object?, Object?> thread) {
  return _hasText(thread['parentThreadId']) ||
      _hasText(thread['agentRole']) ||
      _hasText(thread['agentNickname']) ||
      thread['ephemeral'] == true;
}

bool _hasText(Object? value) => value is String && value.trim().isNotEmpty;
