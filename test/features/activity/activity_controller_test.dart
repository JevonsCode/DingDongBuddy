import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  test('detail retention defaults to 200 without capping the recent count', () {
    var id = 0;
    final DateTime now = DateTime.utc(2026, 7, 21, 10);
    final ActivityController controller = ActivityController(
      idGenerator: () => 'activity-${id++}',
      now: () => now,
    );

    for (var index = 0; index < 205; index += 1) {
      controller.record(source: 'Agent', message: 'Task $index');
    }

    expect(controller.activities, hasLength(200));
    expect(controller.activities.first.message, 'Task 204');
    expect(controller.activities.last.message, 'Task 5');
    expect(controller.recentCount, 205);
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
}
