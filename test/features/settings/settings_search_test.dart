import 'dart:convert';
import 'dart:io';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/settings/ui/release_settings_section.dart';
import 'package:dingdong/features/settings/ui/settings_screen.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final config =
        jsonDecode(await File('.dart_tool/package_config.json').readAsString())
            as Map;
    final sdk = Uri.parse('${config['flutterRoot']}/');
    for (final family in ['Roboto', '.AppleSystemUIFont', 'Segoe UI']) {
      final loader = FontLoader(family)
        ..addFont(
          File.fromUri(
            sdk.resolve(
              'bin/cache/artifacts/material_fonts/roboto-regular.ttf',
            ),
          ).readAsBytes().then(ByteData.sublistView),
        );
      await loader.load();
    }
    await (FontLoader('MaterialIcons')..addFont(
          File.fromUri(
            sdk.resolve(
              'bin/cache/artifacts/material_fonts/materialicons-regular.otf',
            ),
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });

  Future<SettingsViewModel> pumpSettings(
    WidgetTester tester, {
    String language = 'en',
    bool dark = false,
    bool native = false,
    SettingsNavigationController? navigation,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(620, 680);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: Locale(language),
        supportedLocales: DingDongLocalizations.supportedLocales,
        localizationsDelegates: DingDongLocalizations.localizationsDelegates,
        theme: dark
            ? AppTheme.desktopPanelDark()
            : AppTheme.desktopPanelLight(),
        home: SettingsScreen(
          viewModel: model,
          useNativeSearch: native,
          navigationController: navigation,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return model;
  }

  testWidgets(
    'native titlebar query filters settings and window navigation clears it',
    (tester) async {
      const channel = MethodChannel('dingdong/settings_search');
      final calls = <MethodCall>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'configure' ? true : null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      final navigation = SettingsNavigationController();
      addTearDown(navigation.dispose);
      await pumpSettings(tester, navigation: navigation, native: true);
      expect(calls.first.method, 'configure');
      expect(find.byKey(const Key('settings-search')), findsNothing);
      await messenger.handlePlatformMessage(
        channel.name,
        const StandardMethodCodec().encodeMethodCall(
          const MethodCall('queryChanged', 'port'),
        ),
        (_) {},
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-api-port')), findsOneWidget);
      expect(find.byKey(const Key('settings-launch-at-startup')), findsNothing);
      navigation.navigateTo(SettingsWindowDestination.top);
      await tester.pumpAndSettle();
      expect(calls.last.method, 'setQuery');
      expect(calls.last.arguments, '');
      expect(
        find.byKey(const Key('settings-launch-at-startup')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
  for (final dark in [false, true]) {
    testWidgets('settings search surface ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      await pumpSettings(tester, dark: dark);
      await tester.enterText(find.byKey(const Key('settings-search')), 'sound');
      await tester.pumpAndSettle();
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile(
          'goldens/settings_search_${dark ? 'dark' : 'light'}.png',
        ),
      );
    }, tags: ['golden']);
  }
  testWidgets(
    'filters groups locally, keeps editing active, clears and handles no results',
    (tester) async {
      final model = await pumpSettings(tester);
      final search = find.byKey(const Key('settings-search'));
      await tester.enterText(search, 'LAUNCH');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-retention-items')), findsNothing);
      final startup = find.byKey(const Key('settings-launch-at-startup'));
      expect(startup, findsOneWidget);
      final previous = model.settings.launchAtStartup;
      await tester.tap(startup);
      await tester.pumpAndSettle();
      expect(model.settings.launchAtStartup, !previous);
      await tester.enterText(search, 'no-setting-matches-this');
      await tester.pumpAndSettle();
      expect(
        find.text('No matching settings. Try another keyword.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('settings-search-clear')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings-retention-items')), findsOneWidget);
      final before = tester.getTopLeft(search);
      await tester.drag(
        find.byType(CustomScrollView).first,
        const Offset(0, -600),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(search), before, reason: 'Search stays pinned');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('Chinese labels match and version navigation clears the filter', (
    tester,
  ) async {
    final nav = SettingsNavigationController();
    addTearDown(nav.dispose);
    await pumpSettings(tester, language: 'zh', navigation: nav);
    await tester.enterText(find.byKey(const Key('settings-search')), '提醒');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-reminder')), findsOneWidget);
    expect(find.byKey(const Key('settings-api-port')), findsNothing);
    nav.navigateTo(SettingsWindowDestination.version);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('settings-search')))
          .controller!
          .text,
      isEmpty,
    );
    expect(
      tester.getRect(find.byType(ReleaseSettingsSection)).top,
      lessThan(680),
    );
    expect(tester.takeException(), isNull);
  });
}
