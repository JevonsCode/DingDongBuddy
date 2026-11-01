import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/reminder_card_border.dart';
import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/activity/ui/agent_activity_manager_screen.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';
import 'package:dingdong/features/settings/domain/tray_reminder_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _target = AgentConversationTarget(
  client: AgentClient.codex,
  conversationId: 'original-conversation',
);
const _reminder = ReminderProfile(
  id: 'review',
  name: 'Review',
  color: TrayNotificationColor.pink,
);

void main() {
  testWidgets(
    'only notifications above the visit divider keep colored borders',
    (tester) async {
      var id = 0;
      final c = ActivityController(idGenerator: () => 'visit-${++id}')..load();
      final launcher = _Launcher();
      final visible = ValueNotifier(true);
      addTearDown(c.dispose);
      addTearDown(launcher.dispose);
      addTearDown(visible.dispose);
      final old = c
          .record(source: 'History', message: 'Earlier', reminder: _reminder)
          .activity;
      c.markFeedViewed(c.latestSequence);
      final fresh = c
          .record(
            source: 'Codex',
            message: 'This visit',
            conversationTarget: _target,
            reminder: _reminder,
          )
          .activity;
      await tester.pumpWidget(
        DingDongApp(
          activityController: c,
          agentConversationLauncher: launcher,
          windowVisible: visible,
        ),
      );
      await tester.pumpAndSettle();
      Color outline(AgentActivity a) =>
          ((tester
                              .widget<Container>(
                                find.byKey(Key('activity-${a.id}')),
                              )
                              .decoration!
                          as ShapeDecoration)
                      .shape
                  as ReminderCardBorder)
              .side
              .color;
      final gray = PopupStyle.of(
        tester.element(find.byKey(Key('activity-${old.id}'))),
      ).border;
      final pink = Color(0xff000000 | _reminder.color.rgbValue);
      expect(outline(old), gray);
      expect(outline(fresh), pink);
      expect(
        find.byKey(const Key('activity-last-seen-divider')),
        findsOneWidget,
      );
      c.markAllSeen();
      c.markOpened(fresh);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      expect(outline(old), gray);
      expect(outline(fresh), pink);
      visible.value = false;
      await tester.pumpAndSettle();
      final newest = c
          .record(source: 'Other', message: 'Next visit', reminder: _reminder)
          .activity;
      visible.value = true;
      await tester.pumpAndSettle();
      expect(outline(fresh), gray);
      expect(outline(newest), pink);
      expect(
        find.byKey(const Key('activity-last-seen-divider')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      c.clear();
    },
  );

  testWidgets(
    'manager forwards acknowledgements to the host without losing newer notifications',
    (tester) async {
      final store = InMemoryAgentActivityStore();
      var id = 0;
      final host = ActivityController(
        store: store,
        idGenerator: () => 'notification-${++id}',
        now: () => DateTime.utc(2026, 10, 30),
      )..load();
      _record(host, 'Ready');
      final auxiliary = ActivityController(store: store, persistHistory: false)
        ..load();
      final launcher = _Launcher();
      addTearDown(host.dispose);
      addTearDown(auxiliary.dispose);
      addTearDown(launcher.dispose);
      var visits = 0;
      await tester.pumpWidget(
        _view(
          auxiliary,
          launcher,
          true,
          onOpened: (activity) async {
            host.markOpened(activity);
            auxiliary.reload();
          },
          onViewed: (sequence) async {
            visits++;
            host.markFeedViewed(sequence);
            auxiliary.reload();
          },
        ),
      );
      await tester.pumpAndSettle();
      host.record(
        source: 'Other',
        message: 'Newer host notification',
        completedAt: DateTime.utc(2026, 10, 2),
      );
      await tester.tap(find.text('Ready'));
      await tester.pumpAndSettle();
      expect(store.load().activities, hasLength(2));
      expect(
        host.activities.singleWhere((item) => item.message == 'Ready').opened,
        isTrue,
      );
      expect(find.text('Newer host notification'), findsOneWidget);
      expect(visits, 2);
    },
  );

  for (final manager in [false, true]) {
    final surface = manager ? 'manager' : 'compact';
    testWidgets('$surface colors only successfully opened notifications', (
      tester,
    ) async {
      final c = _controller();
      final launcher = _Launcher();
      addTearDown(c.dispose);
      addTearDown(launcher.dispose);
      _record(c, 'Ready');
      await tester.pumpWidget(_view(c, launcher, manager));
      await tester.pumpAndSettle();
      final icon = find.byKey(
        Key(
          manager
              ? 'agent-activity-manager-open-conversation'
              : 'activity-open-conversation',
        ),
      );
      final before = tester.widget<Icon>(icon).color;
      c.markAllSeen();
      await tester.pumpAndSettle();
      expect(c.activities.single.opened, isFalse);
      if (!manager) {
        // The reveal/seen transition must not leave only a momentary outline.
        await tester.pump(const Duration(seconds: 5));
        final card = tester.widget<Container>(_row(false));
        final border =
            (card.decoration! as ShapeDecoration).shape as ReminderCardBorder;
        expect(border.side.color, Color(0xff000000 | _reminder.color.rgbValue));
      }
      await tester.tap(_row(manager));
      await tester.pumpAndSettle();
      expect(c.activities.single.opened, isTrue);
      if (!manager) {
        final card = tester.widget<Container>(_row(false));
        final border =
            (card.decoration! as ShapeDecoration).shape as ReminderCardBorder;
        expect(border.side.color, Color(0xff000000 | _reminder.color.rgbValue));
      }
      expect(
        tester.widget<Icon>(icon).color,
        Color(0xff000000 | _reminder.color.rgbValue),
      );
      expect(
        find.byTooltip('Opened · Open conversation again'),
        findsOneWidget,
      );
      _record(c, 'A newer update');
      await tester.pumpAndSettle();
      expect(c.activities.single.opened, isFalse);
      expect(tester.widget<Icon>(icon).color, before);
      expect(find.byTooltip('Opened · Open conversation again'), findsNothing);
    });

    testWidgets('$surface leaves a failed launch unopened', (tester) async {
      final c = _controller();
      final launcher = _Launcher()..fail = true;
      addTearDown(c.dispose);
      addTearDown(launcher.dispose);
      _record(c, 'Ready');
      await tester.pumpWidget(_view(c, launcher, manager));
      await tester.pumpAndSettle();
      await tester.tap(_row(manager));
      await tester.pump();
      expect(c.activities.single.opened, isFalse);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets(
      '$surface does not open a notification received during launch',
      (tester) async {
        final c = _controller();
        final pending = Completer<void>();
        final launcher = _Launcher()..pending = pending;
        addTearDown(c.dispose);
        addTearDown(launcher.dispose);
        _record(c, 'Ready');
        await tester.pumpWidget(_view(c, launcher, manager));
        await tester.pumpAndSettle();
        await tester.tap(_row(manager));
        await tester.pump();
        _record(c, 'Received while opening');
        pending.complete();
        await tester.pumpAndSettle();
        expect(c.activities.single.message, 'Received while opening');
        expect(c.activities.single.opened, isFalse);
      },
    );
  }
}

ActivityController _controller() => ActivityController(
  idGenerator: () => 'notification',
  now: () => DateTime.utc(2026, 10, 30),
)..load();

void _record(ActivityController c, String message) => c.record(
  source: 'Codex',
  message: message,
  completedAt: DateTime.utc(2026, 10, 1),
  conversationTarget: _target,
  reminder: _reminder,
);

Finder _row(bool manager) => find.byKey(
  Key(manager ? 'agent-activity-row-notification' : 'activity-notification'),
);

Widget _view(
  ActivityController c,
  _Launcher launcher,
  bool manager, {
  Future<void> Function(AgentActivity)? onOpened,
  Future<void> Function(int)? onViewed,
}) => manager
    ? MaterialApp(
        localizationsDelegates: DingDongLocalizations.localizationsDelegates,
        supportedLocales: DingDongLocalizations.supportedLocales,
        home: Scaffold(
          body: AgentActivityManagerScreen(
            controller: c,
            conversationLauncher: launcher,
            onActivityOpened: onOpened,
            onActivityViewed: onViewed,
          ),
        ),
      )
    : DingDongApp(activityController: c, agentConversationLauncher: launcher);

final class _Launcher extends ChangeNotifier
    implements AgentConversationLauncher {
  bool fail = false;
  Completer<void>? pending;
  @override
  bool canOpen(AgentConversationTarget target) => true;
  @override
  bool isSubagent(AgentConversationTarget target) => false;
  @override
  Future<void> open(AgentConversationTarget target) async {
    if (fail) throw StateError('Launch failed');
    await pending?.future;
  }
}
