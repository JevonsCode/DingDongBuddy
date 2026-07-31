import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/agent_api/domain/agent_api_gateway.dart';
import 'package:dingdong/features/agent_api/ui/agent_api_screen.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'agent setup prompt is read-only, copyable, and ding can be tested',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(backend),
        mcpCommandPath: '/opt/DingDong/dingdong-mcp',
      );
      await model.load();
      final _AgentApiGateway gateway = _AgentApiGateway();
      final _ClipboardGateway clipboard = _ClipboardGateway();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentApiScreen(
              settingsViewModel: model,
              baseUri: Uri.parse('http://127.0.0.1:2333'),
              apiGateway: gateway,
              clipboardGateway: clipboard,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(gateway.checked, Uri.parse('http://127.0.0.1:2333'));

      await tester.tap(find.byKey(const Key('agent-api-toggle-advanced')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('agent-api-copy-health')));
      await tester.pump();
      expect(
        clipboard.text,
        'curl --noproxy 127.0.0.1 -sS http://127.0.0.1:2333/health',
      );
      expect(find.text('Copied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));

      final Finder prompt = find.byKey(const Key('agent-api-setup-prompt'));
      await tester.ensureVisible(prompt);
      expect(find.byKey(const Key('agent-api-save-prompt')), findsNothing);
      expect(find.text('恢复默认'), findsNothing);
      expect(find.byType(TextField), findsNothing);

      final Finder copyPrompt = find.byKey(
        const Key('agent-api-copy-setup-prompt'),
      );
      await tester.ensureVisible(copyPrompt);
      await tester.pumpAndSettle();
      await tester.tap(copyPrompt);
      await tester.pump();
      expect(clipboard.text, model.mcpSetupPrompt);
      expect(find.text('Copied'), findsOneWidget);
      expect(
        backend.values,
        isNot(contains('dingdong.mcpSetupPromptOverride')),
      );

      final Finder testButton = find.byKey(const Key('agent-api-test-ding'));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 1200));
      await tester.pumpAndSettle();
      await tester.tap(testButton);
      await tester.pumpAndSettle();
      expect(gateway.tested, Uri.parse('http://127.0.0.1:2333'));
      expect(find.text('Test notification sent'), findsOneWidget);
    },
  );

  testWidgets('narrow unverified page keeps advanced endpoints readable', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
    );
    await model.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AgentApiScreen(settingsViewModel: model)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Runtime status unverified'), findsOneWidget);
    expect(
      find.byKey(const Key('agent-api-endpoint-description-health')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('agent-api-toggle-advanced')));
    await tester.pumpAndSettle();

    final Finder description = find.byKey(
      const Key('agent-api-endpoint-description-health'),
    );
    expect(description, findsOneWidget);
    expect(tester.getSize(description).width, greaterThan(140));
    expect(find.text('MCP access'), findsOneWidget);
  });

  testWidgets('shows the actual runtime port and discloses fallback', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(
        MemoryPreferencesBackend(<String, Object>{'dingdong.api.port': 2333}),
      ),
    );
    await model.load();
    final _AgentApiGateway gateway = _AgentApiGateway();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentApiScreen(
            settingsViewModel: model,
            baseUri: Uri.parse('http://127.0.0.1:58631'),
            apiGateway: gateway,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(gateway.checked, Uri.parse('http://127.0.0.1:58631'));
    expect(find.text('http://127.0.0.1:58631'), findsOneWidget);
    expect(find.byKey(const Key('agent-api-fallback-port')), findsOneWidget);
    expect(
      find.text('Preferred port 2333 was unavailable; using 58631.'),
      findsOneWidget,
    );
  });
}

final class _AgentApiGateway implements AgentApiGateway {
  Uri? checked;
  Uri? tested;

  @override
  Future<void> checkHealth(Uri baseUri) async {
    checked = baseUri;
  }

  @override
  Future<void> testDing(Uri baseUri) async {
    tested = baseUri;
  }
}

final class _ClipboardGateway implements ClipboardGateway {
  String? text;

  @override
  Future<ClipboardSnapshot> read() async => const ClipboardSnapshot();

  @override
  Future<void> writeFiles(List<String> paths) async {}

  @override
  Future<void> writeText(String text) async {
    this.text = text;
  }
}
