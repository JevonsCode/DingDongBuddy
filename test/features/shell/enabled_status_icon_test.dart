import 'package:dingdong/core/widgets/enabled_status_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('enabled indicator uses a simple check without a nested badge', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EnabledStatusIcon(enabled: true)),
    );

    final Icon icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.check_rounded);
    expect(icon.size, 18);
  });

  testWidgets('paused indicator uses a simple pause glyph', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: EnabledStatusIcon(enabled: false)),
    );

    final Icon icon = tester.widget<Icon>(find.byType(Icon));
    expect(icon.icon, Icons.pause_rounded);
    expect(icon.size, 18);
  });
}
