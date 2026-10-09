import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:flutter/material.dart';

/// Distinguishes a new library from a search without matching results.
class ResourceEmptyState extends StatelessWidget {
  const ResourceEmptyState({
    required this.libraryIsEmpty,
    this.onCreate,
    this.onImportJson,
    this.onImportLink,
    super.key,
  });

  final bool libraryIsEmpty;
  final VoidCallback? onCreate;
  final VoidCallback? onImportJson;
  final VoidCallback? onImportLink;

  @override
  Widget build(BuildContext context) {
    final Color foreground = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                libraryIsEmpty
                    ? Icons.library_add_outlined
                    : Icons.search_off_rounded,
                size: 24,
                color: foreground,
              ),
              const SizedBox(height: 10),
              Text(
                libraryIsEmpty
                    ? context.l10n.gettingStartedResourceLibraryEmpty
                    : context.l10n.noMatchingResources,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (libraryIsEmpty) ...<Widget>[
                const SizedBox(height: 7),
                Text(
                  context.l10n.gettingStartedResourceLibraryDescription,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: foreground,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    if (onCreate != null)
                      DesktopActionButton(
                        key: const Key('library-empty-create'),
                        onPressed: onCreate,
                        label: context.l10n.createResource,
                        icon: Icons.add_rounded,
                        tone: DesktopActionTone.primary,
                        compact: true,
                      ),
                    if (onImportJson != null)
                      DesktopActionButton(
                        key: const Key('library-empty-import-json'),
                        onPressed: onImportJson,
                        label: context.l10n.importJSONFile,
                        compact: true,
                      ),
                    if (onImportLink != null)
                      DesktopActionButton(
                        key: const Key('library-empty-import-link'),
                        onPressed: onImportLink,
                        label: context.l10n.importFromLink,
                        compact: true,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
