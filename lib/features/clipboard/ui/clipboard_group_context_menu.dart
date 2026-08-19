import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
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
  final bool deleteRequested;
  if (gateway != null) {
    deleteRequested =
        await gateway.show(
          x: globalPosition.dx,
          y: globalPosition.dy,
          isDark: Theme.of(context).brightness == Brightness.dark,
          items: <DesktopContextMenuItem>[
            DesktopContextMenuItem(
              id: 'delete',
              label: context.l10n.deleteGroup,
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
              label: context.l10n.deleteGroup,
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
    builder: (BuildContext dialogContext) => DesktopAlertDialog(
      title: Text(context.l10n.deleteGroup2(group)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Text(
          context.l10n
              .thisGroupContainsCountArchivedCopiesCopiesWithNoOther_d4ba7c7d(
                count,
              ),
        ),
      ),
      actions: <Widget>[
        DesktopActionButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          label: context.l10n.cancel,
          compact: true,
        ),
        DesktopActionButton(
          key: const Key('clipboard-delete-group-confirm'),
          onPressed: () => Navigator.pop(dialogContext, true),
          label: context.l10n.deleteGroup,
          tone: DesktopActionTone.danger,
        ),
      ],
    ),
  );
  if ((confirmed ?? false) && context.mounted) {
    viewModel.deleteGroup(group);
  }
}
