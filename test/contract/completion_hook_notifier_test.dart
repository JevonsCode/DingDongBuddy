import 'dart:convert';

import 'package:dingdong/features/agent_api/data/completion_hook_notifier.dart';
import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Stop hook sends one bounded completion notification', () async {
    final _RecordingTransport transport = _RecordingTransport();

    await CompletionHookNotifier(transport).notify(
      jsonEncode(<String, Object?>{
        'hook_event_name': 'Stop',
        'session_id': 'session-1',
      }),
    );

    expect(transport.method, 'POST');
    expect(transport.path, '/ding');
    expect(transport.body, <String, Object?>{
      'message': 'Codex 已完成本轮任务',
      'source': 'Codex',
      'flashCount': 4,
      'fallback': true,
    });
  });

  test('hook input can name another compatible Agent', () async {
    final _RecordingTransport transport = _RecordingTransport();

    await CompletionHookNotifier(
      transport,
    ).notify('{"agent_name":"Claude Code"}');

    expect(transport.body?['message'], 'Claude Code 已完成本轮任务');
    expect(transport.body?['source'], 'Claude Code');
  });
}

final class _RecordingTransport implements McpHttpTransport {
  String? method;
  String? path;
  Map<String, Object?>? body;

  @override
  Future<Map<String, Object?>> request({
    required String method,
    required String path,
    Map<String, String> query = const <String, String>{},
    Map<String, Object?>? body,
  }) async {
    this.method = method;
    this.path = path;
    this.body = body;
    return <String, Object?>{'status': 'triggered'};
  }
}
