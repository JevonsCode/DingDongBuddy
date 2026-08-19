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
                context.l10n.quickPastePermission,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                context
                    .l10n
                    .afterTheGlobalShortcutDingDongCanReturnFocusAndPasteThe_5ad1a82a,
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
                          true => context.l10n.permissionGranted,
                          false => context.l10n.permissionRequired,
                          null => context.l10n.permissionStatusUnavailable,
                        },
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DesktopIconButton(
                      tooltip: context.l10n.refreshStatus,
                      onPressed: viewModel.refreshQuickPastePermission,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    if (granted == false) ...<Widget>[
                      const SizedBox(width: 6),
                      DesktopActionButton(
                        key: const Key('settings-open-accessibility'),
                        onPressed: viewModel.openQuickPastePermissionSettings,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: context.l10n.openPermissionHelper,
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
                          context
                              .l10n
                              .theHelperOpensAccessibilityAndPlacesADraggableDingDong_11660c82,
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
