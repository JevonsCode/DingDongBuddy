import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/settings/domain/application_updater.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

/// Version status and release navigation kept separate from general settings.
class ReleaseSettingsSection extends StatelessWidget {
  const ReleaseSettingsSection({required this.viewModel, super.key});

  final SettingsViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (BuildContext context, Widget? child) {
        final ReleaseStatus status = viewModel.releaseStatus;
        final ApplicationUpdateStatus installStatus =
            viewModel.applicationUpdateStatus;
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.localized('Version', '版本'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                context.localized(
                  'DingDong $currentAppVersion · Desktop',
                  'DingDong $currentAppVersion · 桌面版',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              const Divider(),
              _VersionRow(
                label: context.localized('Current', '当前版本'),
                value: '${status.currentVersion} (${status.currentBuild})',
              ),
              _VersionRow(
                label: context.localized('Latest', '最新版本'),
                value:
                    status.latestVersion ?? context.localized('Unknown', '未知'),
              ),
              if (status.isUpdateAvailable == true && status.notes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: status.notes
                        .map(
                          (String note) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text('• $note'),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ),
              const SizedBox(height: 8),
              if (status.isUpdateAvailable == true &&
                  viewModel.applicationUpdaterSupported &&
                  Theme.of(context).platform ==
                      TargetPlatform.macOS) ...<Widget>[
                const _MacOsUpdatePermissionNotice(),
                const SizedBox(height: 12),
              ],
              if (installStatus.isBusy) ...<Widget>[
                LinearProgressIndicator(
                  value:
                      installStatus.phase ==
                              ApplicationUpdatePhase.downloading ||
                          installStatus.phase ==
                              ApplicationUpdatePhase.extracting
                      ? installStatus.progress
                      : null,
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(_statusText(context, status, installStatus)),
                  if (status.isUpdateAvailable == true &&
                      viewModel.applicationUpdaterSupported)
                    _ReleaseActionButton(
                      buttonKey: const Key('settings-install-update'),
                      onPressed: installStatus.isBusy
                          ? null
                          : viewModel.installLatestUpdate,
                      emphasized: true,
                      icon: installStatus.isBusy
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_rounded, size: 18),
                      label: Text(
                        _updateButtonText(context, status, installStatus),
                      ),
                    ),
                  _ReleaseActionButton(
                    buttonKey: const Key('settings-check-updates'),
                    onPressed: status.isChecking || installStatus.isBusy
                        ? null
                        : viewModel.checkForUpdates,
                    icon: status.isChecking
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(context.localized('Check', '检查更新')),
                  ),
                  _ReleaseActionButton(
                    buttonKey: const Key('settings-open-website'),
                    onPressed: viewModel.openWebsite,
                    icon: const Icon(Icons.language_rounded, size: 18),
                    label: Text(context.localized('Website', '官网')),
                  ),
                  _ReleaseActionButton(
                    buttonKey: const Key('settings-open-release'),
                    onPressed: viewModel.openReleasePage,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(context.localized('Release', '发布页')),
                  ),
                  _ReleaseActionButton(
                    buttonKey: const Key('settings-report-problem'),
                    onPressed: viewModel.reportProblem,
                    icon: const Icon(Icons.bug_report_outlined, size: 18),
                    label: Text(context.localized('Report a problem', '上报问题')),
                  ),
                  _ReleaseActionButton(
                    buttonKey: const Key('settings-request-feature'),
                    onPressed: viewModel.requestFeature,
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: Text(context.localized('Request a feature', '提出需求')),
                  ),
                ],
              ),
              if (installStatus.phase == ApplicationUpdatePhase.failed &&
                  installStatus.message != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  installStatus.message!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
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

class _MacOsUpdatePermissionNotice extends StatelessWidget {
  const _MacOsUpdatePermissionNotice();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const Key('settings-macos-update-permission-notice'),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              Icons.warning_amber_rounded,
              color: colors.onTertiaryContainer,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                context.localized(
                  'After updating, you will need to grant DingDong\'s macOS permissions again in System Settings.',
                  '更新完成后，需要在 macOS“系统设置”中重新授予 DingDong 相关权限。',
                ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReleaseActionButton extends StatelessWidget {
  const _ReleaseActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.buttonKey,
    this.emphasized = false,
  });

  final Key? buttonKey;
  final VoidCallback? onPressed;
  final Widget icon;
  final Widget label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 40)),
      padding: const WidgetStatePropertyAll<EdgeInsetsGeometry>(
        EdgeInsets.symmetric(horizontal: 16),
      ),
    );
    return emphasized
        ? FilledButton.icon(
            key: buttonKey,
            onPressed: onPressed,
            style: style,
            icon: icon,
            label: label,
          )
        : OutlinedButton.icon(
            key: buttonKey,
            onPressed: onPressed,
            style: style,
            icon: icon,
            label: label,
          );
  }
}

String _statusText(
  BuildContext context,
  ReleaseStatus status,
  ApplicationUpdateStatus installStatus,
) {
  switch (installStatus.phase) {
    case ApplicationUpdatePhase.checking:
      return context.localized('Preparing update…', '正在准备更新…');
    case ApplicationUpdatePhase.downloading:
      final int? percent = installStatus.progress == null
          ? null
          : (installStatus.progress! * 100).round();
      return percent == null
          ? context.localized('Downloading update…', '正在下载更新…')
          : context.localized(
              'Downloading update… $percent%',
              '正在下载更新… $percent%',
            );
    case ApplicationUpdatePhase.extracting:
      return context.localized('Verifying update…', '正在校验更新…');
    case ApplicationUpdatePhase.installing:
      return context.localized('Installing and restarting…', '正在安装并重启…');
    case ApplicationUpdatePhase.failed:
      return context.localized('Update failed', '更新失败');
    case ApplicationUpdatePhase.current:
      return context.localized("You're up to date", '已是最新版本');
    case ApplicationUpdatePhase.idle:
    case ApplicationUpdatePhase.unsupported:
      break;
  }
  if (status.isChecking) {
    return context.localized('Checking for updates…', '正在检查更新…');
  }
  if (status.errorMessage != null) {
    return context.localized('Update check failed', '更新检查失败');
  }
  return switch (status.isUpdateAvailable) {
    true => context.localized('A new version is available', '有新版本可用'),
    false => context.localized("You're up to date", '已是最新版本'),
    null => context.localized('No update metadata yet', '尚未获取更新信息'),
  };
}

String _updateButtonText(
  BuildContext context,
  ReleaseStatus status,
  ApplicationUpdateStatus installStatus,
) {
  if (installStatus.isBusy) {
    return context.localized('Updating…', '正在更新…');
  }
  final String version = status.latestVersion ?? '';
  return context.localized('Update to $version', '更新到 $version');
}

class _VersionRow extends StatelessWidget {
  const _VersionRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
