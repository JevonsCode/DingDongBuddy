import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:flutter/material.dart';

/// Details pane for the selected resource.
class ResourceEditor extends StatefulWidget {
  const ResourceEditor({
    required this.resource,
    required this.isCreating,
    required this.onCreate,
    required this.onDelete,
    required this.onSave,
    this.onSyncUpdate,
    super.key,
  });

  final Resource? resource;
  final bool isCreating;
  final Future<void> Function({
    required ResourceType type,
    required String title,
    required String content,
  })
  onCreate;
  final Future<void> Function()? onDelete;
  final Future<void> Function(Resource resource) onSave;
  final Future<void> Function(String updateUrl)? onSyncUpdate;

  @override
  State<ResourceEditor> createState() => _ResourceEditorState();
}

class _ResourceEditorState extends State<ResourceEditor> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _groupController;
  late final TextEditingController _tagsController;
  late final TextEditingController _updateUrlController;
  bool _pinned = false;
  bool _enabled = true;
  ResourceType _draftType = ResourceType.prompt;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.resource?.title);
    _contentController = TextEditingController(text: widget.resource?.content);
    _groupController = TextEditingController(text: widget.resource?.group);
    _tagsController = TextEditingController(
      text: widget.resource?.tags.join(', '),
    );
    _updateUrlController = TextEditingController(
      text: widget.resource?.updateUrl,
    );
    _pinned = widget.resource?.pinned ?? false;
    _enabled = widget.resource?.enabled ?? true;
    _draftType = widget.resource?.type ?? ResourceType.prompt;
  }

  @override
  void didUpdateWidget(covariant ResourceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resource?.id != widget.resource?.id ||
        oldWidget.isCreating != widget.isCreating) {
      _titleController.text = widget.resource?.title ?? '';
      _contentController.text = widget.resource?.content ?? '';
      _groupController.text = widget.resource?.group ?? '';
      _tagsController.text = widget.resource?.tags.join(', ') ?? '';
      _updateUrlController.text = widget.resource?.updateUrl ?? '';
      _pinned = widget.resource?.pinned ?? false;
      _enabled = widget.resource?.enabled ?? true;
      _draftType = widget.resource?.type ?? ResourceType.prompt;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _groupController.dispose();
    _tagsController.dispose();
    _updateUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Resource? resource = widget.resource;
    if (resource == null && !widget.isCreating) {
      return Center(
        child: Text(
          context.localized(
            'Select a resource to inspect or edit',
            '选择一个资源以查看或编辑',
          ),
        ),
      );
    }
    return Padding(
      key: const Key('resource-editor'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.localized('Resource details', '资源详情'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      SizedBox(
                        width: 190,
                        child: DesktopSelectField<ResourceType>(
                          key: const Key('resource-type'),
                          value: _draftType,
                          items: ResourceType.values
                              .where(
                                (ResourceType type) => type.isLibraryResource,
                              )
                              .map(
                                (ResourceType type) =>
                                    DesktopSelectItem<ResourceType>(
                                      value: type,
                                      label: _typeLabel(context, type),
                                    ),
                              )
                              .toList(growable: false),
                          onChanged: resource == null
                              ? (ResourceType value) {
                                  setState(() {
                                    final bool hadDefaultGroup =
                                        _groupController.text.isEmpty ||
                                        _groupController.text ==
                                            _draftType.defaultGroup;
                                    _draftType = value;
                                    if (hadDefaultGroup) {
                                      _groupController.text =
                                          value.defaultGroup;
                                    }
                                  });
                                }
                              : (_) {},
                          enabled: resource == null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    key: const Key('resource-title'),
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: context.localized('Title', '标题'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          key: const Key('resource-group'),
                          controller: _groupController,
                          decoration: InputDecoration(
                            labelText: context.localized('Group', '分组'),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('resource-tags'),
                          controller: _tagsController,
                          decoration: InputDecoration(
                            labelText: context.localized('Tags', '标签'),
                            hintText: context.localized(
                              'release, writing',
                              '发布, 写作',
                            ),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          key: const Key('resource-update-url'),
                          controller: _updateUrlController,
                          decoration: InputDecoration(
                            labelText: context.localized('Update link', '更新链接'),
                            hintText: 'HTTPS or GitHub file URL',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      if (resource != null &&
                          widget.onSyncUpdate != null) ...<Widget>[
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          key: const Key('resource-sync-update'),
                          tooltip: context.localized(
                            'Fetch latest content',
                            '获取最新内容',
                          ),
                          onPressed: () =>
                              widget.onSyncUpdate!(_updateUrlController.text),
                          icon: const Icon(Icons.sync_rounded),
                        ),
                      ],
                    ],
                  ),
                  CompactSwitchListTile(
                    key: const Key('resource-pinned'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      context.localized('Pinned for agents', '为 Agent 置顶'),
                    ),
                    value: _pinned,
                    onChanged: (bool value) => setState(() => _pinned = value),
                  ),
                  CompactSwitchListTile(
                    key: const Key('resource-enabled'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.localized('Enabled', '启用')),
                    value: _enabled,
                    onChanged: (bool value) => setState(() => _enabled = value),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 220,
                    child: TextField(
                      key: const Key('resource-content'),
                      controller: _contentController,
                      expands: true,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        labelText: context.localized('Content', '内容'),
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              void reset() {
                _titleController.text = resource?.title ?? '';
                _contentController.text = resource?.content ?? '';
                _groupController.text = resource?.group ?? '';
                _tagsController.text = resource?.tags.join(', ') ?? '';
                _updateUrlController.text = resource?.updateUrl ?? '';
                setState(() {
                  _pinned = resource?.pinned ?? false;
                  _enabled = resource?.enabled ?? true;
                });
              }

              Future<void> save() async {
                if (resource == null) {
                  await widget.onCreate(
                    type: _draftType,
                    title: _titleController.text,
                    content: _contentController.text,
                  );
                } else {
                  await widget.onSave(
                    resource.copyWith(
                      group: _groupController.text,
                      title: _titleController.text,
                      content: _contentController.text,
                      tags: _tagsController.text
                          .split(',')
                          .map((String tag) => tag.trim())
                          .where((String tag) => tag.isNotEmpty)
                          .toList(growable: false),
                      updateUrl: _updateUrlController.text,
                      pinned: _pinned,
                      enabled: _enabled,
                      updatedAt: DateTime.now().toUtc(),
                    ),
                  );
                }
              }

              if (constraints.maxWidth < 400) {
                return Row(
                  children: <Widget>[
                    if (resource != null)
                      IconButton(
                        tooltip: context.localized('Delete', '删除'),
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                    const Spacer(),
                    IconButton(
                      tooltip: context.localized('Reset changes', '重置更改'),
                      onPressed: reset,
                      icon: const Icon(Icons.undo_rounded),
                    ),
                    const SizedBox(width: 6),
                    FilledButton(
                      onPressed: save,
                      child: Text(context.localized('Save', '保存')),
                    ),
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  if (resource != null)
                    TextButton.icon(
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(context.localized('Delete', '删除')),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: reset,
                    child: Text(context.localized('Cancel', '取消')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: save,
                    child: Text(context.localized('Save', '保存')),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

String _typeLabel(BuildContext context, ResourceType type) {
  return switch (type) {
    ResourceType.prompt => context.localized('Prompt', '提示词'),
    ResourceType.skill => context.localized('Skill', '技能'),
    ResourceType.mcp => 'MCP',
    ResourceType.knowledge => context.localized('Knowledge', '知识库'),
    ResourceType.clipboard => context.localized('Clipboard', '剪贴板'),
  };
}
