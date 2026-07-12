import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('desktop select opens a compact custom menu and changes value', (
    WidgetTester tester,
  ) async {
    String selected = 'zh';
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Center(
              child: SizedBox(
                width: 190,
                child: DesktopSelectField<String>(
                  value: selected,
                  items: const <DesktopSelectItem<String>>[
                    DesktopSelectItem<String>(value: 'zh', label: '中文'),
                    DesktopSelectItem<String>(value: 'en', label: 'English'),
                  ],
                  onChanged: (String value) => setState(() => selected = value),
                ),
              ),
            );
          },
        ),
      ),
    );

    expect(find.byType(DropdownButton<String>), findsNothing);
    expect(tester.getSize(find.byType(DesktopSelectField<String>)).height, 38);

    await tester.tap(find.text('中文'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();

    expect(selected, 'en');
    expect(find.text('English'), findsOneWidget);
  });
}
