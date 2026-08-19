import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
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

    return DesktopDialogFrame(
      dialogKey: const Key('clipboard-group-dialog'),
      width: 500,
      maxHeight: 640,
      header: DesktopDialogHeader(
        leading: _DialogSymbol(
          icon: Icons.folder_open_rounded,
          color: colors.primary,
        ),
        title: Text(context.l10n.archiveToGroups),
        subtitle: Text(context.l10n.keepThisItemEasyToFindAcrossMultipleGroups),
        closeTooltip: context.l10n.close,
        onClose: () => Navigator.pop(context),
      ),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (groups.isNotEmpty) ...<Widget>[
            _DialogSectionLabel(
              title: context.l10n.groups2,
              trailing: _selected.isEmpty
                  ? context.l10n.optional
                  : context.l10n.lengthSelected(_selected.length),
            ),
            const SizedBox(height: 8),
            if (groups.length > 5) ...<Widget>[
              DesktopSearchField(
                key: const Key('clipboard-group-search'),
                controller: _searchController,
                autofocus: true,
                height: 36,
                borderRadius: 8,
                backgroundColor: colors.surfaceContainerLow,
                borderColor: colors.outlineVariant,
                focusBorderColor: colors.primary,
                onChanged: (String value) => setState(() => _query = value),
                hintText: context.l10n.searchGroups,
                clearTooltip: context.l10n.clearSearch,
              ),
              const SizedBox(height: 8),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 168),
              child: visibleGroups.isEmpty
                  ? _NoMatchingGroups()
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: visibleGroups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (BuildContext context, int index) {
                        final String group = visibleGroups[index];
                        return _GroupOption(
                          key: ValueKey<String>('clipboard-group-$group'),
                          group: group,
                          selected: _selected.contains(group),
                          onTap: () => setState(() {
                            if (_selected.contains(group)) {
                              _selected.remove(group);
                            } else {
                              _selected.add(group);
                            }
                          }),
                        );
                      },
                    ),
            ),
          ],
          const SizedBox(height: 18),
          _DialogSectionLabel(
            title: context.l10n.newGroup,
            trailing: context.l10n.optional2,
          ),
          const SizedBox(height: 8),
          DesktopTextField(
            key: const Key('clipboard-new-group'),
            controller: _newGroupController,
            autofocus: groups.isEmpty,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              hintText: context.l10n.eGProjectDrafts,
              prefixIcon: Icon(
                Icons.add_rounded,
                size: 18,
                color: colors.onSurfaceVariant,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 42,
                minHeight: 42,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 11,
              ),
            ),
          ),
        ],
      ),
      footer: DesktopDialogFooter(
        actions: <Widget>[
          DesktopActionButton(
            height: 36,
            onPressed: () => Navigator.pop(context),
            label: context.l10n.cancel,
            tone: DesktopActionTone.neutral,
          ),
          DesktopActionButton(
            key: const Key('clipboard-save-groups'),
            height: 36,
            onPressed: _submit,
            label: context.l10n.addToGroups,
            tone: DesktopActionTone.primary,
          ),
        ],
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

class _DialogSymbol extends StatelessWidget {
  const _DialogSymbol({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }
}

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.onSurface,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
        ),
        Text(
          trailing,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.onSurfaceVariant,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _GroupOption extends StatelessWidget {
  const _GroupOption({
    required this.group,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String group;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colors.primary.withValues(alpha: 0.11)
          : colors.surfaceContainerLow.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.resolveWith<Color?>((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return colors.primary.withValues(alpha: 0.055);
          }
          if (states.contains(WidgetState.pressed)) {
            return colors.primary.withValues(alpha: 0.09);
          }
          return Colors.transparent;
        }),
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.folder_outlined,
                  size: 18,
                  color: selected ? colors.primary : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    group,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 12.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SelectionMark(selected: selected, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoMatchingGroups extends StatelessWidget {
  const _NoMatchingGroups();

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      height: 62,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.l10n.noMatchingGroups,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.onSurfaceVariant,
          fontSize: 11,
        ),
      ),
    );
  }
}
