import 'dart:io';

import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:dingdong/features/agent_adapters/ui/agent_adapter_controller.dart';
import 'package:dingdong/features/agent_adapters/ui/agent_adapter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edits, diffs, and observes external Adapter changes', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-adapter-screen-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    Directory('${temp.path}/home/.codex').createSync(recursive: true);
    final Directory user = Directory('${temp.path}/adapters');
    final AgentAdapterController controller = AgentAdapterController(
      repository: AgentAdapterRepository(
        userDirectory: user,
        historyDirectory: Directory('${temp.path}/history'),
        homeDirectory: '${temp.path}/home',
        loadBuiltIns: () async => <String, String>{'codex': _codex},
      ),
      watchExternalChanges: false,
    );
    await tester.runAsync(controller.load);
    addTearDown(controller.close);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        home: Scaffold(body: AgentAdapterScreen(controller: controller)),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('agent-adapter-screen')), findsOneWidget);
    expect(find.text('Codex'), findsNWidgets(2));
    expect(find.text('Built in'), findsOneWidget);
    expect(
      find.byKey(const Key('agent-adapter-status-overview')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('agent-adapter-verification-boundary')),
      findsOneWidget,
    );
    expect(find.text('Detected'), findsWidgets);
    expect(find.textContaining('does not verify MCP'), findsOneWidget);
    expect(find.byKey(const Key('agent-adapter-editor')), findsNothing);

    await tester.tap(find.byKey(const Key('agent-adapter-toggle-advanced')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('agent-adapter-editor')), findsOneWidget);
    expect(
      find.text('A comparison appears after the next saved or external edit.'),
      findsOneWidget,
    );

    final String customized = _codex.replaceFirst(
      'displayName: Codex',
      'displayName: Codex Personal',
    );
    await tester.enterText(
      find.byKey(const Key('agent-adapter-editor')),
      customized,
    );
    expect(find.byKey(const Key('agent-adapter-save')), findsOneWidget);
    await tester.runAsync(() => controller.save(customized));
    await tester.pump();

    final File override = File('${user.path}/codex.yaml');
    expect(override.existsSync(), isTrue);
    expect(controller.selectedEntry?.isCustomized, isTrue);
    expect(find.byKey(const Key('agent-adapter-diff')), findsOneWidget);
    expect(find.byKey(const Key('agent-adapter-reset')), findsOneWidget);

    override.writeAsStringSync(
      customized.replaceFirst(
        'includeBridgeRoutingInstructions: true',
        'includeBridgeRoutingInstructions: false',
      ),
      flush: true,
    );
    await tester.runAsync(controller.load);
    await tester.pump();

    expect(
      (tester.widget<TextField>(
        find.byKey(const Key('agent-adapter-editor')),
      )).controller!.text,
      contains('includeBridgeRoutingInstructions: false'),
    );
    expect(controller.history, hasLength(3));
    expect(
      find.byKey(const Key('agent-adapter-history-selector')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

const String _codex = '''
schemaVersion: 1
id: codex
displayName: Codex

detect:
  directory: ~/.codex

skills:
  global: ~/.codex/skills
  project: .agents/skills

mcp:
  file: ~/.codex/config.toml
  format: codex-toml

prompt:
  file: ~/.codex/AGENTS.md
  includeBridgeRoutingInstructions: true
''';
