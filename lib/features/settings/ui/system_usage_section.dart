import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
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
                context.l10n.usage3,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                context
                    .l10n
                    .seeWhatDingDongStoresLocallyAndCleanOnlyTheHistoryYou_a955b365,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _UsageSummary(usage: usage),
              const SizedBox(height: 20),
              _SectionTitle(
                title: context.l10n.clipboardHistory2,
                description: context
                    .l10n
                    .imagesTextAndFilesAreIndependentCleaningThemNeverRemoves_cb27e3f9,
              ),
              const SizedBox(height: 9),
              for (final SystemDataCategory category in _clipboardCategories)
                _StorageCategoryRow(
                  category: category,
                  usage: usage,
                  enabled:
                      viewModel.canClearSystemData &&
                      !viewModel.isClearingSystemData,
                  onOpen: viewModel.canOpenSystemDataLocation
                      ? () => unawaited(
                          viewModel.openSystemDataLocation(category),
                        )
                      : null,
                  onClear: () => _confirmAndClear(context, category),
                ),
              const SizedBox(height: 18),
              _SectionTitle(
                title: context.l10n.protectedData,
                description: context
                    .l10n
                    .visibleForReferenceOnlyTheseItemsCannotBeClearedHere,
              ),
              const SizedBox(height: 9),
              for (final SystemDataCategory category in _protectedCategories)
                _StorageCategoryRow(category: category, usage: usage),
              const SizedBox(height: 18),
              _SectionTitle(title: context.l10n.maintenance),
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
          dialogContext.l10n.clearCategory(
            _categoryLabel(dialogContext, category),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              isClipboardHistory
                  ? dialogContext.l10n
                        .thisRemovesOnlyThisPartOfClipboardHistoryCategory(
                          _formatBytes(
                            dialogContext,
                            usage?.bytesFor(category),
                          ),
                        )
                  : dialogContext.l10n
                        .thisRemovesCategoryHistoryCategory2CurrentResourcesAnd_a27899ae(
                          _categoryLabel(dialogContext, category),
                          _formatBytes(
                            dialogContext,
                            usage?.bytesFor(category),
                          ),
                        ),
            ),
            if (isClipboardHistory) ...<Widget>[
              const SizedBox(height: 10),
              Text(_clearBoundaryDescription(dialogContext, category)),
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
                      dialogContext
                          .l10n
                          .permanentArchivesAndTheirImageFilesAreProtectedAndWill_889010d8,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              dialogContext.l10n.deletedHistoryCannotBeRestored,
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
            label: dialogContext.l10n.cancel,
          ),
          DesktopActionButton(
            key: const Key('settings-clear-usage-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            label: dialogContext.l10n.clear,
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
              label: context.l10n.localData,
              value: _formatBytes(context, usage?.storageBytes),
            ),
          ),
          Container(width: 1, height: 32, color: colors.outlineVariant),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _UsageMetric(
                label: context.l10n.currentMemory,
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
    this.onOpen,
    this.onClear,
  });

  final SystemDataCategory category;
  final SystemUsageSnapshot? usage;
  final bool enabled;
  final VoidCallback? onOpen;
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
          if (onOpen != null) ...<Widget>[
            DesktopIconButton(
              key: Key('settings-open-${category.id}-folder'),
              tooltip: category == SystemDataCategory.clipboardImages
                  ? context.l10n.openDingDongImageCache
                  : context.l10n.openDingDongDataFolder,
              semanticLabel: context.l10n.openCategoryLocation(
                _categoryLabel(context, category),
              ),
              onPressed: onOpen,
              size: 28,
              iconSize: 16,
              icon: const Icon(Icons.folder_open_rounded),
            ),
            const SizedBox(width: 4),
          ],
          if (onClear != null)
            DesktopActionButton(
              key: Key('settings-clear-${category.id}'),
              onPressed: enabled ? onClear : null,
              label: context.l10n.clean,
              compact: true,
              tone: DesktopActionTone.soft,
            )
          else
            Tooltip(
              message: context.l10n.protectedDataIsNotClearedHere,
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
  if (bytes == null) return context.l10n.unavailable;
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
  return context.l10n.countItemsDescription(count, description);
}

String _categoryLabel(BuildContext context, SystemDataCategory category) {
  return switch (category) {
    SystemDataCategory.clipboardHistory => context.l10n.clipboardDatabase,
    SystemDataCategory.clipboardImages => context.l10n.imageCache,
    SystemDataCategory.clipboardText => context.l10n.textHistory,
    SystemDataCategory.clipboardFiles => context.l10n.fileHistory,
    SystemDataCategory.clipboardArchive => context.l10n.permanentArchives,
    SystemDataCategory.resourceLibrary => context.l10n.resourceLibrary2,
    SystemDataCategory.agentActivity => context.l10n.agentActivity,
    SystemDataCategory.adapterHistory => context.l10n.adapterVersionHistory,
    SystemDataCategory.configuration => context.l10n.applicationConfiguration,
    SystemDataCategory.other => context.l10n.otherLocalFiles,
  };
}

String _categoryDescription(BuildContext context, SystemDataCategory category) {
  return switch (category) {
    SystemDataCategory.clipboardHistory => context.l10n.sharedDatabaseFiles,
    SystemDataCategory.clipboardImages =>
      context.l10n.dingdongOwnedImageCopiesAndRecords,
    SystemDataCategory.clipboardText =>
      context.l10n.textLinksCodeCommandsAndRichText,
    SystemDataCategory.clipboardFiles =>
      context.l10n.copiedFileReferencesOriginalFilesAreNeverDeleted,
    SystemDataCategory.clipboardArchive =>
      context.l10n.independentCopiesProtectedFromHistoryCleanup,
    SystemDataCategory.resourceLibrary =>
      context.l10n.promptsSkillsMCPResourcesAndTriggerScopes,
    SystemDataCategory.agentActivity =>
      context.l10n.completionHistoryAndRecentCounts,
    SystemDataCategory.adapterHistory =>
      context.l10n.savedYAMLRevisionsCurrentAdaptersStayIntact,
    SystemDataCategory.configuration =>
      context.l10n.currentAgentAccessClipboardRulesAndRuntimeState,
    SystemDataCategory.other => context.l10n.unrecognizedLocalFilesAreKept,
  };
}

String _clearBoundaryDescription(
  BuildContext context,
  SystemDataCategory category,
) {
  return switch (category) {
    SystemDataCategory.clipboardImages =>
      context.l10n.onlyImageCopiesInsideDingDongSCacheAreRemovedSource_28dfcaa2,
    SystemDataCategory.clipboardFiles =>
      context
          .l10n
          .onlyDingDongSLocalFileReferencesAreRemovedOriginalFiles_aea4cfa6,
    SystemDataCategory.clipboardText =>
      context.l10n.onlyTextRecordsStoredByDingDongAreRemoved,
    _ => '',
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
