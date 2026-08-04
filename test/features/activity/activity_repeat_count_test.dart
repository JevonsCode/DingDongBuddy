import 'package:dingdong/features/activity/ui/activity_repeat_count.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'repeat count is oversized low-contrast watermark text without a tag',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Center(child: ActivityRepeatCount(count: 3))),
      );

      final Text text = tester.widget<Text>(find.text('×3'));

      expect(find.byType(DecoratedBox), findsNothing);
      expect(text.style?.fontSize, 28);
      expect(text.style?.fontWeight, FontWeight.w900);
      expect(text.style?.fontStyle, isNull);
      expect(text.style?.color?.a, closeTo(0.13, 0.001));

      final Transform transform = tester.widget<Transform>(
        find.ancestor(of: find.text('×3'), matching: find.byType(Transform)),
      );
      expect(transform.transform.getTranslation().y, 0);

      await tester.pumpWidget(
        const MaterialApp(home: Center(child: ActivityRepeatCount(count: 100))),
      );
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('×100'), findsNothing);
    },
  );
}
