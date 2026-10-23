import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/features/plugins/ui/plugins_screen.dart';
import 'package:dingdong/features/screenshot/domain/screenshot_plugin.dart';
import 'package:dingdong/features/screenshot/ui/screenshot_plugin_section.dart';
import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  windowsTest('render screenshot catalog and details for review', (
    tester,
  ) async {
    if (Platform.environment['DINGDONG_SCREENSHOT_REVIEW'] != '1') return;
    await tester.runAsync(() async {
      for (final family in ['ScreenshotReview', 'Roboto', 'Ahem']) {
        final loader = FontLoader(family)
          ..addFont(
            Future.value(
              ByteData.sublistView(
                File('C:/Windows/Fonts/msyh.ttc').readAsBytesSync(),
              ),
            ),
          );
        await loader.load();
      }
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final output = Directory('build/screenshot-review')
      ..createSync(recursive: true);
    for (final locale in ['zh', 'en']) {
      tester.view.physicalSize = Size(locale == 'zh' ? 1000 : 620, 760);
      final host = _Host();
      final boundary = GlobalKey();
      final baseTheme = locale == 'zh' ? AppTheme.light() : AppTheme.dark();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            locale: Locale(locale),
            debugShowCheckedModeBanner: false,
            localizationsDelegates:
                DingDongLocalizations.localizationsDelegates,
            supportedLocales: DingDongLocalizations.supportedLocales,
            theme: baseTheme.copyWith(
              textTheme: baseTheme.textTheme.apply(
                fontFamily: 'ScreenshotReview',
              ),
            ),
            home: Scaffold(body: PluginsScreen(screenshotAction: host.call)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            '${output.path}/$locale-$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await capture('catalog');
      await tester.tap(find.byKey(const Key('plugin-row-screenshot')));
      await tester.pumpAndSettle();
      await capture('details');
      expect(tester.takeException(), isNull);
    }
  });
  windowsTest(
    'clicking the plugin title opens configuration and back returns',
    (tester) async {
      final host = _Host();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PluginsScreen(screenshotAction: host.call)),
        ),
      );
      expect(host.actions, isEmpty);
      await tester.tap(find.text('Screenshot'));
      await tester.pumpAndSettle();
      expect(host.actions, ['status']);
      expect(find.byKey(const Key('screenshot-hot-key')), findsOneWidget);
      expect(find.byKey(const Key('screenshot-enabled')), findsOneWidget);
      await tester.tap(find.byKey(const Key('plugins-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('plugin-row-screenshot')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('plugin-row-selection')));
      await tester.tap(find.byKey(const Key('plugin-row-selection')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('selection-platform-diagnosis')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-selection-enabled')), findsNothing);
    },
  );

  windowsTest('enable and immediate capture go through the primary host', (
    tester,
  ) async {
    final host = _Host();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ScreenshotPluginSection(action: host.call)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('screenshot-enabled')));
    await tester.pumpAndSettle();
    expect(host.enabled, true);
    expect(find.text('Ready · shortcut registered'), findsOneWidget);
    await tester.tap(find.byKey(const Key('screenshot-capture-now')));
    await tester.pumpAndSettle();
    expect(host.actions.last, 'capture');
  });

  windowsTest(
    'recorder saves custom shortcut and reset uses screenshot default',
    (tester) async {
      final host = _Host();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ScreenshotPluginSection(action: host.call)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('screenshot-hot-key')));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(host.shortcut.key, 'B');
      await tester.tap(find.byKey(const Key('screenshot-hot-key-reset')));
      await tester.pumpAndSettle();
      expect(host.shortcut, ScreenshotConfiguration.defaultShortcut);
    },
  );

  windowsTest(
    'conflict is visible and failed configuration does not look enabled',
    (tester) async {
      final host = _Host()..conflict = true;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ScreenshotPluginSection(action: host.call)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('screenshot-enabled')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('screenshot-error')), findsOneWidget);
      expect(find.text('Ready · shortcut registered'), findsNothing);
      expect(host.enabled, false);
    },
  );

  windowsTest('unsupported platform has no enable or capture controls', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final host = _Host();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ScreenshotPluginSection(action: host.call)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('screenshot-unsupported')), findsOneWidget);
    expect(find.byKey(const Key('screenshot-enabled')), findsNothing);
    expect(find.byKey(const Key('screenshot-capture-now')), findsNothing);
  });

  windowsTest('details fit the resource window at minimum content width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(620, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final host = _Host();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ScreenshotPluginSection(action: host.call),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  windowsTest('busy state prevents duplicate configuration requests', (
    tester,
  ) async {
    final host = _Host();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ScreenshotPluginSection(action: host.call)),
      ),
    );
    await tester.pumpAndSettle();
    host.pause = Completer<void>();
    await tester.tap(find.byKey(const Key('screenshot-enabled')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('screenshot-enabled')));
    expect(host.actions.where((action) => action == 'configure'), hasLength(1));
    host.pause!.complete();
    await tester.pumpAndSettle();
  });
}

class _Host {
  final actions = <String>[];
  bool enabled = false;
  bool conflict = false;
  GlobalHotKey shortcut = ScreenshotConfiguration.defaultShortcut;
  Completer<void>? pause;
  Future<Map<String, Object?>> call(
    String action,
    Map<String, Object?> values,
  ) async {
    actions.add(action);
    if (action == 'configure') {
      await pause?.future;
      if (conflict) throw const ScreenshotPluginException('shortcut_conflict');
      final config = ScreenshotConfiguration.fromArguments({
        'enabled': enabled,
        'shortcut': shortcut.toPlatformArguments(),
        ...values,
      });
      enabled = config.enabled;
      shortcut = config.shortcut;
    }
    return {
      'enabled': enabled,
      'shortcut': shortcut.toPlatformArguments(),
      'supported': true,
      'running': enabled,
      'capturing': false,
    };
  }
}

void windowsTest(String name, WidgetTesterCallback body) {
  testWidgets(name, (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await body(tester);
    debugDefaultTargetPlatformOverride = null;
  });
}
