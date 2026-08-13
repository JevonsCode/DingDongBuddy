import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
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

  testWidgets(
    'dark clipboard keeps every popup layer on the dark palette',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final ShellController controller = ShellController(initialIndex: 2);
      addTearDown(controller.dispose);
      final SettingsRepository settings = SettingsRepository(
        MemoryPreferencesBackend(<String, Object>{
          'dingdong.panel.themeMode': 'dark',
        }),
      );
      final DateTime now = DateTime(2026, 8, 10, 19, 30);
      final List<ClipboardRecord> records = <ClipboardRecord>[
        _clipboardRecord(
          id: 'dark-url',
          title: 'https://example.com/dark-mode',
          content: 'https://example.com/dark-mode',
          tags: const <String>['clipboard', 'url'],
          updatedAt: now.subtract(const Duration(minutes: 4)),
          copyCount: 3,
        ),
        _clipboardRecord(
          id: 'dark-text',
          title: 'Dark mode clipboard item',
          content: 'Dark surfaces should stay visually consistent.',
          tags: const <String>['clipboard', 'text'],
          updatedAt: now.subtract(const Duration(minutes: 7)),
        ),
        _clipboardRecord(
          id: 'dark-code',
          title: 'flutter test',
          content: 'flutter test test/features/shell/popup_shell_test.dart',
          tags: const <String>['clipboard', 'command'],
          updatedAt: now.subtract(const Duration(minutes: 12)),
          copyCount: 2,
        ),
      ];

      await tester.pumpWidget(
        DingDongApp(
          settingsRepository: settings,
          shellController: controller,
          clipboardStore: InMemoryClipboardStore(records),
          now: () => now,
        ),
      );
      await tester.pumpAndSettle();
      await _precacheImages(tester);

      await _capture(tester, 'clipboard_dark');
    },
    tags: <String>['golden'],
  );

  testWidgets(
    'dark activity and library keep native contrast across popup layers',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final ({ActivityController activity, ShellController shell})
      activityWorkspace = await _pumpDarkWorkspace(
        tester,
        initialIndex: 0,
        key: 'activity-dark',
      );
      await _capture(tester, 'activity_dark');
      await tester.pumpWidget(const SizedBox.shrink());
      activityWorkspace.activity.dispose();
      activityWorkspace.shell.dispose();

      final ({ActivityController activity, ShellController shell})
      libraryWorkspace = await _pumpDarkWorkspace(
        tester,
        initialIndex: 1,
        key: 'library-dark',
      );
      await _capture(tester, 'library_dark');
      await tester.pumpWidget(const SizedBox.shrink());
      libraryWorkspace.activity.dispose();
      libraryWorkspace.shell.dispose();
    },
    tags: <String>['golden'],
  );

  testWidgets(
    'Agent setup update is visible in Dynamic and actionable at the prompt',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final ShellController controller = ShellController();
      addTearDown(controller.dispose);
      final SettingsRepository settings = SettingsRepository(
        MemoryPreferencesBackend(<String, Object>{
          'dingdong.onboarding.mcpAccessSeen': true,
          'dingdong.agentApi.acknowledgedSetupRevision': 0,
        }),
      );

      await tester.pumpWidget(
        DingDongApp(
          key: const ValueKey<String>('agent-setup-update'),
          agentBaseUri: Uri.parse('http://127.0.0.1:2333'),
          settingsRepository: settings,
          shellController: controller,
          now: () => DateTime(2026, 8, 13, 15, 30),
        ),
      );
      await tester.pumpAndSettle();
      await _precacheImages(tester);

      await _capture(tester, 'agent_setup_update_today');

      await tester.tap(find.byKey(const Key('today-agent-api')));
      await tester.pumpAndSettle();
      await _capture(tester, 'agent_setup_update_prompt');
    },
    tags: <String>['golden'],
  );
}

ClipboardRecord _clipboardRecord({
  required String id,
  required String title,
  required String content,
  required List<String> tags,
  required DateTime updatedAt,
  int copyCount = 1,
}) {
  return ClipboardRecord(
    id: id,
    group: 'Clipboard',
    title: title,
    content: content,
    tags: tags,
    copyCount: copyCount,
    pinned: false,
    enabled: true,
    activation: 'taskMatch',
    createdAt: updatedAt,
    updatedAt: updatedAt,
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

Future<({ActivityController activity, ShellController shell})>
_pumpDarkWorkspace(
  WidgetTester tester, {
  required int initialIndex,
  required String key,
}) async {
  final ShellController controller = ShellController(
    initialIndex: initialIndex,
  );
  final SettingsRepository settings = SettingsRepository(
    MemoryPreferencesBackend(<String, Object>{
      'dingdong.panel.themeMode': 'dark',
    }),
  );
  int nextActivityId = 0;
  final ActivityController activityController = ActivityController(
    idGenerator: () => 'dark-activity-${nextActivityId++}',
    now: () => DateTime(2026, 8, 10, 20, 15),
  );
  activityController.record(
    source: 'Codex',
    message: 'Dark mode release verification completed',
  );
  activityController.record(
    source: 'Claude Code',
    message: 'Resource synchronization completed',
  );
  final DateTime resourceTime = DateTime.utc(2026, 8, 10, 12);
  final List<Resource> resources = <Resource>[
    Resource(
      id: 'dark-release-prompt',
      type: ResourceType.prompt,
      title: 'Release readiness checklist',
      content: 'Verify dark surfaces, contrast, tests, and release metadata.',
      group: 'Release',
      tags: const <String>['dark mode', 'quality'],
      pinned: true,
      createdAt: resourceTime,
      updatedAt: resourceTime,
    ),
    Resource(
      id: 'dark-design-skill',
      type: ResourceType.skill,
      title: 'Dark mode auditor',
      content: 'Inspect popup surfaces and report contrast regressions.',
      group: 'Release',
      tags: const <String>['design', 'accessibility'],
      createdAt: resourceTime,
      updatedAt: resourceTime,
    ),
    Resource(
      id: 'dark-dingdong-mcp',
      type: ResourceType.mcp,
      title: 'DingDong MCP',
      content: '{"command":"dingdong-mcp"}',
      group: 'Release',
      tags: const <String>['stdio', 'local'],
      createdAt: resourceTime,
      updatedAt: resourceTime,
    ),
  ];
  await tester.pumpWidget(
    DingDongApp(
      key: ValueKey<String>(key),
      activityController: activityController,
      resourceStore: InMemoryResourceStore(resources),
      settingsRepository: settings,
      shellController: controller,
      now: () => DateTime(2026, 8, 10, 20, 15),
    ),
  );
  await tester.pumpAndSettle();
  await _precacheImages(tester);
  return (activity: activityController, shell: controller);
}

Future<void> _precacheImages(WidgetTester tester) async {
  final BuildContext imageContext = tester.element(find.byType(MaterialApp));
  await tester.runAsync(() async {
    for (final Image image in tester.widgetList<Image>(find.byType(Image))) {
      await precacheImage(image.image, imageContext);
    }
  });
  await tester.pump();
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
