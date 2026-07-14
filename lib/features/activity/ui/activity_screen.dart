import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/enabled_status_icon.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

part 'activity_cards.dart';

/// Compact activity overview used by the DingDong callout interface.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({
    required this.activityController,
    required this.clipboardViewModel,
    required this.libraryViewModel,
    required this.settingsViewModel,
    required this.onOpenWorkspace,
    this.now,
    super.key,
  });

  final ActivityController activityController;
  final ClipboardViewModel clipboardViewModel;
  final LibraryViewModel libraryViewModel;
  final SettingsViewModel settingsViewModel;
  final ValueChanged<int> onOpenWorkspace;
  final DateTime Function()? now;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _scheduledRevealRevision = 0;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[
        widget.activityController,
        widget.clipboardViewModel,
        widget.libraryViewModel,
        widget.settingsViewModel,
      ]),
      builder: (BuildContext context, Widget? child) {
        _scheduleSeenAcknowledgement();
        final List<Resource> enabled = widget.libraryViewModel.allResources
            .where((Resource resource) => resource.enabled)
            .take(3)
            .toList(growable: false);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          children: <Widget>[
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
              decoration: PopupStyle.card(radius: 9),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.settingsViewModel.settings.clipboardMonitoring
                              ? context.localized(
                                  'Clipboard monitoring is ready.',
                                  '剪贴板监听已就绪。',
                                )
                              : context.localized(
                                  'Clipboard monitoring is paused.',
                                  '剪贴板监听已暂停。',
                                ),
                          style: const TextStyle(
                            color: PopupStyle.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            const Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: PopupStyle.textSecondary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              TimeOfDay.fromDateTime(
                                (widget.now ?? DateTime.now)(),
                              ).format(context),
                              style: const TextStyle(
                                color: PopupStyle.textSecondary,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(key: Key('app-version-0.7.6')),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.verified_outlined,
                    size: 16,
                    color: PopupStyle.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    context.localized('Ready', '就绪'),
                    style: const TextStyle(
                      color: PopupStyle.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MetricCard(
                    key: const Key('today-metric-library'),
                    symbol: 'library',
                    value: '${widget.libraryViewModel.allResources.length}',
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
                    symbol: 'mcp',
                    value: context.localized('Online', '在线'),
                    label: 'Agent API',
                    onTap: () => widget.onOpenWorkspace(3),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              context.localized('Recent agents', '最近 Agent'),
              style: const TextStyle(
                color: PopupStyle.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.activityController.activities.isEmpty)
              Text(
                context.localized('No recent agent events', '暂无 Agent 事件'),
                style: const TextStyle(
                  color: PopupStyle.textSecondary,
                  fontSize: 10,
                ),
              )
            else
              ...widget.activityController.activities
                  .take(4)
                  .map(
                    (AgentActivity activity) => Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: _AgentActivityCard(
                        activity: activity,
                        animate:
                            activity.unseen &&
                            widget.activityController.revealRevision > 0,
                      ),
                    ),
                  ),
            const SizedBox(height: 28),
            Text(
              context.localized('Enabled', '已启用'),
              style: const TextStyle(
                color: PopupStyle.textSecondary,
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
                style: const TextStyle(
                  color: PopupStyle.textSecondary,
                  fontSize: 10,
                ),
              )
            else
              ...enabled.map(
                (Resource resource) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _EnabledResourceCard(resource: resource),
                ),
              ),
          ],
        );
      },
    );
  }

  void _scheduleSeenAcknowledgement() {
    final int revision = widget.activityController.revealRevision;
    if (revision == 0 || revision == _scheduledRevealRevision) {
      return;
    }
    _scheduledRevealRevision = revision;
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && widget.activityController.revealRevision == revision) {
        widget.activityController.markAllSeen();
      }
    });
  }
}
