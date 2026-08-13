import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Windows resource manager close hides without exiting', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    const MethodChannel channels = MethodChannel(
      'mixin.one/desktop_multi_window/channels',
    );
    const MethodChannel registry = MethodChannel(
      'mixin.one/desktop_multi_window',
    );
    const MethodChannel windowManager = MethodChannel('window_manager');
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    final List<MethodCall> windowCalls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channels, (_) async => null);
    messenger.setMockMethodCallHandler(registry, (MethodCall call) async {
      if (call.method == 'getWindowDefinition') {
        return <String, String>{
          'windowId': 'resource-close-test',
          'windowArgument': '',
        };
      }
      return null;
    });
    messenger.setMockMethodCallHandler(windowManager, (MethodCall call) async {
      windowCalls.add(call);
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(channels, null);
      messenger.setMockMethodCallHandler(registry, null);
      messenger.setMockMethodCallHandler(windowManager, null);
    });
    final LibraryViewModel library = LibraryViewModel(InMemoryResourceStore());
    await library.load();
    final ClipboardViewModel clipboard = ClipboardViewModel(
      InMemoryClipboardStore(),
    )..load();
    final ActivityController activity = ActivityController();
    final IssueCenterController issues = IssueCenterController();
    addTearDown(activity.dispose);
    addTearDown(issues.dispose);

    await tester.pumpWidget(
      ResourceManagerApp(
        viewModel: library,
        clipboardViewModel: clipboard,
        activityController: activity,
        issueCenterController: issues,
        settings: const AppSettings(language: AppLanguagePreference.chinese),
        windowController: WindowController.fromWindowId('resource-close-test'),
      ),
    );
    await tester.pump();

    expect(
      windowCalls,
      contains(
        isA<MethodCall>()
            .having(
              (MethodCall call) => call.method,
              'method',
              'setPreventClose',
            )
            .having(
              (MethodCall call) => call.arguments,
              'arguments',
              <String, Object?>{'isPreventClose': true},
            ),
      ),
    );
    windowCalls.clear();

    await _sendWindowManagerEvent(messenger, 'close');
    await tester.pump();

    expect(windowCalls.map((MethodCall call) => call.method), contains('hide'));
    expect(
      windowCalls.map((MethodCall call) => call.method),
      isNot(contains('destroy')),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    debugDefaultTargetPlatformOverride = null;
  });

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
      final InMemoryClipboardStore clipboardStore = InMemoryClipboardStore();
      final ClipboardViewModel clipboard = ClipboardViewModel(clipboardStore)
        ..load();
      final ActivityController activity = ActivityController(
        store: InMemoryAgentActivityStore(
          AgentActivityHistory(
            activities: <AgentActivity>[
              AgentActivity(
                id: 'manager-agent',
                source: 'Codex',
                message: 'Resumable result',
                completedAt: DateTime.utc(2026, 7, 21, 10),
                unseen: false,
                repeatCount: 2,
                conversationTarget: const AgentConversationTarget(
                  client: AgentClient.codex,
                  conversationId: 'thread-1',
                ),
              ),
              AgentActivity(
                id: 'manager-static',
                source: 'Codex',
                message: 'Static result',
                completedAt: DateTime.utc(2026, 7, 21, 9),
                unseen: false,
                repeatCount: 2,
              ),
              AgentActivity(
                id: 'manager-subagent',
                source: 'Codex',
                message: 'Subagent result',
                completedAt: DateTime.utc(2026, 7, 21, 8),
                unseen: false,
                conversationTarget: const AgentConversationTarget(
                  client: AgentClient.codex,
                  conversationId: 'subagent-thread',
                ),
              ),
              AgentActivity(
                id: 'manager-unknown',
                source: 'Codex',
                message: 'Unknown result',
                completedAt: DateTime.utc(2026, 7, 21, 7),
                unseen: false,
                conversationTarget: const AgentConversationTarget(
                  client: AgentClient.codex,
                  conversationId: 'unknown-thread',
                ),
              ),
            ],
          ),
        ),
        now: () => DateTime.utc(2026, 7, 21, 10),
      )..load();
      final _FakeAgentConversationLauncher conversationLauncher =
          _FakeAgentConversationLauncher();
      conversationLauncher.subagentConversationIds.add('subagent-thread');
      conversationLauncher.unavailableConversationIds.add('unknown-thread');
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
        find.byKey(const Key('resource-manager-nav-agent-adapters')),
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
      expect(
        find.byKey(
          const Key('agent-activity-manager-subagent-manager-subagent'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('agent-activity-manager-unknown-manager-unknown')),
        findsOneWidget,
      );

      clipboardStore.save(
        ClipboardRecord(
          id: 'fresh-copy',
          group: '',
          title: 'Fresh copied image',
          content: '/tmp/fresh-copy.png',
          tags: const <String>['clipboard', 'file', 'image'],
          source: 'ChatGPT',
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: DateTime.utc(2026, 8, 4),
          updatedAt: DateTime.utc(2026, 8, 4),
        ),
      );
      await _sendWindowMethod(
        messenger,
        channel: 'mixin.one/window_controller/resource-manager-test',
        method: 'clipboard_changed',
      );
      await tester.pump();
      expect(clipboard.allRecords.single.title, 'Fresh copied image');

      final Rect resumableRepeat = tester.getRect(
        find.byKey(
          const Key('agent-activity-manager-repeat-count-manager-agent'),
        ),
      );
      final Rect staticRepeat = tester.getRect(
        find.byKey(
          const Key('agent-activity-manager-repeat-count-manager-static'),
        ),
      );
      expect(resumableRepeat.left, closeTo(staticRepeat.left, 0.1));
      expect(
        tester
            .getRect(
              find.byKey(
                const Key(
                  'agent-activity-manager-open-placeholder-manager-static',
                ),
              ),
            )
            .width,
        25,
      );

      await tester.tap(
        find.byKey(const Key('agent-activity-row-manager-agent')),
      );
      await tester.pump();
      expect(conversationLauncher.opened?.conversationId, 'thread-1');

      await _sendWindowMethod(
        messenger,
        channel: 'mixin.one/window_controller/resource-manager-test',
        method: manageClipboardCategoriesMethod,
      );
      await tester.pumpAndSettle();
      final Finder categoryDialog = find.byKey(
        const Key('clipboard-category-rules-dialog'),
      );
      expect(find.byKey(const Key('clipboard-manager-search')), findsOneWidget);
      expect(categoryDialog, findsOneWidget);
      await tester.tap(
        find.descendant(
          of: categoryDialog,
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('resource-manager-nav-clipboard')));
      await tester.pump();
      expect(find.byKey(const Key('clipboard-manager-search')), findsOneWidget);

      await tester.tap(find.byKey(const Key('resource-manager-nav-resources')));
      await tester.pump();
      expect(find.byKey(const Key('resource-search')), findsOneWidget);

      await tester.tap(find.text('新建资源'));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('resource-title')),
        'Unsaved workspace draft',
      );
      await tester.tap(find.byKey(const Key('resource-manager-nav-clipboard')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('resource-unsaved-changes-dialog')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('resource-keep-editing')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resource-editor')), findsOneWidget);
      await tester.tap(find.byKey(const Key('resource-manager-nav-clipboard')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('resource-discard-changes')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('clipboard-manager-search')), findsOneWidget);

      await tester.tap(find.byKey(const Key('resource-manager-nav-resources')));
      await tester.pump();

      final ResourceManagerCreateRequest request =
          const ResourceManagerCreateRequest(
            type: ResourceType.prompt,
            title: 'Clipboard draft',
            content: 'Review this before saving.',
          );
      await _sendWindowMethod(
        messenger,
        channel: 'mixin.one/window_controller/resource-manager-test',
        method: 'create_resource',
        arguments: request.toJson(),
      );
      await tester.pump();
      expect(find.byKey(const Key('resource-editor')), findsOneWidget);
      expect(find.text('Clipboard draft'), findsOneWidget);
      expect(find.text('Review this before saving.'), findsOneWidget);
      expect(library.allResources, isEmpty);

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
    expect(find.byKey(const Key('issue-center-empty-mascot')), findsOneWidget);
    final Image mascot = tester.widget<Image>(
      find.byKey(const Key('issue-center-empty-mascot')),
    );
    expect(
      (mascot.image as AssetImage).assetName,
      'Assets/DingDongIP/rest.png',
    );
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

Future<void> _sendWindowManagerEvent(
  TestDefaultBinaryMessenger messenger,
  String eventName,
) async {
  final Completer<void> handled = Completer<void>();
  await messenger.handlePlatformMessage(
    'window_manager',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('onEvent', <String, Object?>{'eventName': eventName}),
    ),
    (_) => handled.complete(),
  );
  await handled.future;
}

Future<void> _sendWindowMethod(
  TestDefaultBinaryMessenger messenger, {
  required String channel,
  required String method,
  Object? arguments,
}) async {
  final Completer<void> handled = Completer<void>();
  await messenger.handlePlatformMessage(
    'mixin.one/desktop_multi_window/channels',
    const StandardMethodCodec().encodeMethodCall(
      MethodCall('methodCall', <String, Object?>{
        'channel': channel,
        'method': method,
        'arguments': arguments,
      }),
    ),
    (_) => handled.complete(),
  );
  await handled.future;
}

final class _FakeAgentConversationLauncher extends ChangeNotifier
    implements AgentConversationLauncher {
  AgentConversationTarget? opened;
  final Set<String> subagentConversationIds = <String>{};
  final Set<String> unavailableConversationIds = <String>{};

  @override
  bool canOpen(AgentConversationTarget target) =>
      target.hasDestination &&
      !unavailableConversationIds.contains(target.conversationId);

  @override
  bool isSubagent(AgentConversationTarget target) =>
      subagentConversationIds.contains(target.conversationId);

  @override
  Future<void> open(AgentConversationTarget target) async {
    opened = target;
  }
}
