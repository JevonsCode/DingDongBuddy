import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/shell/ui/development_test_panel_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DEV test panel triggers state preview and nudge callbacks', (
    WidgetTester tester,
  ) async {
    var sleepingCount = 0;
    var nudgeCount = 0;

    await tester.pumpWidget(
      DevelopmentTestPanelApp(
        settings: const AppSettings(language: AppLanguagePreference.chinese),
        animationsSupported: true,
        onSleeping: () async => sleepingCount += 1,
        onNudge: () async => nudgeCount += 1,
      ),
    );

    expect(find.text('测试面板'), findsOneWidget);
    expect(find.text('DEV'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dev-test-panel-sleeping')));
    await tester.pump();
    expect(sleepingCount, 1);
    expect(find.text('已触发：睡眠状态'), findsOneWidget);

    await tester.tap(find.byKey(const Key('dev-test-panel-nudge')));
    await tester.pump();
    expect(nudgeCount, 1);
    expect(find.text('已触发：左右摇动'), findsOneWidget);
  });

  testWidgets('unsupported platforms explain why animation is unavailable', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      DevelopmentTestPanelApp(
        settings: const AppSettings(language: AppLanguagePreference.chinese),
        animationsSupported: false,
        onSleeping: () async {},
        onNudge: () async {},
      ),
    );

    expect(find.text('状态小人预览目前仅支持 macOS。'), findsOneWidget);
    final FilledButton sleeping = tester.widget(
      find.descendant(
        of: find.byKey(const Key('dev-test-panel-sleeping')),
        matching: find.byType(FilledButton),
      ),
    );
    expect(sleeping.onPressed, isNull);
  });
}
