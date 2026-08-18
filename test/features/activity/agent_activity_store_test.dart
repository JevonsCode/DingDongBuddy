import 'dart:io';

import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
