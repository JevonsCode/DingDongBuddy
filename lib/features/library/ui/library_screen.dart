import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:dingdong/features/library/domain/library_import_history.dart';
import 'package:dingdong/features/library/domain/library_transfer_gateway.dart';
import 'package:dingdong/features/library/ui/library_import_history_dialog.dart';
import 'package:dingdong/features/library/ui/library_import_review_dialog.dart';
import 'package:dingdong/features/library/ui/library_link_import_dialog.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/resource_editor.dart';
import 'package:dingdong/features/library/ui/resource_filter_bar.dart';
import 'package:dingdong/features/library/ui/resource_list.dart';
import 'package:flutter/material.dart';

/// Adaptive list/details resource management workspace.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({
    required this.viewModel,
    this.transferGateway,
    this.contextMenuGateway,
    this.onOpenExternalLink,
    super.key,
  });

  final LibraryViewModel viewModel;
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
                      onImportJson: transferGateway == null
                          ? null
                          : () => _importJson(context),
                      onImportLink: viewModel.updateFetcher == null
                          ? null
                          : () => _importLink(context),
                      onImportHistory: () => _showImportHistory(context),
                      onExport: transferGateway == null
                          ? null
                          : () => _export(context),
                      onDeleteSelection: () => _confirmDeleteSelection(context),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ResourceList(
                        viewModel: viewModel,
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
              DesktopActionButton(
                onPressed: () => Navigator.pop(context, false),
                label: context.localized('Cancel', '取消'),
                compact: true,
              ),
              DesktopActionButton(
                onPressed: () => Navigator.pop(context, true),
                label: context.localized('Delete', '删除'),
                tone: DesktopActionTone.danger,
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
      initialTitle: viewModel.creatingTitle,
      initialContent: viewModel.creatingContent,
      triggerGroups: viewModel.triggerGroups,
      onCreate: viewModel.create,
      onCreateWithAgentSessionName: viewModel.create,
      onCreateTriggerGroup: viewModel.createTriggerGroup,
      onUpdateTriggerGroup: viewModel.updateTriggerGroup,
      onDeleteTriggerGroup: viewModel.deleteTriggerGroup,
      onDelete: () => _confirmDelete(context),
      onSave: viewModel.save,
      onSyncUpdate: (String updateUrl) => _syncUpdate(context, updateUrl),
      onResolveSkillSource: viewModel.installSkillPackage,
      onOpenExternalLink: onOpenExternalLink,
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
            DesktopActionButton(
              onPressed: () => Navigator.pop(context, false),
              label: context.localized('Cancel', '取消'),
              compact: true,
            ),
            DesktopActionButton(
              onPressed: () => Navigator.pop(context, true),
              label: context.localized('Delete', '删除'),
              tone: DesktopActionTone.danger,
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      await viewModel.deleteSelected();
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
    if (!context.mounted) {
      return;
    }
    await _prepareAndCommitImport(
      context,
      prepare: () => viewModel.prepareBundleJson(contents, resolveOnline: true),
      source: 'JSON file',
      kind: LibraryImportSourceKind.file,
    );
  }

  Future<void> _importLink(BuildContext context) async {
    final LibraryLinkImportOptions? options =
        await showDialog<LibraryLinkImportOptions>(
          context: context,
          builder: (BuildContext context) => const LibraryLinkImportDialog(),
        );
    if (options == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _prepareAndCommitImport(
      context,
      prepare: () => viewModel.prepareBundleJsonFromUrl(options.url),
      source: options.url,
      kind: LibraryImportSourceKind.link,
    );
  }

  Future<void> _prepareAndCommitImport(
    BuildContext context, {
    required Future<LibraryBundleImportResult> Function() prepare,
    required String source,
    required LibraryImportSourceKind kind,
  }) async {
    try {
      final LibraryBundleImportResult result = await prepare();
      if (!context.mounted) {
        return;
      }
      final bool confirmed = await showLibraryImportReviewDialog(
        context,
        result,
        onOpenExternalLink: onOpenExternalLink,
      );
      if (!confirmed || !context.mounted) {
        return;
      }
      await viewModel.commitBundleImport(result, source: source, kind: kind);
      if (context.mounted) {
        _showImportFeedback(context, result);
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.localized(
                'Could not import this resource bundle: $error',
                '无法导入这个资源包：$error',
              ),
            ),
          ),
        );
      }
    }
  }

  void _showImportFeedback(
    BuildContext context,
    LibraryBundleImportResult result,
  ) {
    final List<String> details = <String>[];
    if (result.duplicateIds.isNotEmpty) {
      details.add(
        context.localized(
          '${result.duplicateIds.length} duplicates',
          '${result.duplicateIds.length} 项重复',
        ),
      );
    }
    if (result.conflictIds.isNotEmpty) {
      details.add(
        context.localized(
          '${result.conflictIds.length} ID conflicts',
          '${result.conflictIds.length} 项 ID 冲突',
        ),
      );
    }
    if (result.onlineResources.isNotEmpty) {
      details.add(
        context.localized(
          '${result.onlineResources.length} online sources checked',
          '已检查 ${result.onlineResources.length} 个在线来源',
        ),
      );
    }
    final String suffix = details.isEmpty ? '' : ' · ${details.join(' · ')}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.localized(
            'Imported ${result.imported.length}; skipped ${result.skippedCount}.$suffix',
            '已导入 ${result.imported.length} 项；跳过 ${result.skippedCount} 项。$suffix',
          ),
        ),
      ),
    );
  }

  Future<void> _showImportHistory(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          LibraryImportHistoryDialog(entries: viewModel.importHistory),
    );
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
            DesktopIconButton(
              key: const Key('library-editor-back'),
              tooltip: context.localized('Back to resources', '返回资源列表'),
              onPressed: onBack,
              size: 32,
              foregroundColor: colors.onSurfaceVariant,
              backgroundColor: colors.surfaceContainerLow,
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
