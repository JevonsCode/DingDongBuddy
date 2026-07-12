import 'package:dingdong/features/agent_api/domain/agent_api_gateway.dart';
import 'package:dingdong/features/agent_api/ui/agent_api_screen.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('agent setup prompt persists and the local ding can be tested', (
    WidgetTester tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AgentApiScreen(
            settingsViewModel: model,
            baseUri: Uri.parse('http://127.0.0.1:2333'),
            apiGateway: gateway,
          ),
        ),
      ),
    );

    final Finder prompt = find.byKey(const Key('agent-api-setup-prompt'));
    await tester.ensureVisible(prompt);
    await tester.enterText(prompt, 'Connect this agent to DingDong');
    await tester.tap(find.byKey(const Key('agent-api-save-prompt')));
    await tester.pumpAndSettle();
    expect(
      backend.values['dingdong.mcpSetupPromptOverride'],
      'Connect this agent to DingDong',
    );

    final Finder testButton = find.byKey(const Key('agent-api-test-ding'));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 1200));
    await tester.pumpAndSettle();
    await tester.tap(testButton);
    await tester.pumpAndSettle();
    expect(gateway.tested, Uri.parse('http://127.0.0.1:2333'));
    expect(find.text('Test notification sent'), findsOneWidget);
  });
}

final class _AgentApiGateway implements AgentApiGateway {
  Uri? tested;

  @override
  Future<void> testDing(Uri baseUri) async {
    tested = baseUri;
  }
}
