import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/settings/domain/system_usage.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

/// Lightweight diagnostics for memory and durable local storage usage.
class SystemUsageSection extends StatelessWidget {
  const SystemUsageSection({required this.viewModel, super.key});

  final SettingsViewModel viewModel;

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
                  'Current process memory and DingDong local data.',
                  '当前进程内存与 DingDong 本地数据占用。',
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
                label: context.localized('Storage', '本地存储'),
                value: _formatBytes(context, usage?.storageBytes),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  key: const Key('settings-refresh-usage'),
                  onPressed: viewModel.refreshSystemUsage,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(context.localized('Refresh', '刷新')),
                ),
              ),
            ],
          ),
        );
      },
    );
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
