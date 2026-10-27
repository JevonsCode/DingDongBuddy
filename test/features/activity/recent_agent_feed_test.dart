import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/activity/ui/recent_agent_feed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
