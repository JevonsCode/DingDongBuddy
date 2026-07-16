part of 'clipboard_screen.dart';

class _ClipboardList extends StatefulWidget {
  const _ClipboardList({
    required this.viewModel,
    required this.compact,
    required this.showShortcutHints,
    required this.onPreview,
    required this.onDismissPreview,
    required this.contextMenuGateway,
    required this.onAction,
  });

  final ClipboardViewModel viewModel;
  final bool compact;
  final bool showShortcutHints;
  final Future<void> Function(ClipboardRecord record)? onPreview;
  final Future<void> Function()? onDismissPreview;
  final DesktopContextMenuGateway? contextMenuGateway;
  final ValueChanged<_ClipboardAction> onAction;

  @override
  State<_ClipboardList> createState() => _ClipboardListState();
}

class _ClipboardListState extends State<_ClipboardList> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
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
    final bool show =
        _scrollController.position.pixels >
        _scrollController.position.viewportDimension;
    if (show != _showScrollToTop && mounted) {
      setState(() => _showScrollToTop = show);
    }
  }

  Future<void> _scrollToTop() async {
    if (!_scrollController.hasClients) return;
    await _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ClipboardRecord> records = widget.viewModel.visibleRecords;
    final bool callout = MediaQuery.sizeOf(context).width < 600;
    return Stack(
      children: <Widget>[
        ListView.builder(
          key: const Key('clipboard-list'),
          controller: _scrollController,
          itemCount: records.length,
          padding: callout ? const EdgeInsets.only(bottom: 8) : null,
          itemExtent: callout ? 82 : (widget.compact ? 60 : 72),
          itemBuilder: (BuildContext context, int index) {
            final ClipboardRecord record = records[index];
            return ClipboardListTile(
              record: record,
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
              onSecondaryTapUp: (TapUpDetails details) {
                widget.viewModel.select(record);
                unawaited(
                  widget.contextMenuGateway == null
                      ? _showClipboardContextMenu(
                          context,
                          details.globalPosition,
                          widget.onAction,
                        )
                      : _showNativeClipboardContextMenu(
                          context,
                          details.globalPosition,
                          widget.contextMenuGateway!,
                          widget.onAction,
                        ),
                );
              },
              callout: callout,
              shortcutIndex: widget.showShortcutHints && index < 9
                  ? index + 1
                  : null,
            );
          },
        ),
        if (_showScrollToTop)
          Positioned(
            right: 12,
            bottom: 12,
            child: IconButton(
              key: const Key('clipboard-scroll-to-top'),
              tooltip: context.localized('Back to top', '回到顶部'),
              onPressed: _scrollToTop,
              icon: const Icon(Icons.arrow_upward_rounded, size: 16),
              style: IconButton.styleFrom(
                fixedSize: const Size.square(30),
                minimumSize: const Size.square(30),
                maximumSize: const Size.square(30),
                padding: EdgeInsets.zero,
                foregroundColor: PopupStyle.textSecondary,
                backgroundColor: PopupStyle.background,
                side: const BorderSide(color: PopupStyle.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
      ],
    );
  }
}

Future<void> _showNativeClipboardContextMenu(
  BuildContext context,
  Offset position,
  DesktopContextMenuGateway gateway,
  ValueChanged<_ClipboardAction> onAction,
) async {
  final ClipboardContextAction? action = clipboardActionFromId(
    await gateway.show(
      x: position.dx,
      y: position.dy,
      useChinese: Localizations.localeOf(context).languageCode == 'zh',
      items: clipboardContextMenuItems(),
    ),
  );
  if (action != null) {
    final _ClipboardAction? mapped = _actionFromNative(action);
    if (mapped != null) {
      onAction(mapped);
    }
  }
}

_ClipboardAction? _actionFromNative(ClipboardContextAction action) =>
    switch (action) {
      ClipboardContextAction.details => _ClipboardAction.details,
      ClipboardContextAction.copy => _ClipboardAction.copy,
      ClipboardContextAction.addTitle => _ClipboardAction.addTitle,
      ClipboardContextAction.editText => _ClipboardAction.editText,
      ClipboardContextAction.saveAsPrompt => _ClipboardAction.promotePrompt,
      ClipboardContextAction.archiveTo => _ClipboardAction.archiveTo,
      ClipboardContextAction.share => _ClipboardAction.share,
      ClipboardContextAction.toggleEnabled => null,
      ClipboardContextAction.delete => _ClipboardAction.delete,
    };

Future<void> _showClipboardContextMenu(
  BuildContext context,
  Offset position,
  ValueChanged<_ClipboardAction> onAction,
) async {
  final _ClipboardAction? action = await showMenu<_ClipboardAction>(
    context: context,
    position: desktopContextMenuPosition(context, position),
    popUpAnimationStyle: AnimationStyle.noAnimation,
    items: <PopupMenuEntry<_ClipboardAction>>[
      _menuItem(
        context,
        _ClipboardAction.details,
        'details',
        'Details',
        '查看详情',
      ),
      _menuItem(context, _ClipboardAction.copy, 'copy', 'Copy', '复制'),
      const PopupMenuDivider(),
      _menuItem(
        context,
        _ClipboardAction.addTitle,
        'add_title',
        'Add title',
        '添加标题',
      ),
      _menuItem(
        context,
        _ClipboardAction.editText,
        'edit',
        'Edit text',
        '编辑文本',
      ),
      _menuItem(
        context,
        _ClipboardAction.promotePrompt,
        'prompt',
        'Save as prompt',
        '保存为提示词',
      ),
      _menuItem(
        context,
        _ClipboardAction.archiveTo,
        'archive_to',
        'Archive to…',
        '归档到…',
      ),
      _menuItem(context, _ClipboardAction.share, 'share', 'Share', '分享'),
      const PopupMenuDivider(),
      _menuItem(context, _ClipboardAction.delete, 'delete', 'Delete', '删除'),
    ],
  );
  if (action == null) {
    return;
  }
  onAction(action);
}

PopupMenuItem<_ClipboardAction> _menuItem(
  BuildContext context,
  _ClipboardAction action,
  String symbol,
  String english,
  String chinese,
) => PopupMenuItem<_ClipboardAction>(
  value: action,
  child: Row(
    children: <Widget>[
      PopupSymbolIcon(symbol, size: 17, color: PopupStyle.textSecondary),
      const SizedBox(width: 10),
      Flexible(child: Text(context.localized(english, chinese))),
    ],
  ),
);

String _typeLabel(BuildContext context, ResourceType type) {
  return switch (type) {
    ResourceType.prompt => context.localized('Prompts', '提示词'),
    ResourceType.skill => context.localized('Skills', '技能'),
    ResourceType.mcp => 'MCP',
    ResourceType.knowledge => context.localized('Knowledge', '知识库'),
    ResourceType.clipboard => context.localized('Clipboard', '剪贴板'),
  };
}

enum _ClipboardAction {
  details,
  copy,
  addTitle,
  editText,
  edit,
  archiveTo,
  promotePrompt,
  share,
  delete,
}
