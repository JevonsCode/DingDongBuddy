part of 'clipboard_screen.dart';

class _ClipboardPreview extends StatelessWidget {
  const _ClipboardPreview({
    required this.record,
    required this.onRestore,
    this.onTogglePinned,
    required this.onOpen,
    required this.onAction,
  });

  final ClipboardRecord? record;
  final Future<void> Function() onRestore;
  final VoidCallback? onTogglePinned;
  final Future<void> Function(ClipboardRecord record)? onOpen;
  final ValueChanged<_ClipboardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final ClipboardRecord? value = record;
    if (value == null) {
      return Center(child: Text(context.l10n.selectAnItemToPreview));
    }
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(value.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              DesktopActionButton(
                onPressed: () => unawaited(onRestore()),
                icon: Icons.keyboard_return_rounded,
                label: context.l10n.restore,
                tone: DesktopActionTone.primary,
              ),
              if (onOpen != null && canOpenClipboardContent(value)) ...<Widget>[
                const SizedBox(width: 8),
                DesktopActionButton(
                  key: const Key('clipboard-preview-open'),
                  onPressed: () => unawaited(onOpen!(value)),
                  icon: Icons.open_in_new_rounded,
                  label: context.l10n.open,
                  tone: DesktopActionTone.soft,
                ),
              ],
              if (onTogglePinned != null) ...<Widget>[
                const SizedBox(width: 8),
                DesktopActionButton(
                  onPressed: onTogglePinned,
                  icon: value.pinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  label: value.pinned ? context.l10n.unpin : context.l10n.pin,
                ),
              ],
              const SizedBox(width: 8),
              DesktopMenuButton<_ClipboardAction>(
                key: const Key('clipboard-more-actions'),
                tooltip: context.l10n.moreActions,
                onSelected: onAction,
                entries: <DesktopMenuEntry<_ClipboardAction>>[
                  DesktopMenuItem<_ClipboardAction>(
                    value: _ClipboardAction.edit,
                    label: context.l10n.editAndOrganize,
                    symbol: 'edit',
                  ),
                  DesktopMenuItem<_ClipboardAction>(
                    value: _ClipboardAction.archiveTo,
                    label: context.l10n.archiveTo,
                    symbol: 'archive_to',
                  ),
                  const DesktopMenuDivider<_ClipboardAction>(),
                  DesktopMenuItem<_ClipboardAction>(
                    value: _ClipboardAction.promotePrompt,
                    label: context.l10n.saveAsPrompt,
                    symbol: 'prompt',
                  ),
                  const DesktopMenuDivider<_ClipboardAction>(),
                  DesktopMenuItem<_ClipboardAction>(
                    value: _ClipboardAction.delete,
                    label: context.l10n.delete,
                    symbol: 'delete',
                    destructive: true,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SelectableText(
              value.sensitive
                  ? context.l10n.sensitiveContentHidden
                  : value.content,
            ),
          ),
        ],
      ),
    );
  }
}
