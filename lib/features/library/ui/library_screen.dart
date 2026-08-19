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
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    required this.viewModel,
    this.transferGateway,
    this.contextMenuGateway,
    this.onOpenExternalLink,
    this.skillAgents = ResourceEditor.defaultSkillDeliveryAgents,
    super.key,
  });

  final LibraryViewModel viewModel;
  final LibraryTransferGateway? transferGateway;
  final DesktopContextMenuGateway? contextMenuGateway;
  final Future<void> Function(Uri uri)? onOpenExternalLink;
  final List<SkillDeliveryAgentOption> skillAgents;

  @override
  State<LibraryScreen> createState() => LibraryScreenState();
}

class LibraryScreenState extends State<LibraryScreen> {
  bool _editorDirty = false;

  bool get hasUnsavedChanges => _editorDirty;

  Future<bool> confirmDiscardChanges() async {
    if (!_editorDirty) {
      return true;
    }
    final bool discard =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => DesktopAlertDialog(
            key: const Key('resource-unsaved-changes-dialog'),
            title: Text(context.l10n.discardUnsavedChanges),
            content: Text(
              context
                  .l10n
                  .yourEditsHaveNotBeenSavedLeavingThisPageWillDiscardThem,
            ),
            actions: <Widget>[
              DesktopActionButton(
                key: const Key('resource-keep-editing'),
                onPressed: () => Navigator.pop(context, false),
                label: context.l10n.keepEditing,
                compact: true,
              ),
              DesktopActionButton(
                key: const Key('resource-discard-changes'),
                onPressed: () => Navigator.pop(context, true),
                label: context.l10n.discardChanges,
                tone: DesktopActionTone.danger,
              ),
            ],
          ),
        ) ??
        false;
    if (discard && mounted) {
      setState(() => _editorDirty = false);
    }
    return discard;
  }

  Future<void> _closeEditor() async {
    if (await confirmDiscardChanges()) {
      widget.viewModel.closeEditor();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (BuildContext context, Widget? child) {
        final bool showingDetail =
            widget.viewModel.selectedResource != null ||
            widget.viewModel.isCreating;
        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: showingDetail
              ? Column(
                  key: const Key('library-detail-page'),
                  children: <Widget>[
                    _LibraryDetailHeader(
                      resource: widget.viewModel.selectedResource,
                      onBack: _closeEditor,
                    ),
                    const Divider(height: 1),
                    Expanded(child: _buildEditor(context)),
                  ],
                )
              : Column(
                  children: <Widget>[
                    ResourceFilterBar(
                      viewModel: widget.viewModel,
                      onImportJson: widget.transferGateway == null
                          ? null
                          : () => _importJson(context),
                      onImportLink: widget.viewModel.updateFetcher == null
                          ? null
                          : () => _importLink(context),
                      onImportHistory: () => _showImportHistory(context),
                      onExport: widget.transferGateway == null
                          ? null
                          : () => _export(context),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: ResourceList(
                              viewModel: widget.viewModel,
                              contextMenuGateway: widget.contextMenuGateway,
                              onDeleteResource: (Resource resource) =>
                                  _confirmDeleteResource(context, resource),
                            ),
                          ),
                          if (widget.viewModel.selectionCount > 0)
                            Positioned(
                              left: 16,
                              right: 16,
                              bottom: 12,
                              child: _ResourceSelectionBar(
                                selectionCount: widget.viewModel.selectionCount,
                                onDelete: () =>
                                    _confirmDeleteSelection(context),
                                onClear: widget.viewModel.clearSelection,
                              ),
                            ),
                        ],
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
      title: context.l10n.deleteThisResource,
      message: context.l10n.thisRemovesTitleFromTheLocalResourceLibrary(
        resource.title,
      ),
    );
    if (confirmed) {
      await widget.viewModel.deleteResources(<String>{resource.id});
    }
  }

  Future<void> _confirmDeleteSelection(BuildContext context) async {
    final Set<String> ids = widget.viewModel.allResources
        .where((Resource resource) => widget.viewModel.isSelected(resource.id))
        .map((Resource resource) => resource.id)
        .toSet();
    if (ids.isEmpty) {
      return;
    }
    final bool confirmed = await _showDeleteConfirmation(
      context,
      title: context.l10n.deleteSelectedResources,
      message: context.l10n.thisRemovesLengthResourcesFromTheLocalLibrary(
        ids.length,
      ),
    );
    if (confirmed) {
      await widget.viewModel.deleteResources(ids);
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
                label: context.l10n.cancel,
                compact: true,
              ),
              DesktopActionButton(
                onPressed: () => Navigator.pop(context, true),
                label: context.l10n.delete,
                tone: DesktopActionTone.danger,
              ),
            ],
          ),
        ) ??
        false;
  }

  Widget _buildEditor(BuildContext context) {
    return ResourceEditor(
      resource: widget.viewModel.selectedResource,
      isCreating: widget.viewModel.isCreating,
      initialType: widget.viewModel.creatingType,
      initialTitle: widget.viewModel.creatingTitle,
      initialContent: widget.viewModel.creatingContent,
      triggerGroups: widget.viewModel.triggerGroups,
      onCreate: widget.viewModel.create,
      onCreateWithAgentSessionName: widget.viewModel.create,
      onCreateTriggerGroup: widget.viewModel.createTriggerGroup,
      onUpdateTriggerGroup: widget.viewModel.updateTriggerGroup,
      onDeleteTriggerGroup: widget.viewModel.deleteTriggerGroup,
      onDelete: () => _confirmDelete(context),
      onSave: widget.viewModel.save,
      onSyncUpdate: (String updateUrl) => _syncUpdate(context, updateUrl),
      onResolveSkillSource: widget.viewModel.installSkillPackage,
      onOpenExternalLink: widget.onOpenExternalLink,
      skillAgents: widget.skillAgents,
      onDirtyChanged: (bool value) {
        if (mounted && _editorDirty != value) {
          setState(() => _editorDirty = value);
        }
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return DesktopAlertDialog(
          title: Text(context.l10n.deleteThisResource),
          content: Text(
            context.l10n.thisRemovesTheResourceFromTheSharedAgentLibrary,
          ),
          actions: <Widget>[
            DesktopActionButton(
              onPressed: () => Navigator.pop(context, false),
              label: context.l10n.cancel,
              compact: true,
            ),
            DesktopActionButton(
              onPressed: () => Navigator.pop(context, true),
              label: context.l10n.delete,
              tone: DesktopActionTone.danger,
            ),
          ],
        );
      },
    );
    if (confirmed ?? false) {
      await widget.viewModel.deleteSelected();
    }
  }

  Future<void> _export(BuildContext context) async {
    try {
      final String? path = await widget.transferGateway?.saveExport(
        contents: widget.viewModel.exportJson(),
      );
      if (path != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.exportedResourceLibraryToPath(path)),
          ),
        );
      }
    } on FormatException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.aSelectedLocalPathResourceCouldNotBeSharedError(
                error,
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _importJson(BuildContext context) async {
    final String? contents = await widget.transferGateway?.chooseImportJson();
    if (contents == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }
    await _prepareAndCommitImport(
      context,
      prepare: () =>
          widget.viewModel.prepareBundleJson(contents, resolveOnline: true),
      source: context.l10n.jsonFile,
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
      prepare: () => widget.viewModel.prepareBundleJsonFromUrl(options.url),
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
        onOpenExternalLink: widget.onOpenExternalLink,
      );
      if (!confirmed || !context.mounted) {
        return;
      }
      await widget.viewModel.commitBundleImport(
        result,
        source: source,
        kind: kind,
      );
      if (context.mounted) {
        _showImportFeedback(context, result);
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.couldNotImportThisResourceBundleError(error),
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
      details.add(context.l10n.lengthDuplicates(result.duplicateIds.length));
    }
    if (result.conflictIds.isNotEmpty) {
      details.add(context.l10n.lengthIDConflicts(result.conflictIds.length));
    }
    if (result.onlineResources.isNotEmpty) {
      details.add(
        context.l10n.lengthOnlineSourcesChecked(result.onlineResources.length),
      );
    }
    final String suffix = details.isEmpty ? '' : ' · ${details.join(' · ')}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.importedLengthSkippedSkippedCountSuffix(
            result.imported.length,
            result.skippedCount,
            suffix,
          ),
        ),
      ),
    );
  }

  Future<void> _showImportHistory(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          LibraryImportHistoryDialog(entries: widget.viewModel.importHistory),
    );
  }

  Future<void> _syncUpdate(BuildContext context, String updateUrl) async {
    try {
      final updated = await widget.viewModel.syncSelectedFromUpdateLink(
        overrideUrl: updateUrl,
      );
      if (context.mounted && updated != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.updatedTitleFromItsSource(updated.title),
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.couldNotFetchThisUpdateError(error)),
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
    final String title = resource?.title ?? context.l10n.newConfiguration;
    final TextStyle breadcrumbStyle = theme.textTheme.bodyMedium!.copyWith(
      height: 1,
      color: colors.onSurfaceVariant,
    );
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: <Widget>[
            DesktopIconButton(
              key: const Key('library-editor-back'),
              tooltip: context.l10n.backToResources,
              semanticLabel: context.l10n.backToResources,
              onPressed: onBack,
              size: 32,
              foregroundColor: colors.onSurfaceVariant,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              key: const Key('library-detail-breadcrumb'),
              child: Row(
                children: <Widget>[
                  Text(
                    context.l10n.resources,
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

class _ResourceSelectionBar extends StatelessWidget {
  const _ResourceSelectionBar({
    required this.selectionCount,
    required this.onDelete,
    required this.onClear,
  });

  final int selectionCount;
  final VoidCallback onDelete;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: context.l10n.selectioncountResourcesSelected(selectionCount),
      child: Container(
        key: const Key('resource-selection-bar'),
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: colors.outlineVariant.withValues(alpha: 0.9),
          ),
        ),
        child: Row(
          children: <Widget>[
            Text(
              context.l10n.selectioncountSelected(selectionCount),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            DesktopActionButton(
              key: const Key('resource-delete-selection'),
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 16),
              label: context.l10n.delete,
              compact: true,
              tone: DesktopActionTone.danger,
            ),
            const SizedBox(width: 6),
            DesktopActionButton(
              key: const Key('resource-clear-selection'),
              onPressed: onClear,
              icon: const Icon(Icons.close_rounded, size: 15),
              label: context.l10n.clearSelection2,
              compact: true,
              tone: DesktopActionTone.neutral,
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
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Icon(Icons.chevron_right_rounded, size: 15, color: color),
  );
}
