import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DingDong starts with the Dynamic workspace at version 0.7.20', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DingDongApp());

    expect(find.text('Dynamic'), findsWidgets);
    expect(find.byKey(const Key('app-version-0.7.20')), findsOneWidget);
    expect(find.text('v0.7.20'), findsOneWidget);
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

  testWidgets('first MCP entry shows a badge and scrolls to MCP access once', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
    final ShellController controller = ShellController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      DingDongApp(
        settingsRepository: SettingsRepository(backend),
        shellController: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-mcp-badge')), findsOneWidget);

    await tester.tap(find.byKey(const Key('today-agent-api')));
    await tester.pumpAndSettle();

    expect(backend.values['dingdong.onboarding.mcpAccessSeen'], isTrue);
    expect(find.byKey(const Key('agent-api-mcp-access')), findsOneWidget);
    final CustomScrollView scroll = tester.widget<CustomScrollView>(
      find.byKey(const Key('agent-api-scroll')),
    );
    expect(scroll.controller?.offset, greaterThan(0));

    controller.open(0);
    await tester.pump();
    expect(find.byKey(const Key('today-mcp-badge')), findsNothing);
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
      72,
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
      expect(find.byKey(const Key('recent-agent-count')), findsOneWidget);
      expect(find.text('24 h · 1'), findsOneWidget);
      expect(activityController.unseenCount, 1);

      await tester.pump(const Duration(milliseconds: 1600));
      expect(activityController.unseenCount, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      activityController.dispose();
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
    expect(find.byKey(const Key('resource-library-context')), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
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

  testWidgets(
    'deleting the final clipboard item is not undone when the workspace reopens',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final DateTime now = DateTime.utc(2026, 7, 21, 12);
      final ClipboardRecord record = ClipboardRecord(
        id: 'only-item',
        group: 'Clipboard',
        title: 'Only clipboard item',
        content: 'keep deletion durable',
        tags: const <String>['clipboard', 'text'],
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: now,
        updatedAt: now,
      );
      final InMemoryClipboardStore store = InMemoryClipboardStore(
        <ClipboardRecord>[record],
      );
      final _StaticClipboardGateway gateway = _StaticClipboardGateway(
        const ClipboardSnapshot(text: 'keep deletion durable'),
      );
      final ShellController controller = ShellController(initialIndex: 2);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        DingDongApp(
          clipboardStore: store,
          clipboardCaptureService: ClipboardCaptureService(
            gateway: gateway,
            store: store,
          ),
          shellController: controller,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(record.title), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(store.list(limit: 10), isEmpty);
      expect(find.text(record.title), findsNothing);

      controller.open(0);
      await tester.pump();
      controller.open(2);
      await tester.pumpAndSettle();

      expect(store.list(limit: 10), isEmpty);
      expect(find.text(record.title), findsNothing);
      expect(gateway.readCount, 0);
    },
  );

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
    expect(find.text('MCP access'), findsOneWidget);
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
  SettingsWindowDestination? lastDestination;

  @override
  Future<void> show({
    SettingsWindowDestination destination = SettingsWindowDestination.top,
  }) async {
    openCount += 1;
    lastDestination = destination;
  }
}

final class _StaticClipboardGateway implements ClipboardGateway {
  _StaticClipboardGateway(this.snapshot);

  final ClipboardSnapshot snapshot;
  int readCount = 0;

  @override
  Future<ClipboardSnapshot> read() async {
    readCount += 1;
    return snapshot;
  }

  @override
  Future<void> writeFiles(List<String> paths) async {}

  @override
  Future<void> writeText(String text) async {}
}
