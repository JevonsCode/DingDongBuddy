import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_context_menu.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter/material.dart';

enum _ClipboardGroupAction { rename, delete }

/// Shows the shared desktop group menu and removes group membership after the
/// user confirms when the group is not empty.
Future<void> showClipboardGroupContextMenu(
  BuildContext context, {
  required Offset globalPosition,
  required String group,
  required ClipboardViewModel viewModel,
  DesktopContextMenuGateway? gateway,
}) async {
  final String? action;
  if (gateway != null) {
    action = await gateway.show(
      x: globalPosition.dx,
      y: globalPosition.dy,
      isDark: Theme.of(context).brightness == Brightness.dark,
      items: <DesktopContextMenuItem>[
        DesktopContextMenuItem(
          id: 'rename',
          label: context.l10n.clipboardRenameGroup,
        ),
        DesktopContextMenuItem(id: 'delete', label: context.l10n.deleteGroup),
      ],
    );
  } else {
    action = (await showDesktopContextMenu<_ClipboardGroupAction>(
      context: context,
      globalPosition: globalPosition,
      entries: <DesktopMenuEntry<_ClipboardGroupAction>>[
        DesktopMenuItem<_ClipboardGroupAction>(
          key: const Key('clipboard-group-action-rename'),
          value: _ClipboardGroupAction.rename,
          symbol: 'edit',
          label: context.l10n.clipboardRenameGroup,
        ),
        DesktopMenuItem<_ClipboardGroupAction>(
          key: const Key('clipboard-group-action-delete'),
          value: _ClipboardGroupAction.delete,
          symbol: 'delete',
          label: context.l10n.deleteGroup,
          destructive: true,
        ),
      ],
    ))?.name;
  }
  if (!context.mounted) return;
  if (action == 'rename') {
    await showDialog<void>(
      context: context,
      builder: (_) => _RenameGroupDialog(group: group, viewModel: viewModel),
    );
    return;
  }
  if (action != 'delete') return;

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

class _RenameGroupDialog extends StatefulWidget {
  const _RenameGroupDialog({required this.group, required this.viewModel});
  final String group;
  final ClipboardViewModel viewModel;
  @override
  State<_RenameGroupDialog> createState() => _RenameGroupDialogState();
}

class _RenameGroupDialogState extends State<_RenameGroupDialog> {
  late final TextEditingController _name = TextEditingController(
    text: widget.group,
  );
  bool _invalid = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (widget.viewModel.renameGroup(widget.group, _name.text)) {
      Navigator.pop(context);
    } else {
      setState(() => _invalid = true);
    }
  }

  @override
  Widget build(BuildContext context) => DesktopAlertDialog(
    title: Text(context.l10n.clipboardRenameGroup),
    maxWidth: 420,
    content: SizedBox(
      width: 360,
      child: DesktopTextField(
        key: const Key('clipboard-group-rename-name'),
        controller: _name,
        autofocus: true,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(
          labelText: context.l10n.clipboardGroupName,
          errorText: _invalid ? context.l10n.clipboardGroupNameInvalid : null,
        ),
      ),
    ),
    actions: [
      DesktopActionButton(
        onPressed: () => Navigator.pop(context),
        label: context.l10n.cancel,
        compact: true,
      ),
      DesktopActionButton(
        key: const Key('clipboard-group-rename-save'),
        onPressed: _save,
        label: context.l10n.save,
        tone: DesktopActionTone.primary,
      ),
    ],
  );
}
