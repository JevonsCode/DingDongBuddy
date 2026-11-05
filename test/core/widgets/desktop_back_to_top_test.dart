import 'package:dingdong/core/widgets/desktop_back_to_top.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final reduceMotion in [false, true]) {
    testWidgets('returns to top and hides, reduceMotion=$reduceMotion', (
      tester,
    ) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduceMotion),
            child: Scaffold(
              body: SizedBox(
                height: 200,
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: controller,
                      itemExtent: 40,
                      itemCount: 100,
                      itemBuilder: (_, i) => Text('Item $i'),
                    ),
                    DesktopBackToTop(
                      controller: controller,
                      buttonKey: const Key('top'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('top')), findsNothing);
      controller.jumpTo(200);
      await tester.pump();
      expect(find.byKey(const Key('top')), findsNothing);
      controller.jumpTo(250);
      await tester.pump();
      expect(find.byKey(const Key('top')), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('top'))), const Size(32, 32));
      // Exercise keyboard activation, not just a pointer callback.
      Focus.of(
        tester.element(find.byIcon(Icons.vertical_align_top_rounded)),
      ).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      if (reduceMotion) expect(controller.offset, 0);
      await tester.pumpAndSettle();
      expect(controller.offset, 0);
      expect(find.byKey(const Key('top')), findsNothing);
    });
  }
}
