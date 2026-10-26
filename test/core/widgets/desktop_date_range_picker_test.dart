import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/widgets/desktop_date_range_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'desktop calendar shows two months, validates typed bounds, and commits only on Apply',
    (tester) async {
      DateTimeRange? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.desktopPanelLight(),
          localizationsDelegates: DingDongLocalizations.localizationsDelegates,
          supportedLocales: DingDongLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showDesktopDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2026, 10, 27),
                  initialRange: DateTimeRange(
                    start: DateTime(2026, 9, 8),
                    end: DateTime(2026, 10, 9),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('date-range-start')),
        '2026-10-20',
      );
      await tester.tap(find.byKey(const Key('date-range-apply')));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(
        find.text('End date must be on or after start date'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const Key('date-range-end')),
        '2026-10-25',
      );
      await tester.tap(find.byKey(const Key('date-range-apply')));
      await tester.pumpAndSettle();
      expect(result?.start, DateTime(2026, 10, 20));
      expect(result?.end, DateTime(2026, 10, 25));
      expect(tester.takeException(), isNull);
    },
  );
}
