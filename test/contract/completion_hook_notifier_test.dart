import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_api/data/completion_hook_notifier.dart';
import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Antigravity Stop waits until fully idle and uses workspacePaths',
    () async {
      final transport = _RecordingTransport();
      final notifier = CompletionHookNotifier(transport);
      await notifier.notify(
        jsonEncode(<String, Object?>{
          'conversationId': 'ag-session-1',
          'workspacePaths': <String>['/workspace'],
          'fullyIdle': false,
        }),
        sourceOverride: 'Antigravity',
      );
      expect(transport.body, isNull);
      await notifier.notify(
        jsonEncode(<String, Object?>{
          'conversationId': 'ag-session-1',
          'workspacePaths': <String>['/workspace'],
        }),
        sourceOverride: 'Antigravity',
      );
      expect(transport.body, isNull);
      await notifier.notify(
        jsonEncode(<String, Object?>{
          'conversationId': 'ag-session-1',
          'workspacePaths': <String>['/workspace'],
          'fullyIdle': true,
        }),
        sourceOverride: 'Antigravity',
      );
      expect(transport.body?['source'], 'Antigravity');
      expect(transport.body?['conversationId'], 'ag-session-1');
      expect(transport.body?['workspacePath'], '/workspace');
    },
  );

  test(
    'Antigravity identifies the native surface only from its matching transcript location',
    () async {
      const id = 'a45cce14-b0be-4aea-a8f9-e88195674770';
      for (final entry in <(String, String)>[
        ('antigravity-cli', 'Antigravity CLI'),
        ('antigravity-ide', 'Antigravity IDE'),
        ('antigravity', 'Antigravity App'),
      ]) {
        final transport = _RecordingTransport();
        await CompletionHookNotifier(
          transport,
          environment: const {'HOME': '/Users/test'},
        ).notify(
          jsonEncode(<String, Object?>{
            'conversationId': id,
            'workspacePaths': <String>['/workspace'],
            'fullyIdle': true,
            'transcriptPath':
                '/Users/test/.gemini/${entry.$1}/brain/$id/.system_generated/logs/transcript.jsonl',
          }),
          sourceOverride: 'Antigravity',
        );
        expect(transport.body?['source'], entry.$2);
      }
      final transport = _RecordingTransport();
      await CompletionHookNotifier(
        transport,
        environment: const {'HOME': '/Users/test'},
      ).notify(
        jsonEncode(<String, Object?>{
          'conversationId': id,
          'workspacePaths': <String>['/one', '/two'],
          'fullyIdle': true,
          'transcriptPath':
              '/Users/test/.gemini/antigravity-cli/brain/other/.system_generated/logs/transcript.jsonl',
        }),
        sourceOverride: 'Antigravity',
      );
      expect(transport.body?['source'], 'Antigravity');
      expect(transport.body?['workspacePath'], isNull);
    },
  );

  test(
    'camelCase hook payload forwards the original client and session',
    () async {
      final transport = _RecordingTransport();
      await CompletionHookNotifier(transport).notify(
        jsonEncode(<String, Object?>{
          'sessionId': 'copilot-session-1',
          'cwd': '/workspace',
          'lastAssistantMessage': '完成测试。',
        }),
        sourceOverride: 'GitHub Copilot CLI',
      );
      expect(transport.body?['source'], 'GitHub Copilot CLI');
      expect(transport.body?['conversationId'], 'copilot-session-1');
      expect(transport.body?['workspacePath'], '/workspace');
      expect(transport.body?['message'], '完成测试。');
    },
  );

  test(
    'camelCase transcriptPath supplies a final response when present',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'dingdong-camel-transcript-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final transcript = File('${directory.path}/transcript.jsonl');
      await transcript.writeAsString(
        jsonEncode(<String, Object?>{
          'type': 'response_item',
          'payload': <String, Object?>{
            'type': 'message',
            'role': 'assistant',
            'phase': 'final_answer',
            'content': <Object?>[
              <String, Object?>{'type': 'output_text', 'text': '任务完成。'},
            ],
          },
        }),
      );
      final transport = _RecordingTransport();
      await CompletionHookNotifier(transport).notify(
        jsonEncode(<String, Object?>{'transcriptPath': transcript.path}),
        sourceOverride: 'GitHub Copilot CLI',
      );
      expect(transport.body?['message'], '任务完成。');
    },
  );

  test(
    'desktop Stop hook carries the actual client and native session',
    () async {
      final transport = _RecordingTransport();
      await CompletionHookNotifier(
        transport,
        environment: const {
          'CLAUDE_CODE_ENTRYPOINT': 'claude-desktop',
          'CLAUDE_CODE_HOST_SESSION_ID': 'local_desktop-123',
        },
      ).notify(
        '{"session_id":"cli-123","cwd":"/workspace"}',
        sourceOverride: 'Claude Code',
      );

      expect(transport.body?['source'], 'Claude Desktop');
      expect(transport.body?['conversationId'], 'cli-123');
      expect(transport.body?['hostSessionId'], 'local_desktop-123');
    },
  );

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

    expect(transport.body, isNot(contains('message')));
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
    expect(transport.body?['detail'], '已经完成资源同步并安装到本机：\n全量测试通过\n应用正在运行');
  });

  test(
    'Stop hook marks a response waiting for confirmation as attention',
    () async {
      final _RecordingTransport transport = _RecordingTransport();

      await CompletionHookNotifier(transport).notify(
        jsonEncode(<String, Object?>{
          'hook_event_name': 'Stop',
          'last_assistant_message': '本地修改已经完成，但还没有提交。你确认后我再回复 MR。',
        }),
      );

      expect(transport.body?['message'], '本地修改已经完成，但还没有提交。你确认后我再回复 MR。');
      expect(transport.body?['notificationKind'], 'attention');
    },
  );

  test(
    'SessionEnd remains a completion even if the transcript mentions input',
    () async {
      final _RecordingTransport transport = _RecordingTransport();

      await CompletionHookNotifier(transport).notify(
        jsonEncode(<String, Object?>{
          'hook_event_name': 'SessionEnd',
          'last_assistant_message': '任务完成，等待你确认是否归档。',
        }),
      );

      expect(transport.body?.containsKey('notificationKind'), isFalse);
    },
  );

  test('DingDong bridge line is skipped in the recent Agent summary', () async {
    final _RecordingTransport transport = _RecordingTransport();

    await CompletionHookNotifier(transport).notify(
      jsonEncode(<String, Object?>{
        'last_assistant_message': 'DingDong · 🌟\n已经完成剪贴板次数排序。\n测试通过。',
      }),
    );

    expect(transport.body?['message'], '已经完成剪贴板次数排序。');
  });

  test('FULI marker lines are skipped in the recent Agent summary', () async {
    final _RecordingTransport transport = _RecordingTransport();

    await CompletionHookNotifier(transport).notify(
      jsonEncode(<String, Object?>{
        'last_assistant_message':
            '**[◇ FULI · 已检索，未命中](http://127.0.0.1:2727/)**\n'
            'DingDong · 🌟\n'
            '已经完成 DEV 测试面板。\n'
            '测试通过。',
      }),
    );

    expect(transport.body?['message'], '已经完成 DEV 测试面板。');
  });

  test('FULI knowledge marker uses the following line as summary', () async {
    final _RecordingTransport transport = _RecordingTransport();

    await CompletionHookNotifier(transport).notify(
      jsonEncode(<String, Object?>{
        'last_assistant_message':
            '**[🌠 FULI · 知识增强](http://127.0.0.1:2727/knowledge/personal/example)**\n'
            '已经完成最近 Agent 描述修复。\n'
            '测试通过。',
      }),
    );

    expect(transport.body?['message'], '已经完成最近 Agent 描述修复。');
    expect(transport.body?['detail'], isNot(contains('FULI · 知识增强')));
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
      expect(transport.body?['transcriptPath'], transcript.path);
      expect(transport.body, isNot(contains('tokenUsage')));
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
