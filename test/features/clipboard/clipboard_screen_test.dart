import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_context_menu.dart';
import 'package:dingdong/features/clipboard/domain/quick_paste_gateway.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_list_tile.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_screen.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/quick_paste_permission.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void testWidgetsOnPlatform(
  String description,
  TargetPlatform platform,
  WidgetTesterCallback callback,
) {
  testWidgets(description, (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await callback(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  testWidgets('5000 clipboard rows build only the visible window', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026, 7, 12);
    final List<ClipboardRecord> records = List<ClipboardRecord>.generate(
      5000,
      (int index) => ClipboardRecord(
        id: 'clipboard-$index',
        group: 'Clipboard',
        title: 'Clipboard $index',
        content: 'Content $index',
        tags: const <String>['clipboard', 'text'],
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: now.add(Duration(seconds: index)),
        updatedAt: now.add(Duration(seconds: index)),
      ),
    );
    final ClipboardViewModel model = ClipboardViewModel(
      _MemoryClipboardStore(records),
    );
    model.load();

    await tester.pumpWidget(
      MaterialApp(home: ClipboardScreen(viewModel: model)),
    );

    expect(find.byType(ClipboardListTile).evaluate().length, lessThan(100));
    await tester.drag(
      find.byKey(const Key('clipboard-list')),
      const Offset(0, -400000),
    );
    await tester.pumpAndSettle();
    expect(find.text('Clipboard 4999'), findsOneWidget);
  });

  testWidgets('return-to-top appears after one viewport and scrolls to start', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026, 7, 16);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(
        List<ClipboardRecord>.generate(
          100,
          (int index) => ClipboardRecord(
            id: 'item-$index',
            group: 'Clipboard',
            title: 'Item $index',
            content: 'Value $index',
            tags: const <String>['clipboard', 'text'],
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now.subtract(Duration(seconds: index)),
            updatedAt: now.subtract(Duration(seconds: index)),
          ),
        ),
      ),
    )..load();
    await tester.pumpWidget(
      MaterialApp(home: ClipboardScreen(viewModel: model)),
    );

    expect(find.byKey(const Key('clipboard-scroll-to-top')), findsNothing);
    await tester.drag(
      find.byKey(const Key('clipboard-list')),
      const Offset(0, -900),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clipboard-scroll-to-top')), findsOneWidget);

    await tester.tap(find.byKey(const Key('clipboard-scroll-to-top')));
    await tester.pumpAndSettle();

    expect(find.text('Item 0'), findsOneWidget);
    expect(find.byKey(const Key('clipboard-scroll-to-top')), findsNothing);
  });

  testWidgets(
    'category filters narrow clipboard history without a database reload',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final DateTime now = DateTime.utc(2026, 7, 12);
      final ClipboardViewModel model = ClipboardViewModel(
        _MemoryClipboardStore(<ClipboardRecord>[
          ClipboardRecord(
            id: 'command',
            group: 'Commands',
            title: 'Run tests',
            content: 'flutter test',
            tags: const <String>['clipboard', 'command'],
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now,
            updatedAt: now,
          ),
          ClipboardRecord(
            id: 'url',
            group: 'URLs',
            title: 'Flutter docs',
            content: 'https://docs.flutter.dev',
            tags: const <String>['clipboard', 'url'],
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );
      model.load();
      await tester.pumpWidget(
        MaterialApp(home: ClipboardScreen(viewModel: model)),
      );

      await tester.tap(find.byKey(const Key('clipboard-category-text')));
      await tester.pump();

      expect(
        find.widgetWithText(ClipboardListTile, 'Run tests'),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ClipboardListTile, 'Flutter docs'),
        findsNothing,
      );
    },
  );

  testWidgets('arrow keys move selection through visible clipboard rows', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026, 7, 12);
    final List<ClipboardRecord> records = List<ClipboardRecord>.generate(
      2,
      (int index) => ClipboardRecord(
        id: 'item-$index',
        group: 'Clipboard',
        title: 'Item $index',
        content: 'Value $index',
        tags: const <String>['clipboard', 'text'],
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: now,
        updatedAt: now,
      ),
    );
    final ClipboardViewModel model = ClipboardViewModel(
      _MemoryClipboardStore(records),
    );
    model.load();
    await tester.pumpWidget(
      MaterialApp(home: ClipboardScreen(viewModel: model)),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();

    expect(model.selectedRecord?.id, 'item-1');
  });

  testWidgets('Command-R toggles clipboard filters from the icon button', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[_record()]),
    )..load();
    await tester.pumpWidget(
      MaterialApp(home: ClipboardScreen(viewModel: model)),
    );

    final Finder transition = find.byKey(
      const Key('clipboard-filter-transition'),
    );
    expect(transition, findsOneWidget);
    expect(tester.widget<ScaleTransition>(transition).scale.value, 1);
    expect(find.byKey(const Key('clipboard-filter-icon')), findsOneWidget);
    expect(find.byKey(const Key('clipboard-category-text')), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.widget<ScaleTransition>(transition).scale.value, lessThan(1));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clipboard-category-text')), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(tester.widget<ScaleTransition>(transition).scale.value, lessThan(1));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('clipboard-category-text')), findsNothing);
  });

  testWidgets('Command-F focuses clipboard search', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[_record()]),
    )..load();
    await tester.pumpWidget(
      MaterialApp(home: ClipboardScreen(viewModel: model)),
    );
    await tester.pump();

    final Finder searchEditable = find.descendant(
      of: find.byKey(const Key('clipboard-search')),
      matching: find.byType(EditableText),
    );
    expect(
      tester.widget<EditableText>(searchEditable).focusNode.hasFocus,
      isFalse,
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();

    final EditableText editable = tester.widget<EditableText>(searchEditable);
    expect(editable.focusNode.hasFocus, isTrue);
  });

  testWidgets('filter icon explains expand and collapse actions on hover', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[_record()]),
    )..load();
    await tester.pumpWidget(
      MaterialApp(home: ClipboardScreen(viewModel: model)),
    );

    expect(find.byTooltip('Show categories and groups'), findsOneWidget);
    expect(
      find.image(const AssetImage('Assets/Symbols/filter.png')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('clipboard-toggle-filters')));
    await tester.pump();
    expect(find.byTooltip('Hide categories and groups'), findsOneWidget);
    expect(
      find.image(const AssetImage('Assets/Symbols/collapse.png')),
      findsOneWidget,
    );
    expect(
      find.image(const AssetImage('Assets/Symbols/filter.png')),
      findsNothing,
    );
  });

  testWidgets('clipboard group filters use concise names and small type', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ClipboardRecord grouped = ClipboardRecord(
      id: 'grouped',
      group: '项目甲',
      title: 'Grouped item',
      content: 'Grouped value',
      tags: const <String>['clipboard', 'text'],
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: DateTime.utc(2026, 7, 12),
      updatedAt: DateTime.utc(2026, 7, 12),
    );
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[grouped]),
    )..load();
    await tester.pumpWidget(
      MaterialApp(home: ClipboardScreen(viewModel: model)),
    );

    expect(find.text('All'), findsWidgets);
    expect(find.text('项目甲'), findsWidgets);
    expect(find.text('All groups'), findsNothing);
    expect(find.text('Group: 项目甲'), findsNothing);
    expect(tester.widget<Text>(find.text('项目甲')).style?.fontSize, 9);
  });

  testWidgets('group filters keep a dedicated drag target', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ClipboardRecord grouped = ClipboardRecord(
      id: 'filter-layout',
      group: 'test',
      title: 'Flutter',
      content: 'https://flutter.dev',
      tags: const <String>['clipboard', 'url'],
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: DateTime.utc(2026, 7, 13),
      updatedAt: DateTime.utc(2026, 7, 13),
    );
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[grouped]),
    )..load();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: ClipboardScreen(viewModel: model),
      ),
    );
    await tester.tap(find.byKey(const Key('clipboard-toggle-filters')));
    await tester.pump();

    expect(find.byIcon(Icons.drag_handle), findsNothing);
    expect(find.byType(ReorderableDragStartListener), findsOneWidget);
  });

  testWidgets('missing quick paste permission is actionable from clipboard', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final _RecordingQuickPastePermission permission =
        _RecordingQuickPastePermission(granted: true);
    final SettingsViewModel settings = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      quickPastePermissionGateway: permission,
    );
    await settings.load();
    permission.granted = false;
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[_record()]),
    )..load();
    await tester.pumpWidget(
      MaterialApp(
        home: ClipboardScreen(viewModel: model, settingsViewModel: settings),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('clipboard-permission-banner')),
      findsOneWidget,
    );
    expect(find.textContaining('Accessibility permission'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('clipboard-open-permission-settings')),
    );
    await tester.pump();

    expect(permission.openCount, 1);

    permission.granted = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('clipboard-permission-banner')), findsNothing);
  });

  testWidgets('the first row starts selected and Space previews it', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ClipboardRecord first = _record();
    final ClipboardRecord second = ClipboardRecord(
      id: 'clip-2',
      group: 'Clipboard',
      title: 'Second item',
      content: 'Second value',
      tags: const <String>['clipboard', 'text'],
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: DateTime.utc(2026, 7, 12),
      updatedAt: DateTime.utc(2026, 7, 12),
    );
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[first, second]),
    )..load();
    ClipboardRecord? previewed;
    await tester.pumpWidget(
      MaterialApp(
        home: ClipboardScreen(
          viewModel: model,
          onPreview: (ClipboardRecord record) async {
            previewed = record;
          },
        ),
      ),
    );

    expect(model.selectedRecord?.id, first.id);
    final ClipboardListTile firstTile = tester.widget<ClipboardListTile>(
      find.widgetWithText(ClipboardListTile, first.title),
    );
    expect(firstTile.selected, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(model.selectedRecord?.id, first.id);
    expect(previewed?.id, first.id);
  });

  testWidgets('preview actions pin the selected clipboard row', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026, 7, 12);
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[
        ClipboardRecord(
          id: 'clip',
          group: 'Clipboard',
          title: 'Clipboard item',
          content: 'Value',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    )..load();
    await tester.pumpWidget(
      MaterialApp(home: ClipboardScreen(viewModel: model)),
    );
    await tester.tap(find.text('Pin'));
    await tester.pump();

    expect(model.selectedRecord?.pinned, isTrue);
    expect(find.text('Unpin'), findsOneWidget);
  });

  testWidgets('Return restores the selected clipboard row', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026, 7, 12);
    final _RecordingGateway gateway = _RecordingGateway();
    final _RecordingQuickPasteGateway quickPaste =
        _RecordingQuickPasteGateway();
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[
        ClipboardRecord(
          id: 'clip',
          group: 'Clipboard',
          title: 'Clipboard item',
          content: 'Restored value',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        ),
      ]),
      gateway: gateway,
      quickPasteGateway: quickPaste,
    )..load();
    int dismissCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ClipboardScreen(
          viewModel: model,
          onDismissPreview: () async {
            dismissCount += 1;
          },
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(gateway.writtenText, 'Restored value');
    expect(quickPaste.pasteCount, 1);
    expect(dismissCount, 1);
  });

  testWidgets('callout single click previews the clipboard row', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ClipboardRecord record = _record();
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[record]),
    )..load();
    ClipboardRecord? previewed;

    await tester.pumpWidget(
      MaterialApp(
        home: ClipboardScreen(
          viewModel: model,
          onPreview: (ClipboardRecord value) async {
            previewed = value;
          },
        ),
      ),
    );
    await tester.tap(find.text(record.title));
    await tester.pump();

    expect(previewed?.id, record.id);
  });

  testWidgets('callout double click uses the clipboard row', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final _RecordingGateway gateway = _RecordingGateway();
    final _RecordingQuickPasteGateway quickPaste =
        _RecordingQuickPasteGateway();
    final ClipboardRecord record = _record();
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[record]),
      gateway: gateway,
      quickPasteGateway: quickPaste,
    )..load();
    int previewCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ClipboardScreen(
          viewModel: model,
          onPreview: (_) async {
            previewCount += 1;
          },
        ),
      ),
    );
    await tester.tap(find.text(record.title));
    await tester.pump(const Duration(milliseconds: 40));
    await tester.tap(find.text(record.title));
    await tester.pumpAndSettle();

    expect(gateway.writtenText, record.content);
    expect(quickPaste.pasteCount, 1);
    expect(previewCount, 1);
  });

  testWidgetsOnPlatform(
    'secondary click exposes the original clipboard actions',
    TargetPlatform.windows,
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final ClipboardRecord record = _record();
      final ClipboardViewModel model = ClipboardViewModel(
        InMemoryClipboardStore(<ClipboardRecord>[record]),
      )..load();

      await tester.pumpWidget(
        MaterialApp(home: ClipboardScreen(viewModel: model)),
      );
      await tester.tap(find.text(record.title), buttons: kSecondaryButton);
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('windows-context-menu')), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Copy'), findsOneWidget);
      expect(find.text('Add title'), findsOneWidget);
      expect(find.text('Edit text'), findsOneWidget);
      expect(find.text('Save as prompt'), findsOneWidget);
      expect(find.text('Save as knowledge'), findsNothing);
      expect(find.text('Archive'), findsNothing);
      expect(find.text('Archive to…'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    },
  );

  testWidgets(
    'archive to selects existing and new groups without a large alert',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(760, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final ClipboardRecord target = _record();
      final InMemoryClipboardStore store = InMemoryClipboardStore(
        <ClipboardRecord>[
          target,
          ClipboardRecord(
            id: 'existing-group',
            group: '项目甲',
            title: 'Existing',
            content: 'Existing',
            tags: const <String>['clipboard', 'text'],
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: DateTime.utc(2026, 7, 12),
            updatedAt: DateTime.utc(2026, 7, 12),
          ),
        ],
      );
      final ClipboardViewModel model = ClipboardViewModel(store)..load();

      await tester.pumpWidget(
        MaterialApp(home: ClipboardScreen(viewModel: model)),
      );
      await tester.tap(find.text(target.title), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive to…'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('clipboard-group-dialog')), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('项目甲'), findsWidgets);
      final Dialog dialog = tester.widget<Dialog>(
        find.byKey(const Key('clipboard-group-dialog')),
      );
      final RoundedRectangleBorder shape =
          dialog.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(7));
      expect(
        find.descendant(
          of: find.byKey(const Key('clipboard-group-dialog')),
          matching: find.byType(Checkbox),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('clipboard-group-dialog')),
          matching: find.byIcon(Icons.check_box_outline_blank_rounded),
        ),
        findsNothing,
      );

      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('clipboard-group-dialog')),
          matching: find.byKey(const ValueKey<String>('clipboard-group-项目甲')),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('clipboard-new-group')),
        '项目乙',
      );
      await tester.tap(find.byKey(const Key('clipboard-save-groups')));
      await tester.pumpAndSettle();

      expect(model.selectedRecord?.groupNames, <String>[
        'Clipboard',
        '项目甲',
        '项目乙',
      ]);
    },
  );

  testWidgets('right-clicking a group deletes only its membership', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(760, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026, 7, 16);
    final InMemoryClipboardStore store = InMemoryClipboardStore(
      <ClipboardRecord>[
        ClipboardRecord(
          id: 'first',
          group: '项目甲',
          title: 'First',
          content: 'First',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        ),
        ClipboardRecord(
          id: 'second',
          group: '项目甲',
          title: 'Second',
          content: 'Second',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: now,
          updatedAt: now,
        ),
      ],
    );
    final ClipboardViewModel model = ClipboardViewModel(store)..load();

    await tester.pumpWidget(
      MaterialApp(
        home: ClipboardScreen(viewModel: model, filtersExpanded: true),
      ),
    );
    final Finder group = find.byKey(
      const ValueKey<String>('clipboard-group-项目甲'),
    );
    await tester.tap(group, buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('Delete group'), findsOneWidget);
    await tester.tap(find.text('Delete group'));
    await tester.pumpAndSettle();
    expect(find.text('Delete “项目甲”?'), findsOneWidget);
    expect(find.textContaining('2 clipboard items'), findsOneWidget);

    await tester.tap(find.text('Delete group'));
    await tester.pumpAndSettle();

    expect(group, findsNothing);
    expect(store.list(limit: 10), hasLength(2));
    expect(
      store
          .list(limit: 10)
          .every((ClipboardRecord item) => !item.groupNames.contains('项目甲')),
      isTrue,
    );
  });

  testWidgets('secondary click delegates to the native desktop context menu', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ClipboardRecord record = _record();
    final _RecordingGateway clipboardGateway = _RecordingGateway();
    final _FakeContextMenuGateway menuGateway = _FakeContextMenuGateway(
      ClipboardContextAction.copy,
    );
    final ClipboardViewModel model = ClipboardViewModel(
      InMemoryClipboardStore(<ClipboardRecord>[record]),
      gateway: clipboardGateway,
    )..load();

    await tester.pumpWidget(
      MaterialApp(
        home: ClipboardScreen(
          viewModel: model,
          contextMenuGateway: menuGateway,
        ),
      ),
    );
    await tester.tap(find.text(record.title), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(menuGateway.showCount, 1);
    expect(clipboardGateway.writtenText, record.content);
    expect(find.text('Details'), findsNothing);
  });

  testWidgets('Capture now adds the current platform clipboard text', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final InMemoryClipboardStore store = InMemoryClipboardStore();
    final _StaticGateway gateway = _StaticGateway(
      const ClipboardSnapshot(text: 'flutter test', source: 'Terminal'),
    );
    final ClipboardCaptureService captureService = ClipboardCaptureService(
      gateway: gateway,
      store: store,
      idGenerator: () => 'captured',
      now: () => DateTime.utc(2026, 7, 12),
    );
    final ClipboardViewModel model = ClipboardViewModel(
      store,
      captureService: captureService,
      gateway: gateway,
    )..load();
    await tester.pumpWidget(
      MaterialApp(home: ClipboardScreen(viewModel: model)),
    );

    await tester.tap(find.text('Capture now'));
    await tester.pumpAndSettle();

    expect(find.text('flutter test'), findsWidgets);
    expect(model.selectedRecord?.id, 'captured');
  });
}

ClipboardRecord _record() => ClipboardRecord(
  id: 'clip',
  group: 'Clipboard',
  title: 'Clipboard item',
  content: 'Restored value',
  tags: const <String>['clipboard', 'text'],
  pinned: false,
  enabled: true,
  activation: 'taskMatch',
  createdAt: DateTime.utc(2026, 7, 12),
  updatedAt: DateTime.utc(2026, 7, 12),
);

final class _MemoryClipboardStore implements ClipboardStore {
  _MemoryClipboardStore(this.records);

  final List<ClipboardRecord> records;

  @override
  List<ClipboardRecord> list({required int limit}) =>
      records.take(limit).toList();

  @override
  void save(ClipboardRecord record) {}

  @override
  void delete(String id) {
    records.removeWhere((ClipboardRecord record) => record.id == id);
  }
}

final class _FakeContextMenuGateway implements DesktopContextMenuGateway {
  _FakeContextMenuGateway(this.result);

  final ClipboardContextAction? result;
  int showCount = 0;

  @override
  Future<String?> show({
    required double x,
    required double y,
    required bool useChinese,
    required List<DesktopContextMenuItem> items,
  }) async {
    showCount += 1;
    return result?.name;
  }
}

final class _RecordingGateway implements ClipboardGateway {
  String? writtenText;

  @override
  Future<ClipboardSnapshot> read() async => const ClipboardSnapshot();

  @override
  Future<void> writeText(String text) async {
    writtenText = text;
  }

  @override
  Future<void> writeFiles(List<String> paths) async {}
}

final class _RecordingQuickPasteGateway implements QuickPasteGateway {
  int pasteCount = 0;

  @override
  Future<bool> pasteIntoPreviousApplication() async {
    pasteCount += 1;
    return true;
  }
}

final class _RecordingQuickPastePermission
    implements QuickPastePermissionGateway {
  _RecordingQuickPastePermission({required this.granted});

  bool granted;
  int openCount = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<void> openSettings() async {
    openCount += 1;
  }
}

final class _StaticGateway implements ClipboardGateway {
  _StaticGateway(this.snapshot);

  final ClipboardSnapshot snapshot;

  @override
  Future<ClipboardSnapshot> read() async => snapshot;

  @override
  Future<void> writeText(String text) async {}

  @override
  Future<void> writeFiles(List<String> paths) async {}
}
