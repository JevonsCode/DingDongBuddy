import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:dingdong/features/settings/domain/system_usage.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

/// Detailed local usage with explicit, selective data deletion.
class SystemUsageSection extends StatefulWidget {
  const SystemUsageSection({required this.viewModel, super.key});

  final SettingsViewModel viewModel;

  @override
  State<SystemUsageSection> createState() => _SystemUsageSectionState();
}

class _SystemUsageSectionState extends State<SystemUsageSection> {
  final Set<SystemDataCategory> _selected = <SystemDataCategory>{};

  @override
  void didUpdateWidget(SystemUsageSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      _selected.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (BuildContext context, Widget? child) {
        final SettingsViewModel viewModel = widget.viewModel;
        final SystemUsageSnapshot? usage = viewModel.systemUsage;
        final List<SystemDataCategory> categories = SystemDataCategory.values
            .where(
              (SystemDataCategory category) =>
                  category != SystemDataCategory.other ||
                  (usage?.bytesFor(category) ?? 0) > 0,
            )
            .toList(growable: false);
        final bool canClear =
            viewModel.canClearSystemData &&
            _selected.isNotEmpty &&
            !viewModel.isClearingSystemData;
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
                  'Current process memory and a breakdown of DingDong local data.',
                  '当前进程内存与 DingDong 本地数据分类占用。',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              const Divider(),
              _UsageRow(
                label: context.localized('Memory', '当前内存'),
                value: _formatBytes(context, usage?.residentMemoryBytes),
              ),
              _UsageRow(
                label: context.localized('Local data total', '本地数据总计'),
                value: _formatBytes(context, usage?.storageBytes),
              ),
              const SizedBox(height: 6),
              Text(
                context.localized('Data types', '数据类型'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              for (final SystemDataCategory category in categories)
                _StorageCategoryRow(
                  category: category,
                  value: _formatBytes(context, usage?.bytesFor(category)),
                  selected: _selected.contains(category),
                  canSelect:
                      category.canClear &&
                      viewModel.canClearSystemData &&
                      !viewModel.isClearingSystemData,
                  onChanged: (bool selected) {
                    setState(() {
                      if (selected) {
                        _selected.add(category);
                      } else {
                        _selected.remove(category);
                      }
                    });
                  },
                ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: DesktopActionButton(
                  key: const Key('settings-clear-usage'),
                  onPressed: canClear ? _confirmAndClear : null,
                  icon: viewModel.isClearingSystemData
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 18),
                  label: context.localized('Clear selected', '清除所选'),
                  tone: DesktopActionTone.danger,
                  filled: false,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmAndClear() async {
    final List<SystemDataCategory> selected = SystemDataCategory.values
        .where(_selected.contains)
        .toList(growable: false);
    final SystemUsageSnapshot? usage = widget.viewModel.systemUsage;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => DesktopAlertDialog(
        key: const Key('settings-clear-usage-dialog'),
        title: Text(
          dialogContext.localized('Clear selected local data?', '清除所选本地数据？'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              dialogContext.localized(
                'The following history will be permanently deleted. Current resources and configuration will be kept.',
                '以下历史数据将被永久删除；当前资源与配置会保留。',
              ),
            ),
            const SizedBox(height: 12),
            for (final SystemDataCategory category in selected)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: <Widget>[
                    const Text('•'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_categoryLabel(dialogContext, category)),
                    ),
                    Text(
                      _formatBytes(dialogContext, usage?.bytesFor(category)),
                      style: Theme.of(dialogContext).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              dialogContext.localized(
                'This action cannot be undone.',
                '此操作无法撤销。',
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
            compact: true,
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
    if (confirmed != true || !mounted) {
      return;
    }
    final bool cleared = await widget.viewModel.clearSystemData(
      selected.toSet(),
    );
    if (cleared && mounted) {
      setState(_selected.clear);
    }
  }
}

String _formatBytes(BuildContext context, int? bytes) {
  if (bytes == null) {
    return context.localized('Unavailable', '不可用');
  }
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

class _UsageRow extends StatelessWidget {
  const _UsageRow({required this.label, required this.value});

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

class _StorageCategoryRow extends StatelessWidget {
  const _StorageCategoryRow({
    required this.category,
    required this.value,
    required this.selected,
    required this.canSelect,
    required this.onChanged,
  });

  final SystemDataCategory category;
  final String value;
  final bool selected;
  final bool canSelect;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('settings-usage-${category.id}'),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          if (category.canClear)
            SizedBox(
              width: 40,
              child: Semantics(
                checked: selected,
                enabled: canSelect,
                child: GestureDetector(
                  key: Key('settings-select-${category.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: canSelect ? () => onChanged(!selected) : null,
                  child: Center(
                    child: Opacity(
                      opacity: canSelect ? 1 : 0.42,
                      child: SelectionMark(selected: selected),
                    ),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              width: 40,
              child: Tooltip(
                message: context.localized(
                  'Protected data is not cleared here',
                  '受保护数据不会在这里清除',
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _categoryLabel(context, category),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  _categoryDescription(context, category),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(value, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}

String _categoryLabel(BuildContext context, SystemDataCategory category) {
  return switch (category) {
    SystemDataCategory.clipboardHistory => context.localized(
      'Clipboard history',
      '剪贴板历史',
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
      'History database and managed images',
      '历史数据库与托管图片',
    ),
    SystemDataCategory.resourceLibrary => context.localized(
      'Prompts, Skills, MCP resources, and trigger scopes; manage in Resource Manager',
      'Prompt、Skill、MCP 资源与触发范围；请在资源管理中维护',
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
      'Current Agent access, clipboard organization, and runtime state are kept',
      '保留当前 Agent 接入、剪贴板组织方式与运行状态',
    ),
    SystemDataCategory.other => context.localized(
      'Unrecognized local files are kept',
      '保留未识别的本地文件',
    ),
  };
}
