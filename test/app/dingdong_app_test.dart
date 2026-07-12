import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DingDong starts with the Dynamic workspace at version 0.7.0', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DingDongApp());

    expect(find.text('Dynamic'), findsWidgets);
    expect(find.byKey(const Key('app-version-0.7.0')), findsOneWidget);
    expect(find.text('Resource library'), findsOneWidget);
    expect(find.text('Clipboard history'), findsOneWidget);
    expect(find.text('Agent API'), findsWidgets);
  });

  testWidgets('Dynamic quick actions open a working workspace', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const DingDongApp());

    await tester.tap(find.byKey(const Key('today-open-clipboard')));
    await tester.pump();

    expect(find.byKey(const Key('clipboard-search')), findsOneWidget);
  });

  testWidgets('Dynamic cards use compact desktop row heights', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final Resource resource = Resource(
      id: 'compact-today-resource',
      type: ResourceType.skill,
      title: 'Compact resource',
      content: 'A concise enabled resource row',
      enabled: true,
      createdAt: DateTime.utc(2026, 7, 12),
      updatedAt: DateTime.utc(2026, 7, 12),
    );
    await tester.pumpWidget(
      DingDongApp(resourceStore: InMemoryResourceStore(<Resource>[resource])),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('today-metric-library'))).height,
      64,
    );
    expect(
      tester
          .getSize(
            find.byKey(const Key('today-enabled-compact-today-resource')),
          )
          .height,
      92,
    );
  });

  testWidgets(
    'Dynamic highlights an unseen completed Agent then marks it seen',
    (WidgetTester tester) async {
      final ActivityController activityController = ActivityController(
        idGenerator: () => 'completed-agent',
        now: () => DateTime.utc(2026, 7, 12, 10),
      );
      activityController.record(source: 'Codex', message: 'Refactor complete');
      activityController.requestReveal();

      await tester.pumpWidget(
        DingDongApp(activityController: activityController),
      );
      await tester.pump();

      expect(find.byKey(const Key('activity-completed-agent')), findsOneWidget);
      expect(activityController.unseenCount, 1);

      await tester.pump(const Duration(milliseconds: 1600));
      expect(activityController.unseenCount, 0);
    },
  );

  testWidgets('desktop navigation opens the resource library workspace', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const DingDongApp());

    await tester.tap(find.text('Library'));
    await tester.pump();

    expect(find.byKey(const Key('resource-search')), findsOneWidget);
    expect(find.byKey(const Key('resource-manager-open')), findsOneWidget);
  });

  testWidgets('resource card icon actions expose consistent hover labels', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final Resource resource = Resource(
      id: 'tooltip-resource',
      type: ResourceType.prompt,
      title: 'Reusable prompt',
      content: 'Prompt body',
      enabled: true,
      createdAt: DateTime.utc(2026, 7, 13),
      updatedAt: DateTime.utc(2026, 7, 13),
    );
    await tester.pumpWidget(
      DingDongApp(resourceStore: InMemoryResourceStore(<Resource>[resource])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pump();

    expect(find.byTooltip('Disable'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
  });

  testWidgets('desktop navigation opens the clipboard workspace', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const DingDongApp());

    await tester.tap(find.text('Clipboard'));
    await tester.pump();

    expect(find.byKey(const Key('clipboard-search')), findsOneWidget);
    expect(find.byKey(const Key('clipboard-list')), findsOneWidget);
  });

  testWidgets('settings toolbar action opens the dedicated settings panel', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final _FakeSettingsWindowLauncher launcher = _FakeSettingsWindowLauncher();
    await tester.pumpWidget(DingDongApp(settingsWindowLauncher: launcher));

    await tester.tap(find.byKey(const Key('popup-open-settings')));
    await tester.pumpAndSettle();

    expect(launcher.openCount, 1);
    expect(find.byKey(const Key('settings-theme-mode')), findsNothing);
  });

  testWidgets('desktop navigation opens local API and MCP setup details', (
    WidgetTester tester,
  ) async {
    final ShellController controller = ShellController();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(DingDongApp(shellController: controller));

    controller.open(3);
    await tester.pump();

    expect(find.text('http://127.0.0.1:2333'), findsOneWidget);
    expect(find.text('MCP bridge'), findsOneWidget);
    expect(find.byKey(const Key('agent-api-copy-health')), findsOneWidget);
  });

  testWidgets('saved appearance preference controls the application theme', (
    WidgetTester tester,
  ) async {
    final SettingsRepository repository = SettingsRepository(
      MemoryPreferencesBackend(<String, Object>{
        'dingdong.panel.themeMode': 'dark',
      }),
    );

    await tester.pumpWidget(DingDongApp(settingsRepository: repository));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets(
    'saved Chinese preference localizes navigation and workspace copy',
    (WidgetTester tester) async {
      final SettingsRepository repository = SettingsRepository(
        MemoryPreferencesBackend(<String, Object>{'dingdong.language': 'zh'}),
      );

      await tester.pumpWidget(DingDongApp(settingsRepository: repository));
      await tester.pumpAndSettle();

      expect(find.text('动态'), findsWidgets);
      expect(find.text('资源库'), findsWidgets);
      expect(find.text('剪贴板'), findsWidgets);
    },
  );

  testWidgets('external desktop commands control shell navigation', (
    WidgetTester tester,
  ) async {
    final ShellController controller = ShellController();
    await tester.pumpWidget(DingDongApp(shellController: controller));

    controller.open(3);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agent-api-copy-health')), findsOneWidget);
  });
}

final class _FakeSettingsWindowLauncher implements SettingsWindowLauncher {
  int openCount = 0;

  @override
  Future<void> show() async {
    openCount += 1;
  }
}
