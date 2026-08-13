import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/core/widgets/enabled_status_icon.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/activity/ui/activity_repeat_count.dart';
import 'package:dingdong/features/activity/ui/agent_subagent_badge.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/library/domain/resource_card_presentation.dart';
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
        final List<Resource> enabled = widget
            .libraryViewModel
            .configurableResources
            .where((Resource resource) => resource.enabled)
            .toList(growable: false);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricCard(
                    key: const Key('today-metric-library'),
                    symbol: 'library',
                    value:
                        '${widget.libraryViewModel.configurableResources.length}',
                    label: context.localized('Resource library', '资源'),
                    onTap: () => widget.onOpenWorkspace(1),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    key: const Key('today-open-clipboard'),
                    symbol: 'clipboard',
                    value: '${widget.clipboardViewModel.allRecords.length}',
                    label: context.localized('Clipboard history', '剪贴板'),
                    onTap: () => widget.onOpenWorkspace(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _MetricCard(
                    key: const Key('today-agent-api'),
                    symbol: 'mcp',
                    value: widget.agentBaseUri == null
                        ? context.localized('Check', '待确认')
                        : '${widget.agentBaseUri!.port}',
                    label: context.localized(
                      'API | Agent connections',
                      'API | Agent 连接',
                    ),
                    badge:
                        widget
                            .settingsViewModel
                            .settings
                            .requiresAgentSetupUpdate
                        ? _MetricCardBadge(
                            key: const Key('today-agent-setup-update-badge'),
                            label: context.localized('UPDATE', '需要更新'),
                            semanticLabel: context.localized(
                              'Agent setup needs update',
                              'Agent 接入需要更新',
                            ),
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
                  context.localized('Recent agents', '最近 Agent'),
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
                if (widget.activityController.activities.length > 6 &&
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
            const SizedBox(height: 8),
            if (widget.activityController.activities.isEmpty)
              Text(
                context.localized('No recent agent events', '暂无 Agent 事件'),
                style: TextStyle(
                  color: PopupStyle.of(context).textSecondary,
                  fontSize: 10,
                ),
              )
            else
              ...widget.activityController.activities.take(6).map((
                AgentActivity activity,
              ) {
                final AgentConversationTarget? target =
                    activity.conversationTarget;
                final bool isSubagent =
                    target != null &&
                    widget.agentConversationLauncher.isSubagent(target);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: _AgentActivityCard(
                    key: ValueKey<String>(activity.id),
                    activity: activity,
                    isSubagent: isSubagent,
                    onTap: _conversationTap(context, activity),
                    animate:
                        activity.unseen &&
                        widget.activityController.revealActive,
                  ),
                );
              }),
            const SizedBox(height: 28),
            Text(
              context.localized('Enabled', '已启用'),
              style: TextStyle(
                color: PopupStyle.of(context).textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (enabled.isEmpty)
              Text(
                context.localized(
                  'Enable resources from the library to see them here.',
                  '在资源库启用资源后会显示在这里。',
                ),
                style: TextStyle(
                  color: PopupStyle.of(context).textSecondary,
                  fontSize: 10,
                ),
              )
            else
              ...enabled.map(
                (Resource resource) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EnabledResourceCard(
                    resource: resource,
                    contextMenuGateway: widget.contextMenuGateway,
                    onEdit: widget.resourceManagerLauncher == null
                        ? null
                        : () => widget.resourceManagerLauncher!.show(
                            editingResourceId: resource.id,
                          ),
                    onDisable: () => widget.libraryViewModel.save(
                      resource.copyWith(enabled: false),
                    ),
                  ),
                ),
              ),
          ],
        );
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
    return () => unawaited(_openConversation(context, target));
  }

  Future<void> _openConversation(
    BuildContext context,
    AgentConversationTarget target,
  ) async {
    try {
      await widget.agentConversationLauncher.open(target);
      await widget.onHideWindow?.call();
    } on Object {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.localized(
              'Could not open this Agent conversation.',
              '无法打开这个 Agent 对话。',
            ),
          ),
        ),
      );
    }
  }
}
