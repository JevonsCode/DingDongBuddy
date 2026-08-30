import 'dart:convert';

import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';

/// Acknowledges the matching reminder when Codex starts or resumes a session.
final class ConversationOpenedHookNotifier {
  ConversationOpenedHookNotifier(this._transport);

  final McpHttpTransport _transport;

  Future<Map<String, Object?>> notify(
    String hookInput, {
    String? sourceOverride,
  }) async {
    final Map<String, Object?> input = _decodeInput(hookInput);
    if (!_isOpenedSession(input)) {
      return const <String, Object?>{'status': 'ignored'};
    }
    final String? conversationId = _firstText(input, const <String>[
      'session_id',
      'sessionId',
      'conversation_id',
      'conversationId',
      'thread_id',
      'threadId',
    ]);
    if (conversationId == null) {
      return const <String, Object?>{'status': 'ignored'};
    }
    final String source = (sourceOverride ?? '').trim().isNotEmpty
        ? sourceOverride!.trim()
        : 'Codex';
    final String? workspacePath = _firstText(input, const <String>[
      'cwd',
      'workspace_path',
      'workspacePath',
    ]);
    return _transport.request(
      method: 'POST',
      path: '/agent/conversation/opened',
      body: <String, Object?>{
        'source': source,
        'conversationId': conversationId,
        'workspacePath': ?workspacePath,
      },
    );
  }
}

bool _isOpenedSession(Map<String, Object?> input) {
  final String eventName = (input['hook_event_name'] as String? ?? '')
      .replaceAll(RegExp(r'[_-]'), '')
      .trim()
      .toLowerCase();
  if (eventName != 'sessionstart') {
    return false;
  }
  final String reason = (input['source'] as String? ?? '').trim().toLowerCase();
  return reason == 'startup' || reason == 'resume';
}

Map<String, Object?> _decodeInput(String input) {
  if (input.trim().isEmpty) {
    return <String, Object?>{};
  }
  try {
    final Object? decoded = jsonDecode(input);
    return decoded is Map<String, Object?> ? decoded : <String, Object?>{};
  } on Object {
    return <String, Object?>{};
  }
}

String? _firstText(Map<String, Object?> input, List<String> keys) {
  for (final String key in keys) {
    final Object? value = input[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}
