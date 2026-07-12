import 'dart:ui' show Tristate;

import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact switch is 36 by 20 and toggles without ink', (
    WidgetTester tester,
  ) async {
    bool value = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => Center(
            child: CompactSwitch(
              key: const Key('subject'),
              value: value,
              onChanged: (bool next) => setState(() => value = next),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getSize(find.byKey(const Key('subject'))),
      const Size(36, 20),
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('subject')),
        matching: find.byType(InkWell),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('subject')));
    await tester.pumpAndSettle();

    expect(value, isTrue);
    final SemanticsNode semantics = tester.getSemantics(
      find.byKey(const Key('subject')),
    );
    expect(semantics.flagsCollection.isToggled, Tristate.isTrue);
  });
}
