import 'dart:convert';
import 'dart:io';

import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/agent_api/data/agent_http_server.dart';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/ui/library_screen.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/ui/settings_screen.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
import 'package:dingdong/platform/native_notification_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_agent_connection_smoke_test.dart' as connection_smoke;
import 'desktop_device_link_transport_test.dart' as device_transport;

/// Real desktop frames, mouse hit testing, sockets and native channels run here.
/// All content and preference stores are explicit in-memory test substitutes;
/// no real clipboard, Agent account, API token or personal resource is accessed.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  connection_smoke.main();
  device_transport.main();

  testWidgets(
    'resource editor and switches update the real Bridge and Skill endpoint',
    (WidgetTester tester) async {
      await _showWindow(tester, const Size(1100, 820));
      final DateTime now = DateTime.utc(2026, 8, 31);
      final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
        Resource(
          id: 'acceptance-prompt',
          type: ResourceType.prompt,
          title: 'Acceptance prompt (test)',
          content: 'Original test instruction.',
          activation: ResourceActivation.always,
          createdAt: now,
          updatedAt: now,
        ),
        Resource(
          id: 'acceptance-skill',
          type: ResourceType.skill,
          title: 'Acceptance Skill (test)',
          content:
              '---\nname: acceptance-skill\n'
              'description: Use for release acceptance tests\n---\n\n'
              '# Test instructions\nRead only the test fixture.',
          createdAt: now,
          updatedAt: now,
        ),
        Resource(
          id: 'acceptance-mcp',
          type: ResourceType.mcp,
          title: 'Acceptance MCP (test)',
          content: '{"command":"acceptance-test-fixture"}',
          activation: ResourceActivation.always,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final AgentHttpServer server = AgentHttpServer(
        AgentRouter(resourceStore: store),
      );
      await server.start(port: 0);
      addTearDown(server.stop);
      final LibraryViewModel model = LibraryViewModel(store);
      addTearDown(model.dispose);
      await model.load();
      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(viewModel: model)),
      );
      await tester.pumpAndSettle();

      await _tap(tester, 'resource-row-acceptance-prompt');
      await tester.enterText(
        find.byKey(const Key('resource-content')),
        'Updated through the real desktop editor.',
      );
      await _tap(tester, 'resource-save');
      expect(find.byKey(const Key('resource-save-error')), findsNothing);
      Map<String, dynamic> bridge = await _request(
        server.baseUri,
        '/agent/bridge',
        <String, Object?>{
          'task': 'release acceptance',
          'source': 'Codex',
          'expand': 'prompts',
        },
      );
      expect(
        _resources(bridge, 'prompts').single['content'],
        'Updated through the real desktop editor.',
      );
      expect(_resources(bridge, 'skills').single['name'], 'acceptance-skill');
      expect(_resources(bridge, 'mcps'), hasLength(1));

      final Map<String, dynamic> loaded = await _request(
        server.baseUri,
        '/agent/skills/load?name=acceptance-skill&source=Codex',
      );
      expect(jsonEncode(loaded), contains('Read only the test fixture.'));
      expect(
        ((loaded['conversation'] as Map)['item'] as Map)['confirmedUse'],
        isTrue,
      );

      await _tap(tester, 'library-editor-back');
      await _tap(tester, 'resource-status-acceptance-prompt');
      bridge = await _request(
        server.baseUri,
        '/agent/bridge?task=release%20acceptance&source=Codex',
      );
      expect(_resources(bridge, 'prompts'), isEmpty);
      await _tap(tester, 'resource-status-acceptance-prompt');
      bridge = await _request(
        server.baseUri,
        '/agent/bridge?task=release%20acceptance&source=Codex',
      );
      expect(_resources(bridge, 'prompts'), hasLength(1));

      for (final String type in <String>['skill', 'mcp', 'prompt', 'all']) {
        await _tap(tester, 'resource-filter-$type');
        expect(find.byKey(const Key('resource-list')), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'Agent task lifecycle reaches the visible desktop and native reminder',
    (WidgetTester tester) async {
      await _showWindow(tester, const Size(390, 760));
      final ActivityController activity = ActivityController();
      final ShellController shell = ShellController(initialIndex: 2);
      final List<Future<void>> deliveries = <Future<void>>[];
      addTearDown(activity.dispose);
      addTearDown(shell.dispose);
      final AgentHttpServer server = AgentHttpServer(
        AgentRouter(
          resourceStore: InMemoryResourceStore(),
          onAgentTaskStarted: (start) {
            activity.recordTaskStarted(
              source: start.source,
              task: start.task,
              startedAt: start.startedAt,
              conversationId: start.conversationId,
              workspacePath: start.workspacePath,
            );
          },
          onDing: (DingRequest request) {
            activity.record(
              source: request.source ?? 'Codex',
              message: request.message,
              detail: request.detail,
              conversationTarget: request.conversationTarget,
              notificationKind: request.notificationKind,
            );
            deliveries.add(NativeNotificationGateway().trigger(request));
          },
        ),
      );
      await server.start(port: 0);
      addTearDown(server.stop);
      await tester.pumpWidget(
        DingDongApp(
          activityController: activity,
          shellController: shell,
          agentBaseUri: server.baseUri,
          clipboardGateway: _TestClipboard(),
          settingsRepository: SettingsRepository(
            MemoryPreferencesBackend(<String, Object>{
              'dingdong.language': 'en',
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _request(server.baseUri, '/agent/bridge', <String, Object?>{
        'task': 'Release acceptance lifecycle (test)',
        'source': 'Codex',
        'conversationId': 'release-acceptance-test',
      });
      expect(activity.activeRuns, hasLength(1));
      await _request(server.baseUri, '/ding', <String, Object?>{
        'message': 'Release acceptance reminder (test)',
        'detail': 'Test data only; no user action is required.',
        'source': 'Codex',
        'conversationId': 'release-acceptance-test',
        'notificationKind': 'attention',
        'sound': 'muted',
        'flashCount': 2,
      });
      await Future.wait(deliveries);
      expect(activity.activeRuns, isEmpty);
      expect(
        activity.activities.single.notificationKind,
        AgentNotificationKind.attention,
      );
      expect(activity.unseenCount, 1);
      await _tap(tester, 'popup-tab-0');
      expect(find.text('Release acceptance reminder (test)'), findsWidgets);
      expect(activity.unseenCount, 0);
      await _tap(tester, 'today-agent-api');
      for (
        int attempt = 0;
        attempt < 100 && find.text('Local service verified').evaluate().isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Local service verified'), findsOneWidget);
      await _tap(tester, 'agent-api-back');
      expect(find.byKey(const Key('today-agent-api')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'desktop settings clicks persist across closing and reopening',
    (WidgetTester tester) async {
      await _showWindow(tester, const Size(720, 820));
      final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(backend),
      );
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(viewModel: model)),
      );
      await tester.pumpAndSettle();
      for (final String key in <String>[
        'settings-notify-agent-completion',
        'settings-notify-agent-attention',
        'settings-notify-subagent-activity',
        'settings-notify-codex-voice-activity',
      ]) {
        await _tap(tester, key);
      }
      final Finder items = find.byKey(const Key('settings-retention-items'));
      await tester.ensureVisible(items);
      await tester.enterText(items, '4000');
      await tester.pumpAndSettle();
      await model.shutdown();
      await tester.pumpWidget(const SizedBox.shrink());
      model.dispose();

      final SettingsViewModel reloaded = SettingsViewModel(
        SettingsRepository(backend),
      );
      addTearDown(reloaded.dispose);
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(viewModel: reloaded)),
      );
      await tester.pumpAndSettle();
      expect(reloaded.settings.notifyAgentCompletion, isFalse);
      expect(reloaded.settings.notifyAgentAttention, isFalse);
      expect(reloaded.settings.notifySubagentActivity, isTrue);
      expect(reloaded.settings.notifyCodexVoiceActivity, isTrue);
      expect(reloaded.settings.clipboardMaxItems, 4000);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );

  testWidgets(
    'desktop workspace and clipboard search clicks preserve state',
    (WidgetTester tester) async {
      await _showWindow(tester, const Size(390, 760));
      final DateTime now = DateTime.utc(2026, 8, 31);
      final InMemoryClipboardStore store = InMemoryClipboardStore(
        <ClipboardRecord>[
          for (final String label in <String>['Alpha', 'Beta'])
            ClipboardRecord(
              id: 'acceptance-$label',
              group: 'Clipboard',
              title: '$label clipboard fixture',
              content: '$label test text',
              tags: const <String>['clipboard', 'text'],
              pinned: false,
              enabled: true,
              activation: 'taskMatch',
              createdAt: now,
              updatedAt: now,
            ),
        ],
      );
      await tester.pumpWidget(
        DingDongApp(clipboardStore: store, clipboardGateway: _TestClipboard()),
      );
      await tester.pumpAndSettle();
      await _tap(tester, 'popup-tab-2');
      expect(find.text('Alpha clipboard fixture'), findsOneWidget);
      expect(find.text('Beta clipboard fixture'), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('clipboard-search')),
        'Alpha',
      );
      await tester.pumpAndSettle();
      expect(find.text('Beta clipboard fixture'), findsNothing);
      await _tap(tester, 'clipboard-toggle-filters');
      await _tap(tester, 'popup-tab-1');
      await _tap(tester, 'popup-tab-0');
      await _tap(tester, 'popup-tab-2');
      expect(find.text('Alpha clipboard fixture'), findsOneWidget);
      expect(find.text('Beta clipboard fixture'), findsNothing);
      await tester.enterText(find.byKey(const Key('clipboard-search')), '');
      await tester.pumpAndSettle();
      expect(find.text('Beta clipboard fixture'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _showWindow(WidgetTester tester, Size size) async {
  await windowManager.ensureInitialized();
  await windowManager.setSize(size);
  await windowManager.show();
  await windowManager.focus();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

List<Map<String, dynamic>> _resources(
  Map<String, dynamic> bridge,
  String type,
) => ((bridge['active'] as Map<String, dynamic>)[type] as List)
    .cast<Map<String, dynamic>>();

Future<void> _tap(WidgetTester tester, String key) async {
  final Finder target = find.byKey(Key(key));
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<Map<String, dynamic>> _request(
  Uri base,
  String route, [
  Map<String, Object?>? body,
]) async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest request = await client.openUrl(
      body == null ? 'GET' : 'POST',
      base.resolve(route),
    );
    if (body != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(body));
    }
    final HttpClientResponse response = await request.close();
    final String text = await utf8.decoder.bind(response).join();
    expect(response.statusCode, 200, reason: '$route: $text');
    return jsonDecode(text) as Map<String, dynamic>;
  } finally {
    client.close(force: true);
  }
}

final class _TestClipboard implements ClipboardGateway {
  @override
  Future<ClipboardSnapshot> read() async => const ClipboardSnapshot();

  @override
  Future<void> writeFiles(List<String> paths) async {}

  @override
  Future<void> writeText(String text) async {}
}
