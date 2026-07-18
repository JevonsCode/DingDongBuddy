import 'dart:io';

import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_preview_launcher.dart';
import 'package:dingdong/features/clipboard/domain/quick_paste_gateway.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final String todayShortcut = Platform.isMacOS ? '⌘ Q' : 'Ctrl Q';

  testWidgets('quick-launch surface is a compact three-tab popup', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const DingDongApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('popup-shell')), findsOneWidget);
    expect(find.byKey(const Key('popup-tab-bar')), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.byKey(const Key('popup-tab-0')), findsOneWidget);
    expect(find.byKey(const Key('popup-tab-1')), findsOneWidget);
    expect(find.byKey(const Key('popup-tab-2')), findsOneWidget);
    expect(find.byKey(const Key('popup-tab-3')), findsNothing);
  });

  testWidgets('navigator overlays are clipped to the popup window radius', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const DingDongApp());
    await tester.pumpAndSettle();

    final Finder windowClipFinder = find.byKey(
      const Key('popup-window-clip'),
    );
    final ClipRRect windowClip = tester.widget<ClipRRect>(windowClipFinder);

    expect(windowClip.borderRadius, BorderRadius.circular(PopupStyle.radius));
    expect(windowClip.clipBehavior, Clip.antiAlias);
    expect(
      find.descendant(
        of: windowClipFinder,
        matching: find.byType(Overlay),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Escape dismisses the transient popup', (
    WidgetTester tester,
  ) async {
    int hideCount = 0;
    await tester.pumpWidget(
      DingDongApp(
        onHideWindow: () async {
          hideCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(hideCount, 1);
  });

  testWidgets('dragging the brand region starts native window movement', (
    WidgetTester tester,
  ) async {
    int dragCount = 0;
    await tester.pumpWidget(
      DingDongApp(
        onStartDragging: () async {
          dragCount += 1;
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const Key('popup-drag-region')),
      const Offset(40, 30),
    );
    await tester.pump();

    expect(dragCount, 1);
  });

  testWidgets('brand is concise and its mascot shakes without ink ripples', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DingDongApp());
    await tester.pumpAndSettle();

    expect(find.text('本地 Agent 工作台'), findsNothing);
    expect(
      Theme.of(
        tester.element(find.byKey(const Key('popup-shell'))),
      ).splashFactory,
      same(NoSplash.splashFactory),
    );

    final Finder mascot = find.byKey(const Key('popup-mascot'));
    final Finder transform = find.byKey(const Key('popup-mascot-transform'));
    expect(mascot, findsOneWidget);
    expect(
      tester.widget<Transform>(transform).transform.storage,
      equals(Matrix4.identity().storage),
    );

    await tester.tap(mascot);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(
      tester.widget<Transform>(transform).transform.storage,
      isNot(equals(Matrix4.identity().storage)),
    );

    await tester.pumpAndSettle();
    expect(
      tester.widget<Transform>(transform).transform.storage,
      equals(Matrix4.identity().storage),
    );
  });

  testWidgets('resource management opens a separate desktop window', (
    WidgetTester tester,
  ) async {
    final List<String> events = <String>[];
    final _FakeResourceManagerLauncher launcher = _FakeResourceManagerLauncher(
      onShow: () => events.add('manager'),
    );
    await tester.pumpWidget(
      DingDongApp(
        resourceManagerLauncher: launcher,
        onHideWindow: () async => events.add('hide'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('popup-tab-1')));
    await tester.pump();

    expect(find.byKey(const Key('resource-manager-open')), findsOneWidget);
    expect(find.byKey(const Key('resource-editor')), findsNothing);

    await tester.tap(find.byKey(const Key('resource-manager-open')));
    await tester.pump();

    expect(launcher.openCount, 1);
    expect(events, <String>['hide', 'manager']);
  });

  testWidgets(
    'resource card de-duplicates tags and toggles its compact status control',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final ShellController controller = ShellController(initialIndex: 1);
      addTearDown(controller.dispose);
      final DateTime now = DateTime.utc(2026, 7, 16);
      final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
        Resource(
          id: 'built-in-prompt',
          type: ResourceType.prompt,
          group: 'DingDong',
          title: 'Reply marker',
          content: 'Add a marker to the final reply.',
          tags: const <String>['DingDong', '内置', '验证'],
          enabled: true,
          createdAt: now,
          updatedAt: now,
        ),
      ]);

      await tester.pumpWidget(
        DingDongApp(resourceStore: store, shellController: controller),
      );
      await tester.pumpAndSettle();

      final Finder tags = find.byKey(
        const Key('resource-card-tags-built-in-prompt'),
      );
      expect(tags, findsOneWidget);
      expect(
        find.descendant(of: tags, matching: find.text('DingDong')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('resource-card-status-built-in-prompt')),
        findsOneWidget,
      );
      final SizedBox actions = tester.widget<SizedBox>(
        find.byKey(const Key('resource-card-actions-built-in-prompt')),
      );
      expect(actions.width, 64);

      await tester.tap(
        find.byKey(const Key('resource-card-status-built-in-prompt')),
      );
      await tester.pumpAndSettle();

      expect((await store.load()).single.enabled, isFalse);
    },
  );

  testWidgets(
    'Skill cards show parsed metadata in the library and enabled list',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final ShellController controller = ShellController();
      addTearDown(controller.dispose);
      final DateTime now = DateTime.utc(2026, 7, 17);
      final Resource skill = Resource(
        id: 'user-taste',
        type: ResourceType.skill,
        title: '',
        content: '''---
name: user-taste
description: Use when product decisions should follow saved preferences.
---

# User Taste

Apply the user's saved preferences.''',
        updateUrl:
            'https://github.com/JevonsCode/codex-skills/tree/main/skills/user-taste',
        enabled: true,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        DingDongApp(
          resourceStore: InMemoryResourceStore(<Resource>[skill]),
          shellController: controller,
        ),
      );
      await tester.pumpAndSettle();

      final Finder enabledCard = find.byKey(
        const Key('today-enabled-user-taste'),
      );
      expect(
        find.descendant(of: enabledCard, matching: find.text('user-taste')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: enabledCard,
          matching: find.text(
            'Use when product decisions should follow saved preferences.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: enabledCard,
          matching: find.textContaining('--- name:'),
        ),
        findsNothing,
      );

      controller.open(1);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('resource-card-title-user-taste')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('resource-card-summary-user-taste')),
        findsOneWidget,
      );
      expect(find.text('user-taste'), findsOneWidget);
      expect(
        find.text(
          'Use when product decisions should follow saved preferences.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('--- name:'), findsNothing);
      final Finder tags = find.byKey(
        const Key('resource-card-tags-user-taste'),
      );
      expect(
        find.descendant(of: tags, matching: find.text('Skill')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tags, matching: find.text('Online')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tags, matching: find.text('Skills')),
        findsNothing,
      );
    },
  );

  testWidgets('Skill card content is vertically centered', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ShellController controller = ShellController(initialIndex: 1);
    addTearDown(controller.dispose);
    final DateTime now = DateTime.utc(2026, 7, 17);

    await tester.pumpWidget(
      DingDongApp(
        shellController: controller,
        resourceStore: InMemoryResourceStore(<Resource>[
          Resource(
            id: 'centered-skill',
            type: ResourceType.skill,
            title: '',
            content: '''---
name: user-taste
description: Use when product decisions should follow saved preferences.
---

# User Taste''',
            updateUrl:
                'https://github.com/JevonsCode/codex-skills/tree/main/skills/user-taste',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    final Rect card = tester.getRect(
      find.byKey(const Key('resource-card-centered-skill')),
    );
    final Rect content = tester.getRect(
      find.byKey(const Key('resource-card-content-centered-skill')),
    );
    expect((card.center.dy - content.center.dy).abs(), lessThanOrEqualTo(1));
  });

  testWidgets('MCP resource cards use the orange-red accent', (
    WidgetTester tester,
  ) async {
    final ShellController controller = ShellController(initialIndex: 1);
    addTearDown(controller.dispose);
    final DateTime now = DateTime.utc(2026, 7, 16);
    await tester.pumpWidget(
      DingDongApp(
        shellController: controller,
        resourceStore: InMemoryResourceStore(<Resource>[
          Resource(
            id: 'mcp-resource',
            type: ResourceType.mcp,
            title: 'Local MCP',
            content: 'npx local-mcp',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      ),
    );
    await tester.pumpAndSettle();

    final PopupSymbolIcon icon = tester.widget<PopupSymbolIcon>(
      find.byKey(const Key('resource-card-type-mcp-resource')),
    );
    expect(icon.color, PopupStyle.mcp);
    expect(find.text('STDIO · npx local-mcp'), findsOneWidget);
    final Finder tags = find.byKey(
      const Key('resource-card-tags-mcp-resource'),
    );
    expect(
      find.descendant(of: tags, matching: find.text('MCP')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tags, matching: find.text('STDIO')),
      findsOneWidget,
    );
  });

  testWidgets('enabled resources can be edited or disabled by right click', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026, 7, 16);
    final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
      Resource(
        id: 'enabled-skill',
        type: ResourceType.skill,
        title: 'Enabled skill',
        content: 'Use this skill.',
        enabled: true,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final _FakeResourceManagerLauncher launcher =
        _FakeResourceManagerLauncher();
    final _QueuedContextMenuGateway menuGateway = _QueuedContextMenuGateway(
      <String?>['edit', 'disable'],
    );
    await tester.pumpWidget(
      DingDongApp(
        resourceStore: store,
        resourceManagerLauncher: launcher,
        desktopContextMenuGateway: menuGateway,
      ),
    );
    await tester.pumpAndSettle();

    final Finder card = find.byKey(const Key('today-enabled-enabled-skill'));
    await tester.tap(card, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    expect(menuGateway.showCount, 1);
    expect(find.byType(PopupMenuItem), findsNothing);
    expect(launcher.lastEditingResourceId, 'enabled-skill');

    await tester.tap(card, buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(menuGateway.showCount, 2);
    expect((await store.load()).single.enabled, isFalse);
    expect(card, findsNothing);
  });

  testWidgets('settings hides the callout before opening its separate panel', (
    WidgetTester tester,
  ) async {
    final List<String> events = <String>[];
    final _FakeSettingsWindowLauncher launcher = _FakeSettingsWindowLauncher(
      onShow: () => events.add('settings'),
    );
    final ShellController controller = ShellController(initialIndex: 2);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      DingDongApp(
        settingsWindowLauncher: launcher,
        shellController: controller,
        onHideWindow: () async => events.add('hide'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('popup-open-settings')));
    await tester.pump();

    expect(launcher.openCount, 1);
    expect(events, <String>['hide', 'settings']);
    expect(controller.selectedIndex, 2);
    expect(find.byKey(const Key('settings-screen')), findsNothing);
  });

  testWidgets('Escape closes clipboard details before hiding the callout', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ShellController controller = ShellController(initialIndex: 2);
    final _FakeClipboardPreviewLauncher preview =
        _FakeClipboardPreviewLauncher();
    int hideCount = 0;
    addTearDown(controller.dispose);
    final ClipboardRecord record = ClipboardRecord(
      id: 'escape-layer-clip',
      group: 'Clipboard',
      title: 'Layered Escape item',
      content: 'Close details first',
      tags: const <String>['clipboard', 'text'],
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: DateTime.utc(2026, 7, 12),
      updatedAt: DateTime.utc(2026, 7, 12),
    );
    await tester.pumpWidget(
      DingDongApp(
        clipboardStore: InMemoryClipboardStore(<ClipboardRecord>[record]),
        clipboardPreviewLauncher: preview,
        shellController: controller,
        onHideWindow: () async => hideCount += 1,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Layered Escape item'));
    await tester.pump();
    expect(preview.shownRecord?.id, record.id);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(preview.hideCount, 1);
    expect(hideCount, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(hideCount, 1);
  });

  testWidgets('shortcut hints appear only while Command is held', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DingDongApp());
    await tester.pumpAndSettle();

    expect(find.text(todayShortcut), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.text(todayShortcut), findsOneWidget);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.text(todayShortcut), findsNothing);
  });

  testWidgets('Command-Q switches the callout to Today instead of quitting', (
    WidgetTester tester,
  ) async {
    final ShellController controller = ShellController(initialIndex: 2);
    addTearDown(controller.dispose);
    await tester.pumpWidget(DingDongApp(shellController: controller));
    await tester.pumpAndSettle();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyQ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(controller.selectedIndex, 0);
    expect(find.byKey(const Key('today-open-clipboard')), findsOneWidget);
  });

  testWidgets('Command-R toggles filters from the focused callout shell', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ShellController controller = ShellController(initialIndex: 2);
    addTearDown(controller.dispose);
    await tester.pumpWidget(DingDongApp(shellController: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clipboard-category-all')), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    expect(find.byKey(const Key('clipboard-category-all')), findsOneWidget);
  });

  testWidgets(
    'Command-2 restores the second clipboard row from the focused callout shell',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final ShellController controller = ShellController(initialIndex: 2);
      final _RecordingClipboardGateway clipboard = _RecordingClipboardGateway();
      final _RecordingQuickPasteGateway quickPaste =
          _RecordingQuickPasteGateway();
      addTearDown(controller.dispose);
      final DateTime now = DateTime.utc(2026, 7, 15);
      final List<ClipboardRecord> records = <ClipboardRecord>[
        ClipboardRecord(
          id: 'shortcut-first',
          group: 'Clipboard',
          title: 'First shortcut item',
          content: 'first value',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        ),
        ClipboardRecord(
          id: 'shortcut-second',
          group: 'Clipboard',
          title: 'Second shortcut item',
          content: 'second value',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now.subtract(const Duration(seconds: 1)),
          updatedAt: now.subtract(const Duration(seconds: 1)),
        ),
      ];
      await tester.pumpWidget(
        DingDongApp(
          clipboardStore: InMemoryClipboardStore(records),
          clipboardGateway: clipboard,
          quickPasteGateway: quickPaste,
          shellController: controller,
        ),
      );
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(clipboard.writtenText, 'second value');
      expect(quickPaste.pasteCount, 1);
    },
  );

  testWidgets('filter button shows R only while Command is held', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ShellController controller = ShellController(initialIndex: 2);
    addTearDown(controller.dispose);
    await tester.pumpWidget(DingDongApp(shellController: controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clipboard-filter-icon')), findsOneWidget);
    expect(find.byKey(const Key('clipboard-filter-shortcut')), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.byKey(const Key('clipboard-filter-icon')), findsNothing);
    expect(find.byKey(const Key('clipboard-filter-shortcut')), findsOneWidget);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.byKey(const Key('clipboard-filter-icon')), findsOneWidget);
    expect(find.byKey(const Key('clipboard-filter-shortcut')), findsNothing);
  });

  testWidgets('Arrow Down and Space preview from the focused callout shell', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ShellController controller = ShellController(initialIndex: 2);
    final _FakeClipboardPreviewLauncher preview =
        _FakeClipboardPreviewLauncher();
    addTearDown(controller.dispose);
    final ClipboardRecord record = ClipboardRecord(
      id: 'keyboard-clip',
      group: 'Clipboard',
      title: 'Keyboard clipboard item',
      content: 'Keyboard clipboard value',
      tags: const <String>['clipboard', 'text'],
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: DateTime.utc(2026, 7, 12),
      updatedAt: DateTime.utc(2026, 7, 12),
    );
    await tester.pumpWidget(
      DingDongApp(
        clipboardStore: InMemoryClipboardStore(<ClipboardRecord>[record]),
        clipboardPreviewLauncher: preview,
        shellController: controller,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(preview.shownRecord?.id, record.id);
  });

  testWidgets('Return uses the selected row from the focused callout shell', (
    WidgetTester tester,
  ) async {
    final ShellController controller = ShellController(initialIndex: 2);
    final _FakeClipboardPreviewLauncher preview =
        _FakeClipboardPreviewLauncher();
    final _RecordingClipboardGateway clipboard = _RecordingClipboardGateway();
    final _RecordingQuickPasteGateway quickPaste =
        _RecordingQuickPasteGateway();
    addTearDown(controller.dispose);
    final ClipboardRecord record = ClipboardRecord(
      id: 'return-clip',
      group: 'Clipboard',
      title: 'Return clipboard item',
      content: 'Return clipboard value',
      tags: const <String>['clipboard', 'text'],
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: DateTime.utc(2026, 7, 12),
      updatedAt: DateTime.utc(2026, 7, 12),
    );
    await tester.pumpWidget(
      DingDongApp(
        clipboardStore: InMemoryClipboardStore(<ClipboardRecord>[record]),
        clipboardGateway: clipboard,
        clipboardPreviewLauncher: preview,
        quickPasteGateway: quickPaste,
        shellController: controller,
      ),
    );
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(clipboard.writtenText, record.content);
    expect(quickPaste.pasteCount, 1);
    expect(preview.hideCount, 1);
  });

  testWidgets('tab content is centered until Command reveals the shortcut', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const DingDongApp());
    await tester.pumpAndSettle();

    final Finder tab = find.byKey(const Key('popup-tab-0'));
    final Finder content = find.byKey(const Key('popup-tab-content-0'));
    expect(
      (tester.getCenter(tab).dx - tester.getCenter(content).dx).abs(),
      lessThan(1),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.text(todayShortcut), findsOneWidget);
    expect(
      tester.getCenter(content).dx,
      lessThan(tester.getCenter(tab).dx - 10),
    );

    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));

    expect(find.text(todayShortcut), findsNothing);
    expect(
      (tester.getCenter(tab).dx - tester.getCenter(content).dx).abs(),
      lessThan(1),
    );
  });

  testWidgets(
    'refresh uses the original tab loading feedback and button size',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const DingDongApp());
      await tester.pumpAndSettle();

      final Finder refresh = find.byKey(const Key('popup-refresh'));
      expect(tester.getSize(refresh), const Size.square(32));

      await tester.tap(refresh);
      await tester.pump();

      expect(find.byKey(const Key('popup-tab-loading-0')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 719));
      expect(find.byKey(const Key('popup-tab-loading-0')), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 2));
      expect(find.byKey(const Key('popup-tab-loading-0')), findsNothing);
    },
  );
}

final class _QueuedContextMenuGateway implements DesktopContextMenuGateway {
  _QueuedContextMenuGateway(this.results);

  final List<String?> results;
  int showCount = 0;

  @override
  Future<String?> show({
    required double x,
    required double y,
    required bool useChinese,
    required List<DesktopContextMenuItem> items,
  }) async {
    final int index = showCount++;
    return index < results.length ? results[index] : null;
  }
}

final class _FakeResourceManagerLauncher implements ResourceManagerLauncher {
  _FakeResourceManagerLauncher({this.onShow});

  final VoidCallback? onShow;
  int openCount = 0;
  String? lastEditingResourceId;

  @override
  Future<void> show({String? editingResourceId}) async {
    openCount += 1;
    lastEditingResourceId = editingResourceId;
    onShow?.call();
  }
}

final class _FakeSettingsWindowLauncher implements SettingsWindowLauncher {
  _FakeSettingsWindowLauncher({this.onShow});

  final VoidCallback? onShow;
  int openCount = 0;

  @override
  Future<void> show() async {
    openCount += 1;
    onShow?.call();
  }
}

final class _FakeClipboardPreviewLauncher implements ClipboardPreviewLauncher {
  ClipboardRecord? shownRecord;
  int hideCount = 0;

  @override
  Future<void> hide() async {
    hideCount += 1;
  }

  @override
  Future<void> show(ClipboardRecord record) async {
    shownRecord = record;
  }
}

final class _RecordingClipboardGateway implements ClipboardGateway {
  String? writtenText;

  @override
  Future<ClipboardSnapshot> read() async => const ClipboardSnapshot();

  @override
  Future<void> writeFiles(List<String> paths) async {}

  @override
  Future<void> writeText(String text) async {
    writtenText = text;
  }
}

final class _RecordingQuickPasteGateway implements QuickPasteGateway {
  int pasteCount = 0;

  @override
  Future<bool> pasteIntoPreviousApplication() async {
    pasteCount += 1;
    return true;
  }
}
