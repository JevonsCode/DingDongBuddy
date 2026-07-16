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
          builder: (BuildContext context) => AlertDialog(
            title: Text(
              context.localized('Delete this clipboard item?', '删除此剪贴板条目？'),
            ),
            content: Text(
              context.localized(
                'This removes it from local history.',
                '此操作会将其从本地历史中移除。',
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.localized('Cancel', '取消')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.localized('Delete', '删除')),
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
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.localized('Add title', '添加标题')),
        content: TextField(controller: controller, autofocus: true),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.localized('Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.localized('Save', '保存')),
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
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.localized('Edit text', '编辑文本')),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 6,
          maxLines: 12,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.localized('Cancel', '取消')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text(context.localized('Save', '保存')),
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
    final Resource? resource = await viewModel.promoteSelected(type);
    if (resource != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.localized(
              'Saved “${resource.title}” to ${type.defaultGroup}.',
              '已将“${resource.title}”保存到${_typeLabel(context, type)}。',
            ),
          ),
        ),
      );
    }
  }
}
