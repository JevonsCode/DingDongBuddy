import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:dingdong/features/library/domain/library_share_gateway.dart';
import 'package:flutter/material.dart';

Future<String?> chooseLibraryShareTarget(
  BuildContext context,
  List<LibraryShareTarget> targets,
) => showDialog<String>(
  context: context,
  builder: (context) => DesktopAlertDialog(
    title: Text(context.l10n.librarySendBundle),
    maxWidth: 430,
    scrollable: true,
    content: SizedBox(
      width: 380,
      child: targets.isEmpty
          ? Text(context.l10n.libraryNoShareTargets)
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: targets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final target = targets[index];
                  return DesktopActionButton(
                    key: Key('library-share-target-${target.id}'),
                    onPressed: () => Navigator.pop(context, target.id),
                    height: 40,
                    child: Row(
                      children: [
                        const Icon(Icons.computer_outlined, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            target.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
                  );
                },
              ),
            ),
    ),
    actions: [
      DesktopActionButton(
        onPressed: () => Navigator.pop(context),
        label: context.l10n.cancel,
        compact: true,
      ),
    ],
  ),
);

Future<({ReceivedLibraryBundle bundle, bool remove})?> chooseReceivedBundle(
  BuildContext context,
  List<ReceivedLibraryBundle> bundles,
) => showDialog<({ReceivedLibraryBundle bundle, bool remove})>(
  context: context,
  builder: (context) => DesktopAlertDialog(
    title: Text(context.l10n.libraryReceivedBundles),
    maxWidth: 580,
    scrollable: true,
    content: SizedBox(
      width: 520,
      child: bundles.isEmpty
          ? Text(context.l10n.libraryNoReceivedBundles)
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 350),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: bundles.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final bundle = bundles[index];
                  final format = MaterialLocalizations.of(context);
                  final timestamp = bundle.receivedAt.toLocal();
                  final date = format.formatShortDate(timestamp);
                  final time = format.formatTimeOfDay(
                    TimeOfDay.fromDateTime(timestamp),
                  );
                  final theme = Theme.of(context);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 19),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bundle.sender,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '$date · $time',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        DesktopActionButton(
                          key: Key('library-open-bundle-${bundle.id}'),
                          onPressed: () => Navigator.pop(context, (
                            bundle: bundle,
                            remove: false,
                          )),
                          label: context.l10n.libraryViewBundle,
                          compact: true,
                        ),
                        const SizedBox(width: 4),
                        DesktopIconButton(
                          onPressed: () => Navigator.pop(context, (
                            bundle: bundle,
                            remove: true,
                          )),
                          tooltip: context.l10n.libraryInboxRemove,
                          icon: const Icon(Icons.close_rounded, size: 16),
                          size: 30,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
    ),
    actions: [
      DesktopActionButton(
        onPressed: () => Navigator.pop(context),
        label: context.l10n.close,
        compact: true,
      ),
    ],
  ),
);

class LibraryInstallSelectionDialog extends StatefulWidget {
  const LibraryInstallSelectionDialog({
    required this.resources,
    required this.preselect,
    super.key,
  });

  final List<Resource> resources;
  final bool preselect;

  @override
  State<LibraryInstallSelectionDialog> createState() =>
      _LibraryInstallSelectionDialogState();
}

class _LibraryInstallSelectionDialogState
    extends State<LibraryInstallSelectionDialog> {
  late final Set<String> _all = widget.resources.map((item) => item.id).toSet();
  late final Set<String> _selected = widget.preselect ? {..._all} : {};

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasOnline = widget.resources.any((item) => item.updateUrl != null);
    return DesktopAlertDialog(
      title: Text(context.l10n.librarySelectImport),
      maxWidth: 620,
      scrollable: true,
      content: SizedBox(
        width: 560,
        child: widget.resources.isEmpty
            ? Text(context.l10n.libraryEmptyBundle)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasOnline) ...[
                    Text(context.l10n.libraryInstallOnlineSources),
                    const SizedBox(height: 8),
                  ],
                  DesktopActionButton(
                    onPressed: () => setState(() {
                      if (_selected.length == _all.length) {
                        _selected.clear();
                      } else {
                        _selected.addAll(_all);
                      }
                    }),
                    label: _selected.length == _all.length
                        ? context.l10n.clearSelection2
                        : context.l10n.selectAll,
                    compact: true,
                  ),
                  const SizedBox(height: 8),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: widget.resources.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final item = widget.resources[index];
                        final selected = _selected.contains(item.id);
                        final type = switch (item.type) {
                          ResourceType.prompt => context.l10n.prompt,
                          ResourceType.skill => context.l10n.skill2,
                          ResourceType.mcp => 'MCP',
                          ResourceType.knowledge => context.l10n.knowledge,
                          ResourceType.clipboard => context.l10n.clipboard,
                        };
                        return Semantics(
                          checked: selected,
                          child: DesktopActionButton(
                            key: Key('library-install-select-${item.id}'),
                            onPressed: () => setState(() {
                              if (!_selected.remove(item.id)) {
                                _selected.add(item.id);
                              }
                            }),
                            height: item.updateUrl == null ? 38 : 56,
                            tone: selected
                                ? DesktopActionTone.soft
                                : DesktopActionTone.neutral,
                            child: Row(
                              children: [
                                SelectionMark(selected: selected, size: 16),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (item.updateUrl case final String url)
                                        Tooltip(
                                          message: url,
                                          child: Text(
                                            url,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      colors.onSurfaceVariant,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  type,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
      actions: [
        DesktopActionButton(
          onPressed: () => Navigator.pop(context),
          label: context.l10n.cancel,
          compact: true,
        ),
        DesktopActionButton(
          key: const Key('library-install-selection'),
          onPressed: _selected.isEmpty
              ? null
              : () => Navigator.pop(context, {..._selected}),
          label: context.l10n.libraryInstallSelection(_selected.length),
          icon: Icons.download_outlined,
          tone: DesktopActionTone.primary,
          compact: true,
        ),
      ],
    );
  }
}
