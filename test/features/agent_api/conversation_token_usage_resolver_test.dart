import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_api/data/conversation_token_usage_resolver.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory temporary;
  late Directory codex;
  late Directory archivedCodex;
  late Directory claude;
  late Directory pi;
  late LocalConversationTokenUsageResolver resolver;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp('dingdong-token-usage-');
    codex = await Directory(path.join(temporary.path, 'codex')).create();
    archivedCodex = await Directory(
      path.join(temporary.path, 'codex-archive'),
    ).create();
    claude = await Directory(path.join(temporary.path, 'claude')).create();
    pi = await Directory(path.join(temporary.path, 'pi')).create();
    resolver = LocalConversationTokenUsageResolver(
      codexSessionsDirectory: codex,
      codexArchivedSessionsDirectory: archivedCodex,
      claudeProjectsDirectory: claude,
      piSessionsDirectory: pi,
    );
  });

  tearDown(() async {
    await temporary.delete(recursive: true);
  });

  test(
    'Codex returns the latest exact cumulative token_count snapshot',
    () async {
      final Directory day = await Directory(
        path.join(codex.path, '2026', '08', '19'),
      ).create(recursive: true);
      final File transcript = File(
        path.join(day.path, 'rollout-thread-codex-1.jsonl'),
      );
      await transcript.writeAsString(
        <String>[
          '{malformed',
          _codexTokenLine(total: 100, input: 80, output: 20),
          jsonEncode(<String, Object?>{
            'type': 'event_msg',
            'payload': <String, Object?>{'type': 'task_complete'},
          }),
          _codexTokenLine(
            total: 1250,
            input: 1100,
            output: 150,
            cached: 700,
            reasoning: 40,
          ),
        ].join('\n'),
      );

      final ConversationTokenUsage? usage = await resolver.resolve(
        const ConversationTokenUsageRequest(
          source: 'Codex',
          conversationId: 'thread-codex-1',
        ),
      );

      expect(usage?.source, ConversationTokenUsageSource.codex);
      expect(usage?.totalTokens, 1250);
      expect(usage?.inputTokens, 1100);
      expect(usage?.outputTokens, 150);
      expect(usage?.cachedInputTokens, 700);
      expect(usage?.reasoningOutputTokens, 40);
    },
  );

  test(
    'Codex falls back to the newest exact-workspace session without an id',
    () async {
      final Directory day = await Directory(
        path.join(codex.path, '2026', '08', '19'),
      ).create(recursive: true);
      final File matching = File(
        path.join(day.path, 'rollout-current-workspace.jsonl'),
      );
      await matching.writeAsString(
        <String>[
          _codexSessionMetaLine(
            id: 'current-workspace',
            cwd: '/workspace/current',
          ),
          _codexTokenLine(total: 3210, input: 3000, output: 210),
        ].join('\n'),
      );
      final File unrelated = File(
        path.join(day.path, 'rollout-newer-unrelated.jsonl'),
      );
      await unrelated.writeAsString(
        <String>[
          _codexSessionMetaLine(id: 'newer-unrelated', cwd: '/workspace/other'),
          _codexTokenLine(total: 9999, input: 9000, output: 999),
        ].join('\n'),
      );
      await matching.setLastModified(DateTime.utc(2026, 8, 19, 10));
      await unrelated.setLastModified(DateTime.utc(2026, 8, 19, 11));

      final ConversationTokenUsage? usage = await resolver.resolve(
        const ConversationTokenUsageRequest(
          source: 'Codex',
          workspacePath: '/workspace/current',
        ),
      );

      expect(usage?.source, ConversationTokenUsageSource.codex);
      expect(usage?.totalTokens, 3210);
    },
  );

  test(
    'Claude Code deduplicates responses and includes subagent usage',
    () async {
      final Directory project = await Directory(
        path.join(claude.path, 'project-a'),
      ).create();
      final File transcript = File(
        path.join(project.path, 'claude-session-1.jsonl'),
      );
      final String first = _claudeAssistantLine(
        requestId: 'request-1',
        messageId: 'message-1',
        input: 100,
        output: 20,
        cacheRead: 50,
        cacheWrite: 10,
      );
      await transcript.writeAsString(
        <String>[
          first,
          first,
          _claudeAssistantLine(
            messageId: 'message-2',
            input: 200,
            output: 30,
            cacheRead: 70,
            cacheWrite: 15,
          ),
        ].join('\n'),
      );
      final Directory subagents = await Directory(
        path.join(project.path, 'claude-session-1', 'subagents'),
      ).create(recursive: true);
      await File(path.join(subagents.path, 'agent-a.jsonl')).writeAsString(
        _claudeAssistantLine(
          requestId: 'request-subagent',
          messageId: 'message-subagent',
          input: 300,
          output: 40,
          cacheRead: 90,
          cacheWrite: 20,
        ),
      );

      final ConversationTokenUsage? usage = await resolver.resolve(
        ConversationTokenUsageRequest(
          source: 'Claude Code',
          conversationId: 'claude-session-1',
          transcriptPath: transcript.path,
        ),
      );

      expect(usage?.source, ConversationTokenUsageSource.claudeCode);
      expect(usage?.inputTokens, 600);
      expect(usage?.outputTokens, 90);
      expect(usage?.cachedInputTokens, 210);
      expect(usage?.cacheWriteInputTokens, 45);
      expect(usage?.totalTokens, 945);
    },
  );

  test(
    'Claude Code falls back to the exact-workspace transcript without an id',
    () async {
      final Directory project = await Directory(
        path.join(claude.path, 'project-workspace'),
      ).create();
      final File transcript = File(
        path.join(project.path, 'claude-workspace-session.jsonl'),
      );
      await transcript.writeAsString(
        <String>[
          _claudeWorkspaceLine(
            sessionId: 'claude-workspace-session',
            cwd: '/workspace/claude',
          ),
          _claudeAssistantLine(
            requestId: 'request-workspace',
            messageId: 'message-workspace',
            input: 400,
            output: 50,
            cacheRead: 100,
            cacheWrite: 25,
          ),
        ].join('\n'),
      );

      final ConversationTokenUsage? usage = await resolver.resolve(
        const ConversationTokenUsageRequest(
          source: 'Claude Code',
          workspacePath: '/workspace/claude',
        ),
      );

      expect(usage?.source, ConversationTokenUsageSource.claudeCode);
      expect(usage?.totalTokens, 575);
    },
  );

  test(
    'Claude Code resolves workspace symlinks before transcript matching',
    () async {
      final Directory actualWorkspace = await Directory(
        path.join(temporary.path, 'actual-workspace'),
      ).create();
      final Link linkedWorkspace = Link(
        path.join(temporary.path, 'linked-workspace'),
      );
      await linkedWorkspace.create(actualWorkspace.path);
      final Directory project = await Directory(
        path.join(claude.path, 'project-symlink'),
      ).create();
      final File transcript = File(
        path.join(project.path, 'claude-symlink-session.jsonl'),
      );
      await transcript.writeAsString(
        <String>[
          _claudeWorkspaceLine(
            sessionId: 'claude-symlink-session',
            cwd: actualWorkspace.path,
          ),
          _claudeAssistantLine(
            requestId: 'request-symlink',
            messageId: 'message-symlink',
            input: 40,
            output: 5,
            cacheRead: 10,
            cacheWrite: 2,
          ),
        ].join('\n'),
      );

      final ConversationTokenUsage? usage = await resolver.resolve(
        ConversationTokenUsageRequest(
          source: 'Claude Code',
          workspacePath: linkedWorkspace.path,
        ),
      );

      expect(usage?.totalTokens, 57);
    },
    skip: Platform.isWindows
        ? 'Creating a test symlink requires additional Windows privileges.'
        : false,
  );

  test('Pi mirrors its billed all-entry session total', () async {
    final Directory project = await Directory(
      path.join(pi.path, '--project--'),
    ).create();
    final File transcript = File(
      path.join(project.path, '2026-08-19_pi-session-1.jsonl'),
    );
    await transcript.writeAsString(
      <String>[
        jsonEncode(<String, Object?>{
          'type': 'session',
          'id': 'pi-session-1',
          'cwd': '/project',
        }),
        _piMessageLine(
          role: 'assistant',
          input: 100,
          output: 25,
          cacheRead: 50,
          cacheWrite: 10,
          reasoning: 5,
        ),
        _piMessageLine(
          role: 'toolResult',
          input: 20,
          output: 5,
          cacheRead: 4,
          cacheWrite: 1,
        ),
        _piSummaryLine(
          type: 'compaction',
          input: 40,
          output: 10,
          cacheRead: 8,
          cacheWrite: 2,
        ),
        _piSummaryLine(
          type: 'branch_summary',
          input: 60,
          output: 15,
          cacheRead: 12,
          cacheWrite: 3,
        ),
      ].join('\n'),
    );

    final ConversationTokenUsage? usage = await resolver.resolve(
      const ConversationTokenUsageRequest(
        source: 'Pi',
        conversationId: 'pi-session-1',
      ),
    );

    expect(usage?.source, ConversationTokenUsageSource.pi);
    expect(usage?.inputTokens, 220);
    expect(usage?.outputTokens, 55);
    expect(usage?.cachedInputTokens, 74);
    expect(usage?.cacheWriteInputTokens, 16);
    expect(usage?.reasoningOutputTokens, 5);
    expect(usage?.totalTokens, 365);
  });

  test('unsupported and unsafe conversations are never estimated', () async {
    expect(
      await resolver.resolve(
        const ConversationTokenUsageRequest(
          source: 'Gemini CLI',
          conversationId: 'gemini-session',
        ),
      ),
      isNull,
    );
    expect(
      await resolver.resolve(
        const ConversationTokenUsageRequest(
          source: 'Codex',
          conversationId: '../outside',
        ),
      ),
      isNull,
    );
  });
}

String _codexTokenLine({
  required int total,
  required int input,
  required int output,
  int cached = 0,
  int reasoning = 0,
}) => jsonEncode(<String, Object?>{
  'type': 'event_msg',
  'payload': <String, Object?>{
    'type': 'token_count',
    'info': <String, Object?>{
      'total_token_usage': <String, Object?>{
        'input_tokens': input,
        'cached_input_tokens': cached,
        'output_tokens': output,
        'reasoning_output_tokens': reasoning,
        'total_tokens': total,
      },
    },
  },
});

String _codexSessionMetaLine({required String id, required String cwd}) =>
    jsonEncode(<String, Object?>{
      'type': 'session_meta',
      'payload': <String, Object?>{'id': id, 'cwd': cwd},
    });

String _claudeWorkspaceLine({required String sessionId, required String cwd}) =>
    jsonEncode(<String, Object?>{
      'type': 'user',
      'sessionId': sessionId,
      'cwd': cwd,
      'message': <String, Object?>{'role': 'user'},
    });

String _claudeAssistantLine({
  String? requestId,
  required String messageId,
  required int input,
  required int output,
  required int cacheRead,
  required int cacheWrite,
}) => jsonEncode(<String, Object?>{
  'type': 'assistant',
  'requestId': ?requestId,
  'message': <String, Object?>{
    'id': messageId,
    'usage': <String, Object?>{
      'input_tokens': input,
      'output_tokens': output,
      'cache_read_input_tokens': cacheRead,
      'cache_creation_input_tokens': cacheWrite,
    },
  },
});

String _piMessageLine({
  required String role,
  required int input,
  required int output,
  required int cacheRead,
  required int cacheWrite,
  int reasoning = 0,
}) => jsonEncode(<String, Object?>{
  'type': 'message',
  'message': <String, Object?>{
    'role': role,
    'usage': _piUsage(
      input: input,
      output: output,
      cacheRead: cacheRead,
      cacheWrite: cacheWrite,
      reasoning: reasoning,
    ),
  },
});

String _piSummaryLine({
  required String type,
  required int input,
  required int output,
  required int cacheRead,
  required int cacheWrite,
}) => jsonEncode(<String, Object?>{
  'type': type,
  'usage': _piUsage(
    input: input,
    output: output,
    cacheRead: cacheRead,
    cacheWrite: cacheWrite,
  ),
});

Map<String, Object?> _piUsage({
  required int input,
  required int output,
  required int cacheRead,
  required int cacheWrite,
  int reasoning = 0,
}) => <String, Object?>{
  'input': input,
  'output': output,
  'cacheRead': cacheRead,
  'cacheWrite': cacheWrite,
  'reasoning': reasoning,
  'totalTokens': input + output + cacheRead + cacheWrite,
};
