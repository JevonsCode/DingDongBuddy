import 'package:dingdong/app/app_localizations.dart';
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
              if (status.notes.isNotEmpty)
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Text(_statusText(context, status)),
                  OutlinedButton.icon(
                    key: const Key('settings-check-updates'),
                    onPressed: status.isChecking
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
                  FilledButton.tonalIcon(
                    onPressed: viewModel.openWebsite,
                    icon: const Icon(Icons.language_rounded, size: 18),
                    label: Text(context.localized('Website', '官网')),
                  ),
                  OutlinedButton.icon(
                    onPressed: viewModel.openReleasePage,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(context.localized('Release', '发布页')),
                  ),
                  OutlinedButton.icon(
                    key: const Key('settings-report-problem'),
                    onPressed: viewModel.reportProblem,
                    icon: const Icon(Icons.bug_report_outlined, size: 18),
                    label: Text(
                      context.localized('Report a problem', '上报问题'),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const Key('settings-request-feature'),
                    onPressed: viewModel.requestFeature,
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: Text(
                      context.localized('Request a feature', '提出需求'),
                    ),
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

String _statusText(BuildContext context, ReleaseStatus status) {
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
