import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_context_menu_gateway.dart';
import 'package:dingdong/features/clipboard/domain/quick_paste_gateway.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_list_tile.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_screen.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/quick_paste_permission.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

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

      expect(find.text('Run tests'), findsOneWidget);
      expect(find.text('Flutter docs'), findsNothing);
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
    await tester.tap(find.text('Item 0'));
    await tester.pump();

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

    expect(find.byKey(const Key('clipboard-filter-icon')), findsOneWidget);
    expect(find.byKey(const Key('clipboard-category-text')), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.byKey(const Key('clipboard-category-text')), findsOneWidget);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(find.byKey(const Key('clipboard-category-text')), findsNothing);
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
    expect(find.text('项目甲'), findsOneWidget);
    expect(find.text('All groups'), findsNothing);
    expect(find.text('Group: 项目甲'), findsNothing);
    expect(tester.widget<Text>(find.text('项目甲')).style?.fontSize, 9);
  });

  testWidgets('draggable filters do not cover their labels with handles', (
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
    expect(find.byType(ReorderableDragStartListener), findsNWidgets(2));
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

  testWidgets('Arrow Down selects the first row and Space previews it', (
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

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
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
    await tester.tap(find.text('Clipboard item'));
    await tester.pump();

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
    await tester.tap(find.text('Clipboard item'));
    await tester.pump();

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

  testWidgets('secondary click exposes the original clipboard actions', (
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

    await tester.pumpWidget(
      MaterialApp(home: ClipboardScreen(viewModel: model)),
    );
    await tester.tap(find.text(record.title), buttons: kSecondaryButton);
    await tester.pumpAndSettle();

    expect(find.text('Details'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Add title'), findsOneWidget);
    expect(find.text('Edit text'), findsOneWidget);
    expect(find.text('Save as prompt'), findsOneWidget);
    expect(find.text('Save as knowledge'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Archive to…'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
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

final class _FakeContextMenuGateway implements ClipboardContextMenuGateway {
  _FakeContextMenuGateway(this.result);

  final ClipboardContextAction? result;
  int showCount = 0;

  @override
  Future<ClipboardContextAction?> show({
    required double x,
    required double y,
    required bool useChinese,
  }) async {
    showCount += 1;
    return result;
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
