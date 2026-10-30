import 'dart:async';

import 'package:dingdong/features/plugins/ui/plugins_screen.dart';
import 'package:dingdong/features/screenshot/domain/screenshot_plugin.dart';
import 'package:dingdong/features/screenshot/ui/screenshot_plugin_section.dart';
import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
        findsNothing,
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

  windowsTest('macOS exposes system screenshot and shortcut configuration', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final host = _Host();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScreenshotPluginSection(action: host.call),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('screenshot-system-help')), findsOneWidget);
    expect(find.byKey(const Key('screenshot-hot-key')), findsOneWidget);
    expect(find.byKey(const Key('screenshot-enabled')), findsOneWidget);
    expect(find.byKey(const Key('screenshot-unsupported')), findsNothing);
  });

  windowsTest('system screenshot has no backend selector or editor source', (
    tester,
  ) async {
    final host = _Host();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ScreenshotPluginSection(action: host.call)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('screenshot-backend')), findsNothing);
    expect(find.text('Open-source editor'), findsNothing);
    expect(find.text('Open-source components'), findsNothing);
    expect(find.byKey(const Key('screenshot-system-help')), findsOneWidget);
    expect(find.byKey(const Key('screenshot-hot-key')), findsOneWidget);
  });

  windowsTest('pending system launch refreshes status without an extra click', (
    tester,
  ) async {
    final host = _Host()..capturePending = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ScreenshotPluginSection(action: host.call),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('screenshot-enabled')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('screenshot-capture-now')));
    await tester.tap(find.byKey(const Key('screenshot-capture-now')));
    await tester.pumpAndSettle();
    expect(host.capturing, isTrue);
    host.capturing = false;
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Ready · shortcut registered'), findsOneWidget);
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

  windowsTest('macOS records Command Option and restores its default', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    final host = _Host();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ScreenshotPluginSection(action: host.call)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('screenshot-hot-key')));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(
      host.shortcut,
      const GlobalHotKey(
        key: 'B',
        primary: true,
        shift: false,
        alt: true,
        secondary: false,
      ),
    );
    expect(find.text('⌘⌥B'), findsOneWidget);
    await tester.tap(find.byKey(const Key('screenshot-hot-key-reset')));
    await tester.pumpAndSettle();
    expect(host.shortcut, ScreenshotConfiguration.defaultShortcut);
    expect(find.text('⌘⌥A'), findsOneWidget);
  });

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
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
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
  bool capturePending = false;
  bool capturing = false;
  GlobalHotKey shortcut = ScreenshotConfiguration.defaultShortcut;
  Completer<void>? pause;
  Future<Map<String, Object?>> call(
    String action,
    Map<String, Object?> values,
  ) async {
    actions.add(action);
    if (action == 'capture' && capturePending) capturing = true;
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
      'capturing': capturing,
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
