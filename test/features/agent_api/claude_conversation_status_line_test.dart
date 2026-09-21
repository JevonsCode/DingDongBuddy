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
Map<String, Object?> item(String key, String token, String type) => {
  'mergeKey': key,
  'lineToken': token,
  'type': type,
};
void receipt(
  ClaudeConversationStatusLine renderer,
  String name,
  Map<String, Object?> result,
) {
  renderer.accept(
    row('assistant', [
      {'type': 'tool_use', 'id': 'call', 'name': 'mcp__dingdong__$name'},
    ]),
  );
  renderer.accept(
    row('user', [
      {
        'type': 'tool_result',
        'tool_use_id': 'call',
        'content': [
          {'type': 'text', 'text': jsonEncode(result)},
        ],
      },
    ]),
  );
}

Map<String, Object?> bridge(List<Map<String, Object?>> items) => {
  'status': 'ok',
  'conversation': {
    'visible': true,
    'capsule': {
      'items': items,
      'tokenUsage': {'totalTokens': 1},
    },
  },
};
void main() {
  test(
    'renders actual returned symbols and merges only confirmed matching items',
    () {
      final renderer = ClaudeConversationStatusLine();
      receipt(
        renderer,
        'dingdong_bridge',
        bridge([
          item('p', '♥ Rules', 'prompt'),
          item('s', '♦ Review', 'skill'),
        ]),
      );
      receipt(renderer, 'dingdong_load_skill', {
        'status': 'ok',
        'conversation': {
          'item': {...item('s', r'♦ Review\*', 'skill'), 'confirmedUse': true},
        },
      });
      receipt(renderer, 'dingdong_load_skill', {
        'status': 'ok',
        'conversation': {
          'item': {
            ...item('other', '♦ Hidden*', 'skill'),
            'confirmedUse': true,
          },
        },
      });
      expect(renderer.render(ansi: false), 'DingDong · ♥ Rules | ♦ Review*');
      expect(renderer.render(), contains('\u001b[38;5;69m'));
    },
  );
  test('real user turns and failed bridge calls clear previous resources', () {
    final renderer = ClaudeConversationStatusLine();
    receipt(
      renderer,
      'dingdong_bridge',
      bridge([item('p', '♥ Rules', 'prompt')]),
    );
    renderer.accept({...row('user', 'hook context'), 'isMeta': true});
    expect(renderer.render(ansi: false), contains('Rules'));
    renderer.accept(row('user', 'next task'));
    expect(renderer.render(ansi: false), 'DingDong · 本轮未加载');
    receipt(
      renderer,
      'dingdong_bridge',
      bridge([item('p', '♥ New', 'prompt')]),
    );
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
            'content': jsonEncode(bridge([item('p', '♥ Fake', 'prompt')])),
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
      receipt(
        renderer,
        'dingdong_bridge',
        bridge([item('p', '♥ Rules', 'prompt')]),
      );
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
      expect(renderer.render(ansi: false), endsWith('350 Token'));
    },
  );
  test('terminal escape sequences in a receipt are stripped', () {
    final renderer = ClaudeConversationStatusLine();
    receipt(
      renderer,
      'dingdong_bridge',
      bridge([item('p', '♥ \u001b]52;danger\u0007\nRules', 'prompt')]),
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
