import 'dart:async';

import 'package:dingdong/features/screenshot/data/screenshot_plugin_service.dart';
import 'package:dingdong/features/screenshot/domain/screenshot_plugin.dart';
import 'package:dingdong/features/screenshot/ui/screenshot_plugin_section.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/ui/global_hot_key_recorder.dart';
import 'package:dingdong/features/settings/ui/settings_screen.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'screenshot startup and shortcut failures cannot write host settings errors',
    () async {
      final preferences = MemoryPreferencesBackend({
        ScreenshotPluginService.preferenceKey: const ScreenshotConfiguration(
          enabled: true,
        ).encode(),
      });
      final hostRegistrations = <GlobalHotKey>[];
      final settings = SettingsViewModel(
        SettingsRepository(preferences),
        onGlobalHotKeyChanged: (key) async {
          hostRegistrations.add(key);
          return true;
        },
      );
      addTearDown(settings.dispose);
      await settings.load();
      final gateway = _ScreenshotGateway()..failApply = true;
      final screenshot = ScreenshotPluginService(preferences, gateway);
      await screenshot.load();
      expect(
        (await screenshot.manage('status', {}))['error'],
        'shortcut_conflict',
      );
      expect(settings.errorMessage, isNull);
      expect(settings.settings.globalHotKey, GlobalHotKey.defaultValue);

      await expectLater(
        screenshot.manage('configure', {'enabled': true}),
        throwsA(isA<ScreenshotPluginException>()),
      );
      expect(settings.errorMessage, isNull);
      expect(hostRegistrations, [GlobalHotKey.defaultValue]);
      expect(settings.settings.globalHotKey, GlobalHotKey.defaultValue);
    },
  );

  test(
    'clipboard registration banner is independent of screenshot runtime',
    () async {
      final preferences = MemoryPreferencesBackend();
      final settings = SettingsViewModel(
        SettingsRepository(preferences),
        onGlobalHotKeyChanged: (_) async => false,
      );
      addTearDown(settings.dispose);
      await settings.load();
      const hostError =
          'Shortcut could not be registered. It may already be used by another app.';
      expect(settings.errorMessage, hostError);

      final screenshot = ScreenshotPluginService(
        preferences,
        _ScreenshotGateway(),
      );
      await screenshot.load();
      expect((await screenshot.manage('status', {}))['error'], isNull);
      final status = await screenshot.manage('configure', {'enabled': true});
      expect(status['running'], true);
      expect(status['error'], isNull);
      expect(settings.errorMessage, hostError);
      expect(settings.settings.globalHotKey, GlobalHotKey.defaultValue);
    },
  );

  testWidgets(
    'screenshot shortcut, pending state and errors stay in plugin details',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(1600, 1200);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);

        final preferences = MemoryPreferencesBackend();
        final settings = SettingsViewModel(
          SettingsRepository(preferences),
          onGlobalHotKeyChanged: (_) async => true,
        );
        addTearDown(settings.dispose);
        final gateway = _ScreenshotGateway();
        final screenshot = ScreenshotPluginService(preferences, gateway);
        await screenshot.load();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  Expanded(child: SettingsScreen(viewModel: settings)),
                  Expanded(
                    child: SingleChildScrollView(
                      child: ScreenshotPluginSection(action: screenshot.manage),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final hostSurface = find.byType(SettingsScreen);
        Finder insideHost(Finder finder) =>
            find.descendant(of: hostSurface, matching: finder);
        for (final key in [
          'screenshot-hot-key',
          'screenshot-enabled',
          'screenshot-runtime-status',
          'screenshot-loading',
          'screenshot-error',
        ]) {
          expect(insideHost(find.byKey(Key(key))), findsNothing);
        }
        // This existing row controls DingDong's clipboard panel and must remain.
        final hostRecorder = insideHost(find.byType(GlobalHotKeyRecorder));
        expect(hostRecorder, findsOneWidget);
        expect(
          tester.widget<GlobalHotKeyRecorder>(hostRecorder).value,
          GlobalHotKey.defaultValue,
        );
        expect(find.byKey(const Key('screenshot-hot-key')), findsOneWidget);

        gateway.pauseApply = Completer<void>();
        gateway.failApply = true;
        await tester.tap(find.byKey(const Key('screenshot-enabled')));
        await tester.pump();
        expect(find.byKey(const Key('screenshot-loading')), findsOneWidget);
        expect(
          insideHost(find.byKey(const Key('screenshot-loading'))),
          findsNothing,
        );
        expect(settings.errorMessage, isNull);

        gateway.pauseApply!.complete();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('screenshot-error')), findsOneWidget);
        expect(
          insideHost(find.byKey(const Key('screenshot-error'))),
          findsNothing,
        );
        expect(settings.errorMessage, isNull);
        expect(
          tester.widget<GlobalHotKeyRecorder>(hostRecorder).value,
          GlobalHotKey.defaultValue,
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}

class _ScreenshotGateway implements ScreenshotPluginGateway {
  bool failApply = false;
  bool enabled = false;
  Completer<void>? pauseApply;

  @override
  Future<ScreenshotRuntimeStatus> apply(
    ScreenshotConfiguration configuration,
  ) async {
    await pauseApply?.future;
    if (failApply) throw const ScreenshotPluginException('shortcut_conflict');
    enabled = configuration.enabled;
    return status();
  }

  @override
  Future<ScreenshotRuntimeStatus> status() async => ScreenshotRuntimeStatus(
    supported: true,
    running: enabled,
    capturing: false,
  );

  @override
  Future<void> capture() async {}
}
