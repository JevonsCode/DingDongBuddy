import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

/// Explains and manages the OS permission used by quick paste on macOS.
class QuickPastePermissionSection extends StatelessWidget {
  const QuickPastePermissionSection({required this.viewModel, super.key});

  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (BuildContext context, Widget? child) {
        final bool? granted = viewModel.isQuickPastePermissionGranted;
        final Color statusColor = granted == false
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary;
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.localized('Quick paste permission', '快捷粘贴权限'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                context.localized(
                  'After the global shortcut, DingDong can return focus and paste the selected item.',
                  '使用全局快捷键后，DingDong 可返回原应用并粘贴所选内容。',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              const Divider(),
              Row(
                children: <Widget>[
                  Icon(
                    granted == false
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                    color: statusColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(switch (granted) {
                      true => context.localized('Permission granted', '权限已授予'),
                      false => context.localized(
                        'Permission required',
                        '需要授予权限',
                      ),
                      null => context.localized(
                        'Permission status unavailable',
                        '无法获取权限状态',
                      ),
                    }),
                  ),
                  IconButton(
                    tooltip: context.localized('Refresh status', '刷新状态'),
                    onPressed: viewModel.refreshQuickPastePermission,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                  if (granted == false)
                    OutlinedButton.icon(
                      key: const Key('settings-open-accessibility'),
                      onPressed: viewModel.openQuickPastePermissionSettings,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(
                        context.localized('Open permission helper', '打开授权助手'),
                      ),
                    ),
                ],
              ),
              if (granted == false) ...<Widget>[
                const SizedBox(height: 12),
                Container(
                  key: const Key('settings-accessibility-helper-explanation'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.drag_indicator_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.localized(
                            'The helper opens Accessibility and places a draggable DingDong beside it. If “−” works, remove the old entry before dragging. If “−” is disabled, drag once to make it available, remove the entry, then drag again and turn DingDong on.',
                            '助手会打开“辅助功能”，并在旁边显示可拖拽的 DingDong。“−”可用时先删除旧条目再拖入；若“−”置灰，先拖一次让它可用，删除旧条目后再拖一次并打开开关。',
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
