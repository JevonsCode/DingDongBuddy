import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';

/// Commands exposed by the desktop clipboard item's native context menu.
enum ClipboardContextAction {
  paste,
  pastePlainText,
  details,
  copy,
  togglePinned,
  addTitle,
  editText,
  saveAsPrompt,
  archiveTo,
  share,
  delete,
}

List<DesktopContextMenuItem> clipboardContextMenuItems({
  required DingDongLocalizations strings,
  bool includePaste = false,
  bool canPasteAsPlainText = false,
  bool includeShare = true,
  bool includePin = true,
  bool pinned = false,
  bool hasTitle = false,
}) => <DesktopContextMenuItem>[
  if (includePaste) DesktopContextMenuItem(id: 'paste', label: strings.paste),
  if (includePaste && canPasteAsPlainText)
    DesktopContextMenuItem(
      id: 'pastePlainText',
      label: strings.pasteAsPlainText,
    ),
  if (includePaste) const DesktopContextMenuItem.separator(),
  DesktopContextMenuItem(id: 'details', label: strings.details),
  DesktopContextMenuItem(id: 'copy', label: strings.copy),
  if (includePin)
    DesktopContextMenuItem(
      id: 'togglePinned',
      label: pinned ? strings.unpin : strings.pin,
    ),
  const DesktopContextMenuItem.separator(),
  DesktopContextMenuItem(
    id: 'addTitle',
    label: hasTitle ? strings.editTitle : strings.addTitle,
  ),
  DesktopContextMenuItem(id: 'editText', label: strings.editText),
  DesktopContextMenuItem(id: 'saveAsPrompt', label: strings.saveAsPrompt),
  DesktopContextMenuItem(id: 'archiveTo', label: strings.archiveTo),
  if (includeShare)
    DesktopContextMenuItem(id: 'share', label: strings.sendToDevice),
  const DesktopContextMenuItem.separator(),
  DesktopContextMenuItem(id: 'delete', label: strings.delete),
];

ClipboardContextAction? clipboardActionFromId(String? id) {
  if (id == null) return null;
  for (final ClipboardContextAction action in ClipboardContextAction.values) {
    if (action.name == id) return action;
  }
  return null;
}
