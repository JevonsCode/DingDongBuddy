import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/widgets/reminder_card_border.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';
import 'package:dingdong/features/settings/domain/tray_reminder_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const AgentConversationTarget _target = AgentConversationTarget(
  client: AgentClient.codex,
  conversationId: 'gradient-conversation',
);

const ReminderProfile _blue = ReminderProfile(
  id: 'attention',
  name: 'Attention',
  color: TrayNotificationColor.blue,
);

const ReminderProfile _purple = ReminderProfile(
  id: 'completion',
  name: 'Completion',
  color: TrayNotificationColor.purple,
);

void _remind(ActivityController controller, ReminderProfile reminder) {
  controller.record(
    source: 'Codex',
    message: 'Update',
    conversationTarget: _target,
    reminder: reminder,
  );
}

void main() {
  test('a conversation keeps distinct reminder colors in arrival order', () {
    final ActivityController controller = ActivityController(
      idGenerator: () => 'gradient-agent',
    );
    _remind(controller, _blue);
    _remind(controller, _blue);
    _remind(controller, _purple);
    _remind(controller, _blue);

    final AgentActivity activity = controller.activities.single;
    expect(activity.reminderColors, <TrayNotificationColor>[
      TrayNotificationColor.blue,
      TrayNotificationColor.purple,
    ]);
    expect(
      AgentActivity.fromJson(activity.toJson()).reminderColors,
      activity.reminderColors,
    );
    controller.dispose();
  });

  test('the batch count survives seen and restarts with the next batch', () {
    final ActivityController controller = ActivityController(
      idGenerator: () => 'batch-agent',
    );
    for (int index = 0; index < 10; index += 1) {
      _remind(controller, _blue);
    }
    controller.markAllSeen();

    AgentActivity activity = controller.activities.single;
    expect(activity.unseenReminderCount, 0);
    expect(activity.recentReminderCount, 10);
    expect(AgentActivity.fromJson(activity.toJson()).recentReminderCount, 10);

    _remind(controller, _purple);
    activity = controller.activities.single;
    expect(activity.recentReminderCount, 1);
    expect(activity.repeatCount, 11);
    controller.dispose();
  });

  test('older records without a color history fall back to the reminder', () {
    final AgentActivity legacy = AgentActivity.fromJson(<String, Object?>{
      'id': 'legacy',
      'source': 'Codex',
      'message': 'Done',
      'completedAt': '2026-11-01T00:00:00Z',
      'unseen': false,
      'repeatCount': 4,
      'reminder': _purple.toJson(),
    });
    expect(legacy.reminderColors, <TrayNotificationColor>[
      TrayNotificationColor.purple,
    ]);
    expect(legacy.recentReminderCount, 0);
  });

  testWidgets('recent card blends reminder colors and shows the batch count', (
    WidgetTester tester,
  ) async {
    final ActivityController controller = ActivityController(
      idGenerator: () => 'gradient-card',
      now: () => DateTime.utc(2026, 11, 11, 10),
    );
    for (int index = 0; index < 9; index += 1) {
      _remind(controller, _blue);
    }
    _remind(controller, _purple);

    await tester.pumpWidget(DingDongApp(activityController: controller));
    await tester.pump();

    final Finder card = find.byKey(const Key('activity-gradient-card'));
    expect(
      find.descendant(of: card, matching: find.text('+10')),
      findsOneWidget,
    );
    expect(find.descendant(of: card, matching: find.text('×10')), findsNothing);
    expect(
      find.descendant(of: card, matching: find.byType(ShaderMask)),
      findsOneWidget,
    );
    final ShapeDecoration decoration =
        tester.widget<Container>(card).decoration! as ShapeDecoration;
    final ReminderCardBorder border = decoration.shape as ReminderCardBorder;
    expect((border.gradient! as LinearGradient).colors, <Color>[
      Color(0xff000000 | TrayNotificationColor.blue.rgbValue),
      Color(0xff000000 | TrayNotificationColor.purple.rgbValue),
    ]);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
