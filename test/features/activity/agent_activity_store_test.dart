import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'does not guess when a transcript maps to multiple desktop sessions',
    () {
      final temporary = Directory.systemTemp.createTempSync(
        'dingdong-ambiguous-',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      final index = Directory('${temporary.path}/sessions/account/org')
        ..createSync(recursive: true);
      for (final id in ['local_desktop-1', 'local_desktop-2']) {
        File('${index.path}/$id.json').writeAsStringSync(
          jsonEncode({'sessionId': id, 'cliSessionId': 'shared-cli'}),
        );
      }
      File('${index.path}/local_cli-imported.json').writeAsStringSync(
        jsonEncode({
          'sessionId': 'local_cli-imported',
          'cliSessionId': 'cli-imported',
        }),
      );
      File('${index.path}/local_native-other.json').writeAsStringSync(
        jsonEncode({
          'sessionId': 'local_native-other',
          'cliSessionId': 'cli-imported',
        }),
      );
      final store = FileAgentActivityStore(
        File('${temporary.path}/activity.json'),
        claudeDesktopSessionDirectory: Directory('${temporary.path}/sessions'),
      );
      store.save(
        AgentActivityHistory(
          activities: [
            for (final id in ['shared-cli', 'cli-imported'])
              AgentActivity(
                id: id,
                source: 'Claude Code',
                message: 'Finished',
                completedAt: DateTime.utc(2026, 10, 28),
                unseen: false,
                conversationTarget: AgentConversationTarget(
                  client: AgentClient.claudeCode,
                  conversationId: id,
                ),
              ),
          ],
        ),
      );
      expect(
        store.load().activities.map((item) => item.source),
        everyElement('Claude Code'),
      );
    },
  );

  test(
    'recognizes native desktop history without relabeling imported CLI sessions',
    () {
      final temporary = Directory.systemTemp.createTempSync(
        'dingdong-desktop-index-',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      final index = Directory('${temporary.path}/sessions/account/org')
        ..createSync(recursive: true);
      File('${index.path}/local_desktop-123.json').writeAsStringSync(
        jsonEncode({
          'sessionId': 'local_desktop-123',
          'cliSessionId': 'cli-123',
        }),
      );
      File('${index.path}/local_cli-456.json').writeAsStringSync(
        jsonEncode({'sessionId': 'local_cli-456', 'cliSessionId': 'cli-456'}),
      );
      final store = FileAgentActivityStore(
        File('${temporary.path}/activity.json'),
        claudeDesktopSessionDirectory: Directory('${temporary.path}/sessions'),
      );
      store.save(
        AgentActivityHistory(
          activities: [
            for (final id in ['cli-123', 'cli-456', 'cli-unknown'])
              AgentActivity(
                id: id,
                source: 'Claude Code',
                message: 'Finished',
                completedAt: DateTime.utc(2026, 10, 28),
                unseen: true,
                repeatCount: 4,
                conversationTarget: AgentConversationTarget(
                  client: AgentClient.claudeCode,
                  conversationId: id,
                  workspacePath: '/workspace',
                ),
              ),
          ],
        ),
      );

      final items = store.load().activities;
      expect(items[0].source, 'Claude Desktop');
      expect(items[0].conversationTarget?.client, AgentClient.claudeDesktop);
      expect(items[0].conversationTarget?.hostSessionId, 'local_desktop-123');
      expect(items[0].repeatCount, 4);
      expect(items[0].unseen, isTrue);
      expect(items[1].source, 'Claude Code');
      expect(items[2].source, 'Claude Code');
    },
  );

  test('file store round-trips detailed records and count timestamps', () {
    final Directory temporary = Directory.systemTemp.createTempSync(
      'dingdong-agent-activity-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final FileAgentActivityStore store = FileAgentActivityStore(
      File('${temporary.path}/agent-activity.json'),
    );
    final DateTime completedAt = DateTime.utc(2026, 7, 21, 10);
    final DateTime startedAt = completedAt.subtract(const Duration(minutes: 3));

    store.save(
      AgentActivityHistory(
        activities: <AgentActivity>[
          AgentActivity(
            id: 'activity-1',
            source: 'Codex',
            message: 'Finished the task',
            task: 'Build the app',
            detail: 'Built and verified the app.',
            startedAt: startedAt,
            completedAt: completedAt,
            unseen: true,
            repeatCount: 2,
            unseenReminderCount: 2,
            conversationTarget: const AgentConversationTarget(
              client: AgentClient.codex,
              conversationId: 'thread-1',
              workspacePath: '/workspace/dingdong',
            ),
            tokenUsage: const ConversationTokenUsage(
              source: ConversationTokenUsageSource.codex,
              totalTokens: 12345,
              inputTokens: 12000,
              outputTokens: 345,
            ),
          ),
        ],
        completionTimes: <DateTime>[
          completedAt,
          completedAt.subtract(const Duration(minutes: 5)),
        ],
      ),
    );

    final AgentActivityHistory restored = store.load();
    expect(restored.activities.single.message, 'Finished the task');
    expect(restored.activities.single.task, 'Build the app');
    expect(restored.activities.single.detail, 'Built and verified the app.');
    expect(restored.activities.single.startedAt, startedAt);
    expect(restored.activities.single.unseen, isTrue);
    expect(restored.activities.single.repeatCount, 2);
    expect(restored.activities.single.unseenReminderCount, 2);
    expect(restored.activities.single.tokenUsage?.totalTokens, 12345);
    expect(
      restored.activities.single.conversationTarget?.conversationId,
      'thread-1',
    );
    expect(restored.completionTimes, hasLength(2));
  });

  test('file store defaults repeat count for older activity records', () {
    final Directory temporary = Directory.systemTemp.createTempSync(
      'dingdong-agent-activity-legacy-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final File file = File('${temporary.path}/agent-activity.json')
      ..writeAsStringSync('''
{
  "version": 1,
  "activities": [
    {
      "id": "activity-1",
      "source": "Codex",
      "message": "Finished",
      "completedAt": "2026-07-21T10:00:00.000Z",
      "unseen": false
    }
  ],
  "completionTimes": ["2026-07-21T10:00:00.000Z"]
}
''');

    final AgentActivityHistory restored = FileAgentActivityStore(file).load();

    expect(restored.activities.single.repeatCount, 1);
    expect(restored.activities.single.unseenReminderCount, 0);
  });

  test('older unseen records default to one pending reminder', () {
    final AgentActivity restored = AgentActivity.fromJson(<String, Object?>{
      'id': 'activity-1',
      'source': 'Codex',
      'message': 'Finished',
      'completedAt': '2026-07-21T10:00:00.000Z',
      'unseen': true,
      'repeatCount': 5,
    });

    expect(restored.unseenReminderCount, 1);
  });

  test('file store treats malformed history as empty', () {
    final Directory temporary = Directory.systemTemp.createTempSync(
      'dingdong-agent-activity-invalid-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final File file = File('${temporary.path}/agent-activity.json')
      ..writeAsStringSync('{invalid');

    final AgentActivityHistory restored = FileAgentActivityStore(file).load();

    expect(restored.activities, isEmpty);
    expect(restored.completionTimes, isEmpty);
  });

  test('file store clear removes history and atomic-write remnants', () {
    final Directory temporary = Directory.systemTemp.createTempSync(
      'dingdong-agent-activity-clear-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final File file = File('${temporary.path}/agent-activity.json')
      ..writeAsStringSync('{}');
    final File temporaryFile = File('${file.path}.tmp')
      ..writeAsStringSync('{}');
    final File backupFile = File('${file.path}.bak')..writeAsStringSync('{}');

    FileAgentActivityStore(file).clear();

    expect(file.existsSync(), isFalse);
    expect(temporaryFile.existsSync(), isFalse);
    expect(backupFile.existsSync(), isFalse);
  });
}
