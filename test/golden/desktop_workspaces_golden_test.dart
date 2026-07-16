import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
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
      await _pumpAgentApi(tester);
      await _capture(tester, 'agent_api');
      await _pumpMcpAccess(tester);
      await _capture(tester, 'mcp_access');
    },
    tags: <String>['golden'],
  );
}

Future<void> _pumpAgentApi(WidgetTester tester) async {
  final ShellController controller = ShellController(initialIndex: 3);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    DingDongApp(
      key: const ValueKey<String>('screen-agent-api'),
      shellController: controller,
      now: () => DateTime(2026, 7, 13, 0, 36),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpMcpAccess(WidgetTester tester) async {
  await _pumpWorkspace(tester);
  await tester.tap(find.byKey(const Key('today-agent-api')));
  await tester.pumpAndSettle();
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
