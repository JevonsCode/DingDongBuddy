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
      expect(tester.getSize(menuRoot), const Size(224, 34));
      final Finder menuMaterial = find.ancestor(
        of: menuRoot,
        matching: find.byType(Material),
      );
      final Material material = tester.widget<Material>(menuMaterial.first);
      expect(material.color, const Color(0xFFFCFCFB));
      final RoundedRectangleBorder shape =
          material.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(10));
      expect(find.text('Ctrl+E'), findsOneWidget);
      expect(
        tester.widget<Text>(find.text('Delete')).style?.color,
        const Color(0xFFEB5757),
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

      expect(await result, 'second');
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
