import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
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
  });
}

final class _ReleaseSource implements ReleaseMetadataSource {
  @override
  Future<ReleaseMetadata> fetch() async => ReleaseMetadata(
    app: 'DingDong',
    latestVersion: '0.8.0',
    website: Uri.parse('https://example.com'),
    releasePage: Uri.parse('https://example.com/releases/0.8.0'),
    notes: const <String>['Faster history search'],
  );
}
