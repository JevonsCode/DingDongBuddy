import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_api/data/claude_conversation_status_line.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> row(
  String type,
  Object content, {
  Map<String, Object?>? usage,
}) => {
  'type': type,
  'message': {'id': 'response', 'content': content, 'usage': ?usage},
};
void toolCall(
  ClaudeConversationStatusLine renderer,
  String toolName,
  Object result, {
  bool isError = false,
}) {
  renderer.accept(
    row('assistant', [
      {'type': 'tool_use', 'id': 'call', 'name': toolName},
    ]),
  );
  renderer.accept(
    row('user', [
      {
        'type': 'tool_result',
        'tool_use_id': 'call',
        'is_error': isError,
        'content': [
          {
            'type': 'text',
            'text': result is String ? result : jsonEncode(result),
          },
        ],
      },
    ]),
  );
}

void receipt(
  ClaudeConversationStatusLine renderer,
  String name,
  Map<String, Object?> result,
) => toolCall(renderer, 'mcp__dingdong__$name', result);

Map<String, Object?> bridge({
  List<String> prompts = const [],
  Map<String, String> skills = const {},
  Map<String, String> mcps = const {},
  String hash = 'h1',
}) => {
  'status': 'ok',
  'active': {'prompts': [], 'skills': [], 'mcps': []},
  'statusLine': {
    'prompts': prompts,
    'skills': skills,
    'mcps': mcps,
    'tokens': true,
  },
  'hash': hash,
};

void main() {
  test('renders returned symbols and marks only loaded catalog Skills', () {
    final renderer = ClaudeConversationStatusLine();
    receipt(
      renderer,
      'dingdong_bridge',
      bridge(
        prompts: ['♥ Rules'],
        skills: {'review-id': '♦ Review', 'other-id': '♦ Other'},
      ),
    );
    receipt(renderer, 'dingdong_load_skill', {
      'status': 'ok',
      'skill': {'id': 'review-id'},
    });
    receipt(renderer, 'dingdong_load_skill', {
      'status': 'ok',
      'skill': {'id': 'unknown-id'},
    });
    toolCall(renderer, 'mcp__dingdong__dingdong_load_skill', {
      'status': 'ok',
      'skill': {'id': 'other-id'},
    }, isError: true);
    expect(
      renderer.render(ansi: false),
      'DingDong · ♥ Rules | ♦ Review* | ♦ Other',
    );
    expect(renderer.render(), contains('\u001b[38;5;69m'));
  });

  test('a finished managed MCP call marks its server, even on error', () {
    final renderer = ClaudeConversationStatusLine();
    receipt(
      renderer,
      'dingdong_bridge',
      bridge(
        mcps: {
          'dingdong-gitlab-abcdef': '♠ GitLab',
          'dingdong-lark-123456': '♠ Lark',
          'dingdong-figma-654321': '♠ Figma',
        },
      ),
    );
    renderer.accept(
      row('assistant', [
        {
          'type': 'tool_use',
          'id': 'pending',
          'name': 'mcp__dingdong-figma-654321__read',
        },
      ]),
    );
    toolCall(
      renderer,
      'mcp__dingdong-gitlab-abcdef__search',
      'not json',
      isError: true,
    );
    toolCall(renderer, 'mcp__dingdong_lark_123456__send', {'ok': true});
    toolCall(renderer, 'mcp__dingdong__dingdong_notify', {'status': 'ok'});
    expect(
      renderer.render(ansi: false),
      'DingDong · ♠ GitLab* | ♠ Lark* | ♠ Figma',
    );
  });

  test('unchanged Bridge results reuse the receipt with the same hash', () {
    final renderer = ClaudeConversationStatusLine();
    receipt(renderer, 'dingdong_bridge', bridge(prompts: ['♥ Rules']));
    renderer.accept(row('user', 'next task'));
    receipt(renderer, 'dingdong_bridge', {
      'status': 'ok',
      'unchanged': true,
      'hash': 'h1',
    });
    expect(renderer.render(ansi: false), startsWith('DingDong · ♥ Rules'));
    renderer.accept(row('user', 'another task'));
    receipt(renderer, 'dingdong_bridge', {
      'status': 'ok',
      'unchanged': true,
      'hash': 'stale',
    });
    expect(renderer.render(ansi: false), 'DingDong · 本轮未加载');
  });

  test('real user turns and failed bridge calls clear previous resources', () {
    final renderer = ClaudeConversationStatusLine();
    receipt(renderer, 'dingdong_bridge', bridge(prompts: ['♥ Rules']));
    renderer.accept({...row('user', 'hook context'), 'isMeta': true});
    expect(renderer.render(ansi: false), contains('Rules'));
    renderer.accept(row('user', 'next task'));
    expect(renderer.render(ansi: false), 'DingDong · 本轮未加载');
    receipt(renderer, 'dingdong_bridge', bridge(prompts: ['♥ New']));
    receipt(renderer, 'dingdong_bridge', {'status': 'error'});
    expect(renderer.render(ansi: false), 'DingDong · 本轮未加载');
  });
  test(
    'unmatched tool results and user text cannot manufacture resource use',
    () {
      final renderer = ClaudeConversationStatusLine();
      renderer.accept(
        row('user', [
          {
            'type': 'tool_result',
            'tool_use_id': 'unknown',
            'content': jsonEncode(bridge(prompts: ['♥ Fake'])),
          },
        ]),
      );
      expect(renderer.render(ansi: false), 'DingDong · 本轮未加载');
    },
  );
  test(
    'streaming usage replaces repeated response snapshots instead of adding them',
    () {
      final renderer = ClaudeConversationStatusLine();
      receipt(renderer, 'dingdong_bridge', bridge(prompts: ['♥ Rules']));
      renderer.accept(
        row('assistant', [], usage: {'input_tokens': 100, 'output_tokens': 1}),
      );
      renderer.accept(
        row(
          'assistant',
          [],
          usage: {
            'input_tokens': 100,
            'output_tokens': 40,
            'cache_read_input_tokens': 200,
            'cache_creation_input_tokens': 10,
          },
        ),
      );
      expect(
        renderer.render(ansi: false),
        endsWith('输入 310 · 输出 40 · 命中缓存 200 · 非缓存 150'),
      );
    },
  );
  test(
    'statusline shows non-cached tokens regardless of monetary cost',
    () async {
      final dir = await Directory.systemTemp.createTemp(
        'jvs-a-cost-statusline-',
      );
      addTearDown(() => dir.delete(recursive: true));
      final rendererRows = [
        row('assistant', [
          {
            'type': 'tool_use',
            'id': 'b',
            'name': 'mcp__dingdong__dingdong_bridge',
          },
        ]),
        row('user', [
          {
            'type': 'tool_result',
            'tool_use_id': 'b',
            'content': jsonEncode(bridge(prompts: ['♥ Rules'])),
          },
        ]),
        row(
          'assistant',
          [],
          usage: {
            'input_tokens': 100,
            'output_tokens': 40,
            'cache_read_input_tokens': 200,
            'cache_creation_input_tokens': 0,
          },
        ),
      ];
      final file = File('${dir.path}/cost-session.jsonl');
      await file.writeAsString(rendererRows.map(jsonEncode).join('\n'));
      for (final cost in [0.000012, 0, -1, '0.5']) {
        final line = await ClaudeConversationStatusLine.fromInput(
          jsonEncode({
            'session_id': 'cost-session',
            'transcript_path': file.path,
            'cost': {'total_cost_usd': cost},
          }),
        );
        expect(line, contains('输入 300 · 输出 40 · 命中缓存 200'));
        expect(line, contains('非缓存 140'));
        expect(line, isNot(contains(r'US$')));
      }
    },
  );
  test(
    'missing cache falls back to the old total; an explicit zero enables details',
    () {
      final renderer = ClaudeConversationStatusLine();
      receipt(renderer, 'dingdong_bridge', bridge(prompts: ['♥ Rules']));
      renderer.accept(
        row('assistant', [], usage: {'input_tokens': 100, 'output_tokens': 40}),
      );
      expect(renderer.render(ansi: false), endsWith('140 Token'));
      renderer.accept(
        row(
          'assistant',
          [],
          usage: {
            'input_tokens': 100,
            'output_tokens': 40,
            'cache_read_input_tokens': 0,
            'cache_creation_input_tokens': 0,
          },
        ),
      );
      expect(
        renderer.render(ansi: false),
        endsWith('输入 100 · 输出 40 · 命中缓存 0 · 非缓存 140'),
      );
    },
  );
  test('terminal escape sequences in a receipt are stripped', () {
    final renderer = ClaudeConversationStatusLine();
    receipt(
      renderer,
      'dingdong_bridge',
      bridge(prompts: ['♥ \u001b]52;danger\u0007\nRules']),
    );
    final line = renderer.render(ansi: false);
    expect(line, isNot(contains('\u001b')));
    expect(line, isNot(contains('\n')));
    expect(line, isNot(contains('\u0007')));
  });
  test(
    'reads exact session and tolerates an unfinished transcript tail',
    () async {
      final dir = await Directory.systemTemp.createTemp('jvs-a-statusline-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/session-one.jsonl');
      await file.writeAsString('${jsonEncode(row('user', 'hello'))}\n{"type":');
      expect(
        await ClaudeConversationStatusLine.fromInput(
          jsonEncode({
            'session_id': 'session-one',
            'transcript_path': file.path,
          }),
        ),
        contains('本轮未加载'),
      );
      expect(
        await ClaudeConversationStatusLine.fromInput(
          jsonEncode({'session_id': 'other', 'transcript_path': file.path}),
        ),
        isEmpty,
      );
    },
  );
  test('preserves existing HUD stdin and skips recursive wrappers', () async {
    final dir = await Directory.systemTemp.createTemp('jvs-a-statusline-');
    addTearDown(() => dir.delete(recursive: true));
    final config = File('${dir.path}/previous.json');
    await config.writeAsString(
      jsonEncode({'command': Platform.isWindows ? 'more' : 'cat'}),
    );
    expect(
      await runPreviousClaudeStatusLine(config.path, '{"session_id":"test"}'),
      '{"session_id":"test"}',
    );
    await config.writeAsString(
      jsonEncode({'command': 'anything --claude-statusline'}),
    );
    expect(await runPreviousClaudeStatusLine(config.path, '{}'), isEmpty);
  });
}
