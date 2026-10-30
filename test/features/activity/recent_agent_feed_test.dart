import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/activity/ui/recent_agent_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opening a later page retains its rows and loaded range', (
    tester,
  ) async {
    final c = _controller();
    addTearDown(c.dispose);
    c.record(source: 'Codex', message: 'Page one A');
    c.record(source: 'Codex', message: 'Page one B');
    final later = c.record(source: 'Codex', message: 'Page two').activity;
    await tester.pumpWidget(_view(c, pageSize: 2));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('recent-agent-load-more')));
    await tester.pumpAndSettle();
    expect(find.text('Page two'), findsOneWidget);
    c.markOpened(later);
    await tester.pumpAndSettle();
    expect(find.text('Page two'), findsOneWidget);
    expect(find.byKey(const Key('recent-agent-load-more')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    c.clear();
  });

  testWidgets('the first visit has no invented historical divider', (
    tester,
  ) async {
    final c = _controller();
    addTearDown(c.dispose);
    c.record(source: 'Codex', message: 'First notification');
    await tester.pumpWidget(_view(c));
    await tester.pumpAndSettle();
    expect(find.text('上次看到这里'), findsNothing);
    expect(c.lastViewedSequence, c.latestSequence);
    expect(c.activities.single.opened, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    c.clear();
  });

  testWidgets(
    'ten new updates are separated from the eleventh historical row',
    (tester) async {
      final c = _controller();
      addTearDown(c.dispose);
      c.record(source: 'Codex', message: 'Historical');
      c.markFeedViewed(c.latestSequence);
      for (var i = 1; i <= 10; i++) {
        c.record(source: 'Codex', message: 'New $i');
      }
      await tester.pumpWidget(_view(c));
      await tester.pumpAndSettle();
      final divider = find.text('上次看到这里');
      expect(divider, findsOneWidget);
      expect(
        tester.getTopLeft(divider).dy,
        greaterThan(tester.getTopLeft(find.text('New 10')).dy),
      );
      expect(
        tester.getTopLeft(divider).dy,
        lessThan(tester.getTopLeft(find.text('Historical')).dy),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      c.clear();
    },
  );

  testWidgets(
    'opening items and receiving updates keep this visit boundary fixed',
    (tester) async {
      final c = _controller();
      addTearDown(c.dispose);
      c.record(source: 'Codex', message: 'Historical');
      c.markFeedViewed(c.latestSequence);
      final first = c
          .record(source: 'Codex', message: 'First new update')
          .activity;
      await tester.pumpWidget(_view(c));
      await tester.pumpAndSettle();
      c.markOpened(first);
      c.record(source: 'Codex', message: 'Arrived while browsing');
      await tester.pumpAndSettle();
      final divider = find.text('上次看到这里');
      expect(divider, findsOneWidget);
      for (final message in ['First new update', 'Arrived while browsing']) {
        expect(
          tester.getTopLeft(find.text(message)).dy,
          lessThan(tester.getTopLeft(divider).dy),
        );
      }
      expect(c.lastViewedSequence, c.latestSequence);
      await tester.pumpWidget(const SizedBox.shrink());
      c.clear();
    },
  );

  testWidgets(
    'hidden views do not consume new messages and reopening captures a new visit',
    (tester) async {
      final c = _controller();
      addTearDown(c.dispose);
      c.record(source: 'Codex', message: 'Historical');
      c.markFeedViewed(c.latestSequence);
      final previous = c.lastViewedSequence;
      await tester.pumpWidget(_view(c, visible: false));
      c.record(source: 'Codex', message: 'While hidden');
      await tester.pumpAndSettle();
      expect(c.lastViewedSequence, previous);
      await tester.pumpWidget(_view(c));
      await tester.pumpAndSettle();
      expect(find.text('上次看到这里'), findsOneWidget);
      final viewed = c.lastViewedSequence;
      await tester.pumpWidget(_view(c, visible: false));
      c.record(source: 'Codex', message: 'Newest visit');
      await tester.pumpAndSettle();
      expect(c.lastViewedSequence, viewed);
      await tester.pumpWidget(_view(c));
      await tester.pumpAndSettle();
      final divider = find.text('上次看到这里');
      expect(
        tester.getTopLeft(find.text('Newest visit')).dy,
        lessThan(tester.getTopLeft(divider).dy),
      );
      expect(
        tester.getTopLeft(find.text('While hidden')).dy,
        greaterThan(tester.getTopLeft(divider).dy),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      c.clear();
    },
  );

  testWidgets(
    'the divider appears exactly once when history is on the next page',
    (tester) async {
      final c = _controller();
      addTearDown(c.dispose);
      c.record(source: 'Codex', message: 'Historical');
      c.markFeedViewed(c.latestSequence);
      c.record(source: 'Codex', message: 'New A');
      c.record(source: 'Codex', message: 'New B');
      await tester.pumpWidget(_view(c, pageSize: 2));
      await tester.pumpAndSettle();
      expect(find.text('上次看到这里'), findsNothing);
      await tester.tap(find.byKey(const Key('recent-agent-load-more')));
      await tester.pumpAndSettle();
      expect(find.text('上次看到这里'), findsOneWidget);
      expect(find.text('Historical'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      c.clear();
    },
  );

  testWidgets('viewport builds lazily and scrolling requests more', (
    tester,
  ) async {
    var id = 0;
    final c = ActivityController(idGenerator: () => '${++id}');
    addTearDown(c.dispose);
    c.load();
    for (var i = 0; i < 70; i++) {
      c.record(
        source: 'Codex',
        message: 'Update $i',
        completedAt: DateTime(2026, 10, 1, 0, i),
      );
    }
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: DingDongLocalizations.localizationsDelegates,
        supportedLocales: DingDongLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 420,
              height: 360,
              child: RecentAgentFeed(
                controller: c,
                compact: true,
                rowBuilder: (_, activity) =>
                    SizedBox(height: 65, child: Text(activity.message)),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Update 69'), findsOneWidget);
    expect(find.text('Update 40'), findsNothing);
    expect(find.textContaining('Update ').evaluate().length, lessThan(21));
    await tester.scrollUntilVisible(
      find.text('Update 40'),
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Update 40'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

ActivityController _controller() {
  var id = 0;
  return ActivityController(
    idGenerator: () => 'row-${++id}',
    now: () => DateTime.utc(2026, 10, 30, 10),
  )..load();
}

Widget _view(
  ActivityController controller, {
  bool visible = true,
  int pageSize = 21,
}) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: DingDongLocalizations.localizationsDelegates,
  supportedLocales: DingDongLocalizations.supportedLocales,
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 420,
        height: 600,
        child: RecentAgentFeed(
          controller: controller,
          compact: true,
          visible: visible,
          pageSize: pageSize,
          rowBuilder: (_, activity) =>
              SizedBox(height: 34, child: Text(activity.message)),
        ),
      ),
    ),
  ),
);
