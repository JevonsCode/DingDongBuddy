import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/shell/domain/tray_buddy_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'reminder state nudges every interval after five-minute delay',
    () async {
      final ActivityController activityController = ActivityController();
      final List<TrayBuddyState> states = <TrayBuddyState>[];
      var nudgeCount = 0;
      final TrayBuddyController buddy = TrayBuddyController(
        activityController: activityController,
        reminderDelay: const Duration(milliseconds: 15),
        reminderRepeatInterval: const Duration(milliseconds: 20),
        agentRestDelay: const Duration(days: 1),
        clipboardIdleDelay: const Duration(days: 1),
        onStateChanged: (TrayBuddyState state) async => states.add(state),
        onReminderNudge: () async => nudgeCount += 1,
      );
      addTearDown(() {
        buddy.dispose();
        activityController.dispose();
      });

      buddy.start();
      activityController.record(source: 'Codex', message: 'Task complete');

      expect(states.last, TrayBuddyState.reminder);
      expect(nudgeCount, 0);
      await Future<void>.delayed(const Duration(milliseconds: 75));
      expect(nudgeCount, greaterThanOrEqualTo(2));

      activityController.markAllSeen();
      final int stoppedAt = nudgeCount;
      await Future<void>.delayed(const Duration(milliseconds: 55));
      expect(nudgeCount, stoppedAt);
      expect(states.last, TrayBuddyState.normal);
    },
  );

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

  test(
    'clipboard inactivity switches to sleeping without an animation',
    () async {
      final ActivityController activityController = ActivityController();
      final List<TrayBuddyState> states = <TrayBuddyState>[];
      final TrayBuddyController buddy = TrayBuddyController(
        activityController: activityController,
        reminderDelay: const Duration(days: 1),
        agentRestDelay: const Duration(days: 1),
        clipboardIdleDelay: const Duration(milliseconds: 15),
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
      expect(states.last, TrayBuddyState.sleeping);

      buddy.recordClipboardActivity(DateTime.now());
      expect(states.last, TrayBuddyState.normal);
    },
  );

  test('five minutes without an Agent reminder switches to resting', () async {
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

  test('reminder overrides sleeping and sleeping returns after it is seen', () {
    final DateTime now = DateTime.utc(2026, 8, 7, 12);
    final ActivityController activityController = ActivityController(
      now: () => now,
    );
    final List<TrayBuddyState> states = <TrayBuddyState>[];
    final TrayBuddyController buddy = TrayBuddyController(
      activityController: activityController,
      now: () => now,
      onStateChanged: (TrayBuddyState state) async => states.add(state),
      onReminderNudge: () async {},
    );
    addTearDown(() {
      buddy.dispose();
      activityController.dispose();
    });

    activityController.record(source: 'Codex', message: 'Task complete');
    buddy.start(lastClipboardActivity: now.subtract(const Duration(hours: 1)));
    expect(states.last, TrayBuddyState.reminder);

    activityController.markAllSeen();
    expect(states.last, TrayBuddyState.sleeping);
  });
}
