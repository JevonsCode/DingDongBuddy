/// Commands exposed by the desktop clipboard item's native context menu.
enum ClipboardContextAction {
  details,
  copy,
  addTitle,
  editText,
  saveAsPrompt,
  saveAsKnowledge,
  archive,
  archiveTo,
  share,
  delete,
}

/// Opens the platform context menu at a global screen coordinate.
abstract interface class ClipboardContextMenuGateway {
  Future<ClipboardContextAction?> show({
    required double x,
    required double y,
    required bool useChinese,
  });
}
