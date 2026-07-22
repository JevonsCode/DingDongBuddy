import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
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
                        context.localized('Issues', '问题'),
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
                    context.localized(
                      'Review resource sync, Agent configuration, and anything else that needs attention.',
                      '集中查看资源同步、Agent 配置及其他需要处理的问题。',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
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
              label: Text(context.localized('Check', '检测')),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(92, 36),
                visualDensity: VisualDensity.compact,
              ),
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
            TextButton.icon(
              key: Key('issue-open-resource-${issue.resourceId}'),
              onPressed: () => onOpenResource(issue.resourceId!),
              icon: const Icon(Icons.arrow_forward_rounded, size: 15),
              iconAlignment: IconAlignment.end,
              label: Text(context.localized('View resource', '查看资源')),
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
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.check_circle_outline_rounded,
                  size: 24,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.localized('No issues found', '没有发现问题'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 7),
              Text(
                context.localized(
                  'DingDong checks automatically when resources change. Use Check in the upper-right corner to run it again.',
                  '资源发生变化时 DingDong 会自动检查，也可以使用右上角的“检测”重新检查。',
                ),
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
      AppIssueKind.skillNameConflict => context.localized(
        'Skill name conflict',
        'Skill 名称冲突',
      ),
      AppIssueKind.managedSkillNameConflict => context.localized(
        'DingDong Skills use the same name',
        'DingDong Skill 名称重复',
      ),
      AppIssueKind.pluginSkillNameConflict => context.localized(
        'Agent plugin provides the same Skill',
        'Agent 插件提供了同名 Skill',
      ),
      AppIssueKind.skillPackageMissing => context.localized(
        'Skill package is missing',
        'Skill 包缺失',
      ),
      AppIssueKind.invalidSkill => context.localized(
        'Skill configuration is invalid',
        'Skill 配置无效',
      ),
      AppIssueKind.invalidProjectPath => context.localized(
        'Project Skill path is invalid',
        '项目 Skill 路径无效',
      ),
      AppIssueKind.invalidMcp => context.localized(
        'MCP configuration is invalid',
        'MCP 配置无效',
      ),
      AppIssueKind.invalidAgentConfig => context.localized(
        'Agent configuration file is invalid',
        'Agent 配置文件无效',
      ),
      AppIssueKind.syncFailed => context.localized(
        'Agent resource sync failed',
        'Agent 资源同步失败',
      ),
    };

String _localizedIssueDetail(
  BuildContext context,
  AppIssue issue,
) => switch (issue.kind) {
  AppIssueKind.skillNameConflict => context.localized(
    'An existing user-managed Skill was preserved. DingDong did not overwrite it.',
    '已保留用户原有 Skill，DingDong 没有覆盖任何文件。',
  ),
  AppIssueKind.managedSkillNameConflict => context.localized(
    'Two DingDong resources resolve to the same Skill destination. Rename or disable one of them.',
    '两个 DingDong 资源指向同一 Skill 位置，请改名或停用其中一个。',
  ),
  AppIssueKind.pluginSkillNameConflict => context.localized(
    'An enabled Agent plugin provides a Skill with the same name. Both remain available; review which one should be used.',
    '已启用的 Agent 插件提供了同名 Skill。两者仍可使用，请确认应该保留或调用哪一个。',
  ),
  AppIssueKind.skillPackageMissing => context.localized(
    'The complete Skill package could not be found. Reinstall or update its source.',
    '找不到完整 Skill 包，请重新安装或更新来源。',
  ),
  AppIssueKind.invalidSkill => context.localized(
    'The SKILL.md metadata could not be parsed. Review the resource before enabling it.',
    '无法解析 SKILL.md 元数据，请检查资源内容后再启用。',
  ),
  AppIssueKind.invalidProjectPath => context.localized(
    'The scoped project directory no longer exists or is not an absolute path.',
    '限定的项目目录不存在，或不是有效的绝对路径。',
  ),
  AppIssueKind.invalidMcp => context.localized(
    'This MCP resource cannot be written to Agent configuration until its format is corrected.',
    '修正格式前，该 MCP 资源无法写入 Agent 配置。',
  ),
  AppIssueKind.invalidAgentConfig => context.localized(
    'DingDong preserved the existing Agent file because it could not be parsed safely.',
    'DingDong 无法安全解析该文件，因此保留了原有 Agent 配置。',
  ),
  AppIssueKind.syncFailed => issue.detail,
};
