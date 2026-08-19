import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:flutter/material.dart';

/// Asks the user to inspect every online source before committing an import.
Future<bool> showLibraryImportReviewDialog(
  BuildContext context,
  LibraryBundleImportResult result, {
  Future<void> Function(Uri uri)? onOpenExternalLink,
}) async {
  if (result.onlineResources.isEmpty) {
    return true;
  }
  return await showDialog<bool>(
        context: context,
        builder: (BuildContext context) => LibraryImportReviewDialog(
          result: result,
          onOpenExternalLink: onOpenExternalLink,
        ),
      ) ??
      false;
}

final class LibraryImportReviewDialog extends StatelessWidget {
  const LibraryImportReviewDialog({
    required this.result,
    this.onOpenExternalLink,
    super.key,
  });

  final LibraryBundleImportResult result;
  final Future<void> Function(Uri uri)? onOpenExternalLink;

  @override
  Widget build(BuildContext context) {
    final List<Resource> resources = _uniqueOnlineResources(
      result.onlineResources,
    );
    return DesktopAlertDialog(
      maxWidth: 680,
      scrollable: true,
      title: Text(context.l10n.reviewOnlineResources),
      content: SizedBox(
        width: 620,
        height: 390,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              context
                  .l10n
                  .theseResourcesWillBeLoadedFromTheInternetCheckTheSource_08e83c52,
            ),
            if (result.skippedCount > 0) ...<Widget>[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  context.l10n
                      .skippedcountResourcesAlreadyExistAndWillBeSkippedOr_6aa841ce(
                        result.skippedCount,
                      ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: resources.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  final Resource resource = resources[index];
                  return _OnlineResourceRow(
                    resource: resource,
                    onOpenExternalLink: onOpenExternalLink,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        DesktopActionButton(
          onPressed: () => Navigator.pop(context, false),
          label: context.l10n.cancel,
          compact: true,
        ),
        DesktopActionButton(
          key: const Key('library-import-review-confirm'),
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.download_outlined, size: 17),
          label: context.l10n.importLengthResources(result.imported.length),
          tone: DesktopActionTone.primary,
        ),
      ],
    );
  }
}

final class _OnlineResourceRow extends StatelessWidget {
  const _OnlineResourceRow({
    required this.resource,
    required this.onOpenExternalLink,
  });

  final Resource resource;
  final Future<void> Function(Uri uri)? onOpenExternalLink;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String url = resource.updateUrl ?? '';
    final Uri? uri = Uri.tryParse(url);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.cloud_outlined, size: 18, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  resource.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  url,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          DesktopIconButton(
            key: Key('library-import-review-open-${resource.id}'),
            tooltip: context.l10n.openSource,
            onPressed: onOpenExternalLink == null || uri == null
                ? null
                : () => onOpenExternalLink!(uri),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            size: 30,
            iconSize: 16,
          ),
        ],
      ),
    );
  }
}

List<Resource> _uniqueOnlineResources(Iterable<Resource> resources) {
  final Map<String, Resource> unique = <String, Resource>{};
  for (final Resource resource in resources) {
    final String url = resource.updateUrl ?? '';
    unique.putIfAbsent('${resource.title}\u0000$url', () => resource);
  }
  return unique.values.toList(growable: false);
}
