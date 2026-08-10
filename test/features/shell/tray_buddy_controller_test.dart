import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/shell/domain/tray_buddy_controller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default idle thresholds are three minutes and five minutes', () {
    expect(trayBuddyAgentRestDelay, const Duration(minutes: 3));
    expect(trayBuddyClipboardIdleDelay, const Duration(minutes: 5));
  });

  test('reminder state nudges every interval after five-minute delay', () {
    fakeAsync((FakeAsync time) {
      final DateTime startedAt = DateTime.utc(2026, 8, 10, 12);
      DateTime now() => startedAt.add(time.elapsed);
      final ActivityController activityController = ActivityController(
        now: now,
      );
      final List<TrayBuddyState> states = <TrayBuddyState>[];
      var nudgeCount = 0;
      final TrayBuddyController buddy = TrayBuddyController(
        activityController: activityController,
        now: now,
        reminderDelay: const Duration(milliseconds: 15),
        reminderRepeatInterval: const Duration(milliseconds: 20),
        agentRestDelay: const Duration(days: 1),
        clipboardIdleDelay: const Duration(days: 1),
        onStateChanged: (TrayBuddyState state) async => states.add(state),
        onReminderNudge: () async => nudgeCount += 1,
      );

      try {
        buddy.start();
        activityController.record(source: 'Codex', message: 'Task complete');

        expect(states.last, TrayBuddyState.reminder);
        expect(nudgeCount, 0);
        time.elapse(const Duration(milliseconds: 75));
        expect(nudgeCount, greaterThanOrEqualTo(2));

        activityController.markAllSeen();
        final int stoppedAt = nudgeCount;
        time.elapse(const Duration(milliseconds: 55));
        expect(nudgeCount, stoppedAt);
        expect(states.last, TrayBuddyState.normal);
      } finally {
        buddy.dispose();
        activityController.dispose();
      }
    });
  });

  test('an overdue reminder on launch nudges immediately', () {
    final DateTime now = DateTime.utc(2026, 8, 7, 12);
    final ActivityController activityController = ActivityController(
      store: InMemoryAgentActivityStore(
        AgentActivityHistory(
          activities: <AgentActivity>[
            AgentActivity(
              id: 'late-reminder',
              source: 'Codex',
              message: 'Task complete',
              completedAt: now.subtract(const Duration(minutes: 6)),
              unseen: true,
            ),
          ],
        ),
      ),
      now: () => now,
    )..load();
    final List<TrayBuddyState> states = <TrayBuddyState>[];
    var nudgeCount = 0;
    final TrayBuddyController buddy = TrayBuddyController(
      activityController: activityController,
      now: () => now,
      onStateChanged: (TrayBuddyState state) async => states.add(state),
      onReminderNudge: () async => nudgeCount += 1,
    );
    addTearDown(() {
      buddy.dispose();
      activityController.dispose();
    });

    buddy.start(lastClipboardActivity: now);

    expect(states.last, TrayBuddyState.reminder);
    expect(nudgeCount, 1);
  });

  test('launch starts normal then progresses through rest and sleep', () async {
    final ActivityController activityController = ActivityController();
    final List<TrayBuddyState> states = <TrayBuddyState>[];
    final TrayBuddyController buddy = TrayBuddyController(
      activityController: activityController,
      reminderDelay: const Duration(days: 1),
      agentRestDelay: const Duration(milliseconds: 20),
      clipboardIdleDelay: const Duration(milliseconds: 50),
      onStateChanged: (TrayBuddyState state) async => states.add(state),
      onReminderNudge: () async {},
    );
    addTearDown(() {
      buddy.dispose();
      activityController.dispose();
    });

    buddy.start(
      lastClipboardActivity: DateTime.now().subtract(const Duration(days: 1)),
    );
    expect(states.last, TrayBuddyState.normal);
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(states.last, TrayBuddyState.resting);
    await Future<void>.delayed(const Duration(milliseconds: 35));
    expect(states.last, TrayBuddyState.sleeping);

    buddy.recordClipboardActivity(DateTime.now());
    expect(states.last, TrayBuddyState.normal);
  });

  test('three minutes without activity switches to resting', () async {
    final ActivityController activityController = ActivityController();
    final List<TrayBuddyState> states = <TrayBuddyState>[];
    final TrayBuddyController buddy = TrayBuddyController(
      activityController: activityController,
      reminderDelay: const Duration(days: 1),
      reminderRepeatInterval: const Duration(days: 1),
      agentRestDelay: const Duration(milliseconds: 15),
      clipboardIdleDelay: const Duration(days: 1),
      onStateChanged: (TrayBuddyState state) async => states.add(state),
      onReminderNudge: () async {},
    );
    addTearDown(() {
      buddy.dispose();
      activityController.dispose();
    });

    buddy.start(lastClipboardActivity: DateTime.now());
    expect(states.last, TrayBuddyState.normal);
    await Future<void>.delayed(const Duration(milliseconds: 45));
    expect(states.last, TrayBuddyState.resting);
  });

  test(
    'acknowledging a reminder wakes the mascot and restarts idle time',
    () async {
      final ActivityController activityController = ActivityController();
      final List<TrayBuddyState> states = <TrayBuddyState>[];
      final TrayBuddyController buddy = TrayBuddyController(
        activityController: activityController,
        reminderDelay: const Duration(days: 1),
        agentRestDelay: const Duration(milliseconds: 20),
        clipboardIdleDelay: const Duration(milliseconds: 50),
        onStateChanged: (TrayBuddyState state) async => states.add(state),
        onReminderNudge: () async {},
      );
      addTearDown(() {
        buddy.dispose();
        activityController.dispose();
      });

      buddy.start();
      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(states.last, TrayBuddyState.sleeping);

      activityController.record(source: 'Codex', message: 'Task complete');
      expect(states.last, TrayBuddyState.reminder);

      activityController.markAllSeen();
      expect(states.last, TrayBuddyState.normal);
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(states.last, TrayBuddyState.resting);
      await Future<void>.delayed(const Duration(milliseconds: 35));
      expect(states.last, TrayBuddyState.sleeping);
    },
  );
}
