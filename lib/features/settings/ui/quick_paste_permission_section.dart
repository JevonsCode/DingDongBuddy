import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
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
        final ColorScheme colors = Theme.of(context).colorScheme;
        final Color statusColor = granted == false
            ? colors.error
            : colors.primary;
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
              Container(
                key: const Key('settings-quick-paste-permission-status'),
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 9, 10, 9),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      granted == false
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline_rounded,
                      size: 20,
                      color: statusColor,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        switch (granted) {
                          true => context.localized(
                            'Permission granted',
                            '权限已授予',
                          ),
                          false => context.localized(
                            'Permission required',
                            '需要授予权限',
                          ),
                          null => context.localized(
                            'Permission status unavailable',
                            '无法获取权限状态',
                          ),
                        },
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DesktopIconButton(
                      tooltip: context.localized('Refresh status', '刷新状态'),
                      onPressed: viewModel.refreshQuickPastePermission,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    if (granted == false) ...<Widget>[
                      const SizedBox(width: 6),
                      DesktopActionButton(
                        key: const Key('settings-open-accessibility'),
                        onPressed: viewModel.openQuickPastePermissionSettings,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: context.localized(
                          'Open permission helper',
                          '打开授权助手',
                        ),
                        tone: DesktopActionTone.neutral,
                      ),
                    ],
                  ],
                ),
              ),
              if (granted == false) ...<Widget>[
                const SizedBox(height: 8),
                Container(
                  key: const Key('settings-accessibility-helper-explanation'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh.withValues(alpha: 0.46),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.drag_indicator_rounded,
                        size: 20,
                        color: colors.primary,
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
