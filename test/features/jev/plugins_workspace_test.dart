import 'dart:io';
import 'dart:ui' as ui;

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/resource_manager_app.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'plugin destination lists both plugins without installing either',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final capture = Platform.environment['JVS_A_PLUGIN_CAPTURE'] == '1';
      if (capture) {
        await tester.runAsync(() async {
          for (final name in ['.AppleSystemUIFont', 'Roboto', 'Ahem']) {
            final loader = FontLoader(name)
              ..addFont(
                Future.value(
                  ByteData.sublistView(
                    File(
                      '/System/Library/Fonts/STHeiti Light.ttc',
                    ).readAsBytesSync(),
                  ),
                ),
              );
            await loader.load();
          }
          final loader = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await loader.load();
        });
      }
      const channel = MethodChannel('mixin.one/desktop_multi_window/channels');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      const registry = MethodChannel('mixin.one/desktop_multi_window');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        registry,
        (call) async => call.method == 'getWindowDefinition'
            ? {'windowId': 'plugin-test', 'windowArgument': ''}
            : null,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          registry,
          null,
        ),
      );
      final library = LibraryViewModel(InMemoryResourceStore());
      await library.load();
      final clipboard = ClipboardViewModel(InMemoryClipboardStore())..load();
      final activity = ActivityController();
      final issues = IssueCenterController();
      addTearDown(activity.dispose);
      addTearDown(issues.dispose);
      final calls = <String>[];
      final model = SettingsViewModel(
        SettingsRepository(MemoryPreferencesBackend()),
      );
      await model.load();
      tester.view.physicalSize = const Size(1000, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ResourceManagerApp(
            viewModel: library,
            clipboardViewModel: clipboard,
            activityController: activity,
            issueCenterController: issues,
            pluginSettings: model,
            settings: const AppSettings(
              language: AppLanguagePreference.chinese,
            ),
            windowController: WindowController.fromWindowId('plugin-test'),
            initialDestination: ResourceManagerDestination.plugins,
            jevAction: (action, arguments) async {
              calls.add(action);
              return {
                'installed': false,
                'configured': false,
                'enabled': false,
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('resource-manager-nav-plugins')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('plugin-open-jev')), findsOneWidget);
      expect(find.byKey(const Key('plugin-open-selection')), findsOneWidget);
      expect(calls, isEmpty);
      Future<void> screenshot(String name) async {
        if (!capture) return;
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()!
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          Directory('build/plugins-review').createSync(recursive: true);
          File(
            'build/plugins-review/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await screenshot('catalog-zh');
      await tester.tap(find.byKey(const Key('plugin-open-jev')));
      await tester.pumpAndSettle();
      expect(calls, ['status']);
      expect(find.byKey(const Key('jev-install')), findsOneWidget);
      expect(find.byKey(const Key('jev-website')), findsOneWidget);
      expect(find.textContaining('0.042'), findsNothing);
      await screenshot('jev-zh');
      await tester.tap(find.byKey(const Key('plugins-back')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('plugin-open-selection')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-selection-enabled')),
        findsOneWidget,
      );
      expect(model.settings.selectionPlugin.enabled, isFalse);
      await screenshot('selection-zh');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
