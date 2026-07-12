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
                      label: Text(context.localized('Open settings', '打开系统设置')),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
