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

  test('activity history is bounded to the latest twenty completions', () {
    var id = 0;
    final ActivityController controller = ActivityController(
      idGenerator: () => 'activity-${id++}',
    );

    for (var index = 0; index < 25; index += 1) {
      controller.record(source: 'Agent', message: 'Task $index');
    }

    expect(controller.activities, hasLength(20));
    expect(controller.activities.first.message, 'Task 24');
    expect(controller.activities.last.message, 'Task 5');
  });
}
