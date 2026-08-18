import 'dart:async';

import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/agent_api/domain/agent_setup_revision.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_capture_service.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
import 'package:dingdong/platform/native_agent_conversation_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DingDong exposes its desktop context menu controller', (
    WidgetTester tester,
  ) async {
    final DesktopContextMenuController controller =
        DesktopContextMenuController();

    await tester.pumpWidget(
      DingDongApp(desktopContextMenuController: controller),
    );

    final DesktopContextMenuScope scope = tester.widget(
      find.byType(DesktopContextMenuScope),
    );
    expect(scope.controller, same(controller));
  });

  testWidgets('DingDong starts with the Dynamic workspace at version 1.4.6', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DingDongApp());

    expect(find.text('Dynamic'), findsWidgets);
    expect(find.byKey(const Key('app-version-1.4.6')), findsOneWidget);
    expect(find.text('v1.4.6'), findsOneWidget);
    expect(find.byKey(const Key('popup-development-badge')), findsNothing);
    expect(find.text('Resource library'), findsOneWidget);
    expect(find.text('Clipboard history'), findsOneWidget);
    expect(find.text('API | Agent connections'), findsOneWidget);
  });

  testWidgets('development build is visibly labeled beside DingDong', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const DingDongApp(developmentBuild: true));

    expect(find.byKey(const Key('popup-development-badge')), findsOneWidget);
    expect(find.text('DEV'), findsOneWidget);
    final Text brand = tester.widget<Text>(find.text('DingDong').first);
    expect(brand.softWrap, isFalse);
    expect(brand.style?.height, 1.18);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Dynamic quick actions open a working workspace', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const DingDongApp());

    await tester.tap(find.byKey(const Key('today-open-clipboard')));
    await tester.pump();

    expect(find.byKey(const Key('clipboard-search')), findsOneWidget);
  });

  testWidgets('first MCP entry shows a badge and scrolls to MCP access once', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
    final ShellController controller = ShellController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      DingDongApp(
        settingsRepository: SettingsRepository(backend),
        shellController: controller,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('today-mcp-badge')), findsOneWidget);

    await tester.tap(find.byKey(const Key('today-agent-api')));
    await tester.pumpAndSettle();

    expect(backend.values['dingdong.onboarding.mcpAccessSeen'], isTrue);
    expect(find.byKey(const Key('agent-api-mcp-access')), findsOneWidget);
    final CustomScrollView scroll = tester.widget<CustomScrollView>(
      find.byKey(const Key('agent-api-scroll')),
    );
    expect(scroll.controller?.offset, greaterThan(0));

    controller.open(0);
    await tester.pump();
    expect(find.byKey(const Key('today-mcp-badge')), findsNothing);
  });

  testWidgets(
    'Agent setup update badge stays until the user confirms the new prompt',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final MemoryPreferencesBackend backend =
          MemoryPreferencesBackend(<String, Object>{
            'dingdong.onboarding.mcpAccessSeen': true,
            'dingdong.agentApi.acknowledgedSetupRevision': 0,
          });
      final ShellController controller = ShellController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        DingDongApp(
          settingsRepository: SettingsRepository(backend),
          shellController: controller,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('today-agent-setup-update-badge')),
        findsOneWidget,
      );
      expect(find.text('UPDATE'), findsOneWidget);
      expect(find.byKey(const Key('today-mcp-badge')), findsNothing);

      await tester.tap(find.byKey(const Key('today-agent-api')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('agent-api-setup-update-notice')),
        findsOneWidget,
      );
      expect(backend.values['dingdong.agentApi.acknowledgedSetupRevision'], 0);

      final Finder confirm = find.byKey(
        const Key('agent-api-mark-setup-updated'),
      );
      await tester.ensureVisible(confirm);
      await tester.pumpAndSettle();
      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(
        backend.values['dingdong.agentApi.acknowledgedSetupRevision'],
        currentAgentSetupRevision,
      );
      expect(
        find.byKey(const Key('agent-api-setup-update-notice')),
        findsNothing,
      );

      controller.open(0);
      await tester.pump();
      expect(
        find.byKey(const Key('today-agent-setup-update-badge')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Dynamic cards use compact desktop row heights', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final Resource resource = Resource(
      id: 'compact-today-resource',
      type: ResourceType.skill,
      title: 'Compact resource',
      content: 'A concise enabled resource row',
      enabled: true,
      createdAt: DateTime.utc(2026, 7, 12),
      updatedAt: DateTime.utc(2026, 7, 12),
    );
    await tester.pumpWidget(
      DingDongApp(resourceStore: InMemoryResourceStore(<Resource>[resource])),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('today-metric-library'))).height,
      72,
    );
    expect(
      tester
          .getSize(
            find.byKey(const Key('today-enabled-compact-today-resource')),
          )
          .height,
      92,
    );
  });

  testWidgets('Dynamic marks a rendered Agent seen without a delay', (
    WidgetTester tester,
  ) async {
    final ActivityController activityController = ActivityController(
      idGenerator: () => 'completed-agent',
      now: () => DateTime.utc(2026, 7, 12, 10),
    );
    const AgentConversationTarget target = AgentConversationTarget(
      client: AgentClient.codex,
      conversationId: 'thread-unseen-repeat',
    );
    activityController.record(
      source: 'Codex',
      message: 'Refactor complete',
      conversationTarget: target,
    );
    activityController.record(
      source: 'Codex',
      message: 'Refactor complete again',
      conversationTarget: target,
    );
    activityController.requestReveal();

    await tester.pumpWidget(
      DingDongApp(activityController: activityController),
    );
    await tester.pump();

    expect(find.byKey(const Key('activity-completed-agent')), findsOneWidget);
    expect(find.byKey(const Key('recent-agent-count')), findsOneWidget);
    expect(find.text('24 h · 1'), findsOneWidget);
    expect(activityController.unseenCount, 0);
    Text repeatText = tester.widget<Text>(find.text('×2'));
    expect(
      repeatText.style?.color,
      PopupStyle.textPrimary.withValues(alpha: 0.13),
    );

    await tester.pump(const Duration(milliseconds: 50));
    expect(activityController.unseenCount, 0);
    repeatText = tester.widget<Text>(find.text('×2'));
    expect(
      repeatText.style?.color,
      PopupStyle.textPrimary.withValues(alpha: 0.13),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    activityController.dispose();
  });

  testWidgets('Dynamic acknowledges a new unseen Agent while already visible', (
    WidgetTester tester,
  ) async {
    final ActivityController activityController = ActivityController(
      idGenerator: () => 'live-unseen-agent',
      now: () => DateTime.utc(2026, 7, 12, 10),
    );
    const AgentConversationTarget target = AgentConversationTarget(
      client: AgentClient.codex,
      conversationId: 'live-unseen-conversation',
    );

    await tester.pumpWidget(
      DingDongApp(activityController: activityController),
    );
    await tester.pump();

    activityController.record(
      source: 'Codex',
      message: 'First live reminder',
      conversationTarget: target,
    );
    activityController.record(
      source: 'Codex',
      message: 'Second live reminder',
      conversationTarget: target,
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(activityController.unseenCount, 0);
    Text repeatText = tester.widget<Text>(find.text('×2'));
    expect(
      repeatText.style?.color,
      PopupStyle.textPrimary.withValues(alpha: 0.13),
    );

    await tester.pump(const Duration(milliseconds: 50));

    expect(activityController.unseenCount, 0);
    repeatText = tester.widget<Text>(find.text('×2'));
    expect(
      repeatText.style?.color,
      PopupStyle.textPrimary.withValues(alpha: 0.13),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    activityController.dispose();
  });

  testWidgets('Dynamic keeps Agent events unseen while the window is hidden', (
    WidgetTester tester,
  ) async {
    final ActivityController activityController = ActivityController(
      idGenerator: () => 'hidden-unseen-agent',
      now: () => DateTime.utc(2026, 8, 11, 10),
    );
    final ValueNotifier<bool> windowVisible = ValueNotifier<bool>(false);
    addTearDown(windowVisible.dispose);

    await tester.pumpWidget(
      DingDongApp(
        activityController: activityController,
        windowVisible: windowVisible,
      ),
    );
    await tester.pump();

    activityController.record(
      source: 'Codex',
      message: 'Background task complete',
      conversationTarget: const AgentConversationTarget(
        client: AgentClient.codex,
        conversationId: 'hidden-unseen-conversation',
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(activityController.unseenCount, 1);
    expect(activityController.revealActive, isFalse);

    activityController.requestReveal();
    await tester.pump();
    await tester.pump();

    expect(activityController.unseenCount, 1);
    expect(activityController.revealActive, isTrue);

    windowVisible.value = true;
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(activityController.unseenCount, 0);
    expect(activityController.revealActive, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
    activityController.dispose();
  });

  testWidgets('Dynamic resets activity highlights when items become seen', (
    WidgetTester tester,
  ) async {
    int nextId = 0;
    final ActivityController activityController = ActivityController(
      idGenerator: () => 'activity-${nextId++}',
      now: () => DateTime.utc(2026, 7, 12, 10),
    );
    activityController.record(source: 'Codex', message: 'First reminder');
    activityController.requestReveal();

    await tester.pumpWidget(
      DingDongApp(activityController: activityController),
    );
    await tester.pump(const Duration(milliseconds: 200));

    BoxDecoration cardDecoration() {
      final Container card = tester.widget<Container>(
        find.byKey(const Key('activity-activity-0')),
      );
      return card.decoration! as BoxDecoration;
    }

    expect(cardDecoration().color, PopupStyle.surface);

    activityController.markAllSeen();
    await tester.pump();
    expect(cardDecoration().color, PopupStyle.surface);

    activityController.record(source: 'Codex', message: 'Later reminder');
    await tester.pump(const Duration(milliseconds: 200));
    final Container laterCard = tester.widget<Container>(
      find.byKey(const Key('activity-activity-1')),
    );
    expect((laterCard.decoration! as BoxDecoration).color, PopupStyle.surface);

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpWidget(const SizedBox.shrink());
    activityController.dispose();
  });

  testWidgets('clicking a resumable Agent item opens its conversation', (
    WidgetTester tester,
  ) async {
    final ActivityController activityController = ActivityController(
      idGenerator: () => 'resumable-agent',
      now: () => DateTime.utc(2026, 7, 22, 10),
    );
    activityController.record(
      source: 'Codex',
      message: 'Conversation ready',
      conversationTarget: const AgentConversationTarget(
        client: AgentClient.codex,
        conversationId: 'thread-1',
      ),
    );
    final _FakeAgentConversationLauncher launcher =
        _FakeAgentConversationLauncher();

    await tester.pumpWidget(
      DingDongApp(
        activityController: activityController,
        agentConversationLauncher: launcher,
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Open Agent conversation'), findsOneWidget);
    await tester.tap(find.byKey(const Key('activity-resumable-agent')));
    await tester.pump();

    expect(launcher.opened?.conversationId, 'thread-1');
    await tester.pumpWidget(const SizedBox.shrink());
    activityController.dispose();
  });

  testWidgets('Dynamic waits for Codex preflight before showing open action', (
    WidgetTester tester,
  ) async {
    final Completer<bool> openability = Completer<bool>();
    final NativeAgentConversationLauncher launcher =
        NativeAgentConversationLauncher(
          codexConversationOpenability: (_) => openability.future,
        );
    final ActivityController activityController = ActivityController(
      idGenerator: () => 'pending-codex-agent',
      now: () => DateTime.utc(2026, 7, 22, 10),
    );
    const AgentConversationTarget target = AgentConversationTarget(
      client: AgentClient.codex,
      conversationId: 'pending-codex-thread',
    );
    activityController.record(
      source: 'Codex',
      message: 'Background task',
      conversationTarget: target,
    );

    await tester.pumpWidget(
      DingDongApp(
        activityController: activityController,
        agentConversationLauncher: launcher,
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('activity-open-conversation')), findsNothing);
    expect(
      find.byKey(
        const Key('activity-unknown-conversation-pending-codex-agent'),
      ),
      findsOneWidget,
    );

    final Future<void> preflight = launcher.preflight(<AgentConversationTarget>[
      target,
    ]);
    await tester.pump();
    expect(find.byKey(const Key('activity-open-conversation')), findsNothing);
    expect(
      find.byKey(
        const Key('activity-unknown-conversation-pending-codex-agent'),
      ),
      findsOneWidget,
    );

    openability.complete(true);
    await preflight;
    await tester.pump();
    expect(find.byKey(const Key('activity-open-conversation')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    activityController.dispose();
    launcher.dispose();
  });

  testWidgets('Dynamic marks a recognized Codex subagent with a sub badge', (
    WidgetTester tester,
  ) async {
    final NativeAgentConversationLauncher launcher =
        NativeAgentConversationLauncher(
          codexConversationPreflightBatch: (_) async =>
              const AgentConversationPreflightResult(
                subagentConversationIds: <String>{'subagent-thread'},
              ),
        );
    final ActivityController activityController = ActivityController(
      idGenerator: () => 'subagent-agent',
      now: () => DateTime.utc(2026, 7, 22, 10),
    );
    const AgentConversationTarget target = AgentConversationTarget(
      client: AgentClient.codex,
      conversationId: 'subagent-thread',
    );
    activityController.record(
      source: 'Codex',
      message: 'Subagent result',
      conversationTarget: target,
    );

    await tester.pumpWidget(
      DingDongApp(
        activityController: activityController,
        agentConversationLauncher: launcher,
      ),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('activity-subagent-subagent-agent')),
      findsNothing,
    );
    expect(find.byKey(const Key('activity-open-conversation')), findsNothing);
    expect(
      find.byKey(const Key('activity-unknown-conversation-subagent-agent')),
      findsOneWidget,
    );

    await launcher.preflight(<AgentConversationTarget>[target]);
    await tester.pump();

    expect(
      find.byKey(const Key('activity-subagent-subagent-agent')),
      findsOneWidget,
    );
    expect(find.text('sub'), findsOneWidget);
    expect(find.byTooltip('Codex subagent'), findsOneWidget);
    expect(
      find.byKey(const Key('activity-unknown-conversation-subagent-agent')),
      findsNothing,
    );
    expect(find.byKey(const Key('activity-open-conversation')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    activityController.dispose();
    launcher.dispose();
  });

  testWidgets('Dynamic shows repeat count and contains long activity text', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 540);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ActivityController activityController = ActivityController(
      idGenerator: () => 'repeated-long-agent',
      now: () => DateTime.utc(2026, 7, 22, 10),
    );
    const AgentConversationTarget target = AgentConversationTarget(
      client: AgentClient.codex,
      conversationId: 'thread-long',
    );
    activityController.record(
      source:
          'Codex source with a deliberately long name that must remain inside the dynamic card',
      message:
          'A deliberately long completion message that should be truncated in the compact Dynamic card instead of pushing the time or open action out of bounds.',
      conversationTarget: target,
      tokenUsage: const ConversationTokenUsage(
        source: ConversationTokenUsageSource.codex,
        totalTokens: 1000,
      ),
    );
    activityController.record(
      source:
          'Codex source with a deliberately long name that must remain inside the dynamic card',
      message:
          'A second long completion message for the same conversation, represented by the same item.',
      conversationTarget: target,
      tokenUsage: const ConversationTokenUsage(
        source: ConversationTokenUsageSource.codex,
        totalTokens: 1234567,
      ),
    );

    await tester.pumpWidget(
      DingDongApp(
        activityController: activityController,
        settingsRepository: SettingsRepository(
          MemoryPreferencesBackend(<String, Object>{
            'dingdong.agentApi.showConversationTokenUsage': true,
          }),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('activity-repeat-count-repeated-long-agent')),
      findsOneWidget,
    );
    expect(find.text('×2'), findsOneWidget);
    final Tooltip repeatTooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('activity-repeat-count-repeated-long-agent')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(
      repeatTooltip.message,
      'This conversation has notified you 2 times and used 1,234,567 tokens.',
    );
    final Rect cardRect = tester.getRect(
      find.byKey(const Key('activity-repeated-long-agent')),
    );
    final Rect repeatRect = tester.getRect(find.text('×2'));
    final Rect messageRect = tester.getRect(
      find.byKey(const Key('activity-message-repeated-long-agent')),
    );
    expect(messageRect.bottom, closeTo(repeatRect.bottom, 0.1));
    expect(cardRect.bottom - repeatRect.bottom, greaterThan(8));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    activityController.dispose();
  });

  testWidgets('Dynamic reserves the open action slot across activity rows', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 540);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final ActivityController activityController = ActivityController(
      store: InMemoryAgentActivityStore(
        AgentActivityHistory(
          activities: <AgentActivity>[
            AgentActivity(
              id: 'repeat-without-open',
              source: 'Codex',
              message: 'No conversation target',
              completedAt: DateTime.utc(2026, 7, 22, 10),
              unseen: false,
              repeatCount: 2,
            ),
            AgentActivity(
              id: 'repeat-with-open',
              source: 'Codex',
              message: 'Has a conversation target',
              completedAt: DateTime.utc(2026, 7, 22, 9),
              unseen: false,
              repeatCount: 2,
              conversationTarget: const AgentConversationTarget(
                client: AgentClient.codex,
                conversationId: 'thread-aligned-repeat',
              ),
            ),
          ],
        ),
      ),
      now: () => DateTime.utc(2026, 7, 22, 10),
    )..load();

    await tester.pumpWidget(
      DingDongApp(activityController: activityController),
    );
    await tester.pumpAndSettle();

    final Rect withoutOpenRepeat = tester.getRect(
      find.byKey(const Key('activity-repeat-count-repeat-without-open')),
    );
    final Rect withOpenRepeat = tester.getRect(
      find.byKey(const Key('activity-repeat-count-repeat-with-open')),
    );
    expect(withoutOpenRepeat.left, closeTo(withOpenRepeat.left, 0.1));

    final Rect placeholder = tester.getRect(
      find.byKey(
        const Key('activity-open-conversation-placeholder-repeat-without-open'),
      ),
    );
    expect(placeholder.width, 20);
    expect(
      find.descendant(
        of: find.byKey(const Key('activity-repeat-with-open')),
        matching: find.byKey(const Key('activity-open-conversation')),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    activityController.dispose();
  });

  testWidgets('recent Agent preview shows six items and opens the full list', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    int nextId = 0;
    final ActivityController activityController = ActivityController(
      idGenerator: () => 'overflow-${nextId++}',
      now: () => DateTime.utc(2026, 7, 22, 10),
    );
    for (int index = 0; index < 7; index += 1) {
      activityController.record(
        source: 'Codex',
        message: 'Recent activity $index',
      );
    }
    final _FakeResourceManagerLauncher launcher =
        _FakeResourceManagerLauncher();

    await tester.pumpWidget(
      DingDongApp(
        activityController: activityController,
        resourceManagerLauncher: launcher,
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('activity-overflow-0')), findsNothing);
    for (int index = 1; index < 7; index += 1) {
      expect(find.byKey(Key('activity-overflow-$index')), findsOneWidget);
    }
    expect(find.byKey(const Key('recent-agent-more')), findsOneWidget);

    await tester.tap(find.byKey(const Key('recent-agent-more')));
    await tester.pump();

    expect(launcher.lastDestination, ResourceManagerDestination.recentAgents);
    await tester.pumpWidget(const SizedBox.shrink());
    activityController.dispose();
  });

  testWidgets('desktop navigation opens the resource library workspace', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const DingDongApp());

    await tester.tap(find.text('Library'));
    await tester.pump();

    expect(find.byKey(const Key('resource-search')), findsOneWidget);
    expect(find.byKey(const Key('resource-manager-open')), findsOneWidget);
    expect(find.byKey(const Key('resource-library-context')), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
  });

  testWidgets('resource card icon actions expose consistent hover labels', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final Resource resource = Resource(
      id: 'tooltip-resource',
      type: ResourceType.prompt,
      title: 'Reusable prompt',
      content: 'Prompt body',
      enabled: true,
      createdAt: DateTime.utc(2026, 7, 13),
      updatedAt: DateTime.utc(2026, 7, 13),
    );
    await tester.pumpWidget(
      DingDongApp(resourceStore: InMemoryResourceStore(<Resource>[resource])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pump();

    expect(find.byTooltip('Disable'), findsOneWidget);
    expect(find.byTooltip('Copy'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
  });

  testWidgets('desktop navigation opens the clipboard workspace', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(const DingDongApp());

    await tester.tap(find.text('Clipboard'));
    await tester.pump();

    expect(find.byKey(const Key('clipboard-search')), findsOneWidget);
    expect(find.byKey(const Key('clipboard-list')), findsOneWidget);
  });

  testWidgets(
    'deleting the final clipboard item is not undone when the workspace reopens',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final DateTime now = DateTime.utc(2026, 7, 21, 12);
      final ClipboardRecord record = ClipboardRecord(
        id: 'only-item',
        group: 'Clipboard',
        title: 'Only clipboard item',
        content: 'keep deletion durable',
        tags: const <String>['clipboard', 'text'],
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: now,
        updatedAt: now,
      );
      final InMemoryClipboardStore store = InMemoryClipboardStore(
        <ClipboardRecord>[record],
      );
      final _StaticClipboardGateway gateway = _StaticClipboardGateway(
        const ClipboardSnapshot(text: 'keep deletion durable'),
      );
      final ShellController controller = ShellController(initialIndex: 2);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        DingDongApp(
          clipboardStore: store,
          clipboardCaptureService: ClipboardCaptureService(
            gateway: gateway,
            store: store,
          ),
          shellController: controller,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(record.title), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(store.list(limit: 10), isEmpty);
      expect(find.text(record.title), findsNothing);

      controller.open(0);
      await tester.pump();
      controller.open(2);
      await tester.pumpAndSettle();

      expect(store.list(limit: 10), isEmpty);
      expect(find.text(record.title), findsNothing);
      expect(gateway.readCount, 0);
    },
  );

  testWidgets('settings toolbar action opens the dedicated settings panel', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final _FakeSettingsWindowLauncher launcher = _FakeSettingsWindowLauncher();
    await tester.pumpWidget(DingDongApp(settingsWindowLauncher: launcher));

    await tester.tap(find.byKey(const Key('popup-open-settings')));
    await tester.pumpAndSettle();

    expect(launcher.openCount, 1);
    expect(find.byKey(const Key('settings-theme-mode')), findsNothing);
  });

  testWidgets('desktop navigation opens local API and MCP setup details', (
    WidgetTester tester,
  ) async {
    final ShellController controller = ShellController();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      DingDongApp(
        shellController: controller,
        agentBaseUri: Uri.parse('http://127.0.0.1:58631'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('58631'), findsOneWidget);
    expect(find.text('API | Agent connections'), findsOneWidget);
    expect(
      find.textContaining('API listening on 127.0.0.1:58631'),
      findsOneWidget,
    );

    controller.open(3);
    await tester.pumpAndSettle();

    expect(find.text('http://127.0.0.1:58631'), findsWidgets);
    final Finder advanced = find.byKey(const Key('agent-api-toggle-advanced'));
    await tester.ensureVisible(advanced);
    await tester.pumpAndSettle();
    await tester.tap(advanced);
    await tester.pumpAndSettle();
    expect(find.text('MCP access'), findsOneWidget);
    expect(find.byKey(const Key('agent-api-copy-health')), findsOneWidget);
  });

  testWidgets('saved appearance preference controls the application theme', (
    WidgetTester tester,
  ) async {
    final SettingsRepository repository = SettingsRepository(
      MemoryPreferencesBackend(<String, Object>{
        'dingdong.panel.themeMode': 'dark',
      }),
    );

    await tester.pumpWidget(DingDongApp(settingsRepository: repository));
    await tester.pumpAndSettle();

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.dark,
    );
  });

  testWidgets(
    'saved Chinese preference localizes navigation and workspace copy',
    (WidgetTester tester) async {
      final SettingsRepository repository = SettingsRepository(
        MemoryPreferencesBackend(<String, Object>{'dingdong.language': 'zh'}),
      );

      await tester.pumpWidget(DingDongApp(settingsRepository: repository));
      await tester.pumpAndSettle();

      expect(find.text('动态'), findsWidgets);
      expect(find.text('资源库'), findsWidgets);
      expect(find.text('剪贴板'), findsWidgets);
    },
  );

  testWidgets('external desktop commands control shell navigation', (
    WidgetTester tester,
  ) async {
    final ShellController controller = ShellController();
    await tester.pumpWidget(DingDongApp(shellController: controller));

    controller.open(3);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('agent-connection-health')), findsOneWidget);
  });
}

final class _FakeAgentConversationLauncher extends ChangeNotifier
    implements AgentConversationLauncher {
  AgentConversationTarget? opened;

  @override
  bool canOpen(AgentConversationTarget target) => target.hasDestination;

  @override
  bool isSubagent(AgentConversationTarget target) => false;

  @override
  Future<void> open(AgentConversationTarget target) async {
    opened = target;
  }
}

final class _FakeResourceManagerLauncher implements ResourceManagerLauncher {
  ResourceManagerDestination? lastDestination;

  @override
  Future<void> show({
    String? editingResourceId,
    ResourceManagerCreateRequest? createRequest,
    ResourceManagerDestination destination =
        ResourceManagerDestination.resources,
  }) async {
    lastDestination = destination;
  }
}

final class _FakeSettingsWindowLauncher implements SettingsWindowLauncher {
  int openCount = 0;
  SettingsWindowDestination? lastDestination;

  @override
  Future<void> show({
    SettingsWindowDestination destination = SettingsWindowDestination.top,
  }) async {
    openCount += 1;
    lastDestination = destination;
  }
}

final class _StaticClipboardGateway implements ClipboardGateway {
  _StaticClipboardGateway(this.snapshot);

  final ClipboardSnapshot snapshot;
  int readCount = 0;

  @override
  Future<ClipboardSnapshot> read() async {
    readCount += 1;
    return snapshot;
  }

  @override
  Future<void> writeFiles(List<String> paths) async {}

  @override
  Future<void> writeText(String text) async {}
}
