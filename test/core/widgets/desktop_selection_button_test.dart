import 'package:dingdong/core/widgets/desktop_selection_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('row selection updates action label and selection', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (_, setState) => Center(
            child: DesktopSelectionButton(
              selected: selected,
              onPressed: () => setState(() => selected = !selected),
            ),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Select item'), findsOneWidget);
    await tester.tap(find.byType(DesktopSelectionButton));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
    expect(find.byTooltip('Remove from selection'), findsOneWidget);
  });
}
