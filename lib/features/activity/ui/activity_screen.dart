import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/core/widgets/reminder_card_border.dart';
import 'package:dingdong/core/widgets/reminder_marker.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/activity/ui/activity_repeat_count.dart';
import 'package:dingdong/features/activity/ui/agent_subagent_badge.dart';
import 'package:dingdong/features/activity/ui/conversation_usage_tooltip.dart';
import 'package:dingdong/features/activity/ui/recent_agent_feed.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

part 'activity_cards.dart';

/// Compact activity overview used by the DingDong callout interface.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    required this.activityController,
    required this.agentConversationLauncher,
    required this.clipboardViewModel,
    required this.libraryViewModel,
    required this.settingsViewModel,
    required this.onOpenWorkspace,
    required this.onOpenAgentApi,
    this.agentBaseUri,
    this.agentSetupNeedsUpdate,
    this.onHideWindow,
    this.contextMenuGateway,
    this.resourceManagerLauncher,
    this.windowVisible,
    this.now,
    super.key,
  });

  final ActivityController activityController;
  final AgentConversationLauncher agentConversationLauncher;
  final ClipboardViewModel clipboardViewModel;
  final LibraryViewModel libraryViewModel;
  final SettingsViewModel settingsViewModel;
  final ValueChanged<int> onOpenWorkspace;
  final VoidCallback onOpenAgentApi;
  final Uri? agentBaseUri;
  final bool? agentSetupNeedsUpdate;
  final Future<void> Function()? onHideWindow;
  final DesktopContextMenuGateway? contextMenuGateway;
  final ResourceManagerLauncher? resourceManagerLauncher;
  final ValueListenable<bool>? windowVisible;
  final DateTime Function()? now;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _scheduledRevealRevision = 0;
  bool _revealRequestScheduled = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.activityController,
        widget.agentConversationLauncher,
        widget.clipboardViewModel,
        widget.libraryViewModel,
        widget.settingsViewModel,
        if (widget.windowVisible != null) widget.windowVisible!,
      ]),
      builder: (BuildContext context, Widget? child) {
        _scheduleSeenAcknowledgement();
        final feed = RecentAgentFeed(
          controller: widget.activityController,
          visible: _windowIsVisible,
          compact: true,
          pageSize: widget.settingsViewModel.settings.quickPanelAgentCount,
          now: widget.now,
          header: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: <Widget>[
                  Expanded(
                    child: _MetricCard(
                      key: const Key('today-metric-library'),
                      symbol: 'library',
                      value:
                          '${widget.libraryViewModel.configurableResources.length}',
                      label: context.l10n.resourceLibrary,
                      onTap: () => widget.onOpenWorkspace(1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      key: const Key('today-open-clipboard'),
                      symbol: 'clipboard',
                      value: '${widget.clipboardViewModel.allRecords.length}',
                      label: context.l10n.clipboardHistory,
                      onTap: () => widget.onOpenWorkspace(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MetricCard(
                      key: const Key('today-agent-api'),
                      symbol: 'mcp',
                      value: widget.agentBaseUri == null
                          ? context.l10n.check
                          : '${widget.agentBaseUri!.port}',
                      label: context.l10n.apiAgentConnections,
                      badge:
                          (widget.agentSetupNeedsUpdate ??
                              widget
                                  .settingsViewModel
                                  .settings
                                  .requiresAgentSetupUpdate)
                          ? _MetricCardBadge(
                              key: const Key('today-agent-setup-update-badge'),
                              label: context.l10n.update,
                              semanticLabel: context.l10n.agentSetupNeedsUpdate,
                              tone: _MetricCardBadgeTone.attention,
                            )
                          : !widget.settingsViewModel.settings.mcpAccessSeen
                          ? const _MetricCardBadge(
                              key: Key('today-mcp-badge'),
                              label: 'MCP',
                            )
                          : null,
                      onTap: widget.onOpenAgentApi,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Text(
                    context.l10n.recentAgents,
                    style: TextStyle(
                      color: PopupStyle.of(context).textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 7),
                  _RecentAgentCount(
                    count: widget.activityController.recentCount,
                    hours: widget.activityController.countWindowHours,
                  ),
                  if (widget.activityController.activities.length >
                          widget
                              .settingsViewModel
                              .settings
                              .quickPanelAgentCount &&
                      widget.resourceManagerLauncher != null) ...<Widget>[
                    const Spacer(),
                    _RecentAgentMoreButton(
                      onTap: () => unawaited(
                        widget.resourceManagerLauncher!.show(
                          destination: ResourceManagerDestination.recentAgents,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          empty: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.noRecentAgentEvents,
                style: TextStyle(
                  color: PopupStyle.of(context).textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                context.l10n.gettingStartedAgentActivityDescription,
                style: TextStyle(
                  color: PopupStyle.of(context).textSecondary,
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 10),
              DesktopActionButton(
                key: const Key('today-connect-agent'),
                onPressed: widget.onOpenAgentApi,
                icon: Icons.hub_outlined,
                label: context.l10n.gettingStartedConnectAgent,
                tone: DesktopActionTone.soft,
                compact: true,
              ),
            ],
          ),
          rowBuilder: (context, activity, isNewThisVisit) {
            final AgentConversationTarget? target = activity.conversationTarget;
            final bool isSubagent =
                target != null &&
                widget.agentConversationLauncher.isSubagent(target);
            return _AgentActivityCard(
              key: ValueKey<String>(activity.id),
              activity: activity,
              isNewThisVisit: isNewThisVisit,
              now: (widget.now ?? DateTime.now)(),
              isSubagent: isSubagent,
              showConversationTokenUsage:
                  widget.settingsViewModel.settings.showConversationTokenUsage,
              onTap: _conversationTap(context, activity),
              animate:
                  activity.unseen && widget.activityController.revealActive,
            );
          },
        );
        return Scaffold(backgroundColor: Colors.transparent, body: feed);
      },
    );
  }

  void _scheduleSeenAcknowledgement() {
    final ActivityController controller = widget.activityController;
    if (!_windowIsVisible || controller.unseenCount == 0) {
      return;
    }

    if (!controller.revealActive) {
      if (_revealRequestScheduled) {
        return;
      }
      _revealRequestScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _revealRequestScheduled = false;
        if (!mounted) {
          return;
        }
        final ActivityController current = widget.activityController;
        if (_windowIsVisible &&
            current.unseenCount > 0 &&
            !current.revealActive) {
          current.requestReveal();
        }
      });
      return;
    }

    final int revision = controller.revealRevision;
    if (revision == 0 || revision == _scheduledRevealRevision) {
      return;
    }
    _scheduledRevealRevision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _windowIsVisible &&
          controller.revealRevision == revision) {
        controller.markAllSeen();
      }
    });
  }

  bool get _windowIsVisible => widget.windowVisible?.value ?? true;

  VoidCallback? _conversationTap(BuildContext context, AgentActivity activity) {
    final AgentConversationTarget? target = activity.conversationTarget;
    if (target == null ||
        widget.agentConversationLauncher.isSubagent(target) ||
        !widget.agentConversationLauncher.canOpen(target)) {
      return null;
    }
    return () => unawaited(_openConversation(context, activity));
  }

  Future<void> _openConversation(
    BuildContext context,
    AgentActivity activity,
  ) async {
    final controller = widget.activityController;
    try {
      await widget.agentConversationLauncher.open(activity.conversationTarget!);
      controller.markOpened(activity);
      await widget.onHideWindow?.call();
    } on Object {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenThisAgentConversation)),
      );
    }
  }
}
