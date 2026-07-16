import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:dingdong/features/settings/domain/sound_preview_gateway.dart';
import 'package:dingdong/features/settings/ui/settings_screen.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opening settings immediately checks the latest release', (
    WidgetTester tester,
  ) async {
    final _CountingReleaseSource source = _CountingReleaseSource();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      releaseMetadataSource: source,
    );

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(viewModel: model)),
    );
    await tester.pumpAndSettle();

    expect(source.fetchCount, 1);
    expect(find.text('0.8.0'), findsOneWidget);
  });

  testWidgets('default workspace uses the Dynamic product name', (
    WidgetTester tester,
  ) async {
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
    );
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(viewModel: model)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dynamic'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
  });

  testWidgets(
    'settings expose appearance, monitoring, retention, and API controls',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 820);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(backend),
      );

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(viewModel: model)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-theme-mode')), findsOneWidget);
      expect(find.byKey(const Key('settings-language')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-launch-at-startup')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-anonymous-telemetry')),
        findsNothing,
      );
      expect(find.byKey(const Key('settings-opacity')), findsOneWidget);
      expect(find.byKey(const Key('settings-density')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-default-workspace')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-clipboard-monitoring')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-retention-items')), findsOneWidget);
      expect(find.byKey(const Key('settings-retention-days')), findsOneWidget);
      expect(find.byKey(const Key('settings-api-port')), findsOneWidget);
      expect(find.byKey(const Key('settings-sound')), findsOneWidget);
      expect(find.byKey(const Key('settings-refresh-usage')), findsOneWidget);

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-clipboard-monitoring')));
      await tester.pumpAndSettle();
      expect(backend.values['dingdong.clipboard.monitoring'], isTrue);

      await tester.ensureVisible(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(backend.values['dingdong.panel.themeMode'], 'dark');
    },
  );

  testWidgets('sound picker keeps the DingDong family and supports preview', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 820);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
    );
    final _RecordingSoundPreview preview = _RecordingSoundPreview();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(viewModel: model, soundPreviewGateway: preview),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settings-sound')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-sound')));
    await tester.pumpAndSettle();

    expect(find.text('DingDong Classic'), findsWidgets);
    expect(find.text('DingDong Soft'), findsOneWidget);
    expect(find.text('DingDong Bright'), findsOneWidget);
    expect(find.text('DingDong Crisp'), findsOneWidget);
    expect(find.text('DingDong Wood'), findsNothing);
    expect(find.text('DingDong Deep'), findsOneWidget);
    expect(find.text('Joy'), findsNothing);
    expect(find.text('Candy'), findsNothing);

    await tester.tap(find.text('DingDong Crisp'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-preview-sound')));
    await tester.pump();

    expect(preview.sounds, <String>['dingCrisp']);
  });

  testWidgets('changed local port reveals an adjacent restart action', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 820);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
    );
    int restartCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          viewModel: model,
          onRestartApplication: () async => restartCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-restart')), findsNothing);

    await model.setApiPort(2444);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('settings-restart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-restart')));
    await tester.pump();

    expect(restartCount, 1);
  });
}

final class _RecordingSoundPreview implements SoundPreviewGateway {
  final List<String> sounds = <String>[];

  @override
  Future<void> preview({required String sound, String? customSoundPath}) async {
    sounds.add(sound);
  }
}

final class _CountingReleaseSource implements ReleaseMetadataSource {
  int fetchCount = 0;

  @override
  Future<ReleaseMetadata> fetch() async {
    fetchCount += 1;
    return ReleaseMetadata(
      app: 'DingDong',
      latestVersion: '0.8.0',
      website: Uri.parse('https://example.com'),
      releasePage: Uri.parse('https://example.com/releases/0.8.0'),
    );
  }
}
