import 'dart:async';

import 'package:dingdong/features/library/ui/resource_manager_startup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'the window shows loading, failure and retry before the library',
    (tester) async {
      final firstAttempt = Completer<Widget>();
      var attempts = 0;
      await tester.pumpWidget(
        ResourceManagerStartup(
          load: () => ++attempts == 1
              ? firstAttempt.future
              : Future.value(
                  const SizedBox(key: Key('loaded-resource-manager')),
                ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      firstAttempt.completeError(StateError('resource file unavailable'));
      await tester.pumpAndSettle();
      expect(find.text('Could not open Resource Manager'), findsOneWidget);
      expect(find.text('resource file unavailable'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('loaded-resource-manager')), findsOneWidget);
    },
  );
}
