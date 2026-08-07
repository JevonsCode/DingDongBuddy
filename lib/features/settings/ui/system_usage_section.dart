import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/features/settings/domain/system_usage.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

/// Detailed local usage with explicit, isolated history cleanup actions.
class SystemUsageSection extends StatelessWidget {
  const SystemUsageSection({required this.viewModel, super.key});

  final SettingsViewModel viewModel;

  static const List<SystemDataCategory> _clipboardCategories =
      <SystemDataCategory>[
        SystemDataCategory.clipboardImages,
        SystemDataCategory.clipboardText,
        SystemDataCategory.clipboardFiles,
      ];
  static const List<SystemDataCategory> _protectedCategories =
      <SystemDataCategory>[
        SystemDataCategory.clipboardArchive,
        SystemDataCategory.resourceLibrary,
        SystemDataCategory.configuration,
      ];
  static const List<SystemDataCategory> _maintenanceCategories =
      <SystemDataCategory>[
        SystemDataCategory.agentActivity,
        SystemDataCategory.adapterHistory,
        SystemDataCategory.other,
      ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: viewModel,
      builder: (BuildContext context, Widget? child) {
        final SystemUsageSnapshot? usage = viewModel.systemUsage;
        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.localized('Usage', '占用'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                context.localized(
                  'See what DingDong stores locally and clean only the history you choose.',
                  '查看 DingDong 的本地占用，只清理你明确选择的历史数据。',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _UsageSummary(usage: usage),
              const SizedBox(height: 20),
              _SectionTitle(
                title: context.localized('Clipboard history', '剪贴板历史'),
                description: context.localized(
                  'Images, text, and files are independent. Cleaning them never removes permanent archives.',
                  '图片、文字与文件彼此独立；这里的清理永远不会删除永久归档。',
                ),
              ),
              const SizedBox(height: 9),
              for (final SystemDataCategory category in _clipboardCategories)
                _StorageCategoryRow(
                  category: category,
                  usage: usage,
                  enabled:
                      viewModel.canClearSystemData &&
                      !viewModel.isClearingSystemData,
                  onClear: () => _confirmAndClear(context, category),
                ),
              const SizedBox(height: 18),
              _SectionTitle(
                title: context.localized('Protected data', '受保护数据'),
                description: context.localized(
                  'Visible for reference only. These items cannot be cleared here.',
                  '仅供查看占用；这些数据不允许在这里清除。',
                ),
              ),
              const SizedBox(height: 9),
              for (final SystemDataCategory category in _protectedCategories)
                _StorageCategoryRow(category: category, usage: usage),
              const SizedBox(height: 18),
              _SectionTitle(title: context.localized('Maintenance', '维护数据')),
              const SizedBox(height: 9),
              for (final SystemDataCategory category in _maintenanceCategories)
                if (category != SystemDataCategory.other ||
                    (usage?.bytesFor(category) ?? 0) > 0)
                  _StorageCategoryRow(
                    category: category,
                    usage: usage,
                    enabled:
                        category.canClear &&
                        viewModel.canClearSystemData &&
                        !viewModel.isClearingSystemData,
                    onClear: category.canClear
                        ? () => _confirmAndClear(context, category)
                        : null,
                  ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAndClear(
    BuildContext context,
    SystemDataCategory category,
  ) async {
    final SystemUsageSnapshot? usage = viewModel.systemUsage;
    final bool isClipboardHistory = _clipboardCategories.contains(category);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => DesktopAlertDialog(
        key: const Key('settings-clear-usage-dialog'),
        title: Text(
          dialogContext.localized(
            'Clear ${_categoryLabel(dialogContext, category)}?',
            '清除${_categoryLabel(dialogContext, category)}？',
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              isClipboardHistory
                  ? dialogContext.localized(
                      'This removes only this part of clipboard history (${_formatBytes(dialogContext, usage?.bytesFor(category))}).',
                      '只会删除这部分剪贴板历史（${_formatBytes(dialogContext, usage?.bytesFor(category))}）。',
                    )
                  : dialogContext.localized(
                      'This removes ${_categoryLabel(dialogContext, category)} history (${_formatBytes(dialogContext, usage?.bytesFor(category))}). Current resources and configuration stay intact.',
                      '将删除${_categoryLabel(dialogContext, category)}历史（${_formatBytes(dialogContext, usage?.bytesFor(category))}），当前资源与配置会保留。',
                    ),
            ),
            if (isClipboardHistory) ...<Widget>[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: Theme.of(dialogContext).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dialogContext.localized(
                        'Permanent archives and their image files are protected and will stay intact.',
                        '永久归档及归档引用的图片文件受保护，会完整保留。',
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              dialogContext.localized(
                'Deleted history cannot be restored.',
                '被删除的历史记录无法恢复。',
              ),
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                color: Theme.of(dialogContext).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          DesktopActionButton(
            key: const Key('settings-clear-usage-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            label: dialogContext.localized('Cancel', '取消'),
          ),
          DesktopActionButton(
            key: const Key('settings-clear-usage-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            label: dialogContext.localized('Clear', '清除'),
            tone: DesktopActionTone.danger,
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await viewModel.clearSystemData(<SystemDataCategory>{category});
    }
  }
}

class _UsageSummary extends StatelessWidget {
  const _UsageSummary({required this.usage});

  final SystemUsageSnapshot? usage;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _UsageMetric(
              label: context.localized('Local data', '本地数据'),
              value: _formatBytes(context, usage?.storageBytes),
            ),
          ),
          Container(width: 1, height: 32, color: colors.outlineVariant),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _UsageMetric(
                label: context.localized('Current memory', '当前内存'),
                value: _formatBytes(context, usage?.residentMemoryBytes),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UsageMetric extends StatelessWidget {
  const _UsageMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.description});

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (description != null) ...<Widget>[
          const SizedBox(height: 3),
          Text(description!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _StorageCategoryRow extends StatelessWidget {
  const _StorageCategoryRow({
    required this.category,
    required this.usage,
    this.enabled = false,
    this.onClear,
  });

  final SystemDataCategory category;
  final SystemUsageSnapshot? usage;
  final bool enabled;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final int? count = usage?.itemsFor(category);
    return Container(
      key: Key('settings-usage-${category.id}'),
      margin: const EdgeInsets.only(bottom: 7),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: _categoryBackground(colors, category),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colors.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _categoryIcon(category),
              size: 18,
              color: _categoryForeground(colors, category),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _categoryLabel(context, category),
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  _descriptionWithCount(context, category, count),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _formatBytes(context, usage?.bytesFor(category)),
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 10),
          if (onClear != null)
            DesktopActionButton(
              key: Key('settings-clear-${category.id}'),
              onPressed: enabled ? onClear : null,
              label: context.localized('Clean', '清理'),
              compact: true,
              tone: DesktopActionTone.soft,
            )
          else
            Tooltip(
              message: context.localized(
                'Protected data is not cleared here',
                '受保护数据不会在这里清除',
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9),
                child: Icon(
                  Icons.lock_rounded,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String _formatBytes(BuildContext context, int? bytes) {
  if (bytes == null) return context.localized('Unavailable', '不可用');
  const List<String> units = <String>['B', 'KB', 'MB', 'GB', 'TB'];
  double value = bytes.toDouble();
  int unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit += 1;
  }
  final String digits = unit == 0 || value >= 10
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$digits ${units[unit]}';
}

String _descriptionWithCount(
  BuildContext context,
  SystemDataCategory category,
  int? count,
) {
  final String description = _categoryDescription(context, category);
  if (count == null ||
      !<SystemDataCategory>{
        SystemDataCategory.clipboardImages,
        SystemDataCategory.clipboardText,
        SystemDataCategory.clipboardFiles,
        SystemDataCategory.clipboardArchive,
      }.contains(category)) {
    return description;
  }
  return context.localized(
    '$count items · $description',
    '$count 项 · $description',
  );
}

String _categoryLabel(BuildContext context, SystemDataCategory category) {
  return switch (category) {
    SystemDataCategory.clipboardHistory => context.localized(
      'Clipboard database',
      '剪贴板数据库',
    ),
    SystemDataCategory.clipboardImages => context.localized(
      'Image cache',
      '图片缓存',
    ),
    SystemDataCategory.clipboardText => context.localized(
      'Text history',
      '文字记录',
    ),
    SystemDataCategory.clipboardFiles => context.localized(
      'File history',
      '文件记录',
    ),
    SystemDataCategory.clipboardArchive => context.localized(
      'Permanent archives',
      '永久归档',
    ),
    SystemDataCategory.resourceLibrary => context.localized(
      'Resource library',
      '资源库',
    ),
    SystemDataCategory.agentActivity => context.localized(
      'Agent activity',
      'Agent 活动',
    ),
    SystemDataCategory.adapterHistory => context.localized(
      'Adapter version history',
      'Adapter 版本历史',
    ),
    SystemDataCategory.configuration => context.localized(
      'Application configuration',
      '应用配置',
    ),
    SystemDataCategory.other => context.localized(
      'Other local files',
      '其他本地文件',
    ),
  };
}

String _categoryDescription(BuildContext context, SystemDataCategory category) {
  return switch (category) {
    SystemDataCategory.clipboardHistory => context.localized(
      'Shared database files',
      '共享数据库文件',
    ),
    SystemDataCategory.clipboardImages => context.localized(
      'Managed images and image records',
      '托管图片与图片记录',
    ),
    SystemDataCategory.clipboardText => context.localized(
      'Text, links, code, commands, and rich text',
      '文本、链接、代码、命令与富文本',
    ),
    SystemDataCategory.clipboardFiles => context.localized(
      'Copied file references; original files are never deleted',
      '复制过的文件引用；不会删除原文件',
    ),
    SystemDataCategory.clipboardArchive => context.localized(
      'Independent copies protected from history cleanup',
      '独立副本，不受历史清理影响',
    ),
    SystemDataCategory.resourceLibrary => context.localized(
      'Prompts, Skills, MCP resources, and trigger scopes',
      'Prompt、Skill、MCP 资源与触发范围',
    ),
    SystemDataCategory.agentActivity => context.localized(
      'Completion history and recent counts',
      '任务完成记录与近期计数',
    ),
    SystemDataCategory.adapterHistory => context.localized(
      'Saved YAML revisions; current Adapters stay intact',
      '已保存的 YAML 修订；当前 Adapter 不受影响',
    ),
    SystemDataCategory.configuration => context.localized(
      'Current Agent access, clipboard rules, and runtime state',
      '当前 Agent 接入、剪贴板规则与运行状态',
    ),
    SystemDataCategory.other => context.localized(
      'Unrecognized local files are kept',
      '保留未识别的本地文件',
    ),
  };
}

IconData _categoryIcon(SystemDataCategory category) => switch (category) {
  SystemDataCategory.clipboardHistory => Icons.storage_rounded,
  SystemDataCategory.clipboardImages => Icons.photo_library_rounded,
  SystemDataCategory.clipboardText => Icons.subject_rounded,
  SystemDataCategory.clipboardFiles => Icons.insert_drive_file_rounded,
  SystemDataCategory.clipboardArchive => Icons.inventory_2_rounded,
  SystemDataCategory.resourceLibrary => Icons.layers_rounded,
  SystemDataCategory.agentActivity => Icons.auto_awesome_rounded,
  SystemDataCategory.adapterHistory => Icons.history_rounded,
  SystemDataCategory.configuration => Icons.tune_rounded,
  SystemDataCategory.other => Icons.more_horiz_rounded,
};

Color _categoryBackground(ColorScheme colors, SystemDataCategory category) {
  return switch (category) {
    SystemDataCategory.clipboardImages => colors.tertiaryContainer.withValues(
      alpha: 0.36,
    ),
    SystemDataCategory.clipboardArchive => colors.primaryContainer.withValues(
      alpha: 0.34,
    ),
    _ => colors.surfaceContainerLow,
  };
}

Color _categoryForeground(ColorScheme colors, SystemDataCategory category) {
  return switch (category) {
    SystemDataCategory.clipboardImages => colors.onTertiaryContainer,
    SystemDataCategory.clipboardArchive => colors.onPrimaryContainer,
    _ => colors.onSurfaceVariant,
  };
}
