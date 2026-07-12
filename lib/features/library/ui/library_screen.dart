import 'dart:io';

import 'package:dingdong/app/app_localizations.dart';
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
    super.key,
  });

  final LibraryViewModel viewModel;
  final bool compact;
  final LibraryTransferGateway? transferGateway;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (BuildContext context, Widget? child) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool narrow = constraints.maxWidth < 900;
              if (narrow &&
                  (viewModel.selectedResource != null ||
                      viewModel.isCreating)) {
                return Column(
                  children: <Widget>[
                    ListTile(
                      key: const Key('library-editor-back'),
                      dense: true,
                      leading: const Icon(Icons.arrow_back_rounded),
                      title: Text(
                        context.localized('Back to resources', '返回资源列表'),
                      ),
                      onTap: viewModel.closeEditor,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ResourceEditor(
                        resource: viewModel.selectedResource,
                        isCreating: viewModel.isCreating,
                        onCreate: viewModel.create,
                        onDelete: () => _confirmDelete(context),
                        onSave: viewModel.save,
                        onSyncUpdate: (String updateUrl) =>
                            _syncUpdate(context, updateUrl),
                      ),
                    ),
                  ],
                );
              }
              return Column(
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
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: narrow
                        ? ResourceList(viewModel: viewModel, compact: compact)
                        : Row(
                            children: <Widget>[
                              SizedBox(
                                width: constraints.maxWidth * 0.46,
                                child: ResourceList(
                                  viewModel: viewModel,
                                  compact: compact,
                                ),
                              ),
                              const VerticalDivider(width: 1),
                              Expanded(
                                child: ResourceEditor(
                                  resource: viewModel.selectedResource,
                                  isCreating: viewModel.isCreating,
                                  onCreate: viewModel.create,
                                  onDelete: () => _confirmDelete(context),
                                  onSave: viewModel.save,
                                  onSyncUpdate: (String updateUrl) =>
                                      _syncUpdate(context, updateUrl),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
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
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
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

  Future<void> _import(BuildContext context) async {
    final LibraryTransferGateway? gateway = transferGateway;
    if (gateway == null) {
      return;
    }
    final LibraryImportOptions? options =
        await showDialog<LibraryImportOptions>(
          context: context,
          builder: (BuildContext context) => const LibraryImportDialog(),
        );
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
        group: options.group,
        tags: options.tags.isEmpty ? null : options.tags,
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
