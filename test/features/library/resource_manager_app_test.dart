import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
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
      const MethodChannel registry = MethodChannel(
        'mixin.one/desktop_multi_window',
      );
      final TestDefaultBinaryMessenger messenger =
          tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channels, (_) async => null);
      messenger.setMockMethodCallHandler(registry, (MethodCall call) async {
        if (call.method == 'getWindowDefinition') {
          return <String, String>{
            'windowId': 'resource-manager-test',
            'windowArgument': '',
          };
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channels, null);
        messenger.setMockMethodCallHandler(registry, null);
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
      final IssueCenterController issues = IssueCenterController();
      addTearDown(issues.dispose);

      await tester.pumpWidget(
        ResourceManagerApp(
          viewModel: library,
          clipboardViewModel: clipboard,
          activityController: activity,
          issueCenterController: issues,
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
      expect(
        find.byKey(const Key('resource-manager-nav-issues')),
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

  testWidgets('issues are a persistent workspace with manual detection', (
    WidgetTester tester,
  ) async {
    const MethodChannel channels = MethodChannel(
      'mixin.one/desktop_multi_window/channels',
    );
    const MethodChannel registry = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channels, (_) async => null);
    messenger.setMockMethodCallHandler(registry, (MethodCall call) async {
      if (call.method == 'getWindowDefinition') {
        return <String, String>{
          'windowId': 'issues-test',
          'windowArgument': '',
        };
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channels, null);
      messenger.setMockMethodCallHandler(registry, null);
    });

    final LibraryViewModel library = LibraryViewModel(InMemoryResourceStore());
    await library.load();
    final ClipboardViewModel clipboard = ClipboardViewModel(
      InMemoryClipboardStore(),
    )..load();
    final ActivityController activity = ActivityController();
    addTearDown(activity.dispose);
    int checks = 0;
    final IssueCenterController issues = IssueCenterController(
      inspector: () async {
        checks += 1;
        return const <AppIssue>[
          AppIssue(
            id: 'skill-conflict',
            source: agentResourceSyncIssueSource,
            kind: AppIssueKind.skillNameConflict,
            severity: AppIssueSeverity.error,
            title: 'Skill name conflict',
            detail: 'Existing Skill preserved.',
            resourceId: 'resource-1',
            resourceTitle: 'code-review',
            clientName: 'Claude Code',
            targetPath: '/Users/test/.claude/skills/code-review',
          ),
          AppIssue(
            id: 'plugin-skill-conflict',
            source: agentResourceSyncIssueSource,
            kind: AppIssueKind.pluginSkillNameConflict,
            severity: AppIssueSeverity.warning,
            title: 'Agent plugin provides the same Skill',
            detail: 'superpowers also provides this Skill.',
            resourceId: 'resource-2',
            resourceTitle: 'verification-before-completion',
            clientName: 'Claude Code · superpowers',
            targetPath:
                '/Users/test/.claude/plugins/superpowers/skills/verification-before-completion/SKILL.md',
          ),
        ];
      },
    );
    addTearDown(issues.dispose);

    await tester.pumpWidget(
      ResourceManagerApp(
        viewModel: library,
        clipboardViewModel: clipboard,
        activityController: activity,
        issueCenterController: issues,
        settings: const AppSettings(language: AppLanguagePreference.chinese),
        windowController: WindowController.fromWindowId('issues-test'),
        initialDestination: ResourceManagerDestination.issues,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('issue-center-screen')), findsOneWidget);
    expect(find.text('没有发现问题'), findsOneWidget);
    expect(find.text('集中查看资源同步、Agent 配置及其他需要处理的问题。'), findsOneWidget);
    expect(find.byKey(const Key('issue-center-check')), findsOneWidget);
    expect(find.byKey(const Key('issue-center-empty-check')), findsNothing);
    expect(find.text('检测'), findsOneWidget);
    expect(
      find.byKey(const Key('resource-manager-nav-issues')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('issue-center-check')));
    await tester.pumpAndSettle();

    expect(checks, 1);
    expect(find.byKey(const Key('issue-center-list')), findsOneWidget);
    expect(find.byKey(const Key('issue-center-count')), findsOneWidget);
    expect(
      find.byKey(const Key('resource-manager-issue-count')),
      findsOneWidget,
    );
    expect(find.text('Claude Code'), findsOneWidget);
    expect(find.text('/Users/test/.claude/skills/code-review'), findsOneWidget);
    expect(find.text('Agent 插件提供了同名 Skill'), findsOneWidget);
    expect(find.text('Claude Code · superpowers'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
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
