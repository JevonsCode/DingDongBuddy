import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/features/jev/data/jev_service.dart';
import 'package:dingdong/features/jev/ui/jev_plugin_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, Object?> state({
  bool installed = false,
  bool configured = false,
  bool enabled = false,
}) => {
  'installed': installed,
  'configured': configured,
  'enabled': enabled,
  'today': usage,
  'usage': usage,
};
const usage = {
  'requests': 0,
  'input_tokens': 0,
  'output_tokens': 0,
  'estimated_usd': 0.0,
  'unknown_usage_requests': 0,
};

Future<void> pump(
  WidgetTester tester,
  JevAction action, {
  double width = 620,
  bool dark = false,
  String locale = 'en',
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: DingDongLocalizations.localizationsDelegates,
      supportedLocales: DingDongLocalizations.supportedLocales,
      theme: (dark ? AppTheme.desktopPanelDark() : AppTheme.desktopPanelLight())
          .copyWith(
            textTheme:
                (dark
                        ? AppTheme.desktopPanelDark()
                        : AppTheme.desktopPanelLight())
                    .textTheme
                    .apply(fontFamily: 'JevReview'),
          ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: RepaintBoundary(
            key: const Key('jev-preview'),
            child: ColoredBox(
              color: dark ? const Color(0xFF202C33) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: JevPluginSection(action: action),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opt-in lifecycle, key clearing and no implicit live test', (
    tester,
  ) async {
    final calls = <String>[];
    var installed = false, configured = false, enabled = false;
    await pump(tester, (action, args) async {
      calls.add(action);
      if (action == 'install') installed = true;
      if (action == 'saveKey') {
        configured = true;
        enabled = false;
      }
      if (action == 'enable') enabled = args['enabled'] == true;
      if (action == 'uninstall') {
        installed = false;
        configured = false;
        enabled = false;
      }
      return state(
        installed: installed,
        configured: configured,
        enabled: enabled,
      );
    });
    expect(find.byKey(const Key('jev-api-key')), findsNothing);
    await tester.tap(find.byKey(const Key('jev-install')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('jev-api-key')),
      'synthetic-test-key-never-a-real-key',
    );
    await tester.tap(find.byKey(const Key('jev-save-key')));
    await tester.pumpAndSettle();
    final field = tester.widget<EditableText>(find.byType(EditableText));
    expect(field.obscureText, true);
    expect(field.controller.text, isEmpty);
    expect(calls, ['status', 'install', 'saveKey']);
    await tester.ensureVisible(find.byKey(const Key('jev-enabled')));
    await tester.tap(find.byKey(const Key('jev-enabled')));
    await tester.pumpAndSettle();
    expect(calls.last, 'enable');
    expect(calls, isNot(contains('verify')));
    await tester.ensureVisible(find.byKey(const Key('jev-uninstall')));
    await tester.tap(find.byKey(const Key('jev-uninstall')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('jev-install')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'loading suppresses duplicate install; failed status is not zero usage',
    (tester) async {
      final gate = Completer<Map<String, Object?>>();
      int installs = 0;
      await pump(tester, (action, args) async {
        if (action == 'install') {
          installs++;
          return gate.future;
        }
        return state();
      });
      await tester.tap(find.byKey(const Key('jev-install')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('jev-install')));
      await tester.pump();
      expect(installs, 1);
      gate.complete(state(installed: true));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(
        tester,
        (_, _) async => throw const JevException('local_storage_failed'),
      );
      expect(find.byKey(const Key('jev-retry')), findsOneWidget);
      expect(find.text('No Jev calls recorded yet.'), findsNothing);
    },
  );
  for (final locale in ['en', 'zh', 'es']) {
    testWidgets('settings remain usable at minimum width in $locale', (
      tester,
    ) async {
      await pump(
        tester,
        (_, _) async => state(installed: true, configured: true, enabled: true),
        locale: locale,
        width: 620,
      );
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'render Jev settings for visual review with explicitly synthetic usage',
    (tester) async {
      if (!Platform.isMacOS ||
          Platform.environment['JVS_A_JEV_CAPTURE'] != '1') {
        return;
      }
      // Use the actual system typeface for human review, not Ahem test glyphs.
      await tester.runAsync(() async {
        for (final spec in [
          ('JevReview', '/System/Library/Fonts/STHeiti Light.ttc'),
          ('.AppleSystemUIFont', '/System/Library/Fonts/STHeiti Light.ttc'),
          ('Roboto', '/System/Library/Fonts/STHeiti Light.ttc'),
          ('Ahem', '/System/Library/Fonts/STHeiti Light.ttc'),
          (
            'MaterialIcons',
            '/Users/temptrip/.local/share/flutter-3.44.6/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ),
        ]) {
          final file = File(spec.$2);
          if (file.existsSync()) {
            final font = FontLoader(spec.$1)
              ..addFont(
                Future.value(ByteData.sublistView(file.readAsBytesSync())),
              );
            await font.load();
          }
        }
      });
      final dir = Directory('build/jev-review')..createSync(recursive: true);
      for (final view in [(620.0, false, 'zh'), (1000.0, true, 'en')]) {
        await tester.pumpWidget(const SizedBox.shrink());
        await pump(
          tester,
          (_, _) async =>
              state(installed: true, configured: true, enabled: true),
          width: view.$1,
          dark: view.$2,
          locale: view.$3,
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(const Key('jev-preview')),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${dir.path}/${view.$3}-${view.$1.toInt()}.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
        expect(tester.takeException(), isNull);
      }
    },
  );
}
