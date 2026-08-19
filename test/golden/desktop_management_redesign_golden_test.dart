import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_category_rules_dialog.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_preview_app.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/device_link/domain/device_link_management.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:dingdong/features/device_link/ui/device_link_dialog.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/resource_manager_app.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'resource manager continuous list and detail light and dark',
    (WidgetTester tester) async {
      const MethodChannel channels = MethodChannel(
        'mixin.one/desktop_multi_window/channels',
      );
      const MethodChannel registry = MethodChannel(
        'mixin.one/desktop_multi_window',
      );
      final TestDefaultBinaryMessenger messenger =
          tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channels, (_) async => null);
      messenger.setMockMethodCallHandler(registry, (MethodCall call) async {
        if (call.method == 'getWindowDefinition') {
          return <String, String>{
            'windowId': 'management-golden',
            'windowArgument': '',
          };
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channels, null);
        messenger.setMockMethodCallHandler(registry, null);
      });
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1080, 752);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final LibraryViewModel model = LibraryViewModel(
        InMemoryResourceStore(_resources()),
      );
      await model.load();
      model.toggleSelection('prompt-one');
      model.toggleSelection('prompt-two');
      addTearDown(model.dispose);
      final ClipboardViewModel clipboardModel = ClipboardViewModel(
        InMemoryClipboardStore(),
      )..load();
      addTearDown(clipboardModel.dispose);
      final ActivityController activityController = ActivityController();
      addTearDown(activityController.dispose);
      final IssueCenterController issueController = IssueCenterController();

      for (final (ThemeMode mode, String name) in <(ThemeMode, String)>[
        (ThemeMode.light, 'resource_manager_redesign_light'),
        (ThemeMode.dark, 'resource_manager_redesign_dark'),
      ]) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('management-golden'),
            child: ResourceManagerApp(
              viewModel: model,
              clipboardViewModel: clipboardModel,
              activityController: activityController,
              issueCenterController: issueController,
              settings: AppSettings(
                themeMode: mode == ThemeMode.dark
                    ? AppThemePreference.dark
                    : AppThemePreference.light,
                language: AppLanguagePreference.english,
              ),
              windowController: WindowController.fromWindowId(
                'management-golden',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await expectLater(
          find.byKey(const Key('management-golden')),
          matchesGoldenFile('goldens/$name.png'),
        );
      }

      model.clearSelection();
      model.selectResource(
        model.allResources.firstWhere(
          (Resource resource) => resource.id == 'skill-one',
        ),
      );
      for (final (ThemeMode mode, String name) in <(ThemeMode, String)>[
        (ThemeMode.light, 'resource_manager_detail_redesign_light'),
        (ThemeMode.dark, 'resource_manager_detail_redesign_dark'),
      ]) {
        await tester.pumpWidget(
          RepaintBoundary(
            key: const Key('management-golden'),
            child: ResourceManagerApp(
              viewModel: model,
              clipboardViewModel: clipboardModel,
              activityController: activityController,
              issueCenterController: issueController,
              settings: AppSettings(
                themeMode: mode == ThemeMode.dark
                    ? AppThemePreference.dark
                    : AppThemePreference.light,
                language: AppLanguagePreference.english,
              ),
              windowController: WindowController.fromWindowId(
                'management-golden',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('library-detail-page')), findsOneWidget);
        expect(find.byKey(const Key('resource-editor')), findsOneWidget);
        await expectLater(
          find.byKey(const Key('management-golden')),
          matchesGoldenFile('goldens/$name.png'),
        );
      }
    },
    tags: <String>['golden'],
  );

  testWidgets('connected devices pair-first light and dark', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(620, 580);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final _GoldenDeviceManagement controller = _GoldenDeviceManagement();

    for (final (ThemeMode mode, String name) in <(ThemeMode, String)>[
      (ThemeMode.light, 'connected_devices_redesign_light'),
      (ThemeMode.dark, 'connected_devices_redesign_dark'),
    ]) {
      await tester.pumpWidget(
        _testApp(
          mode: mode,
          home: RepaintBoundary(
            key: const Key('management-golden'),
            child: DeviceLinkManagerScreen(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('management-golden')),
        matchesGoldenFile('goldens/$name.png'),
      );
    }
  }, tags: <String>['golden']);

  testWidgets('clipboard detail preview light and dark', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(304, 420);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ClipboardRecord record = ClipboardRecord(
      id: 'detail-preview',
      group: 'Project notes',
      title: 'Release checklist',
      content:
          'Review the desktop build, verify keyboard focus, and confirm the connected-device handoff.',
      tags: const <String>['clipboard', 'text'],
      sources: const <String>['Notes', 'DingDong'],
      copyCount: 3,
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: DateTime.utc(2026, 8, 12, 8, 30),
      updatedAt: DateTime.utc(2026, 8, 12, 9, 45),
    );

    for (final (ThemeMode mode, String name) in <(ThemeMode, String)>[
      (ThemeMode.light, 'clipboard_detail_redesign_light'),
      (ThemeMode.dark, 'clipboard_detail_redesign_dark'),
    ]) {
      await tester.pumpWidget(
        _testApp(
          mode: mode,
          home: RepaintBoundary(
            key: const Key('management-golden'),
            child: ClipboardPreviewCard(
              record: record,
              onCopy: () {},
              onOpen: () {},
              onShare: () {},
              onClose: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('management-golden')),
        matchesGoldenFile('goldens/$name.png'),
      );
    }
  }, tags: <String>['golden']);

  testWidgets('clipboard category list light and dark', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(700, 520);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(),
    )..load();
    addTearDown(model.dispose);

    for (final (ThemeMode mode, String name) in <(ThemeMode, String)>[
      (ThemeMode.light, 'clipboard_categories_redesign_light'),
      (ThemeMode.dark, 'clipboard_categories_redesign_dark'),
    ]) {
      await tester.pumpWidget(
        _testApp(
          mode: mode,
          home: Builder(
            builder: (BuildContext context) => Center(
              child: FilledButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) =>
                      ClipboardCategoryRulesDialog(viewModel: model),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      final BuildContext imageContext = tester.element(find.byType(Scaffold));
      await tester.runAsync(() async {
        for (final String symbol in <String>[
          'delete',
          'edit',
          'file',
          'image',
          'link',
          'text',
        ]) {
          await precacheImage(
            AssetImage('Assets/Symbols/$symbol.png'),
            imageContext,
          );
        }
      });
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await expectLater(
        find.byKey(const Key('clipboard-category-rules-dialog')),
        matchesGoldenFile('goldens/$name.png'),
      );
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
  }, tags: <String>['golden']);
}

Widget _testApp({required ThemeMode mode, required Widget home}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: AppTheme.desktopPanelLight(),
  darkTheme: AppTheme.desktopPanelDark(),
  themeMode: mode,
  locale: const Locale('en'),
  supportedLocales: DingDongLocalizations.supportedLocales,
  localizationsDelegates: DingDongLocalizations.localizationsDelegates,
  home: Scaffold(body: home),
);

List<Resource> _resources() {
  final DateTime now = DateTime.utc(2026, 8, 12);
  return <Resource>[
    Resource(
      id: 'prompt-one',
      type: ResourceType.prompt,
      title: 'Desktop release review',
      content: 'Review the DingDong desktop release.',
      pinned: true,
      usageCount: 128,
      lastUsedAt: now,
      createdAt: now,
      updatedAt: now,
    ),
    Resource(
      id: 'skill-one',
      type: ResourceType.skill,
      title: 'Product design audit',
      content: 'Audit product surfaces and return actionable findings.',
      updateUrl: 'https://example.test/skills/product-design-audit',
      candidateCount: 46,
      lastCandidateAt: now.subtract(const Duration(minutes: 12)),
      usageCount: 18,
      lastUsedAt: now.subtract(const Duration(hours: 1)),
      createdAt: now,
      updatedAt: now.subtract(const Duration(hours: 2)),
    ),
    Resource(
      id: 'mcp-one',
      type: ResourceType.mcp,
      title: 'Local DingDong tools',
      content: '{"mcpServers":{"dingdong":{"command":"dingdong_mcp"}}}',
      candidateCount: 35,
      lastCandidateAt: now.subtract(const Duration(minutes: 20)),
      invocationCount: 12,
      lastInvokedAt: now.subtract(const Duration(hours: 2)),
      createdAt: now,
      updatedAt: now.subtract(const Duration(days: 1)),
    ),
    Resource(
      id: 'prompt-two',
      type: ResourceType.prompt,
      title: 'Summarize selected notes',
      content: 'Summarize the selected notes with next actions.',
      usageCount: 9,
      lastUsedAt: now.subtract(const Duration(days: 1)),
      createdAt: now,
      updatedAt: now.subtract(const Duration(days: 2)),
    ),
    Resource(
      id: 'skill-two',
      type: ResourceType.skill,
      title: 'Keyboard regression pass',
      content: 'Verify focus order and keyboard operations.',
      candidateCount: 7,
      lastCandidateAt: now.subtract(const Duration(days: 1)),
      usageCount: 2,
      lastUsedAt: now.subtract(const Duration(days: 2)),
      createdAt: now,
      updatedAt: now.subtract(const Duration(days: 3)),
    ),
    Resource(
      id: 'mcp-two',
      type: ResourceType.mcp,
      title: 'Desktop bridge',
      content: '{"mcpServers":{"desktop":{"command":"desktop_bridge"}}}',
      candidateCount: 14,
      lastCandidateAt: now.subtract(const Duration(days: 2)),
      invocationCount: 3,
      lastInvokedAt: now.subtract(const Duration(days: 3)),
      createdAt: now,
      updatedAt: now.subtract(const Duration(days: 4)),
    ),
    Resource(
      id: 'prompt-three',
      type: ResourceType.prompt,
      title: 'Prepare handoff notes',
      content: 'Prepare a concise implementation handoff.',
      enabled: false,
      createdAt: now,
      updatedAt: now.subtract(const Duration(days: 5)),
    ),
    Resource(
      id: 'skill-three',
      type: ResourceType.skill,
      title: 'Release readiness',
      content: 'Check the release against the product contract.',
      candidateCount: 4,
      lastCandidateAt: now.subtract(const Duration(days: 4)),
      usageCount: 1,
      lastUsedAt: now.subtract(const Duration(days: 5)),
      createdAt: now,
      updatedAt: now.subtract(const Duration(days: 6)),
    ),
    Resource(
      id: 'prompt-four',
      type: ResourceType.prompt,
      title: 'Extract follow-up tasks',
      content: 'Extract actionable follow-up tasks from the review.',
      usageCount: 2,
      lastUsedAt: now.subtract(const Duration(days: 6)),
      createdAt: now,
      updatedAt: now.subtract(const Duration(days: 7)),
    ),
  ];
}

final class _GoldenDeviceManagement extends ChangeNotifier
    implements DeviceLinkManagement {
  @override
  bool get canPair => true;

  @override
  List<LinkedDevice> get devices => const <LinkedDevice>[];

  @override
  LocalDeviceIdentity get localDevice => const LocalDeviceIdentity(
    id: 'host-one',
    name: 'Studio Mac',
    platform: 'macos',
  );

  @override
  PendingDevicePairing? get pendingPairing => null;

  @override
  DeviceConnectionStatus get pairingStatus =>
      DeviceConnectionStatus.disconnected;

  @override
  Future<PendingDevicePairing?> beginPairing() async => null;

  @override
  Future<void> cancelPairing() async {}

  @override
  Future<void> deleteDevice(String deviceId) async {}

  @override
  Future<void> disconnect(String deviceId) async {}

  @override
  bool isConnected(String deviceId) => false;

  @override
  Future<void> reconnect(String deviceId) async {}

  @override
  Future<void> setAgentNotifications(String deviceId, bool value) async {}

  @override
  Future<void> setAutoSendClipboard(String deviceId, bool value) async {}

  @override
  DeviceConnectionStatus statusOf(String deviceId) =>
      DeviceConnectionStatus.disconnected;
}
