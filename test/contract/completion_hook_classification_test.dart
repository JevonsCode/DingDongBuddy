import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/agent_api/data/completion_hook_notifier.dart';
import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which reminder sound each Agent event plays. Replies below are taken from
/// reminders that played the wrong sound on a real machine.
void main() {
  Future<String> kindOf(Map<String, Object?> input) async {
    final _RecordingTransport transport = _RecordingTransport();
    await CompletionHookNotifier(transport).notify(jsonEncode(input));
    return transport.body?['notificationKind'] as String? ?? 'completion';
  }

  group('finished replies play the completion sound', () {
    for (final String reply in <String>[
      // A quoted UI label is not a request.
      '两个修复都合并了：JevonsCode/fuli#775 和 #776，CI 全绿。\n'
          '第一次打开页面时，项目选择器显示「请选择」，不显示「个人项目 · shop-web」。',
      '已合并 JevonsCode/fuli#783：顶栏按钮已经挪到关闭按钮下面。\n'
          '截图里「有 N 件事需要你」没出现：临时 console 只回健康检查。',
      'I merged PR #723 after all 14 CI checks passed.\n'
          'A new line at the top of 「知识整理」 (「n 条知识等你确认 · 去确认」) opens the same page.',
      // Reported state, not a request.
      'Release notes are written. Nothing committed or pushed yet; not published.',
      '本地改动已完成，测试通过，未提交、未推送。',
      // Nouns, table cells and code are description, not requests.
      <String>[
        '两个 PR 都已合并，14 项检查全过。',
        '服务端：100 条待确认、空间里另有 1000 条偏好时，从 11.69s 降到 2.46s。',
        '| 场景 | 提示 |',
        '| --- | --- |',
        '| 首次打开 | 请选择项目 |',
        '```',
        'echo "please confirm"',
        '```',
        '不需要你做任何操作，也 nothing needed from you。',
      ].join('\n'),
      // Receipts and bridge footers never decide the kind.
      'PR #831 is merged with 9 checks passing.\n'
          'FULI Agent：[Lyra North \\[fuli 负责人\\]](<fuli://agents/a/b>)',
      'Pushed 858667bc. Waiting for the dependency install so I can check the '
          'built console in the browser.',
    ]) {
      test(reply.split('\n').first, () async {
        expect(
          await kindOf(<String, Object?>{
            'hook_event_name': 'Stop',
            'last_assistant_message': reply,
          }),
          'completion',
        );
      });
    }
  });

  group('replies that wait for the user play the attention sound', () {
    for (final String reply in <String>[
      'The unit check failed again, and I still have no log.\n'
          '🟥 Please approve gh run view --log-failed or paste the failing '
          'unit output here, or pause the CI monitor for this PR.',
      'This is the tenth identical event.\n'
          '🟥 Needed from you: approve gh in this session, or pause the monitor.',
      'rec76-measure-10 completed with no output. That makes ten '
          'notifications with no results.\n'
          'Do you want me to look for the process sending them, or can you '
          'tell me where the results are written?\n'
          'FULI Agent：[Lyra North](<fuli://agents/a/b>)',
      'rec76-measure-10 is the tenth completion notice. Please stop it.',
      '本地修改已经完成，但还没有提交。你确认后我再回复 MR。',
      'Notion 数据库没建成：权限被拒了。\n🟥 需要你在 Claude 里放行 Notion 的创建数据库。',
      '方案 A 改动小，方案 B 更彻底。\n你想先做哪个？',
      'Which branch should I release from?',
    ]) {
      test(reply.split('\n').first, () async {
        expect(
          await kindOf(<String, Object?>{
            'hook_event_name': 'Stop',
            'last_assistant_message': reply,
          }),
          'attention',
        );
      });
    }
  });

  group('host events', () {
    for (final (String type, String expected) in <(String, String)>[
      ('permission_prompt', 'attention'),
      ('idle_prompt', 'attention'),
      ('elicitation_dialog', 'attention'),
      ('auth_success', 'completion'),
    ]) {
      test('Claude Code Notification $type plays $expected', () async {
        expect(
          await kindOf(<String, Object?>{
            'hook_event_name': 'Notification',
            'notification_type': type,
            'message': 'Claude needs your permission to use Bash',
          }),
          expected,
        );
      });
    }

    test('a Notification without a type waits for the user', () async {
      expect(
        await kindOf(<String, Object?>{
          'hook_event_name': 'Notification',
          'message': 'Claude is waiting for your input',
        }),
        'attention',
      );
    });

    test('PermissionRequest always waits for the user', () async {
      expect(
        await kindOf(<String, Object?>{
          'hook_event_name': 'PermissionRequest',
          'tool_name': 'Bash',
        }),
        'attention',
      );
    });

    test('SessionEnd stays a completion', () async {
      expect(
        await kindOf(<String, Object?>{
          'hook_event_name': 'SessionEnd',
          'last_assistant_message': 'Which branch should I release from?',
        }),
        'completion',
      );
    });
  });

  group('the turn\'s own dingdong_notify call decides the Stop', () {
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('dingdong-turn-');
    });
    tearDown(() => directory.delete(recursive: true));

    Future<String> stopKind(List<Map<String, Object?>> entries) async {
      final File transcript = File('${directory.path}/session.jsonl');
      await transcript.writeAsString(entries.map(jsonEncode).join('\n'));
      return kindOf(<String, Object?>{
        'hook_event_name': 'Stop',
        'transcript_path': transcript.path,
      });
    }

    Map<String, Object?> claudeUser(Object content) => <String, Object?>{
      'type': 'user',
      'message': <String, Object?>{'role': 'user', 'content': content},
    };
    Map<String, Object?> claudeAssistant(List<Map<String, Object?>> content) =>
        <String, Object?>{
          'type': 'assistant',
          'message': <String, Object?>{'role': 'assistant', 'content': content},
        };
    Map<String, Object?> claudeNotify(Map<String, Object?> input) =>
        claudeAssistant(<Map<String, Object?>>[
          <String, Object?>{
            'type': 'tool_use',
            'id': 'toolu_1',
            'name': 'mcp__dingdong__dingdong_notify',
            'input': input,
          },
        ]);
    final Map<String, Object?> toolResult = claudeUser(<Map<String, Object?>>[
      <String, Object?>{
        'type': 'tool_result',
        'tool_use_id': 'toolu_1',
        'content': 'ok',
      },
    ]);
    final Map<String, Object?> finished = claudeAssistant(
      <Map<String, Object?>>[
        <String, Object?>{'type': 'text', 'text': 'macOS 安装包已挂到 beta.4 发布页。'},
      ],
    );

    test('Claude Code: attention notify then a plain reply', () async {
      expect(
        await stopKind(<Map<String, Object?>>[
          claudeUser('发布 beta.4'),
          claudeNotify(<String, Object?>{
            'message': '可以在 Mac 上装了',
            'conversationId': 'c1',
          }),
          toolResult,
          finished,
        ]),
        'attention',
      );
    });

    test('Claude Code: a notify from an earlier turn does not count', () async {
      expect(
        await stopKind(<Map<String, Object?>>[
          claudeUser('发布 beta.4'),
          claudeNotify(<String, Object?>{
            'message': '请确认发布范围',
            'conversationId': 'c1',
            'notificationKind': 'attention',
          }),
          toolResult,
          claudeUser('正式发布'),
          finished,
        ]),
        'completion',
      );
    });

    test('Claude Code: an explicit completion notify stays completion', () {
      return expectLater(
        stopKind(<Map<String, Object?>>[
          claudeUser('发布 beta.4'),
          claudeNotify(<String, Object?>{
            'message': 'Done',
            'conversationId': 'c1',
            'notificationKind': 'completion',
          }),
          toolResult,
          finished,
        ]),
        completion('completion'),
      );
    });

    test('Codex: attention notify then a plain reply', () async {
      expect(
        await stopKind(<Map<String, Object?>>[
          <String, Object?>{
            'type': 'event_msg',
            'payload': <String, Object?>{
              'type': 'user_message',
              'message': '继续',
            },
          },
          <String, Object?>{
            'type': 'response_item',
            'payload': <String, Object?>{
              'type': 'function_call',
              'namespace': 'mcp__dingdong__',
              'name': 'dingdong_notify',
              'arguments': jsonEncode(<String, Object?>{
                'message': '请在手机允许安装',
                'conversationId': 'thread-1',
              }),
            },
          },
          <String, Object?>{
            'type': 'response_item',
            'payload': <String, Object?>{
              'type': 'message',
              'role': 'assistant',
              'phase': 'final_answer',
              'content': <Map<String, Object?>>[
                <String, Object?>{'type': 'output_text', 'text': '新版已安装。'},
              ],
            },
          },
        ]),
        'attention',
      );
    });
  });

  test('every attention spelling an Agent or host uses parses', () {
    for (final String value in <String>[
      'attention',
      ' Attention ',
      'needs_input',
      'needs-input',
      'question',
      'permission_prompt',
      'idle_prompt',
      'elicitation_dialog',
    ]) {
      expect(
        AgentNotificationKind.parse(value),
        AgentNotificationKind.attention,
        reason: value,
      );
    }
    expect(AgentNotificationKind.tryParse('auth_success'), isNull);
    expect(
      AgentNotificationKind.parse('auth_success'),
      AgentNotificationKind.completion,
    );
  });
}

final class _RecordingTransport implements McpHttpTransport {
  Map<String, Object?>? body;

  @override
  Future<Map<String, Object?>> request({
    required String method,
    required String path,
    Map<String, String> query = const <String, String>{},
    Map<String, Object?>? body,
  }) async {
    this.body = body;
    return <String, Object?>{'status': 'triggered'};
  }
}
