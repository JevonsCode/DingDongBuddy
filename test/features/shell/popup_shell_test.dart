import 'dart:io';

import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_preview_launcher.dart';
import 'package:dingdong/features/clipboard/domain/quick_paste_gateway.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
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

final class _FakeResourceManagerLauncher implements ResourceManagerLauncher {
  _FakeResourceManagerLauncher({this.onShow});

  final VoidCallback? onShow;
  int openCount = 0;

  @override
  Future<void> show({String? editingResourceId}) async {
    openCount += 1;
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
