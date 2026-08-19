import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:flutter/material.dart';

/// Full-size issue workspace hosted by Resource Manager.
final class IssueCenterScreen extends StatelessWidget {
  const IssueCenterScreen({
    required this.controller,
    required this.onOpenResource,
    super.key,
  });

  final IssueCenterController controller;
  final ValueChanged<String> onOpenResource;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      key: const Key('issue-center-screen'),
      color: colors.surface,
      child: AnimatedBuilder(
        animation: controller,
        builder: (BuildContext context, _) {
          final List<AppIssue> issues = controller.issues;
          return Column(
            children: <Widget>[
              _IssueHeader(controller: controller, count: issues.length),
              Divider(height: 1, color: colors.outlineVariant),
              Expanded(
                child: issues.isEmpty
                    ? _EmptyIssueState(controller: controller)
                    : _IssueList(
                        issues: issues,
                        onOpenResource: onOpenResource,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _IssueHeader extends StatelessWidget {
  const _IssueHeader({required this.controller, required this.count});

  final IssueCenterController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return SizedBox(
      height: 86,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text(
                        context.l10n.issues,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (count > 0) ...<Widget>[
                        const SizedBox(width: 9),
                        _IssueCount(count: count),
                      ],
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    context
                        .l10n
                        .reviewResourceSyncAgentConfigurationAndAnythingElseThat_a562ea61,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            DesktopActionButton(
              key: const Key('issue-center-check'),
              onPressed: controller.isChecking
                  ? null
                  : () => unawaited(controller.refresh()),
              icon: controller.isChecking
                  ? const SizedBox.square(
                      dimension: 14,
                      child: CircularProgressIndicator(strokeWidth: 1.6),
                    )
                  : const Icon(Icons.refresh_rounded, size: 17),
              label: context.l10n.check3,
              tone: DesktopActionTone.neutral,
            ),
          ],
        ),
      ),
    );
  }
}

final class _IssueCount extends StatelessWidget {
  const _IssueCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('issue-center-count'),
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFBE9E7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Color(0xFFB93A32),
          fontSize: 11,
          height: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

final class _IssueList extends StatelessWidget {
  const _IssueList({required this.issues, required this.onOpenResource});

  final List<AppIssue> issues;
  final ValueChanged<String> onOpenResource;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border.all(color: colors.outlineVariant),
          borderRadius: BorderRadius.circular(9),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ListView.separated(
            key: const Key('issue-center-list'),
            itemCount: issues.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, indent: 66, color: colors.outlineVariant),
            itemBuilder: (BuildContext context, int index) =>
                _IssueRow(issue: issues[index], onOpenResource: onOpenResource),
          ),
        ),
      ),
    );
  }
}

final class _IssueRow extends StatelessWidget {
  const _IssueRow({required this.issue, required this.onOpenResource});

  final AppIssue issue;
  final ValueChanged<String> onOpenResource;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool warning = issue.severity == AppIssueSeverity.warning;
    final Color issueBackground = warning
        ? const Color(0xFFFFF4DE)
        : const Color(0xFFFBE9E7);
    final Color issueForeground = warning
        ? const Color(0xFF9A6700)
        : const Color(0xFFB93A32);
    return Padding(
      key: Key('issue-row-${issue.id}'),
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: issueBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              warning
                  ? Icons.warning_amber_rounded
                  : Icons.error_outline_rounded,
              size: 18,
              color: issueForeground,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 7,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      _localizedIssueTitle(context, issue),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (issue.clientName != null)
                      _MetadataLabel(text: issue.clientName!),
                    if (issue.resourceTitle != null)
                      _MetadataLabel(text: issue.resourceTitle!),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  _localizedIssueDetail(context, issue),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
                if (issue.targetPath != null) ...<Widget>[
                  const SizedBox(height: 9),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      issue.targetPath!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (issue.resourceId != null) ...<Widget>[
            const SizedBox(width: 18),
            DesktopActionButton(
              key: Key('issue-open-resource-${issue.resourceId}'),
              onPressed: () => onOpenResource(issue.resourceId!),
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              label: context.l10n.viewResource,
              tone: DesktopActionTone.soft,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

final class _MetadataLabel extends StatelessWidget {
  const _MetadataLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

final class _EmptyIssueState extends StatelessWidget {
  const _EmptyIssueState({required this.controller});

  final IssueCenterController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Image.asset(
                'Assets/DingDongIP/rest.png',
                key: const Key('issue-center-empty-mascot'),
                width: 82,
                height: 82,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.noIssuesFound,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Text(
                context
                    .l10n
                    .dingdongChecksAutomaticallyWhenResourcesChangeUseCheckIn_ab07f57c,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _localizedIssueTitle(BuildContext context, AppIssue issue) =>
    switch (issue.kind) {
      AppIssueKind.skillNameConflict => context.l10n.skillNameConflict,
      AppIssueKind.managedSkillNameConflict =>
        context.l10n.dingdongSkillsUseTheSameName,
      AppIssueKind.pluginSkillNameConflict =>
        context.l10n.agentPluginProvidesTheSameSkill,
      AppIssueKind.skillPackageMissing => context.l10n.skillPackageIsMissing,
      AppIssueKind.invalidSkill => context.l10n.skillConfigurationIsInvalid,
      AppIssueKind.invalidProjectPath => context.l10n.projectSkillPathIsInvalid,
      AppIssueKind.invalidMcp => context.l10n.mcpConfigurationIsInvalid,
      AppIssueKind.invalidAgentConfig =>
        context.l10n.agentConfigurationFileIsInvalid,
      AppIssueKind.syncFailed => context.l10n.agentResourceSyncFailed,
    };

String _localizedIssueDetail(
  BuildContext context,
  AppIssue issue,
) => switch (issue.kind) {
  AppIssueKind.skillNameConflict =>
    context.l10n.anExistingUserManagedSkillWasPreservedDingDongDidNot_0f7d7c2a,
  AppIssueKind.managedSkillNameConflict =>
    context.l10n.twoDingDongResourcesResolveToTheSameSkillDestination_aac6ae3f,
  AppIssueKind.pluginSkillNameConflict =>
    context.l10n.anEnabledAgentPluginProvidesASkillWithTheSameNameBoth_c5e2f5ee,
  AppIssueKind.skillPackageMissing =>
    context
        .l10n
        .theCompleteSkillPackageCouldNotBeFoundReinstallOrUpdate_2a4648b6,
  AppIssueKind.invalidSkill =>
    context.l10n.theSKILLMdMetadataCouldNotBeParsedReviewTheResource_d8ef0c36,
  AppIssueKind.invalidProjectPath =>
    context
        .l10n
        .theScopedProjectDirectoryNoLongerExistsOrIsNotAnAbsolute_78de1cff,
  AppIssueKind.invalidMcp =>
    context
        .l10n
        .thisMCPResourceCannotBeWrittenToAgentConfigurationUntil_ad7aa3e0,
  AppIssueKind.invalidAgentConfig =>
    context
        .l10n
        .dingdongPreservedTheExistingAgentFileBecauseItCouldNotBe_6c5484e5,
  AppIssueKind.syncFailed => issue.detail,
};
