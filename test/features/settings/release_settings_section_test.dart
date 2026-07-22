import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/application_updater.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:dingdong/features/settings/ui/release_settings_section.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('version section checks and displays the latest release', (
    WidgetTester tester,
  ) async {
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      releaseMetadataSource: _ReleaseSource(),
    );

    await tester.pumpWidget(
      MaterialApp(home: ReleaseSettingsSection(viewModel: model)),
    );
    await tester.tap(find.byKey(const Key('settings-check-updates')));
    await tester.pumpAndSettle();

    expect(find.text('0.8.0'), findsOneWidget);
    expect(find.text('A new version is available'), findsOneWidget);
    expect(find.textContaining('Faster history search'), findsOneWidget);
    expect(find.byKey(const Key('settings-report-problem')), findsOneWidget);
    expect(find.byKey(const Key('settings-request-feature')), findsOneWidget);
    expect(find.byType(OutlinedButton), findsNWidgets(5));
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('current release does not repeat its historical notes', (
    WidgetTester tester,
  ) async {
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      releaseMetadataSource: _ReleaseSource(
        latestVersion: currentAppVersion,
        notes: const <String>['Withdrawn analytics announcement'],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(home: ReleaseSettingsSection(viewModel: model)),
    );
    await tester.tap(find.byKey(const Key('settings-check-updates')));
    await tester.pumpAndSettle();

    expect(find.text("You're up to date"), findsOneWidget);
    expect(find.textContaining('Withdrawn analytics'), findsNothing);
  });

  testWidgets('available native update installs from one emphasized action', (
    WidgetTester tester,
  ) async {
    final _ApplicationUpdater updater = _ApplicationUpdater();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      releaseMetadataSource: const _ReleaseSource(),
      applicationUpdater: updater,
    );
    await model.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.macOS),
        home: SingleChildScrollView(
          child: ReleaseSettingsSection(viewModel: model),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('settings-check-updates')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-install-update')), findsOneWidget);
    expect(
      find.byKey(const Key('settings-macos-update-permission-notice')),
      findsOneWidget,
    );
    expect(
      find.textContaining('grant DingDong\'s macOS permissions again'),
      findsOneWidget,
    );
    expect(find.text('Update to 0.8.0'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-install-update')));
    await tester.pumpAndSettle();

    expect(updater.installCount, 1);
    expect(find.text("You're up to date"), findsOneWidget);
    model.dispose();
  });

  testWidgets('Windows native update omits the macOS permission notice', (
    WidgetTester tester,
  ) async {
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      releaseMetadataSource: const _ReleaseSource(),
      applicationUpdater: _ApplicationUpdater(),
    );
    await model.load();

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: ReleaseSettingsSection(viewModel: model),
      ),
    );
    await tester.tap(find.byKey(const Key('settings-check-updates')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('settings-install-update')), findsOneWidget);
    expect(
      find.byKey(const Key('settings-macos-update-permission-notice')),
      findsNothing,
    );
    model.dispose();
  });
}

final class _ApplicationUpdater implements ApplicationUpdater {
  int installCount = 0;
  ApplicationUpdateStatus status = const ApplicationUpdateStatus();

  @override
  Future<void> installLatest() async {
    installCount += 1;
    status = const ApplicationUpdateStatus(
      phase: ApplicationUpdatePhase.current,
    );
  }

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<ApplicationUpdateStatus> readStatus() async => status;
}

final class _ReleaseSource implements ReleaseMetadataSource {
  const _ReleaseSource({
    this.latestVersion = '0.8.0',
    this.notes = const <String>['Faster history search'],
  });

  final String latestVersion;
  final List<String> notes;

  @override
  Future<ReleaseMetadata> fetch() async => ReleaseMetadata(
    app: 'DingDong',
    latestVersion: latestVersion,
    website: Uri.parse('https://example.com'),
    releasePage: Uri.parse('https://example.com/releases/0.8.0'),
    notes: notes,
  );
}
