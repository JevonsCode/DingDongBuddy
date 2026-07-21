import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:flutter/material.dart';

/// Editable clipboard fields returned by the organization dialog.
final class ClipboardOrganization {
  const ClipboardOrganization({
    required this.title,
    required this.content,
    required this.group,
    required this.tags,
  });

  final String title;
  final String content;
  final String group;
  final List<String> tags;
}

/// Keeps clipboard editing, grouping, and snippet aliases in one focused flow.
final class ClipboardOrganizeDialog extends StatefulWidget {
  const ClipboardOrganizeDialog({required this.record, super.key});

  final ClipboardRecord record;

  @override
  State<ClipboardOrganizeDialog> createState() =>
      _ClipboardOrganizeDialogState();
}

final class _ClipboardOrganizeDialogState
    extends State<ClipboardOrganizeDialog> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _group;
  late final TextEditingController _tags;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.record.title);
    _content = TextEditingController(text: widget.record.content);
    _group = TextEditingController(text: widget.record.group);
    _tags = TextEditingController(text: widget.record.tags.join(', '));
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _group.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DesktopAlertDialog(
      maxWidth: 600,
      title: Text(context.localized('Organize clipboard item', '整理剪贴板条目')),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              key: const Key('clipboard-edit-title'),
              controller: _title,
              decoration: InputDecoration(
                labelText: context.localized('Title', '标题'),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    key: const Key('clipboard-edit-group'),
                    controller: _group,
                    decoration: InputDecoration(
                      labelText: context.localized('Group', '分组'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    key: const Key('clipboard-edit-tags'),
                    controller: _tags,
                    decoration: InputDecoration(
                      labelText: context.localized('Tags and aliases', '标签与别名'),
                      hintText: 'command, alias:build',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: TextField(
                key: const Key('clipboard-edit-content'),
                controller: _content,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  labelText: context.localized('Content', '内容'),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.localized('Cancel', '取消')),
        ),
        FilledButton(
          key: const Key('clipboard-edit-save'),
          onPressed: () {
            if (_title.text.trim().isEmpty ||
                _group.text.trim().isEmpty ||
                _content.text.trim().isEmpty) {
              return;
            }
            Navigator.pop(
              context,
              ClipboardOrganization(
                title: _title.text,
                content: _content.text,
                group: _group.text,
                tags: _tags.text
                    .split(',')
                    .map((String tag) => tag.trim())
                    .where((String tag) => tag.isNotEmpty)
                    .toList(growable: false),
              ),
            );
          },
          child: Text(context.localized('Save', '保存')),
        ),
      ],
    );
  }
}
