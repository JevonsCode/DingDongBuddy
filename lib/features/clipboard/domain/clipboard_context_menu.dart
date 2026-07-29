import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';

/// Commands exposed by the desktop clipboard item's native context menu.
enum ClipboardContextAction {
  paste,
  pastePlainText,
  details,
  copy,
  addTitle,
  editText,
  saveAsPrompt,
  archiveTo,
  share,
  toggleEnabled,
  delete,
}

List<DesktopContextMenuItem> clipboardContextMenuItems({
  bool includePaste = false,
  bool canPasteAsPlainText = false,
  bool includeShare = true,
  bool? enabled,
}) => <DesktopContextMenuItem>[
  if (includePaste)
    const DesktopContextMenuItem(
      id: 'paste',
      englishLabel: 'Paste',
      chineseLabel: '粘贴',
    ),
  if (includePaste && canPasteAsPlainText)
    const DesktopContextMenuItem(
      id: 'pastePlainText',
      englishLabel: 'Paste as Plain Text',
      chineseLabel: '粘贴为纯文本',
    ),
  if (includePaste) const DesktopContextMenuItem.separator(),
  const DesktopContextMenuItem(
    id: 'details',
    englishLabel: 'Details',
    chineseLabel: '查看详情',
  ),
  const DesktopContextMenuItem(
    id: 'copy',
    englishLabel: 'Copy',
    chineseLabel: '复制',
  ),
  const DesktopContextMenuItem.separator(),
  const DesktopContextMenuItem(
    id: 'addTitle',
    englishLabel: 'Add title',
    chineseLabel: '添加标题',
  ),
  const DesktopContextMenuItem(
    id: 'editText',
    englishLabel: 'Edit text',
    chineseLabel: '编辑文本',
  ),
  const DesktopContextMenuItem(
    id: 'saveAsPrompt',
    englishLabel: 'Save as prompt',
    chineseLabel: '保存为提示词',
  ),
  const DesktopContextMenuItem(
    id: 'archiveTo',
    englishLabel: 'Archive to…',
    chineseLabel: '归档到…',
  ),
  if (includeShare)
    const DesktopContextMenuItem(
      id: 'share',
      englishLabel: 'Share',
      chineseLabel: '分享',
    ),
  if (enabled != null)
    DesktopContextMenuItem(
      id: 'toggleEnabled',
      englishLabel: enabled ? 'Disable' : 'Enable',
      chineseLabel: enabled ? '停用' : '启用',
    ),
  const DesktopContextMenuItem.separator(),
  const DesktopContextMenuItem(
    id: 'delete',
    englishLabel: 'Delete',
    chineseLabel: '删除',
  ),
];

ClipboardContextAction? clipboardActionFromId(String? id) {
  if (id == null) return null;
  for (final ClipboardContextAction action in ClipboardContextAction.values) {
    if (action.name == id) return action;
  }
  return null;
}
