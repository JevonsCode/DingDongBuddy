import 'package:dingdong/app/dingdong_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'desktop workspaces retain the approved visual hierarchy',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      await _pumpWorkspace(tester);
      await _capture(tester, 'today');
      await _pumpWorkspace(tester, navigationKey: 'popup-tab-1');
      await _capture(tester, 'library');
      await _pumpWorkspace(tester, navigationKey: 'popup-tab-2');
      await _capture(tester, 'clipboard');
    },
    tags: <String>['golden'],
  );
}

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  String? navigationKey,
}) async {
  await tester.pumpWidget(
    DingDongApp(
      key: ValueKey<String>('screen-${navigationKey ?? 'Today'}'),
      now: () => DateTime(2026, 7, 13, 0, 36),
    ),
  );
  await tester.pumpAndSettle();
  if (navigationKey != null) {
    await tester.tap(find.byKey(Key(navigationKey)));
  }
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String fileName) {
  return expectLater(
    find.byKey(const Key('desktop-shell-golden')),
    matchesGoldenFile('goldens/$fileName.png'),
  );
}
