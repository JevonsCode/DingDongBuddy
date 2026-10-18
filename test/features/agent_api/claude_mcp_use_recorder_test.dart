import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/claude_mcp_use_recorder.dart';
import 'package:dingdong/features/agent_api/data/http_request_data.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> _user(Object content) => {
  'type': 'user',
  'message': {'role': 'user', 'content': content},
};

Map<String, Object?> _toolUse(String id, String name) => {
  'type': 'assistant',
  'message': {
    'content': [
      {'type': 'tool_use', 'id': id, 'name': name, 'input': {}},
    ],
  },
};

void main() {
  late Directory projects;
  late InMemoryResourceStore store;
  final DateTime now = DateTime.utc(2026, 10, 18);

  setUp(() {
    projects = Directory.systemTemp.createTempSync('dingdong-claude-projects-');
    store = InMemoryResourceStore(<Resource>[
      Resource(
        id: 'abcdef-gitlab',
        type: ResourceType.mcp,
        title: 'GitLab',
        content: '{"command":"gitlab-mcp"}',
        createdAt: now,
        updatedAt: now,
      ),
      Resource(
        id: '123456-lark',
        type: ResourceType.mcp,
        title: 'Lark',
        content: '{"command":"lark-mcp"}',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
  });
  tearDown(() => projects.deleteSync(recursive: true));

  File transcript(List<Map<String, Object?>> rows) {
    final File file = File('${projects.path}/project/session.jsonl')
      ..createSync(recursive: true)
      ..writeAsStringSync(rows.map(jsonEncode).join('\n'));
    return file;
  }

  Map<String, int> invocations(List<Resource> resources) => <String, int>{
    for (final Resource resource in resources)
      resource.title: resource.invocationCount,
  };

  test('counts managed MCP calls from the latest user turn only', () async {
    final File file = transcript(<Map<String, Object?>>[
      _user('earlier task'),
      _toolUse('old', 'mcp__dingdong-lark-123456__send'),
      _user('current task'),
      _toolUse('a', 'mcp__dingdong-gitlab-abcdef__search'),
      _toolUse('b', 'mcp__dingdong-gitlab-abcdef__read'),
      // A tool result is a user row without text and keeps the turn open.
      _user([
        {'type': 'tool_result', 'tool_use_id': 'a', 'content': 'ok'},
      ]),
      _toolUse('c', 'mcp__dingdong__dingdong_notify'),
      _toolUse('d', 'mcp__other-server__run'),
    ]);
    final ClaudeMcpUseRecorder recorder = ClaudeMcpUseRecorder(
      claudeProjectsDirectory: projects,
    );

    expect(
      await recorder.record(
        transcriptPath: file.path,
        store: store,
        invokedAt: now,
      ),
      <String>{'abcdef-gitlab'},
    );
    expect(invocations(await store.load()), <String, int>{
      'GitLab': 1,
      'Lark': 0,
    });
    expect((await store.load()).first.lastInvokedAt, now);

    // A repeated Stop for the same turn does not count the same calls again.
    await recorder.record(
      transcriptPath: file.path,
      store: store,
      invokedAt: now,
    );
    expect(invocations(await store.load())['GitLab'], 1);
  });

  test('ignores transcripts outside the Claude projects directory', () async {
    final Directory outside = Directory.systemTemp.createTempSync(
      'dingdong-outside-',
    );
    addTearDown(() => outside.deleteSync(recursive: true));
    final File file = File('${outside.path}/session.jsonl')
      ..writeAsStringSync(
        <Map<String, Object?>>[
          _user('task'),
          _toolUse('a', 'mcp__dingdong-gitlab-abcdef__search'),
        ].map(jsonEncode).join('\n'),
      );

    expect(
      await ClaudeMcpUseRecorder(
        claudeProjectsDirectory: projects,
      ).record(transcriptPath: file.path, store: store, invokedAt: now),
      isEmpty,
    );
    expect(invocations(await store.load())['GitLab'], 0);
  });

  test('the Claude Code Stop hook records MCP use through /ding', () async {
    final File file = transcript(<Map<String, Object?>>[
      _user('task'),
      _toolUse('a', 'mcp__dingdong_lark_123456__send'),
    ]);
    final AgentRouter router = AgentRouter(
      resourceStore: store,
      now: () => now,
      claudeMcpUseRecorder: ClaudeMcpUseRecorder(
        claudeProjectsDirectory: projects,
      ),
    );
    Future<void> ding(String source) => router.route(
      HttpRequestData(
        method: 'POST',
        uri: '/ding',
        body: jsonEncode(<String, Object?>{
          'message': 'done',
          'source': source,
          'fallback': true,
          'transcriptPath': file.path,
        }),
      ),
    );

    await ding('Codex');
    expect(invocations(await store.load())['Lark'], 0);
    await ding('Claude Code');
    expect(invocations(await store.load())['Lark'], 1);
  });
}
