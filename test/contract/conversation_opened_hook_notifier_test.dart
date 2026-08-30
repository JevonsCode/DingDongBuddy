import 'dart:convert';

import 'package:dingdong/features/agent_api/data/conversation_opened_hook_notifier.dart';
import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Codex SessionStart startup acknowledges the opened conversation',
    () async {
      final _RecordingTransport transport = _RecordingTransport();

      await ConversationOpenedHookNotifier(transport).notify(
        jsonEncode(<String, Object?>{
          'hook_event_name': 'SessionStart',
          'source': 'startup',
          'session_id': 'thread-1',
          'cwd': '/workspace/dingdong',
        }),
        sourceOverride: 'Codex',
      );

      expect(transport.method, 'POST');
      expect(transport.path, '/agent/conversation/opened');
      expect(transport.body, <String, Object?>{
        'source': 'Codex',
        'conversationId': 'thread-1',
        'workspacePath': '/workspace/dingdong',
      });
    },
  );

  test(
    'Codex SessionStart resume also acknowledges the conversation',
    () async {
      final _RecordingTransport transport = _RecordingTransport();

      await ConversationOpenedHookNotifier(transport).notify(
        jsonEncode(<String, Object?>{
          'hook_event_name': 'SessionStart',
          'source': 'resume',
          'session_id': 'thread-2',
        }),
      );

      expect(transport.body?['source'], 'Codex');
      expect(transport.body?['conversationId'], 'thread-2');
    },
  );

  test(
    'clear, compact, malformed, and unidentified events are ignored',
    () async {
      final _RecordingTransport transport = _RecordingTransport();
      final ConversationOpenedHookNotifier notifier =
          ConversationOpenedHookNotifier(transport);

      for (final String input in <String>[
        jsonEncode(<String, Object?>{
          'hook_event_name': 'SessionStart',
          'source': 'clear',
          'session_id': 'thread-1',
        }),
        jsonEncode(<String, Object?>{
          'hook_event_name': 'SessionStart',
          'source': 'compact',
          'session_id': 'thread-1',
        }),
        jsonEncode(<String, Object?>{
          'hook_event_name': 'Stop',
          'source': 'resume',
          'session_id': 'thread-1',
        }),
        jsonEncode(<String, Object?>{
          'hook_event_name': 'SessionStart',
          'source': 'resume',
        }),
        '{not-json',
      ]) {
        expect(await notifier.notify(input), <String, Object?>{
          'status': 'ignored',
        });
      }

      expect(transport.requestCount, 0);
    },
  );
}

final class _RecordingTransport implements McpHttpTransport {
  String? method;
  String? path;
  Map<String, Object?>? body;
  int requestCount = 0;

  @override
  Future<Map<String, Object?>> request({
    required String method,
    required String path,
    Map<String, String> query = const <String, String>{},
    Map<String, Object?>? body,
  }) async {
    requestCount += 1;
    this.method = method;
    this.path = path;
    this.body = body;
    return <String, Object?>{'status': 'acknowledged'};
  }
}
