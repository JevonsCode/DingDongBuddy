import 'dart:io';

import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> withTargetPlatform(
  TargetPlatform platform,
  Future<void> Function() callback,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await callback();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  testWidgets('controller dismisses the active desktop context menu', (
    WidgetTester tester,
  ) async {
    final DesktopContextMenuController controller =
        DesktopContextMenuController();
    late BuildContext menuContext;
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopContextMenuScope(
          controller: controller,
          child: Builder(
            builder: (BuildContext context) {
              menuContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      ),
    );

    final Future<String?> result = showDesktopContextMenu<String>(
      context: menuContext,
      globalPosition: const Offset(40, 40),
      entries: const <DesktopMenuEntry<String>>[
        DesktopMenuItem<String>(value: 'edit', label: 'Edit', symbol: 'edit'),
      ],
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit'), findsOneWidget);

    final Future<void> dismissal = controller.dismissActiveMenu();
    await tester.pumpAndSettle();
    await dismissal;

    expect(await result, isNull);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('controller does not dismiss routes opened after the menu', (
    WidgetTester tester,
  ) async {
    final DesktopContextMenuController controller =
        DesktopContextMenuController();
    late BuildContext menuContext;
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopContextMenuScope(
          controller: controller,
          child: Builder(
            builder: (BuildContext context) {
              menuContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      ),
    );

    final Future<String?> menuResult = showDesktopContextMenu<String>(
      context: menuContext,
      globalPosition: const Offset(40, 40),
      entries: const <DesktopMenuEntry<String>>[
        DesktopMenuItem<String>(value: 'edit', label: 'Edit', symbol: 'edit'),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(await menuResult, 'edit');

    final Future<void> dialogResult = showDialog<void>(
      context: menuContext,
      builder: (BuildContext context) => const AlertDialog(
        key: Key('unrelated-dialog'),
        content: Text('Keep this dialog open'),
      ),
    );
    await tester.pumpAndSettle();

    await controller.dismissActiveMenu();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unrelated-dialog')), findsOneWidget);

    Navigator.of(menuContext).pop();
    await tester.pumpAndSettle();
    await dialogResult;
  });

  testWidgets('controller removes the menu below a later dialog', (
    WidgetTester tester,
  ) async {
    final DesktopContextMenuController controller =
        DesktopContextMenuController();
    late BuildContext menuContext;
    await tester.pumpWidget(
      MaterialApp(
        home: DesktopContextMenuScope(
          controller: controller,
          child: Builder(
            builder: (BuildContext context) {
              menuContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      ),
    );

    final Future<String?> menuResult = showDesktopContextMenu<String>(
      context: menuContext,
      globalPosition: const Offset(40, 40),
      entries: const <DesktopMenuEntry<String>>[
        DesktopMenuItem<String>(
          value: 'edit',
          label: 'Edit',
          symbol: 'edit',
        ),
      ],
    );
    await tester.pumpAndSettle();

    final Future<void> dialogResult = showDialog<void>(
      context: menuContext,
      builder: (BuildContext context) => const AlertDialog(
        key: Key('dialog-above-menu'),
        content: Text('Keep this dialog open'),
      ),
    );
    await tester.pumpAndSettle();

    final Future<void> dismissal = controller.dismissActiveMenu();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dialog-above-menu')), findsOneWidget);
    expect(find.text('Edit'), findsNothing);

    Navigator.of(menuContext).pop();
    await tester.pumpAndSettle();
    await dialogResult;
    await dismissal;
    expect(await menuResult, isNull);
  });

  testWidgets('Windows menu uses compact Notion-like styling', (
    WidgetTester tester,
  ) async {
    await withTargetPlatform(TargetPlatform.windows, () async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      late BuildContext menuContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              menuContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );

      final Future<String?> result = showDesktopContextMenu<String>(
        context: menuContext,
        globalPosition: const Offset(40, 40),
        entries: const <DesktopMenuEntry<String>>[
          DesktopMenuItem<String>(
            key: Key('menu-edit'),
            value: 'edit',
            label: 'Edit',
            symbol: 'edit',
            shortcut: 'Ctrl+E',
          ),
          DesktopMenuDivider<String>(),
          DesktopMenuItem<String>(
            key: Key('menu-delete'),
            value: 'delete',
            label: 'Delete',
            symbol: 'delete',
            destructive: true,
          ),
        ],
      );
      await tester.pumpAndSettle();

      final Finder menuRoot = find.byKey(const Key('windows-context-menu'));
      expect(menuRoot, findsOneWidget);
      expect(tester.getSize(menuRoot), const Size(252, 32));
      final Finder menuMaterial = find.ancestor(
        of: menuRoot,
        matching: find.byType(Material),
      );
      final Material material = tester.widget<Material>(menuMaterial.first);
      expect(material.color, const Color(0xFFFCFCFB));
      expect(material.elevation, 2);
      final RoundedRectangleBorder shape =
          material.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(10));
      expect(find.text('Ctrl+E'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Delete')).style?.color,
        const Color(0xFF37352F),
      );

      await tester.tap(find.byKey(const Key('menu-delete')));
      await tester.pumpAndSettle();
      expect(await result, 'delete');
    });
  });

  testWidgets('Windows menu supports keyboard selection', (
    WidgetTester tester,
  ) async {
    await withTargetPlatform(TargetPlatform.windows, () async {
      late BuildContext menuContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              menuContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );
      final Future<String?> result = showDesktopContextMenu<String>(
        context: menuContext,
        globalPosition: const Offset(40, 40),
        entries: const <DesktopMenuEntry<String>>[
          DesktopMenuItem<String>(
            value: 'first',
            label: 'First',
            symbol: 'details',
          ),
          DesktopMenuItem<String>(
            value: 'second',
            label: 'Second',
            symbol: 'copy',
          ),
        ],
      );
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(await result, 'first');
    });
  });

  testWidgets('Windows menu follows the app dark theme', (
    WidgetTester tester,
  ) async {
    await withTargetPlatform(TargetPlatform.windows, () async {
      late BuildContext menuContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Builder(
            builder: (BuildContext context) {
              menuContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );
      final Future<String?> result = showDesktopContextMenu<String>(
        context: menuContext,
        globalPosition: const Offset(40, 40),
        entries: const <DesktopMenuEntry<String>>[
          DesktopMenuItem<String>(value: 'edit', label: 'Edit', symbol: 'edit'),
        ],
      );
      await tester.pumpAndSettle();

      final Finder menuRoot = find.byKey(const Key('windows-context-menu'));
      final Material material = tester.widget<Material>(
        find.ancestor(of: menuRoot, matching: find.byType(Material)).first,
      );
      expect(material.color, const Color(0xFF252523));

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(await result, 'edit');
    });
  });

  testWidgets('Windows menu visual reference matches the Notion-like spec', (
    WidgetTester tester,
  ) async {
    await withTargetPlatform(TargetPlatform.windows, () async {
      final FontLoader windowsFont = FontLoader('Segoe UI')
        ..addFont(
          Future<ByteData>.value(
            ByteData.sublistView(
              File(r'C:\Windows\Fonts\segoeui.ttf').readAsBytesSync(),
            ),
          ),
        );
      await windowsFont.load();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(271, 483);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      late BuildContext menuContext;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(fontFamily: 'Segoe UI'),
          home: Builder(
            builder: (BuildContext context) {
              menuContext = context;
              return const Scaffold(
                backgroundColor: Color(0xFFF7F7F5),
                body: SizedBox.expand(),
              );
            },
          ),
        ),
      );
      await tester.runAsync(() async {
        for (final String symbol in <String>[
          'enabled',
          'archive',
          'link',
          'copy',
          'edit',
          'archive_to',
          'delete',
          'details',
          'share',
        ]) {
          await precacheImage(
            AssetImage('Assets/Symbols/$symbol.png'),
            menuContext,
          );
        }
      });

      final Future<String?> result = showDesktopContextMenu<String>(
        context: menuContext,
        globalPosition: const Offset(7, 5),
        entries: const <DesktopMenuEntry<String>>[
          DesktopMenuItem<String>(
            value: 'favorite',
            label: 'Add to Favorites',
            symbol: 'enabled',
          ),
          DesktopMenuItem<String>(
            value: 'recents',
            label: 'Remove from Recents',
            symbol: 'archive',
          ),
          DesktopMenuDivider<String>(),
          DesktopMenuItem<String>(
            value: 'copy',
            label: 'Copy link',
            symbol: 'link',
          ),
          DesktopMenuItem<String>(
            value: 'duplicate',
            label: 'Duplicate',
            symbol: 'copy',
            shortcut: 'Ctrl+D',
          ),
          DesktopMenuItem<String>(
            value: 'rename',
            label: 'Rename',
            symbol: 'edit',
            shortcut: 'Ctrl+Shift+R',
          ),
          DesktopMenuItem<String>(
            value: 'move',
            label: 'Move to',
            symbol: 'archive_to',
          ),
          DesktopMenuItem<String>(
            value: 'trash',
            label: 'Move to Trash',
            symbol: 'delete',
            destructive: true,
          ),
          DesktopMenuDivider<String>(),
          DesktopMenuItem<String>(
            value: 'details',
            label: 'View details',
            symbol: 'details',
          ),
          DesktopMenuItem<String>(
            value: 'share',
            label: 'Share',
            symbol: 'share',
          ),
        ],
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(Overlay).first,
        matchesGoldenFile('goldens/windows_context_menu_reference.png'),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(await result, isNull);
    });
  }, skip: !Platform.isWindows);

  testWidgets('non-Windows fallback keeps the Material menu', (
    WidgetTester tester,
  ) async {
    await withTargetPlatform(TargetPlatform.macOS, () async {
      late BuildContext menuContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              menuContext = context;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      );
      final Future<String?> result = showDesktopContextMenu<String>(
        context: menuContext,
        globalPosition: const Offset(40, 40),
        entries: const <DesktopMenuEntry<String>>[
          DesktopMenuItem<String>(value: 'edit', label: 'Edit', symbol: 'edit'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('windows-context-menu')), findsNothing);
      expect(find.byType(PopupMenuItem<String>), findsOneWidget);

      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(await result, 'edit');
    });
  });
}
