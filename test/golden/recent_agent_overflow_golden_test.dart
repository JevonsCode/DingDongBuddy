import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'recent Agent overflow keeps a restrained More action',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      int nextId = 0;
      final ActivityController activityController = ActivityController(
        idGenerator: () => 'golden-agent-${nextId++}',
        now: () => DateTime(2026, 7, 22, 1, 24),
      );
      for (int index = 0; index < 7; index += 1) {
        activityController.record(
          source: 'Codex',
          message: 'Completed Agent task ${index + 1}',
        );
      }

      await tester.pumpWidget(
        DingDongApp(
          activityController: activityController,
          resourceManagerLauncher: _NoopResourceManagerLauncher(),
          now: () => DateTime(2026, 7, 22, 1, 24),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('desktop-shell-golden')),
        matchesGoldenFile('goldens/recent_agents_more.png'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      activityController.dispose();
    },
    tags: <String>['golden'],
  );
}

final class _NoopResourceManagerLauncher implements ResourceManagerLauncher {
  @override
  Future<void> show({
    String? editingResourceId,
    ResourceManagerDestination destination =
        ResourceManagerDestination.resources,
  }) async {}
}
