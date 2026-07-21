import 'dart:convert';
import 'dart:io';

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
      'conversationId': 'session-1',
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

  test('hook command source overrides client payload defaults', () async {
    final _RecordingTransport transport = _RecordingTransport();

    await CompletionHookNotifier(transport).notify(
      '{"agent_name":"Codex","prompt_response":"已完成 Gemini 配置。"}',
      sourceOverride: 'Gemini CLI',
    );

    expect(transport.body?['message'], '已完成 Gemini 配置。');
    expect(transport.body?['source'], 'Gemini CLI');
  });

  test('Cursor final response text becomes the notification summary', () async {
    final _RecordingTransport transport = _RecordingTransport();

    await CompletionHookNotifier(transport).notify(
      '{"hook_event_name":"afterAgentResponse","text":"已经修复构建流程。\\n测试全部通过。"}',
      sourceOverride: 'Cursor',
    );

    expect(transport.body?['message'], '已经修复构建流程。');
    expect(transport.body?['source'], 'Cursor');
  });

  test('Kiro Stop hook forwards resumable session context', () async {
    final _RecordingTransport transport = _RecordingTransport();

    await CompletionHookNotifier(transport).notify(
      jsonEncode(<String, Object?>{
        'hook_event_name': 'stop',
        'session_id': 'kiro-session-1',
        'cwd': '/workspace/kiro',
        'assistant_response': '已经完成 Kiro 接入。\n测试通过。',
      }),
      sourceOverride: 'Kiro',
    );

    expect(transport.body?['message'], '已经完成 Kiro 接入。');
    expect(transport.body?['conversationId'], 'kiro-session-1');
    expect(transport.body?['workspacePath'], '/workspace/kiro');
  });

  test('hook uses a direct final message as a one-line summary', () async {
    final _RecordingTransport transport = _RecordingTransport();

    await CompletionHookNotifier(transport).notify(
      jsonEncode(<String, Object?>{
        'last_assistant_message': '已经完成资源同步并安装到本机：\n\n- 全量测试通过\n- 应用正在运行',
      }),
    );

    expect(transport.body?['message'], '已经完成资源同步并安装到本机');
  });

  test(
    'Codex Stop hook extracts the final answer from its transcript',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-completion-hook-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final File transcript = File('${directory.path}/transcript.jsonl');
      await transcript.writeAsString(
        <String>[
          jsonEncode(<String, Object?>{
            'type': 'response_item',
            'payload': <String, Object?>{
              'type': 'message',
              'role': 'assistant',
              'phase': 'commentary',
              'content': <Object?>[
                <String, Object?>{'type': 'output_text', 'text': '我正在运行测试。'},
              ],
            },
          }),
          jsonEncode(<String, Object?>{
            'type': 'response_item',
            'payload': <String, Object?>{
              'type': 'message',
              'role': 'assistant',
              'phase': 'final_answer',
              'content': <Object?>[
                <String, Object?>{
                  'type': 'output_text',
                  'text': '已修好任务结束通知，现在会显示一句本轮结果。\n\n详细测试全部通过。',
                },
              ],
            },
          }),
        ].join('\n'),
      );
      final _RecordingTransport transport = _RecordingTransport();

      await CompletionHookNotifier(transport).notify(
        jsonEncode(<String, Object?>{'transcript_path': transcript.path}),
      );

      expect(transport.body?['message'], '已修好任务结束通知，现在会显示一句本轮结果。');
    },
  );
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
