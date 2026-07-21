import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/resource_manager_app.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'resource manager opens recent agents and resumes conversations',
    (WidgetTester tester) async {
      const MethodChannel channels = MethodChannel(
        'mixin.one/desktop_multi_window/channels',
      );
      final TestDefaultBinaryMessenger messenger =
          tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channels, (_) async => null);
      addTearDown(() {
        messenger.setMockMethodCallHandler(channels, null);
      });

      final LibraryViewModel library = LibraryViewModel(
        InMemoryResourceStore(),
      );
      await library.load();
      final ClipboardViewModel clipboard = ClipboardViewModel(
        InMemoryClipboardStore(),
      )..load();
      final ActivityController activity =
          ActivityController(
            idGenerator: () => 'manager-agent',
            now: () => DateTime.utc(2026, 7, 21, 10),
          )..record(
            source: 'Codex',
            message: 'Resumable result',
            conversationTarget: const AgentConversationTarget(
              client: AgentClient.codex,
              conversationId: 'thread-1',
            ),
          );
      final _FakeAgentConversationLauncher conversationLauncher =
          _FakeAgentConversationLauncher();

      await tester.pumpWidget(
        ResourceManagerApp(
          viewModel: library,
          clipboardViewModel: clipboard,
          activityController: activity,
          settings: const AppSettings(language: AppLanguagePreference.chinese),
          windowController: WindowController.fromWindowId(
            'resource-manager-test',
          ),
          initialDestination: ResourceManagerDestination.recentAgents,
          agentConversationLauncher: conversationLauncher,
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('resource-manager-navigation')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('resource-manager-nav-resources')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('resource-manager-nav-clipboard')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('resource-manager-nav-agent-activity')),
        findsOneWidget,
      );
      expect(find.text('资源'), findsOneWidget);
      expect(find.text('剪贴板'), findsOneWidget);
      expect(
        find.byKey(const Key('agent-activity-manager-list')),
        findsOneWidget,
      );
      expect(find.text('Resumable result'), findsOneWidget);
      expect(
        find.byKey(const Key('agent-activity-manager-open-conversation')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('agent-activity-row-manager-agent')),
      );
      await tester.pump();
      expect(conversationLauncher.opened?.conversationId, 'thread-1');

      await tester.tap(find.byKey(const Key('resource-manager-nav-clipboard')));
      await tester.pump();
      expect(find.byKey(const Key('clipboard-manager-search')), findsOneWidget);

      await tester.tap(find.byKey(const Key('resource-manager-nav-resources')));
      await tester.pump();
      expect(find.byKey(const Key('resource-search')), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      activity.dispose();
    },
  );
}

final class _FakeAgentConversationLauncher
    implements AgentConversationLauncher {
  AgentConversationTarget? opened;

  @override
  bool canOpen(AgentConversationTarget target) => target.hasDestination;

  @override
  Future<void> open(AgentConversationTarget target) async {
    opened = target;
  }
}
