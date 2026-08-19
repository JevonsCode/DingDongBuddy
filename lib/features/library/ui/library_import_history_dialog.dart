import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/features/library/domain/library_import_history.dart';
import 'package:flutter/material.dart';

/// Read-only history of resource-library imports.
final class LibraryImportHistoryDialog extends StatelessWidget {
  const LibraryImportHistoryDialog({required this.entries, super.key});

  final List<LibraryImportHistoryEntry> entries;

  @override
  Widget build(BuildContext context) {
    return DesktopAlertDialog(
      maxWidth: 660,
      scrollable: true,
      title: Text(context.l10n.importHistory),
      content: SizedBox(
        width: 600,
        height: entries.isEmpty ? 88 : 390,
        child: entries.isEmpty
            ? Center(child: Text(context.l10n.noResourceImportsYet))
            : ListView.separated(
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (BuildContext context, int index) {
                  return _HistoryRow(
                    key: Key('library-import-history-row-$index'),
                    entry: entries[index],
                  );
                },
              ),
      ),
      actions: <Widget>[
        DesktopActionButton(
          onPressed: () => Navigator.pop(context),
          label: context.l10n.close,
          tone: DesktopActionTone.primary,
        ),
      ],
    );
  }
}

final class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.entry, super.key});

  final LibraryImportHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isLink = entry.kind == LibraryImportSourceKind.link;
    final String status = context.l10n.importedImportedCountSkippedSkippedCount(
      entry.importedCount,
      entry.skippedCount,
    );
    final String online = entry.onlineTitles.isEmpty
        ? ''
        : context.l10n.onlineOnlineTitles(entry.onlineTitles.join('、'));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isLink ? Icons.link_rounded : Icons.description_outlined,
            size: 18,
            color: colors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.source,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(entry.createdAt)} · $status',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                if (online.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    online,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.primary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final DateTime local = value.toLocal();
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} '
      '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
}
