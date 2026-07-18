import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter/material.dart';

enum _ClipboardGroupAction { delete }

/// Shows the shared desktop group menu and removes group membership after the
/// user confirms when the group is not empty.
Future<void> showClipboardGroupContextMenu(
  BuildContext context, {
  required Offset globalPosition,
  required String group,
  required ClipboardViewModel viewModel,
  DesktopContextMenuGateway? gateway,
}) async {
  final ColorScheme colors = Theme.of(context).colorScheme;
  final bool deleteRequested;
  if (gateway != null) {
    deleteRequested =
        await gateway.show(
          x: globalPosition.dx,
          y: globalPosition.dy,
          useChinese: Localizations.localeOf(context).languageCode == 'zh',
          items: const <DesktopContextMenuItem>[
            DesktopContextMenuItem(
              id: 'delete',
              englishLabel: 'Delete group',
              chineseLabel: '删除分组',
            ),
          ],
        ) ==
        'delete';
  } else {
    deleteRequested =
        await showDesktopContextMenu<_ClipboardGroupAction>(
          context: context,
          globalPosition: globalPosition,
          entries: <DesktopMenuEntry<_ClipboardGroupAction>>[
            DesktopMenuItem<_ClipboardGroupAction>(
              key: const Key('clipboard-group-action-delete'),
              value: _ClipboardGroupAction.delete,
              symbol: 'delete',
              label: context.localized('Delete group', '删除分组'),
              destructive: true,
            ),
          ],
        ) ==
        _ClipboardGroupAction.delete;
  }
  if (!deleteRequested || !context.mounted) return;

  final int count = viewModel.groupItemCount(group);
  if (count == 0) {
    viewModel.deleteGroup(group);
    return;
  }
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) => AlertDialog(
      title: Text(context.localized('Delete “$group”?', '删除“$group”？')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Text(
          context.localized(
            'This group contains $count clipboard ${count == 1 ? 'item' : 'items'}. The items stay in history; only the group membership is removed.',
            '这个分组中有 $count 条剪贴板内容。内容会保留在历史记录中，只移除分组归属。',
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(context.localized('Cancel', '取消')),
        ),
        FilledButton(
          key: const Key('clipboard-delete-group-confirm'),
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(context.localized('Delete group', '删除分组')),
        ),
      ],
    ),
  );
  if ((confirmed ?? false) && context.mounted) {
    viewModel.deleteGroup(group);
  }
}
