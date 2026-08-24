part of 'clipboard_manager_screen.dart';

// Translate native and Flutter context-menu choices into one screen action model.
enum _ManagerAction {
  details,
  copy,
  togglePinned,
  addTitle,
  editText,
  archiveTo,
  savePrompt,
  delete,
}

_ManagerAction? _managerActionFromNative(ClipboardContextAction? action) =>
    switch (action) {
      ClipboardContextAction.paste ||
      ClipboardContextAction.pastePlainText => null,
      ClipboardContextAction.details => _ManagerAction.details,
      ClipboardContextAction.copy => _ManagerAction.copy,
      ClipboardContextAction.togglePinned => _ManagerAction.togglePinned,
      ClipboardContextAction.addTitle => _ManagerAction.addTitle,
      ClipboardContextAction.editText => _ManagerAction.editText,
      ClipboardContextAction.saveAsPrompt => _ManagerAction.savePrompt,
      ClipboardContextAction.archiveTo => _ManagerAction.archiveTo,
      ClipboardContextAction.delete => _ManagerAction.delete,
      ClipboardContextAction.share || null => null,
    };

DesktopMenuItem<_ManagerAction> _managerMenuItem(
  BuildContext context,
  _ManagerAction action,
  String symbol,
  String label, {
  bool destructive = false,
}) => DesktopMenuItem<_ManagerAction>(
  key: Key('clipboard-manager-action-${action.name}'),
  value: action,
  symbol: symbol,
  label: label,
  destructive: destructive,
);
