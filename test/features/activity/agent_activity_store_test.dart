import 'dart:io';

import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
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

    store.save(
      AgentActivityHistory(
        activities: <AgentActivity>[
          AgentActivity(
            id: 'activity-1',
            source: 'Codex',
            message: 'Finished the task',
            completedAt: completedAt,
            unseen: true,
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
    expect(restored.activities.single.unseen, isTrue);
    expect(restored.completionTimes, hasLength(2));
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
}
