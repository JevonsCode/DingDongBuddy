part of 'clipboard_screen.dart';

extension _ClipboardActions on _ClipboardScreenState {
  Future<void> _handleAction(
    BuildContext context,
    _ClipboardAction action,
  ) async {
    final ClipboardRecord? selected = viewModel.selectedRecord;
    if (selected == null) {
      return;
    }
    switch (action) {
      case _ClipboardAction.paste:
        await onDismissPreview?.call();
        await viewModel.restoreSelected();
      case _ClipboardAction.pastePlainText:
        await onDismissPreview?.call();
        await viewModel.restoreSelected(mode: ClipboardPasteMode.plainText);
      case _ClipboardAction.details:
        await onPreview?.call(selected);
      case _ClipboardAction.edit:
        final ClipboardOrganization? organization =
            await showDialog<ClipboardOrganization>(
              context: context,
              builder: (BuildContext context) =>
                  ClipboardOrganizeDialog(record: selected),
            );
        if (organization != null) {
          viewModel.organizeSelected(
            title: organization.title,
            content: organization.content,
            group: organization.group,
            tags: organization.tags,
          );
        }
      case _ClipboardAction.archiveTo:
        await _archiveTo(context, selected);
      case _ClipboardAction.copy:
        await viewModel.copySelected();
      case _ClipboardAction.togglePinned:
        viewModel.togglePinned();
      case _ClipboardAction.addTitle:
        await _editTitle(context, selected);
      case _ClipboardAction.editText:
        await _editText(context, selected);
      case _ClipboardAction.promotePrompt:
        await _promote(context, ResourceType.prompt);
      case _ClipboardAction.share:
        await onShare?.call(selected);
      case _ClipboardAction.delete:
        final bool? confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => DesktopAlertDialog(
            title: Text(
              viewModel.selectedRecordIsArchived
                  ? context.l10n.deleteThisArchivedCopy
                  : context.l10n.deleteThisClipboardItem,
            ),
            content: Text(
              viewModel.selectedRecordIsArchived
                  ? context.l10n.clipboardHistoryRemainsUnchanged
                  : context.l10n.archivedCopiesRemainUnchanged,
            ),
            actions: <Widget>[
              DesktopActionButton(
                onPressed: () => Navigator.pop(context, false),
                label: context.l10n.cancel,
                compact: true,
              ),
              DesktopActionButton(
                onPressed: () => Navigator.pop(context, true),
                label: context.l10n.delete,
                tone: DesktopActionTone.danger,
              ),
            ],
          ),
        );
        if (confirmed ?? false) {
          viewModel.deleteSelected();
        }
    }
  }

  Future<void> _editTitle(BuildContext context, ClipboardRecord record) async {
    final TextEditingController controller = TextEditingController(
      text: record.title,
    );
    final String? title = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => DesktopAlertDialog(
        title: Text(
          record.title.trim().isEmpty
              ? context.l10n.addTitle
              : context.l10n.editTitle,
        ),
        content: DesktopTextField(controller: controller, autofocus: true),
        actions: <Widget>[
          DesktopActionButton(
            onPressed: () => Navigator.pop(context),
            label: context.l10n.cancel,
            compact: true,
          ),
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, controller.text),
            label: context.l10n.save,
            tone: DesktopActionTone.primary,
          ),
        ],
      ),
    );
    controller.dispose();
    if (title != null && title.trim().isNotEmpty) {
      viewModel.organizeSelected(
        title: title,
        content: record.content,
        group: record.group,
        tags: record.tags,
      );
    }
  }

  Future<void> _editText(BuildContext context, ClipboardRecord record) async {
    final TextEditingController controller = TextEditingController(
      text: record.content,
    );
    final String? content = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => DesktopAlertDialog(
        title: Text(context.l10n.editText),
        content: DesktopTextField(
          controller: controller,
          autofocus: true,
          minLines: 6,
          maxLines: 12,
        ),
        actions: <Widget>[
          DesktopActionButton(
            onPressed: () => Navigator.pop(context),
            label: context.l10n.cancel,
            compact: true,
          ),
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, controller.text),
            label: context.l10n.save,
            tone: DesktopActionTone.primary,
          ),
        ],
      ),
    );
    controller.dispose();
    if (content != null && content.trim().isNotEmpty) {
      viewModel.organizeSelected(
        title: record.title,
        content: content,
        group: record.group,
        tags: record.tags,
      );
    }
  }

  Future<void> _archiveTo(BuildContext context, ClipboardRecord record) async {
    final Set<String>? groups = await showDialog<Set<String>>(
      context: context,
      builder: (BuildContext context) => ClipboardGroupDialog(
        availableGroups: viewModel.groups,
        selectedGroups: record.groupNames
            .where(viewModel.groups.contains)
            .toSet(),
      ),
    );
    if (groups != null && groups.isNotEmpty) {
      viewModel.addSelectedToGroups(groups);
    }
  }

  Future<void> _promote(BuildContext context, ResourceType type) async {
    final ResourceManagerLauncher? launcher = resourceManagerLauncher;
    final ClipboardRecord? selected = viewModel.selectedRecord;
    if (launcher == null || selected == null || !type.isLibraryResource) {
      return;
    }
    await launcher.show(
      createRequest: ResourceManagerCreateRequest(
        type: type,
        title: selected.title.trim().isEmpty ? null : selected.title,
        content: selected.content,
      ),
    );
  }
}
