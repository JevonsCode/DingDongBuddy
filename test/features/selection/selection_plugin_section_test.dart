import 'package:dingdong/features/selection/domain/selection_plugin_gateway.dart';
import 'package:dingdong/features/selection/ui/selection_plugin_section.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('user explicitly enables the system selection plugin', (
    WidgetTester tester,
  ) async {
    final _Gateway gateway = _Gateway(permissionGranted: true);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      selectionPluginGateway: gateway,
    );
    await model.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SelectionPluginSection(viewModel: model),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('System selection tools'), findsOneWidget);
    expect(find.byKey(const Key('settings-selection-enabled')), findsOneWidget);
    expect(model.settings.selectionPlugin.enabled, isFalse);

    await tester.tap(find.byKey(const Key('settings-selection-enabled')));
    await tester.pumpAndSettle();

    expect(model.settings.selectionPlugin.enabled, isTrue);
    expect(gateway.applied.last.enabled, isTrue);
    expect(find.text('Running'), findsOneWidget);
  });

  testWidgets('cloud provider lets the user save and remove a Keychain token', (
    WidgetTester tester,
  ) async {
    final _Gateway gateway = _Gateway(permissionGranted: true);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      selectionPluginGateway: gateway,
    );
    await model.load();
    await model.setSelectionPluginConfiguration(
      model.settings.selectionPlugin.withProvider(
        SelectionModelProvider.openRouter,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SelectionPluginSection(viewModel: model),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('settings-selection-token')),
      'user-token',
    );
    await tester.tap(find.byKey(const Key('settings-selection-token-save')));
    await tester.pumpAndSettle();

    expect(gateway.token, 'user-token');
    expect(find.text('Saved securely in Keychain'), findsOneWidget);

    await tester.ensureVisible(
      find.byKey(const Key('settings-selection-token-clear')),
    );
    await tester.tap(find.byKey(const Key('settings-selection-token-clear')));
    await tester.pumpAndSettle();
    expect(gateway.token, isNull);
  });

  testWidgets('switching provider clears a token that has not been saved', (
    WidgetTester tester,
  ) async {
    final _Gateway gateway = _Gateway(permissionGranted: true);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      selectionPluginGateway: gateway,
    );
    addTearDown(model.dispose);
    await model.load();
    await model.setSelectionPluginConfiguration(
      model.settings.selectionPlugin.withProvider(
        SelectionModelProvider.openRouter,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SelectionPluginSection(viewModel: model),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('settings-selection-token')),
      'unsaved-fixture-only',
    );
    await tester.ensureVisible(
      find.byKey(const Key('settings-selection-provider')),
    );
    await tester.tap(find.byKey(const Key('settings-selection-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini').last);
    await tester.pumpAndSettle();

    final EditableText field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('settings-selection-token')),
        matching: find.byType(EditableText),
      ),
    );
    expect(
      model.settings.selectionPlugin.provider,
      SelectionModelProvider.gemini,
    );
    expect(field.controller.text, isEmpty);
    expect(gateway.token, isNull);
  });
}

final class _Gateway implements SelectionPluginGateway {
  _Gateway({required this.permissionGranted});

  final bool permissionGranted;
  final List<SelectionPluginConfiguration> applied =
      <SelectionPluginConfiguration>[];
  String? token;

  @override
  Future<SelectionPluginRuntimeStatus> apply(
    SelectionPluginConfiguration configuration,
  ) async {
    applied.add(configuration);
    return _status(configuration.enabled);
  }

  @override
  Future<void> clearToken() async {
    token = null;
  }

  @override
  Future<void> openAccessibilitySettings() async {}

  @override
  Future<void> saveToken(String token) async {
    this.token = token;
  }

  @override
  Future<SelectionPluginRuntimeStatus> status() async {
    return _status(applied.lastOrNull?.enabled ?? false);
  }

  SelectionPluginRuntimeStatus _status(bool enabled) {
    return SelectionPluginRuntimeStatus(
      enabled: enabled,
      running: enabled && permissionGranted,
      permissionGranted: permissionGranted,
      tokenConfigured: token != null,
    );
  }
}
