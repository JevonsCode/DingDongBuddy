part of 'clipboard_screen.dart';

class _ClipboardList extends StatefulWidget {
  const _ClipboardList({
    required this.viewModel,
    required this.includeShare,
    required this.showShortcutHints,
    required this.showPlainTextShortcutHints,
    required this.onShortcutStartIndexChanged,
    required this.onPreview,
    required this.onOpenContent,
    required this.onDismissPreview,
    required this.contextMenuGateway,
    required this.now,
    required this.onAction,
  });

  final ClipboardViewModel viewModel;
  final bool includeShare;
  final bool showShortcutHints;
  final bool showPlainTextShortcutHints;
  final ValueChanged<int> onShortcutStartIndexChanged;
  final Future<void> Function(ClipboardRecord record)? onPreview;
  final Future<void> Function(ClipboardRecord record)? onOpenContent;
  final Future<void> Function()? onDismissPreview;
  final DesktopContextMenuGateway? contextMenuGateway;
  final DateTime now;
  final ValueChanged<_ClipboardAction> onAction;

  @override
  State<_ClipboardList> createState() => _ClipboardListState();
}

class _ClipboardListState extends State<_ClipboardList> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;
  int _shortcutStartIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        widget.onShortcutStartIndexChanged(_shortcutStartIndex);
      }
    });
  }

  @override
  void didUpdateWidget(covariant _ClipboardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updateShortcutStartIndex();
      }
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    _updateShortcutStartIndex();
    final bool show =
        _scrollController.position.pixels >
        _scrollController.position.viewportDimension;
    if (show != _showScrollToTop && mounted) {
      setState(() => _showScrollToTop = show);
    }
  }

  void _updateShortcutStartIndex() {
    if (!_scrollController.hasClients) return;
    final List<ClipboardRecord> records = widget.viewModel.visibleRecords;
    final double itemExtent = _itemExtent(context);
    final int lastIndex = records.isEmpty ? 0 : records.length - 1;
    final int next = (_scrollController.offset / itemExtent).floor().clamp(
      0,
      lastIndex,
    );
    if (next == _shortcutStartIndex) return;
    setState(() => _shortcutStartIndex = next);
    widget.onShortcutStartIndexChanged(next);
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _openContent(ClipboardRecord record) async {
    try {
      await widget.onOpenContent?.call(record);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.thisContentIsNoLongerAvailableOrCouldNotBeOpened,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<ClipboardRecord> records = widget.viewModel.visibleRecords;
    final bool callout = MediaQuery.sizeOf(context).width < 600;
    final bool showArchiveControls = widget.viewModel.showingArchivedRecords;
    final double itemExtent = _itemExtent(context);
    return Stack(
      children: <Widget>[
        ListView.builder(
          key: const Key('clipboard-list'),
          controller: _scrollController,
          itemCount: records.length,
          padding: callout ? const EdgeInsets.only(bottom: 8) : null,
          itemExtent: itemExtent,
          itemBuilder: (BuildContext context, int index) {
            final ClipboardRecord record = records[index];
            final int shortcutIndex = index - _shortcutStartIndex + 1;
            return ClipboardListTile(
              record: record,
              showPinnedIndicator: showArchiveControls,
              selected: widget.viewModel.selectedRecord?.id == record.id,
              onSelected: () {
                widget.viewModel.select(record);
                widget.onPreview?.call(record);
              },
              onDoubleTap: () {
                widget.viewModel.select(record);
                unawaited(() async {
                  await widget.onDismissPreview?.call();
                  await widget.viewModel.restoreSelected();
                }());
              },
              onOpenContent:
                  widget.onOpenContent != null &&
                      canOpenClipboardContent(record)
                  ? () => unawaited(_openContent(record))
                  : null,
              onSecondaryTapUp: (TapUpDetails details) {
                widget.viewModel.select(record);
                unawaited(
                  widget.contextMenuGateway == null
                      ? _showClipboardContextMenu(
                          context,
                          details.globalPosition,
                          record,
                          widget.includeShare,
                          showArchiveControls,
                          widget.onAction,
                        )
                      : _showNativeClipboardContextMenu(
                          context,
                          details.globalPosition,
                          widget.contextMenuGateway!,
                          record,
                          widget.includeShare,
                          showArchiveControls,
                          widget.onAction,
                        ),
                );
              },
              callout: callout,
              shortcutIndex:
                  widget.showShortcutHints &&
                      shortcutIndex >= 1 &&
                      shortcutIndex <= 9
                  ? shortcutIndex
                  : null,
              plainTextShortcut:
                  widget.showPlainTextShortcutHints &&
                  record.canPasteAsPlainText,
              now: widget.now,
            );
          },
        ),
        if (_showScrollToTop)
          Positioned(
            right: 12,
            bottom: 12,
            child: DesktopIconButton(
              key: const Key('clipboard-scroll-to-top'),
              tooltip: context.l10n.backToTop,
              onPressed: _scrollToTop,
              icon: const Icon(Icons.arrow_upward_rounded, size: 16),
              size: 30,
              iconSize: 16,
              foregroundColor: PopupStyle.of(context).textSecondary,
              backgroundColor: PopupStyle.of(context).background,
              borderColor: PopupStyle.of(context).border,
            ),
          ),
      ],
    );
  }

  double _itemExtent(BuildContext context) {
    final bool callout = MediaQuery.sizeOf(context).width < 600;
    return callout ? 82 : 72;
  }
}

Future<void> _showNativeClipboardContextMenu(
  BuildContext context,
  Offset position,
  DesktopContextMenuGateway gateway,
  ClipboardRecord record,
  bool includeShare,
  bool includePin,
  ValueChanged<_ClipboardAction> onAction,
) async {
  final ClipboardContextAction? action = clipboardActionFromId(
    await gateway.show(
      x: position.dx,
      y: position.dy,
      isDark: Theme.of(context).brightness == Brightness.dark,
      items: clipboardContextMenuItems(
        strings: context.l10n,
        includePaste: true,
        canPasteAsPlainText: record.canPasteAsPlainText,
        includeShare: includeShare,
        includePin: includePin,
        pinned: record.pinned,
        hasTitle: record.title.trim().isNotEmpty,
      ),
    ),
  );
  if (action == null) return;
  final _ClipboardAction? mapped = _actionFromNative(action);
  if (mapped != null) onAction(mapped);
}

_ClipboardAction? _actionFromNative(ClipboardContextAction action) =>
    switch (action) {
      ClipboardContextAction.paste => _ClipboardAction.paste,
      ClipboardContextAction.pastePlainText => _ClipboardAction.pastePlainText,
      ClipboardContextAction.details => _ClipboardAction.details,
      ClipboardContextAction.copy => _ClipboardAction.copy,
      ClipboardContextAction.togglePinned => _ClipboardAction.togglePinned,
      ClipboardContextAction.addTitle => _ClipboardAction.addTitle,
      ClipboardContextAction.editText => _ClipboardAction.editText,
      ClipboardContextAction.saveAsPrompt => _ClipboardAction.promotePrompt,
      ClipboardContextAction.archiveTo => _ClipboardAction.archiveTo,
      ClipboardContextAction.share => _ClipboardAction.share,
      ClipboardContextAction.delete => _ClipboardAction.delete,
    };

Future<void> _showClipboardContextMenu(
  BuildContext context,
  Offset position,
  ClipboardRecord record,
  bool includeShare,
  bool includePin,
  ValueChanged<_ClipboardAction> onAction,
) async {
  final _ClipboardAction? action =
      await showDesktopContextMenu<_ClipboardAction>(
        context: context,
        globalPosition: position,
        entries: <DesktopMenuEntry<_ClipboardAction>>[
          DesktopMenuItem<_ClipboardAction>(
            value: _ClipboardAction.paste,
            symbol: 'clipboard',
            label: context.l10n.paste,
          ),
          if (record.canPasteAsPlainText)
            DesktopMenuItem<_ClipboardAction>(
              value: _ClipboardAction.pastePlainText,
              symbol: 'text',
              label: context.l10n.pasteAsPlainText,
            ),
          const DesktopMenuDivider<_ClipboardAction>(),
          DesktopMenuItem<_ClipboardAction>(
            value: _ClipboardAction.details,
            symbol: 'details',
            label: context.l10n.details,
          ),
          DesktopMenuItem<_ClipboardAction>(
            value: _ClipboardAction.copy,
            symbol: 'copy',
            label: context.l10n.copy,
          ),
          if (includePin)
            DesktopMenuItem<_ClipboardAction>(
              value: _ClipboardAction.togglePinned,
              symbol: 'archive',
              label: record.pinned ? context.l10n.unpin : context.l10n.pin,
            ),
          const DesktopMenuDivider<_ClipboardAction>(),
          DesktopMenuItem<_ClipboardAction>(
            value: _ClipboardAction.addTitle,
            symbol: 'add_title',
            label: record.title.trim().isEmpty
                ? context.l10n.addTitle
                : context.l10n.editTitle,
          ),
          DesktopMenuItem<_ClipboardAction>(
            value: _ClipboardAction.editText,
            symbol: 'edit',
            label: context.l10n.editText,
          ),
          DesktopMenuItem<_ClipboardAction>(
            value: _ClipboardAction.promotePrompt,
            symbol: 'prompt',
            label: context.l10n.saveAsPrompt,
          ),
          DesktopMenuItem<_ClipboardAction>(
            value: _ClipboardAction.archiveTo,
            symbol: 'archive_to',
            label: context.l10n.archiveTo,
          ),
          if (includeShare)
            DesktopMenuItem<_ClipboardAction>(
              value: _ClipboardAction.share,
              symbol: 'link',
              label: context.l10n.sendToDevice,
            ),
          const DesktopMenuDivider<_ClipboardAction>(),
          DesktopMenuItem<_ClipboardAction>(
            value: _ClipboardAction.delete,
            symbol: 'delete',
            label: context.l10n.delete,
            destructive: true,
          ),
        ],
      );
  if (action == null) {
    return;
  }
  onAction(action);
}

enum _ClipboardAction {
  paste,
  pastePlainText,
  details,
  copy,
  togglePinned,
  addTitle,
  editText,
  edit,
  archiveTo,
  promotePrompt,
  share,
  delete,
}
