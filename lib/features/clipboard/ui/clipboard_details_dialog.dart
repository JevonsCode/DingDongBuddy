part of 'clipboard_manager_screen.dart';

// Read-only clipboard metadata and content presentation.
class _ClipboardDetailsDialog extends StatelessWidget {
  const _ClipboardDetailsDialog({
    required this.record,
    required this.categoryLabel,
    required this.onClose,
    required this.onCopy,
  });

  final ClipboardRecord record;
  final String categoryLabel;
  final VoidCallback onClose;
  final Future<void> Function() onCopy;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String title = record.title.trim().isEmpty
        ? context.l10n.untitledClipboardItem
        : record.title;
    final List<_DetailDatum> overview = <_DetailDatum>[
      _DetailDatum(label: context.l10n.category, value: categoryLabel),
      _DetailDatum(
        label: context.l10n.contentType,
        value: _clipboardKindLabel(context, record.kind),
      ),
      _DetailDatum(label: context.l10n.copyCount, value: '${record.copyCount}'),
      _DetailDatum(
        label: context.l10n.updated3,
        value: MaterialLocalizations.of(
          context,
        ).formatMediumDate(record.updatedAt.toLocal()),
      ),
    ];
    return DesktopDialogFrame(
      dialogKey: const Key('clipboard-details-dialog'),
      width: 660,
      maxHeight: (MediaQuery.sizeOf(context).height - 48).clamp(360, 700),
      density: DesktopDialogDensity.editor,
      header: DesktopDialogHeader(
        density: DesktopDialogDensity.editor,
        leading: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _clipboardKindIcon(record.kind),
            size: 17,
            color: colors.primary,
          ),
        ),
        title: Text(title),
        subtitle: Text(context.l10n.clipboardDetailsAndCompleteContent),
        onClose: onClose,
        closeTooltip: context.l10n.close,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisExtent: 52,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: overview.length,
              itemBuilder: (BuildContext context, int index) =>
                  _DetailDatumView(datum: overview[index]),
            ),
            if (record.groupNames.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              _DetailSectionLabel(label: context.l10n.groups),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: record.groupNames
                    .map((String value) => _MetaChip(label: value))
                    .toList(growable: false),
              ),
            ],
            if (record.sources.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              _DetailSectionLabel(label: context.l10n.sources),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: record.sources
                    .map((String value) => _MetaChip(label: value))
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 18),
            _DetailSectionLabel(label: context.l10n.content),
            const SizedBox(height: 8),
            Container(
              key: const Key('clipboard-details-content'),
              constraints: const BoxConstraints(minHeight: 130),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.72),
                ),
              ),
              child: SelectableText(
                record.sensitive
                    ? context.l10n.sensitiveContentHidden
                    : record.content,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  fontFamily: _clipboardKindIsCodeLike(record.kind)
                      ? 'monospace'
                      : null,
                  color: record.sensitive
                      ? colors.onSurfaceVariant
                      : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
      footer: DesktopDialogFooter(
        density: DesktopDialogDensity.editor,
        showDivider: true,
        actions: <Widget>[
          DesktopActionButton(
            onPressed: onClose,
            label: context.l10n.close,
            compact: true,
          ),
          DesktopActionButton(
            key: const Key('clipboard-details-copy'),
            onPressed: record.sensitive ? null : () => onCopy(),
            icon: const Icon(Icons.copy_rounded, size: 15),
            label: context.l10n.copyContent,
            tone: DesktopActionTone.primary,
          ),
        ],
      ),
    );
  }
}

final class _DetailDatum {
  const _DetailDatum({required this.label, required this.value});

  final String label;
  final String value;
}

class _DetailDatumView extends StatelessWidget {
  const _DetailDatumView({required this.datum});

  final _DetailDatum datum;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            datum.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            datum.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSectionLabel extends StatelessWidget {
  const _DetailSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    ),
  );
}

String _clipboardKindLabel(BuildContext context, ClipboardKind kind) =>
    switch (kind) {
      ClipboardKind.text => context.l10n.text,
      ClipboardKind.url => context.l10n.link,
      ClipboardKind.command => context.l10n.command2,
      ClipboardKind.code => context.l10n.code,
      ClipboardKind.json => 'JSON',
      ClipboardKind.path => context.l10n.path,
      ClipboardKind.email => context.l10n.email,
      ClipboardKind.file => context.l10n.file,
      ClipboardKind.image => context.l10n.image,
    };

IconData _clipboardKindIcon(ClipboardKind kind) => switch (kind) {
  ClipboardKind.image => Icons.image_outlined,
  ClipboardKind.file => Icons.description_outlined,
  ClipboardKind.command => Icons.terminal_rounded,
  ClipboardKind.url => Icons.link_rounded,
  ClipboardKind.code || ClipboardKind.json => Icons.code_rounded,
  ClipboardKind.path => Icons.folder_outlined,
  ClipboardKind.email => Icons.mail_outline_rounded,
  ClipboardKind.text => Icons.notes_rounded,
};

bool _clipboardKindIsCodeLike(ClipboardKind kind) =>
    kind == ClipboardKind.command ||
    kind == ClipboardKind.code ||
    kind == ClipboardKind.json;

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    child: Text(label, style: Theme.of(context).textTheme.labelSmall),
  );
}
