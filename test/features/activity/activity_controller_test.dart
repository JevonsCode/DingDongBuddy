import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('observed task lifecycle keeps the real start and completion times', () {
    final DateTime startedAt = DateTime.utc(2026, 8, 11, 9, 30, 4);
    final DateTime completedAt = DateTime.utc(2026, 8, 11, 9, 42, 19);
    final ActivityController controller = ActivityController(
      idGenerator: () => 'run-1',
      now: () => completedAt,
    );

    controller.recordTaskStarted(
      source: 'Codex',
      task: '实现实时任务状态',
      startedAt: startedAt,
      workspacePath: '/workspace/dingdong',
      conversationId: 'thread-1',
    );

    expect(controller.activeRuns.single.startedAt, startedAt);
    final AgentCompletionRecord completion = controller.record(
      source: 'Codex',
      message: '实时状态已完成',
      detail: '包含开始与结束时间。',
      completedAt: completedAt,
      conversationTarget: const AgentConversationTarget(
        client: AgentClient.codex,
        conversationId: 'thread-1',
        workspacePath: '/workspace/dingdong',
      ),
    );

    expect(controller.activeRuns, isEmpty);
    expect(completion.notificationId, 'run-1');
    expect(completion.activity.task, '实现实时任务状态');
    expect(completion.activity.startedAt, startedAt);
    expect(completion.activity.completedAt, completedAt);
    expect(completion.activity.detail, '包含开始与结束时间。');
  });

  test('activity preserves a response waiting for user input', () {
    final ActivityController controller = ActivityController(
      idGenerator: () => 'attention-1',
    );

    final AgentCompletionRecord record = controller.record(
      source: 'Codex',
      message: '等待你确认下一步操作',
      notificationKind: AgentNotificationKind.attention,
    );

    expect(record.activity.notificationKind, AgentNotificationKind.attention);
    expect(record.activity.needsUserAttention, isTrue);
    expect(controller.recentCount, 0);
  });

  test(
    'repeated starts without a conversation id replace the same running chat',
    () {
      var id = 0;
      final ActivityController controller = ActivityController(
        idGenerator: () => 'run-${++id}',
      );

      for (var round = 1; round <= 8; round += 1) {
        controller.recordTaskStarted(
          source: 'Codex',
          task: '第 $round 轮对话',
          startedAt: DateTime.utc(2026, 8, 11, 9, round),
          workspacePath: '/workspace/dingdong',
        );
      }

      expect(controller.activeRuns, hasLength(1));
      expect(controller.activeRuns.single.id, 'run-8');
      expect(controller.activeRuns.single.task, '第 8 轮对话');
    },
  );

  test('missing conversation ids stay isolated between Agent clients', () {
    var id = 0;
    final ActivityController controller = ActivityController(
      idGenerator: () => 'run-${++id}',
    );

    controller.recordTaskStarted(
      source: 'Codex',
      task: 'Codex task',
      startedAt: DateTime.utc(2026, 8, 11, 9),
      workspacePath: '/workspace/dingdong',
    );
    controller.recordTaskStarted(
      source: 'Claude Code',
      task: 'Claude task',
      startedAt: DateTime.utc(2026, 8, 11, 9, 5),
      workspacePath: '/workspace/dingdong',
    );

    expect(controller.activeRuns, hasLength(2));
  });

  test('conversation id closes only its matching running task', () {
    var id = 0;
    final ActivityController controller = ActivityController(
      idGenerator: () => 'run-${++id}',
      now: () => DateTime.utc(2026, 8, 11, 10),
    );
    controller.recordTaskStarted(
      source: 'Codex',
      task: '第一项任务',
      startedAt: DateTime.utc(2026, 8, 11, 9),
      conversationId: 'thread-1',
    );
    controller.recordTaskStarted(
      source: 'Codex',
      task: '第二项任务',
      startedAt: DateTime.utc(2026, 8, 11, 9, 5),
      conversationId: 'thread-2',
    );

    controller.record(
      source: 'Codex',
      message: '第一项完成',
      conversationTarget: const AgentConversationTarget(
        client: AgentClient.codex,
        conversationId: 'thread-1',
      ),
    );

    expect(controller.activeRuns.single.task, '第二项任务');
    expect(controller.activities.single.task, '第一项任务');
  });

  test('filtered completion discards only its matching running task', () {
    final ActivityController controller = ActivityController();
    controller.recordTaskStarted(
      source: 'Codex',
      task: 'Main task',
      startedAt: DateTime.utc(2026, 8, 13, 9),
      conversationId: 'main-thread',
    );
    controller.recordTaskStarted(
      source: 'Codex',
      task: 'Subagent task',
      startedAt: DateTime.utc(2026, 8, 13, 9, 1),
      conversationId: 'subagent-thread',
    );

    expect(
      controller.discardActiveRun(
        source: 'Codex',
        target: const AgentConversationTarget(
          client: AgentClient.codex,
          conversationId: 'subagent-thread',
        ),
      ),
      isTrue,
    );

    expect(controller.activeRuns, hasLength(1));
    expect(controller.activeRuns.single.task, 'Main task');
    expect(controller.activities, isEmpty);
    expect(controller.unseenCount, 0);
    expect(controller.recentCount, 0);
  });

  test('filtered subagent completion never discards a main task', () {
    final ActivityController controller = ActivityController();
    controller.recordTaskStarted(
      source: 'Codex',
      task: 'Main task',
      startedAt: DateTime.utc(2026, 8, 13, 9),
      workspacePath: '/workspace',
      conversationId: 'main-thread',
    );

    expect(
      controller.discardActiveRun(
        source: 'Codex',
        target: const AgentConversationTarget(
          client: AgentClient.codex,
          conversationId: 'subagent-thread',
          workspacePath: '/workspace',
        ),
      ),
      isFalse,
    );

    expect(controller.activeRuns, hasLength(1));
    expect(controller.activeRuns.single.task, 'Main task');
  });

  test('conversation ids are isolated between known Agent clients', () {
    var id = 0;
    final ActivityController controller = ActivityController(
      idGenerator: () => 'run-${++id}',
      now: () => DateTime.utc(2026, 8, 11, 10),
    );
    controller.recordTaskStarted(
      source: 'Codex',
      task: 'Codex task',
      startedAt: DateTime.utc(2026, 8, 11, 9),
      conversationId: 'shared-conversation-id',
    );
    controller.recordTaskStarted(
      source: 'Claude Code',
      task: 'Claude task',
      startedAt: DateTime.utc(2026, 8, 11, 9, 5),
      conversationId: 'shared-conversation-id',
    );

    expect(controller.activeRuns, hasLength(2));

    controller.record(
      source: 'Claude Code',
      message: 'Claude task complete',
      conversationTarget: const AgentConversationTarget(
        client: AgentClient.claudeCode,
        conversationId: 'shared-conversation-id',
      ),
    );

    expect(controller.activeRuns.single.source, 'Codex');
    expect(controller.activities.single.task, 'Claude task');

    controller.record(
      source: 'Codex',
      message: 'Codex task complete',
      conversationTarget: const AgentConversationTarget(
        client: AgentClient.codex,
        conversationId: 'shared-conversation-id',
      ),
    );

    expect(controller.activeRuns, isEmpty);
    expect(controller.activities, hasLength(2));
    expect(controller.activities.first.task, 'Codex task');
  });

  test('notification stays unseen until the Dynamic reveal finishes', () {
    final ActivityController controller = ActivityController(
      idGenerator: () => 'activity-1',
      now: () => DateTime.utc(2026, 7, 12, 10),
    );

    controller.record(source: 'Codex', message: 'Build complete');

    expect(controller.activities.single.source, 'Codex');
    expect(controller.activities.single.message, 'Build complete');
    expect(controller.unseenCount, 1);

    controller.requestReveal();
    expect(controller.revealRevision, 1);
    expect(controller.unseenCount, 1);

    controller.markAllSeen();
    expect(controller.unseenCount, 0);
    expect(controller.activities.single.unseen, isFalse);
  });

  test('suppressed completion hook enriches the latest matching item', () {
    final ActivityController controller = ActivityController(
      idGenerator: () => 'activity-1',
      now: () => DateTime.utc(2026, 7, 12, 10),
    );
    controller.record(source: 'Codex', message: 'Build complete');

    controller.attachConversationTarget(
      source: 'Codex',
      target: const AgentConversationTarget(
        client: AgentClient.codex,
        conversationId: 'thread-1',
        workspacePath: '/workspace/dingdong',
      ),
    );

    expect(controller.activities, hasLength(1));
    expect(
      controller.activities.single.conversationTarget?.conversationId,
      'thread-1',
    );
    expect(controller.recentCount, 1);
  });

  test('same conversation is one recent item with a repeat count', () {
    DateTime now = DateTime.utc(2026, 7, 12, 10);
    final ActivityController controller = ActivityController(
      idGenerator: () => 'activity-1',
      now: () => now,
    );
    const AgentConversationTarget target = AgentConversationTarget(
      client: AgentClient.codex,
      conversationId: 'thread-1',
      workspacePath: '/workspace/dingdong',
    );

    controller.record(
      source: 'Codex',
      message: 'First reminder',
      conversationTarget: target,
      tokenUsage: const ConversationTokenUsage(
        source: ConversationTokenUsageSource.codex,
        totalTokens: 1000,
      ),
    );
    now = now.add(const Duration(seconds: 2));
    controller.record(
      source: 'Codex',
      message: 'Second reminder',
      conversationTarget: target,
      tokenUsage: const ConversationTokenUsage(
        source: ConversationTokenUsageSource.codex,
        totalTokens: 2500,
      ),
    );

    expect(controller.activities, hasLength(1));
    expect(controller.activities.single.id, 'activity-1');
    expect(controller.activities.single.message, 'Second reminder');
    expect(controller.activities.single.repeatCount, 2);
    expect(controller.activities.single.tokenUsage?.totalTokens, 2500);
    expect(controller.activities.single.completedAt, now.toUtc());
    expect(controller.recentCount, 1);
  });

  test('grouping can be disabled to count repeated sessions separately', () {
    var id = 0;
    final ActivityController controller = ActivityController(
      groupRepeatedAgentSessions: false,
      idGenerator: () => 'activity-${id++}',
      now: () => DateTime.utc(2026, 7, 12, 10),
    );
    const AgentConversationTarget target = AgentConversationTarget(
      client: AgentClient.codex,
      conversationId: 'thread-1',
    );

    controller.record(
      source: 'Codex',
      message: 'First reminder',
      conversationTarget: target,
    );
    controller.record(
      source: 'Codex',
      message: 'Second reminder',
      conversationTarget: target,
    );

    expect(controller.activities, hasLength(2));
    expect(
      controller.activities.every((item) => item.repeatCount == 1),
      isTrue,
    );
    expect(controller.recentCount, 2);
  });

  test(
    'suppressed completion hook repeats an existing item without counting it',
    () {
      final ActivityController controller = ActivityController(
        idGenerator: () => 'activity-1',
        now: () => DateTime.utc(2026, 7, 12, 10),
      );
      controller.record(source: 'Codex', message: 'Primary reminder');

      controller.recordRepeat(
        source: 'Codex',
        message: 'Fallback reminder',
        target: const AgentConversationTarget(
          client: AgentClient.codex,
          conversationId: 'thread-1',
          workspacePath: '/workspace/dingdong',
        ),
      );

      expect(controller.activities, hasLength(1));
      expect(controller.activities.single.repeatCount, 2);
      expect(controller.activities.single.message, 'Fallback reminder');
      expect(
        controller.activities.single.conversationTarget?.conversationId,
        'thread-1',
      );
      expect(controller.recentCount, 1);
    },
  );

  test('detail retention defaults to 500 without capping the recent count', () {
    var id = 0;
    final DateTime now = DateTime.utc(2026, 7, 21, 10);
    final ActivityController controller = ActivityController(
      idGenerator: () => 'activity-${id++}',
      now: () => now,
    );

    for (var index = 0; index < 505; index += 1) {
      controller.record(source: 'Agent', message: 'Task $index');
    }

    expect(controller.activities, hasLength(500));
    expect(controller.activities.first.message, 'Task 504');
    expect(controller.activities.last.message, 'Task 5');
    expect(controller.recentCount, 505);
  });

  test('recent count follows the configurable rolling hour window', () {
    DateTime now = DateTime.utc(2026, 7, 21, 10);
    var id = 0;
    final ActivityController controller = ActivityController(
      idGenerator: () => 'activity-${id++}',
      now: () => now,
      countWindowHours: 2,
    );

    controller.record(source: 'Codex', message: 'Older');
    now = now.add(const Duration(hours: 3));
    controller.record(source: 'Codex', message: 'Recent');

    expect(controller.recentCount, 1);
    controller.configure(
      rememberAcrossRestarts: true,
      maxItems: 200,
      countWindowHours: 4,
    );
    expect(controller.recentCount, 2);
  });

  test('history survives restart when remembering is enabled', () {
    final InMemoryAgentActivityStore store = InMemoryAgentActivityStore();
    final DateTime now = DateTime.utc(2026, 7, 21, 10);
    final ActivityController first = ActivityController(
      store: store,
      idGenerator: () => 'persisted',
      now: () => now,
    )..load(resetPreviousSession: true);
    first.record(source: 'Codex', message: 'Persist me');

    final ActivityController restarted = ActivityController(
      store: store,
      now: () => now,
    )..load(resetPreviousSession: true);

    expect(restarted.activities.single.message, 'Persist me');
    expect(restarted.recentCount, 1);
  });

  test('history starts clean after restart when remembering is disabled', () {
    final InMemoryAgentActivityStore store = InMemoryAgentActivityStore();
    final DateTime now = DateTime.utc(2026, 7, 21, 10);
    final ActivityController first = ActivityController(
      store: store,
      idGenerator: () => 'session-only',
      now: () => now,
      rememberAcrossRestarts: false,
    )..load(resetPreviousSession: true);
    first.record(source: 'Claude', message: 'Current session');
    expect(store.history.activities, hasLength(1));

    final ActivityController restarted = ActivityController(
      store: store,
      now: () => now,
      rememberAcrossRestarts: false,
    )..load(resetPreviousSession: true);

    expect(restarted.activities, isEmpty);
    expect(restarted.recentCount, 0);
  });

  test('explicit clear removes current and persisted activity history', () {
    final InMemoryAgentActivityStore store = InMemoryAgentActivityStore();
    final ActivityController controller = ActivityController(
      store: store,
      idGenerator: () => 'activity-1',
      now: () => DateTime.utc(2026, 7, 21, 10),
    )..load();
    controller.record(source: 'Codex', message: 'Build complete');

    controller.clear();

    expect(controller.activities, isEmpty);
    expect(controller.recentCount, 0);
    expect(controller.unseenCount, 0);
    expect(store.history.activities, isEmpty);
    expect(store.history.completionTimes, isEmpty);
  });
}
