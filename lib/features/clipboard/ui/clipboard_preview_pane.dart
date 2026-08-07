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
              DesktopActionButton(
                onPressed: () => unawaited(onRestore()),
                icon: Icons.keyboard_return_rounded,
                label: context.localized('Restore', '恢复'),
                tone: DesktopActionTone.primary,
              ),
              if (onOpen != null && canOpenClipboardContent(value)) ...<Widget>[
                const SizedBox(width: 8),
                DesktopActionButton(
                  key: const Key('clipboard-preview-open'),
                  onPressed: () => unawaited(onOpen!(value)),
                  icon: Icons.open_in_new_rounded,
                  label: context.localized('Open', '打开'),
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
                  label: value.pinned
                      ? context.localized('Unpin', '取消置顶')
                      : context.localized('Pin', '置顶'),
                ),
              ],
              const SizedBox(width: 8),
              DesktopMenuButton<_ClipboardAction>(
                key: const Key('clipboard-more-actions'),
                tooltip: context.localized('More actions', '更多操作'),
                onSelected: onAction,
                entries: <DesktopMenuEntry<_ClipboardAction>>[
                  DesktopMenuItem<_ClipboardAction>(
                    value: _ClipboardAction.edit,
                    label: context.localized('Edit and organize', '编辑与整理'),
                    symbol: 'edit',
                  ),
                  DesktopMenuItem<_ClipboardAction>(
                    value: _ClipboardAction.archiveTo,
                    label: context.localized('Archive to…', '归档到…'),
                    symbol: 'archive_to',
                  ),
                  const DesktopMenuDivider<_ClipboardAction>(),
                  DesktopMenuItem<_ClipboardAction>(
                    value: _ClipboardAction.promotePrompt,
                    label: context.localized('Save as prompt', '保存为提示词'),
                    symbol: 'prompt',
                  ),
                  const DesktopMenuDivider<_ClipboardAction>(),
                  DesktopMenuItem<_ClipboardAction>(
                    value: _ClipboardAction.delete,
                    label: context.localized('Delete', '删除'),
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
                  ? context.localized('Sensitive content hidden', '敏感内容已隐藏')
                  : value.content,
            ),
          ),
        ],
      ),
    );
  }
}
