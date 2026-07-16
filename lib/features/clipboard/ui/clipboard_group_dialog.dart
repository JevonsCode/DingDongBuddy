import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:flutter/material.dart';

/// Compact multi-select group picker used by explicit "Archive to" actions.
class ClipboardGroupDialog extends StatefulWidget {
  const ClipboardGroupDialog({
    required this.availableGroups,
    this.selectedGroups = const <String>{},
    super.key,
  });

  final List<String> availableGroups;
  final Set<String> selectedGroups;

  @override
  State<ClipboardGroupDialog> createState() => _ClipboardGroupDialogState();
}

class _ClipboardGroupDialogState extends State<ClipboardGroupDialog> {
  late final Set<String> _selected;
  late final TextEditingController _newGroupController;
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = <String>{...widget.selectedGroups};
    _newGroupController = TextEditingController();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _newGroupController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<String> groups =
        <String>{...widget.availableGroups, ...widget.selectedGroups}.toList()
          ..sort(
            (String left, String right) =>
                left.toLowerCase().compareTo(right.toLowerCase()),
          );
    final String needle = _query.trim().toLowerCase();
    final List<String> visibleGroups = groups
        .where(
          (String group) =>
              needle.isEmpty || group.toLowerCase().contains(needle),
        )
        .toList(growable: false);
    return Dialog(
      key: const Key('clipboard-group-dialog'),
      elevation: 4,
      backgroundColor: colors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 19, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                context.localized('Add to groups', '归档到分组'),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Text(
                context.localized(
                  'One clipboard item can belong to several groups.',
                  '一个剪贴板条目可以同时属于多个分组。',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
              if (groups.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  context.localized('Existing groups', '已有分组'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                if (groups.length > 5) ...<Widget>[
                  TextField(
                    key: const Key('clipboard-group-search'),
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (String value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: context.localized('Search groups', '搜索分组'),
                      prefixIcon: const Icon(Icons.search_rounded, size: 17),
                      prefixIconConstraints: const BoxConstraints(minWidth: 36),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 190),
                  child: visibleGroups.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            context.localized('No matching groups', '没有匹配的分组'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: visibleGroups.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String group = visibleGroups[index];
                            final bool selected = _selected.contains(group);
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: index == visibleGroups.length - 1
                                    ? 0
                                    : 5,
                              ),
                              child: Material(
                                key: ValueKey<String>('clipboard-group-$group'),
                                color: selected
                                    ? colors.primary.withValues(alpha: 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(5),
                                  onTap: () => setState(() {
                                    selected
                                        ? _selected.remove(group)
                                        : _selected.add(group);
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 9,
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Icon(
                                          Icons.folder_outlined,
                                          size: 16,
                                          color: selected
                                              ? colors.primary
                                              : colors.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 9),
                                        Expanded(
                                          child: Text(
                                            group,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: selected
                                                      ? FontWeight.w600
                                                      : FontWeight.w500,
                                                ),
                                          ),
                                        ),
                                        SelectionMark(
                                          selected: selected,
                                          size: 17,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
              const SizedBox(height: 15),
              Text(
                context.localized('Create another group', '新建分组'),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              TextField(
                key: const Key('clipboard-new-group'),
                controller: _newGroupController,
                autofocus: groups.isEmpty,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: context.localized('e.g. Project drafts', '例如：项目草稿'),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.localized('Cancel', '取消')),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('clipboard-save-groups'),
                    onPressed: _submit,
                    child: Text(context.localized('Add to groups', '加入分组')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    final String newGroup = _newGroupController.text.trim();
    if (newGroup.isNotEmpty) {
      _selected.add(newGroup);
    }
    Navigator.pop(context, Set<String>.unmodifiable(_selected));
  }
}
