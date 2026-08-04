import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_choice_chip.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/desktop_segmented_control.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('custom action style overrides the shared defaults', (
    WidgetTester tester,
  ) async {
    const Color customBackground = Color(0xFFE4F1F8);
    const Color customBorder = Color(0xFF7CA9C2);
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: DesktopActionButton(
            key: const Key('custom-action'),
            onPressed: () {},
            label: 'Library',
            style: DesktopActionButton.styleFrom(
              minimumSize: const Size(120, 40),
              backgroundColor: customBackground,
              side: const BorderSide(color: customBorder),
            ),
          ),
        ),
      ),
    );

    final OutlinedButton button = tester.widget<OutlinedButton>(
      find.byKey(const Key('custom-action')),
    );
    expect(
      button.style?.backgroundColor?.resolve(const <WidgetState>{}),
      customBackground,
    );
    expect(
      button.style?.side?.resolve(const <WidgetState>{})?.color,
      customBorder,
    );
    expect(
      button.style?.minimumSize?.resolve(const <WidgetState>{}),
      const Size(120, 40),
    );
  });

  testWidgets('segmented control switches without ink or selection animation', (
    WidgetTester tester,
  ) async {
    String selected = 'first';
    int changeCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Center(
              child: DesktopSegmentedControl<String>(
                key: const Key('segmented'),
                value: selected,
                segments: const <DesktopSegment<String>>[
                  DesktopSegment<String>(value: 'first', label: Text('First')),
                  DesktopSegment<String>(
                    value: 'second',
                    label: Text('Second'),
                  ),
                ],
                onChanged: (String value) {
                  changeCount += 1;
                  setState(() => selected = value);
                },
              ),
            );
          },
        ),
      ),
    );

    final Finder segmented = find.byKey(const Key('segmented'));
    expect(
      find.descendant(of: segmented, matching: find.byType(InkWell)),
      findsNothing,
    );
    expect(
      find.descendant(of: segmented, matching: find.byType(AnimatedContainer)),
      findsNothing,
    );

    await tester.tap(find.text('Second'));
    await tester.pump();
    expect(selected, 'second');
    expect(changeCount, 1);

    await tester.tap(find.text('Second'));
    await tester.pump();
    expect(changeCount, 1);
  });

  testWidgets('choice chip keeps selection changes animation-free', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopChoiceChip(
          label: const Text('Prompts'),
          selected: false,
          onSelected: (_) {},
        ),
      ),
    );

    expect(find.byType(AnimatedContainer), findsNothing);
    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('choice chip centers its label in a stretched filter slot', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              key: const Key('filter-slot'),
              width: 160,
              child: DesktopChoiceChip(
                key: const Key('filter-chip'),
                label: const Text('Skills', key: Key('filter-label')),
                selected: false,
                padding: EdgeInsets.zero,
                onSelected: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    final Offset slotCenter = tester.getCenter(
      find.byKey(const Key('filter-slot')),
    );
    final Offset labelCenter = tester.getCenter(
      find.byKey(const Key('filter-label')),
    );
    expect((slotCenter.dx - labelCenter.dx).abs(), lessThan(0.5));
    expect((slotCenter.dy - labelCenter.dy).abs(), lessThan(0.5));
  });

  testWidgets('search field exposes and operates a stable clear action', (
    WidgetTester tester,
  ) async {
    final TextEditingController controller = TextEditingController();
    addTearDown(controller.dispose);
    String latestValue = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: DesktopSearchField(
                key: const Key('search'),
                clearButtonKey: const Key('clear-search'),
                controller: controller,
                hintText: 'Search resources',
                onChanged: (String value) => latestValue = value,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('search')), 'agent');
    await tester.pump();
    expect(find.byKey(const Key('clear-search')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear-search')));
    await tester.pump();
    expect(controller.text, isEmpty);
    expect(latestValue, isEmpty);
    expect(find.byKey(const Key('clear-search')), findsNothing);
  });
}
