import 'dart:convert';
import 'dart:io';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/sound_preview_gateway.dart';
import 'package:dingdong/features/settings/ui/reminder_profiles_editor.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
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
  Future<SettingsViewModel> pumpEditor(
    WidgetTester tester, {
    bool dark = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(780, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repository = SettingsRepository(MemoryPreferencesBackend());
    // Example reminder profiles, not the user's live configuration.
    var settings = const AppSettings();
    for (final profile in [
      const ReminderProfile(
        id: 'build-error',
        name: 'Build failed',
        description: 'When a build or test fails',
        color: TrayNotificationColor.pink,
      ),
      const ReminderProfile(
        id: 'review-ready',
        name: 'Review ready',
        description: 'When a result needs my review',
        color: TrayNotificationColor.blue,
      ),
      const ReminderProfile(
        id: 'waiting',
        name: 'Waiting for me',
        description: 'When the Agent cannot continue',
        color: TrayNotificationColor.pink,
      ),
    ]) {
      settings = settings.withReminderProfile(profile);
    }
    await repository.save(settings);
    final model = SettingsViewModel(repository);
    await model.load();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark
            ? AppTheme.desktopPanelDark()
            : AppTheme.desktopPanelLight(),
        localizationsDelegates: DingDongLocalizations.localizationsDelegates,
        supportedLocales: DingDongLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: AnimatedBuilder(
            animation: model,
            builder: (_, _) => SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ReminderProfilesEditor(
                  settings: model.settings,
                  viewModel: model,
                  soundPreviewGateway: _Preview(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return model;
  }

  testWidgets('add, edit and delete a profile without touching the others', (
    tester,
  ) async {
    final model = await pumpEditor(tester);
    await tester.tap(find.byKey(const Key('add-reminder')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('reminder-name')),
      'Deployment failed',
    );
    await tester.enterText(
      find.byKey(const Key('reminder-condition')),
      'When deployment returns an error',
    );
    await tester.tap(find.byKey(const Key('save-reminder')));
    await tester.pumpAndSettle();
    final profile = model.settings.reminderProfiles.last;
    expect(profile.name, 'Deployment failed');
    expect(profile.description, 'When deployment returns an error');
    expect(model.settings.reminderProfiles.length, 6);
    await tester.tap(find.byKey(Key('delete-reminder-${profile.id}')));
    await tester.pumpAndSettle();
    expect(model.settings.reminderProfiles.length, 5);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'reminder list and shared sound markers ${dark ? 'dark' : 'light'}',
      (tester) async {
        await pumpEditor(tester, dark: dark);
        expect(tester.takeException(), isNull);
        final dots = tester
            .widgetList<ReminderUsageDots>(find.byType(ReminderUsageDots))
            .where((x) => x.profiles.isNotEmpty)
            .single;
        expect(dots.profiles.length, 5);
        expect(
          dots.profiles
              .where((x) => x.color == TrayNotificationColor.pink)
              .length,
          2,
        );
        await expectLater(
          find.byType(Scaffold),
          matchesGoldenFile(
            'goldens/reminder_profiles_${dark ? 'dark' : 'light'}.png',
          ),
        );
        if (!dark) {
          await tester.tap(find.byKey(const Key('edit-reminder-build-error')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byType(Overlay),
            matchesGoldenFile('goldens/reminder_profile_editor.png'),
          );
        }
      },
    );
  }
}

final class _Preview implements SoundPreviewGateway {
  @override
  Future<void> preview({
    required String sound,
    String? customSoundPath,
  }) async {}
}
