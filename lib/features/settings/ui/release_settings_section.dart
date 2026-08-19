import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
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
        final List<String> releaseNotes = status.notesFor(
          context.l10n.localeName,
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.version,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.dingdongCurrentAppVersionDesktop(
                  currentAppVersion,
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              const Divider(),
              _VersionRow(
                label: context.l10n.current,
                value: '${status.currentVersion} (${status.currentBuild})',
              ),
              _VersionRow(
                label: context.l10n.latest,
                value: status.latestVersion ?? context.l10n.unknown,
              ),
              const SizedBox(height: 8),
              const Divider(),
              CompactSwitchListTile(
                key: const Key('settings-anonymous-telemetry'),
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.anonymousInstallAndUpdateStatistics),
                subtitle: Text(
                  context
                      .l10n
                      .onByDefaultSendsOneEventAfterInstallationOrAVersion_153fb4ab,
                ),
                value: viewModel.settings.lifecycleTelemetryEnabled,
                onChanged: viewModel.setLifecycleTelemetryEnabled,
              ),
              if (status.isUpdateAvailable == true && releaseNotes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: releaseNotes
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
                    label: Text(context.l10n.check2),
                  ),
                  _ReleaseActionButton(
                    buttonKey: const Key('settings-open-website'),
                    onPressed: viewModel.openWebsite,
                    icon: const Icon(Icons.language_rounded, size: 18),
                    label: Text(context.l10n.website),
                  ),
                  _ReleaseActionButton(
                    buttonKey: const Key('settings-open-release'),
                    onPressed: viewModel.openReleasePage,
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(context.l10n.release),
                  ),
                  _ReleaseActionButton(
                    buttonKey: const Key('settings-report-problem'),
                    onPressed: viewModel.reportProblem,
                    icon: const Icon(Icons.bug_report_outlined, size: 18),
                    label: Text(context.l10n.reportAProblem),
                  ),
                  _ReleaseActionButton(
                    buttonKey: const Key('settings-request-feature'),
                    onPressed: viewModel.requestFeature,
                    icon: const Icon(Icons.lightbulb_outline, size: 18),
                    label: Text(context.l10n.requestAFeature),
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
                context
                    .l10n
                    .afterUpdatingYouWillNeedToGrantDingDongSMacOSPermissions_20660ff5,
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
    return DesktopActionButton(
      key: buttonKey,
      onPressed: onPressed,
      icon: icon,
      label: label,
      tone: emphasized ? DesktopActionTone.primary : DesktopActionTone.neutral,
      height: 40,
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
      return context.l10n.preparingUpdate;
    case ApplicationUpdatePhase.downloading:
      final int? percent = installStatus.progress == null
          ? null
          : (installStatus.progress! * 100).round();
      return percent == null
          ? context.l10n.downloadingUpdate
          : context.l10n.downloadingUpdatePercent(percent);
    case ApplicationUpdatePhase.extracting:
      return context.l10n.verifyingUpdate;
    case ApplicationUpdatePhase.installing:
      return context.l10n.installingAndRestarting;
    case ApplicationUpdatePhase.failed:
      return context.l10n.updateFailed;
    case ApplicationUpdatePhase.current:
      return context.l10n.youReUpToDate;
    case ApplicationUpdatePhase.idle:
    case ApplicationUpdatePhase.unsupported:
      break;
  }
  if (status.isChecking) {
    return context.l10n.checkingForUpdates;
  }
  if (status.errorMessage != null) {
    return context.l10n.updateCheckFailed;
  }
  return switch (status.isUpdateAvailable) {
    true => context.l10n.aNewVersionIsAvailable,
    false => context.l10n.youReUpToDate,
    null => context.l10n.noUpdateMetadataYet,
  };
}

String _updateButtonText(
  BuildContext context,
  ReleaseStatus status,
  ApplicationUpdateStatus installStatus,
) {
  if (installStatus.isBusy) {
    return context.l10n.updating2;
  }
  final String version = status.latestVersion ?? '';
  return context.l10n.updateToVersion(version);
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
