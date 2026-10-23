import 'dart:convert';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_store.dart';
import 'package:dingdong/features/ai_companion/ui/ai_companion_controller.dart';
import 'package:dingdong/features/ai_companion/ui/ai_companion_screen.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const legacy = <String, Object>{
  'automaticAnalysis': true,
  'clipboardAnalysis': true,
  'usageOptimization': true,
  'progressiveDisclosure': true,
  'tokenOptimization': true,
  'cloudAnalysis': true,
  'proactiveCheckIns': true,
  'autoResourceSelection': true,
  'providerEndpoint': 'http://127.0.0.1:3456',
  'model': 'configured-model',
  'protocol': 'anthropic',
};
void main() {
  test(
    'legacy analysis settings are retired while routing config survives',
    () {
      final settings = AiCompanionSettings.fromJson(legacy);
      expect(settings.autoResourceSelection, true);
      expect(settings.model, 'configured-model');
      expect(settings.protocol, AiCompanionProtocol.anthropic);
      for (final key in legacy.keys.where(
        (key) =>
            key.endsWith('Analysis') ||
            key.endsWith('Optimization') ||
            key == 'progressiveDisclosure' ||
            key == 'proactiveCheckIns',
      )) {
        expect(settings.toJson(), isNot(contains(key)), reason: key);
      }
    },
  );
  test(
    'API token persists locally and stays separate from settings JSON',
    () async {
      final backend = MemoryPreferencesBackend();
      final store = AiCompanionPreferencesStore(backend);
      await store.writeApiKey('test-token');
      final restored = AiCompanionPreferencesStore(backend);
      expect(await restored.readApiKey(), 'test-token');
      expect(
        (await restored.loadSettings()).toJson().values,
        isNot(contains('test-token')),
      );
      await restored.writeApiKey(null);
      expect(await store.readApiKey(), isNull);
    },
  );
  testWidgets(
    'AI+ opens directly to routing settings with no analysis controls',
    (tester) async {
      final store = AiCompanionPreferencesStore(
        MemoryPreferencesBackend({
          AiCompanionPreferencesStore.settingsKey: jsonEncode(legacy),
        }),
      );
      final controller = AiCompanionController(store: store);
      addTearDown(controller.dispose);
      await controller.load();
      await tester.binding.setSurfaceSize(const Size(1000, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.desktopPanelLight(),
          locale: const Locale('en'),
          localizationsDelegates: DingDongLocalizations.localizationsDelegates,
          supportedLocales: DingDongLocalizations.supportedLocales,
          home: Scaffold(body: AiCompanionScreen(controller: controller)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('ai-feature-auto-resources')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('ai-configure-provider')), findsOneWidget);
      expect(find.byKey(const Key('ai-analyze')), findsNothing);
      expect(find.text('Insights and suggestions'), findsNothing);
      expect(find.text('Automatic analysis'), findsNothing);
      for (final name in [
        'clipboard',
        'resources',
        'progressive-disclosure',
        'tokens',
        'cloud',
        'check-ins',
      ]) {
        expect(find.byKey(Key('ai-feature-$name')), findsNothing);
      }
      await tester.pump(const Duration(hours: 2));
      expect(find.byType(SnackBar), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
