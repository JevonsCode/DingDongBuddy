import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/quick_paste_permission.dart';
import 'package:dingdong/features/settings/ui/quick_paste_permission_section.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('quick paste permission section opens desktop settings', (
    WidgetTester tester,
  ) async {
    final _PermissionGateway gateway = _PermissionGateway();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      quickPastePermissionGateway: gateway,
    );
    await model.load();

    await tester.pumpWidget(
      MaterialApp(home: QuickPastePermissionSection(viewModel: model)),
    );
    expect(find.text('Permission required'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings-open-accessibility')));
    await tester.pump();
    expect(gateway.openCount, 1);
  });
}

final class _PermissionGateway implements QuickPastePermissionGateway {
  int openCount = 0;

  @override
  Future<bool> isGranted() async => false;

  @override
  Future<void> openSettings() async {
    openCount += 1;
  }
}
