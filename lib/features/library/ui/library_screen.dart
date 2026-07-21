import 'dart:io';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:dingdong/features/library/domain/library_importer.dart';
import 'package:dingdong/features/library/domain/library_transfer_gateway.dart';
import 'package:dingdong/features/library/ui/library_import_dialog.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/resource_editor.dart';
import 'package:dingdong/features/library/ui/resource_filter_bar.dart';
import 'package:dingdong/features/library/ui/resource_list.dart';
import 'package:flutter/material.dart';

/// Adaptive list/details resource management workspace.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    required this.viewModel,
    this.compact = false,
    this.transferGateway,
    this.contextMenuGateway,
    this.onOpenExternalLink,
    super.key,
  });

  final LibraryViewModel viewModel;
  final bool compact;
  final LibraryTransferGateway? transferGateway;
  final DesktopContextMenuGateway? contextMenuGateway;
  final Future<void> Function(Uri uri)? onOpenExternalLink;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (BuildContext context, Widget? child) {
        final bool showingDetail =
            viewModel.selectedResource != null || viewModel.isCreating;
        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: showingDetail
              ? Column(
                  children: <Widget>[
                    _LibraryDetailHeader(
                      resource: viewModel.selectedResource,
                      onBack: viewModel.closeEditor,
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildEditor(context)),
                  ],
                )
              : Column(
                  children: <Widget>[
                    ResourceFilterBar(
                      viewModel: viewModel,
                      onImport: transferGateway == null
                          ? null
                          : () => _import(context),
                      onImportJson: transferGateway == null
                          ? null
                          : () => _importJson(context),
                      onExport: transferGateway == null
                          ? null
                          : () => _export(context),
                      onDeleteSelection: () => _confirmDeleteSelection(context),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ResourceList(
                        viewModel: viewModel,
                        compact: compact,
                        contextMenuGateway: contextMenuGateway,
                        onDeleteResource: (Resource resource) =>
                            _confirmDeleteResource(context, resource),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _confirmDeleteResource(
    BuildContext context,
    Resource resource,
  ) async {
    final bool confirmed = await _showDeleteConfirmation(
      context,
      title: context.localized('Delete this resource?', '删除此资源？'),
      message: context.localized(
        'This removes “${resource.title}” from the local resource library.',
        '这会从本地资源库中移除“${resource.title}”。',
      ),
    );
    if (confirmed) {
      await viewModel.deleteResources(<String>{resource.id});
    }
  }

  Future<void> _confirmDeleteSelection(BuildContext context) async {
    final Set<String> ids = viewModel.allResources
        .where((Resource resource) => viewModel.isSelected(resource.id))
        .map((Resource resource) => resource.id)
        .toSet();
    if (ids.isEmpty) {
      return;
    }
    final bool confirmed = await _showDeleteConfirmation(
      context,
      title: context.localized('Delete selected resources?', '删除所选资源？'),
      message: context.localized(
        'This removes ${ids.length} resources from the local library.',
        '这会从本地资源库中移除 ${ids.length} 项资源。',
      ),
    );
    if (confirmed) {
      await viewModel.deleteResources(ids);
    }
  }

  Future<bool> _showDeleteConfirmation(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => DesktopAlertDialog(
            title: Text(title),
            content: Text(message),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.localized('Cancel', '取消')),
              ),
              FilledButton(
                style: DesktopDialogStyle.destructiveButtonStyle(context),
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.localized('Delete', '删除')),
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildEditor(BuildContext context) {
    return ResourceEditor(
      resource: viewModel.selectedResource,
      isCreating: viewModel.isCreating,
      initialType: viewModel.creatingType,
      triggerGroups: viewModel.triggerGroups,
      onCreate: viewModel.create,
      onCreateTriggerGroup: viewModel.createTriggerGroup,
      onUpdateTriggerGroup: viewModel.updateTriggerGroup,
      onDeleteTriggerGroup: viewModel.deleteTriggerGroup,
      onDelete: () => _confirmDelete(context),
      onSave: viewModel.save,
      onSyncUpdate: (String updateUrl) => _syncUpdate(context, updateUrl),
      onResolveSkillSource: viewModel.installSkillPackage,
      onOpenExternalLink: onOpenExternalLink,
      onImportSkill: transferGateway == null
          ? null
          : () => _import(context, fixedType: ResourceType.skill),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return DesktopAlertDialog(
          title: Text(context.localized('Delete this resource?', '删除此资源？')),
          content: Text(
            context.localized(
              'This removes the resource from the shared agent library.',
              '此操作会将资源从共享 Agent 资源库中移除。',
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.localized('Cancel', '取消')),
            ),
            FilledButton(
              style: DesktopDialogStyle.destructiveButtonStyle(context),
              onPressed: () => Navigator.pop(context, true),
              child: Text(context.localized('Delete', '删除')),
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      await viewModel.deleteSelected();
    }
  }

  Future<void> _import(BuildContext context, {ResourceType? fixedType}) async {
    final LibraryTransferGateway? gateway = transferGateway;
    if (gateway == null) {
      return;
    }
    final LibraryImportOptions? options = fixedType == null
        ? await showDialog<LibraryImportOptions>(
            context: context,
            builder: (BuildContext context) => const LibraryImportDialog(),
          )
        : LibraryImportOptions(type: fixedType);
    if (options == null) {
      return;
    }
    final String? directory = await gateway.chooseImportDirectory();
    if (directory == null) {
      return;
    }
    try {
      final LibraryImportResult result = await viewModel.importDirectory(
        type: options.type,
        path: directory,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                'Imported ${result.imported.length}; skipped ${result.skippedCount}.',
                '已导入 ${result.imported.length} 项，跳过 ${result.skippedCount} 项。',
              ),
            ),
          ),
        );
      }
    } on FileSystemException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                'The selected folder could not be read.',
                '无法读取所选文件夹。',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _export(BuildContext context) async {
    try {
      final String? path = await transferGateway?.saveExport(
        contents: viewModel.exportJson(),
      );
      if (path != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                'Exported resource library to $path',
                '资源库已导出到 $path',
              ),
            ),
          ),
        );
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                'A selected local-path resource could not be shared: $error',
                '所选资源包含无法安全分享的本地路径：$error',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _importJson(BuildContext context) async {
    final String? contents = await transferGateway?.chooseImportJson();
    if (contents == null) {
      return;
    }
    try {
      final LibraryBundleImportResult result = await viewModel.importBundleJson(
        contents,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                'Imported ${result.imported.length}; skipped ${result.skippedCount}.',
                '已导入 ${result.imported.length} 项，跳过 ${result.skippedCount} 项。',
              ),
            ),
          ),
        );
      }
    } on FormatException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                'The selected JSON is not a DingDongBuddy resource bundle.',
                '所选 JSON 不是有效的 DingDongBuddy 资源包。',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _syncUpdate(BuildContext context, String updateUrl) async {
    try {
      final updated = await viewModel.syncSelectedFromUpdateLink(
        overrideUrl: updateUrl,
      );
      if (context.mounted && updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                'Updated ${updated.title} from its source.',
                '已从来源更新 ${updated.title}。',
              ),
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                'Could not fetch this update: $error',
                '无法获取此更新：$error',
              ),
            ),
          ),
        );
      }
    }
  }
}

class _LibraryDetailHeader extends StatelessWidget {
  const _LibraryDetailHeader({required this.resource, required this.onBack});

  final Resource? resource;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String title =
        resource?.title ?? context.localized('New configuration', '新建配置');
    final TextStyle breadcrumbStyle = theme.textTheme.bodyMedium!.copyWith(
      height: 1,
      color: colors.onSurfaceVariant,
    );
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: <Widget>[
            IconButton(
              key: const Key('library-editor-back'),
              tooltip: context.localized('Back to resources', '返回资源列表'),
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              style: IconButton.styleFrom(
                fixedSize: const Size.square(32),
                minimumSize: const Size.square(32),
                maximumSize: const Size.square(32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: colors.onSurfaceVariant,
                backgroundColor: colors.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              key: const Key('library-detail-breadcrumb'),
              child: Row(
                children: <Widget>[
                  Text(
                    context.localized('Resources', '资源'),
                    key: const Key('library-breadcrumb-root'),
                    style: breadcrumbStyle,
                  ),
                  _BreadcrumbDivider(color: colors.onSurfaceVariant),
                  Flexible(
                    child: Text(
                      title,
                      key: const Key('library-breadcrumb-current'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: breadcrumbStyle.copyWith(
                        color: colors.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbDivider extends StatelessWidget {
  const _BreadcrumbDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 6),
    child: Icon(Icons.chevron_right_rounded, size: 18, color: color),
  );
}
