part of 'clipboard_screen.dart';

class _ClipboardPreview extends StatelessWidget {
  const _ClipboardPreview({
    required this.record,
    required this.onRestore,
    required this.onTogglePinned,
    required this.onAction,
  });

  final ClipboardRecord? record;
  final Future<void> Function() onRestore;
  final VoidCallback onTogglePinned;
  final ValueChanged<_ClipboardAction> onAction;

  @override
  Widget build(BuildContext context) {
    final ClipboardRecord? value = record;
    if (value == null) {
      return Center(
        child: Text(
          context.localized('Select an item to preview', '选择一个条目以预览'),
        ),
      );
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
              FilledButton.icon(
                onPressed: onRestore,
                icon: const Icon(Icons.keyboard_return_rounded, size: 17),
                label: Text(context.localized('Restore', '恢复')),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onTogglePinned,
                icon: Icon(
                  value.pinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  size: 17,
                ),
                label: Text(
                  value.pinned
                      ? context.localized('Unpin', '取消置顶')
                      : context.localized('Pin', '置顶'),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<_ClipboardAction>(
                key: const Key('clipboard-more-actions'),
                tooltip: context.localized('More actions', '更多操作'),
                onSelected: onAction,
                itemBuilder: (BuildContext context) =>
                    <PopupMenuEntry<_ClipboardAction>>[
                      _previewMenuItem(
                        context,
                        _ClipboardAction.edit,
                        Icons.edit_outlined,
                        'Edit and organize',
                        '编辑与整理',
                      ),
                      _previewMenuItem(
                        context,
                        _ClipboardAction.archiveTo,
                        Icons.create_new_folder_outlined,
                        'Archive to…',
                        '归档到…',
                      ),
                      const PopupMenuDivider(),
                      _previewMenuItem(
                        context,
                        _ClipboardAction.promotePrompt,
                        Icons.format_quote_outlined,
                        'Save as prompt',
                        '保存为提示词',
                      ),
                      const PopupMenuDivider(),
                      _previewMenuItem(
                        context,
                        _ClipboardAction.delete,
                        Icons.delete_outline,
                        'Delete',
                        '删除',
                      ),
                    ],
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SelectableText(
              value.sensitive
                  ? context.localized('Sensitive content hidden', '敏感内容已隐藏')
                  : value.content,
            ),
          ),
        ],
      ),
    );
  }
}

PopupMenuItem<_ClipboardAction> _previewMenuItem(
  BuildContext context,
  _ClipboardAction action,
  IconData icon,
  String english,
  String chinese,
) => PopupMenuItem<_ClipboardAction>(
  value: action,
  child: ListTile(
    leading: Icon(icon),
    title: Text(context.localized(english, chinese)),
  ),
);
