import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/quick_paste_permission.dart';
import 'package:dingdong/features/settings/ui/quick_paste_permission_section.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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
    expect(find.text('Open permission helper'), findsOneWidget);
    expect(
      find.byKey(const Key('settings-accessibility-helper-explanation')),
      findsOneWidget,
    );
    expect(
      find.textContaining('drag once to make it available'),
      findsOneWidget,
    );
    final Container statusSurface = tester.widget<Container>(
      find.byKey(const Key('settings-quick-paste-permission-status')),
    );
    final BoxDecoration statusDecoration =
        statusSurface.decoration! as BoxDecoration;
    expect(statusDecoration.border, isNull);
    final Container helperSurface = tester.widget<Container>(
      find.byKey(const Key('settings-accessibility-helper-explanation')),
    );
    final BoxDecoration helperDecoration =
        helperSurface.decoration! as BoxDecoration;
    expect(helperDecoration.border, isNull);
    expect(find.byType(Divider), findsNothing);

    await tester.tap(find.byKey(const Key('settings-open-accessibility')));
    await tester.pump();
    expect(gateway.openCount, 1);
  });

  testWidgets('quick paste permission uses quiet tonal grouping', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 360);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      quickPastePermissionGateway: _PermissionGateway(),
    );
    await model.load();
    addTearDown(model.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.desktopPanelLight(),
        locale: const Locale('zh'),
        supportedLocales: const <Locale>[Locale('en'), Locale('zh')],
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          DingDongLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(52),
            child: QuickPastePermissionSection(viewModel: model),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(QuickPastePermissionSection),
      matchesGoldenFile(
        '../../golden/goldens/quick_paste_permission_quiet.png',
      ),
    );
  }, tags: <String>['golden']);
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
