part of 'clipboard_screen.dart';

class _ClipboardList extends StatelessWidget {
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
  final ClipboardContextMenuGateway? contextMenuGateway;
  final ValueChanged<_ClipboardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final List<ClipboardRecord> records = viewModel.visibleRecords;
    final bool callout = MediaQuery.sizeOf(context).width < 600;
    return ListView.builder(
      key: const Key('clipboard-list'),
      itemCount: records.length,
      padding: callout ? const EdgeInsets.only(bottom: 8) : null,
      itemExtent: callout ? 82 : (compact ? 60 : 72),
      itemBuilder: (BuildContext context, int index) {
        final ClipboardRecord record = records[index];
        return ClipboardListTile(
          record: record,
          selected: viewModel.selectedRecord?.id == record.id,
          onSelected: () {
            viewModel.select(record);
            onPreview?.call(record);
          },
          onDoubleTap: () {
            viewModel.select(record);
            unawaited(() async {
              await onDismissPreview?.call();
              await viewModel.restoreSelected();
            }());
          },
          onSecondaryTapUp: (TapUpDetails details) {
            viewModel.select(record);
            unawaited(
              contextMenuGateway == null
                  ? _showClipboardContextMenu(
                      context,
                      details.globalPosition,
                      onAction,
                    )
                  : _showNativeClipboardContextMenu(
                      context,
                      details.globalPosition,
                      contextMenuGateway!,
                      onAction,
                    ),
            );
          },
          callout: callout,
          shortcutIndex: showShortcutHints && index < 9 ? index + 1 : null,
        );
      },
    );
  }
}

Future<void> _showNativeClipboardContextMenu(
  BuildContext context,
  Offset position,
  ClipboardContextMenuGateway gateway,
  ValueChanged<_ClipboardAction> onAction,
) async {
  final ClipboardContextAction? action = await gateway.show(
    x: position.dx,
    y: position.dy,
    useChinese: Localizations.localeOf(context).languageCode == 'zh',
  );
  if (action != null) {
    onAction(_actionFromNative(action));
  }
}

_ClipboardAction _actionFromNative(ClipboardContextAction action) =>
    switch (action) {
      ClipboardContextAction.details => _ClipboardAction.details,
      ClipboardContextAction.copy => _ClipboardAction.copy,
      ClipboardContextAction.addTitle => _ClipboardAction.addTitle,
      ClipboardContextAction.editText => _ClipboardAction.editText,
      ClipboardContextAction.saveAsPrompt => _ClipboardAction.promotePrompt,
      ClipboardContextAction.saveAsKnowledge =>
        _ClipboardAction.promoteKnowledge,
      ClipboardContextAction.archive => _ClipboardAction.archive,
      ClipboardContextAction.archiveTo => _ClipboardAction.archiveTo,
      ClipboardContextAction.share => _ClipboardAction.share,
      ClipboardContextAction.delete => _ClipboardAction.delete,
    };

Future<void> _showClipboardContextMenu(
  BuildContext context,
  Offset position,
  ValueChanged<_ClipboardAction> onAction,
) async {
  final RenderBox overlay =
      Overlay.of(context).context.findRenderObject()! as RenderBox;
  final _ClipboardAction? action = await showMenu<_ClipboardAction>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(position.dx, position.dy, 0, 0),
      Offset.zero & overlay.size,
    ),
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
        _ClipboardAction.promoteKnowledge,
        'knowledge',
        'Save as knowledge',
        '保存为知识',
      ),
      _menuItem(context, _ClipboardAction.archive, 'archive', 'Archive', '归档'),
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
  archive,
  archiveTo,
  promotePrompt,
  promoteKnowledge,
  share,
  delete,
}
