part of 'clipboard_manager_screen.dart';

// Bulk actions and bounded list-row rendering, selection, and reorder handles.
class _BulkToolbar extends StatelessWidget {
  const _BulkToolbar({
    required this.count,
    required this.onAssignGroup,
    required this.onDelete,
  });

  final int count;
  final VoidCallback onAssignGroup;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('clipboard-bulk-toolbar'),
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border.symmetric(
          horizontal: BorderSide(color: colors.outlineVariant),
        ),
      ),
      child: Row(
        children: <Widget>[
          Text(context.l10n.countSelected(count)),
          const SizedBox(width: 12),
          DesktopActionButton(
            key: const Key('clipboard-bulk-archive-to'),
            onPressed: onAssignGroup,
            label: context.l10n.archiveTo,
            tone: DesktopActionTone.soft,
          ),
          const Spacer(),
          Container(height: 24, width: 1, color: colors.outlineVariant),
          const SizedBox(width: 12),
          DesktopActionButton(
            key: const Key('clipboard-bulk-delete'),
            onPressed: onDelete,
            label: context.l10n.delete,
            tone: DesktopActionTone.danger,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _ManagerRow extends StatefulWidget {
  const _ManagerRow({
    required this.record,
    required this.categoryLabel,
    required this.selected,
    required this.onChanged,
    required this.onOpenDetails,
    required this.onSecondaryTapUp,
    required this.showReorderHandle,
    required this.showPinnedIndicator,
    required this.reorderIndex,
    super.key,
  });

  final ClipboardRecord record;
  final String categoryLabel;
  final bool selected;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenDetails;
  final GestureTapUpCallback onSecondaryTapUp;
  final bool showReorderHandle;
  final bool showPinnedIndicator;
  final int reorderIndex;

  @override
  State<_ManagerRow> createState() => _ManagerRowState();
}

class _ManagerRowState extends State<_ManagerRow> {
  final FocusNode _focusNode = FocusNode();
  bool _hovered = false;
  bool _focused = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: <Widget>[
          Material(
            color: widget.selected
                ? colors.primary.withValues(alpha: 0.075)
                : _hovered || _focused
                ? colors.onSurface.withValues(alpha: 0.035)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hovered = true),
              onExit: (_) => setState(() => _hovered = false),
              child: FocusableActionDetector(
                key: Key('clipboard-manager-open-${widget.record.id}'),
                focusNode: _focusNode,
                mouseCursor: SystemMouseCursors.click,
                shortcuts: const <ShortcutActivator, Intent>{
                  SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                  SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
                },
                actions: <Type, Action<Intent>>{
                  ActivateIntent: CallbackAction<ActivateIntent>(
                    onInvoke: (_) {
                      widget.onOpenDetails();
                      return null;
                    },
                  ),
                },
                onShowFocusHighlight: (bool value) {
                  if (_focused != value) setState(() => _focused = value);
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onOpenDetails,
                  onSecondaryTapUp: widget.onSecondaryTapUp,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: _focused
                            ? colors.primary.withValues(alpha: 0.58)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        const SizedBox(width: 5),
                        Semantics(
                          selected: widget.selected,
                          button: true,
                          label: context.l10n.selectItem,
                          child: DesktopIconButton(
                            key: Key(
                              'clipboard-manager-select-${widget.record.id}',
                            ),
                            tooltip: context.l10n.selectItem,
                            semanticLabel: context.l10n.selectItem,
                            selected: widget.selected,
                            size: 32,
                            onPressed: () => widget.onChanged(!widget.selected),
                            icon: SelectionMark(selected: widget.selected),
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (widget.showReorderHandle)
                          ReorderableDragStartListener(
                            index: widget.reorderIndex,
                            child: Tooltip(
                              message: context.l10n.reorder,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  size: 17,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                widget.record.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.record.content.replaceAll('\n', ' '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        if (widget.record.groupNames.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              widget.record.groupNames.join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          color: colors.surfaceContainerLow,
                          child: Text(
                            widget.categoryLabel,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.record.kind.name,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(width: 8),
                        if (widget.record.copyCount > 1) ...<Widget>[
                          ClipboardCopyCount(
                            recordId: widget.record.id,
                            count: widget.record.copyCount,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          clipboardTimestampLabel(
                            context,
                            widget.record.updatedAt,
                          ),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                        const SizedBox(width: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.showPinnedIndicator && widget.record.pinned)
            Positioned(
              top: -7,
              right: -2,
              child: ClipboardPinnedIndicator(
                recordId: widget.record.id,
                keyPrefix: 'clipboard-manager-pinned-indicator',
                color: colors.primary,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }
}
