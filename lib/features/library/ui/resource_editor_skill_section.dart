part of 'resource_editor.dart';

// Skill source and package metadata fields are isolated from other resource types.
enum SkillSourceMode { local, online }

class _SkillEditor extends StatelessWidget {
  const _SkillEditor({
    required this.name,
    required this.sourceMode,
    required this.onSourceModeChanged,
    required this.updateUrlController,
    required this.documentController,
    required this.parsedNameController,
    required this.parsedDescriptionController,
    required this.noteController,
    required this.installedOnline,
    required this.updating,
    required this.updated,
    required this.onOpenSource,
    required this.onUpdate,
  });

  final String name;
  final SkillSourceMode sourceMode;
  final ValueChanged<SkillSourceMode> onSourceModeChanged;
  final TextEditingController updateUrlController;
  final TextEditingController documentController;
  final TextEditingController parsedNameController;
  final TextEditingController parsedDescriptionController;
  final TextEditingController noteController;
  final bool installedOnline;
  final bool updating;
  final bool updated;
  final VoidCallback onOpenSource;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FieldLabel(text: context.l10n.skillSource),
        const SizedBox(height: 7),
        if (installedOnline)
          Container(
            key: const Key('resource-skill-installed-online'),
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.cloud_done_outlined,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.installedFromAnOnlineSource,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        else
          _FlatChoiceRow<SkillSourceMode>(
            selected: sourceMode,
            choices: <_Choice<SkillSourceMode>>[
              _Choice<SkillSourceMode>(
                value: SkillSourceMode.local,
                keyName: 'resource-skill-source-local',
                label: context.l10n.localAuthoring,
              ),
              _Choice<SkillSourceMode>(
                value: SkillSourceMode.online,
                keyName: 'resource-skill-source-online',
                label: context.l10n.onlineSync,
              ),
            ],
            onSelected: onSourceModeChanged,
          ),
        const SizedBox(height: 16),
        if (sourceMode == SkillSourceMode.online) ...<Widget>[
          if (installedOnline) ...<Widget>[
            _FieldLabel(text: context.l10n.skillName),
            const SizedBox(height: 7),
            DesktopTextField(
              key: const Key('resource-skill-name'),
              controller: parsedNameController,
              readOnly: true,
            ),
            const SizedBox(height: 14),
            _FieldLabel(text: context.l10n.whenToUse),
            const SizedBox(height: 7),
            DesktopTextField(
              key: const Key('resource-skill-description'),
              controller: parsedDescriptionController,
              readOnly: true,
              minLines: 2,
              maxLines: 4,
            ),
            const SizedBox(height: 14),
            _FieldLabel(text: context.l10n.myNote),
            const SizedBox(height: 7),
            DesktopTextField(
              key: const Key('resource-skill-note'),
              controller: noteController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: context.l10n.addALocalNoteAboutHowYouUseThisSkill,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 17,
                  color: Color(0xFFB26A19),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    installedOnline
                        ? context
                              .l10n
                              .theInstalledPackageIsReadOnlyReviewTheSourceBefore_d3e0119e
                        : context
                              .l10n
                              .reviewTheSkillBeforeInstallingDingDongSavesTheFullFolder_1375b575,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _FieldLabel(text: context.l10n.sourceURL),
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: DesktopTextField(
                  key: const Key('resource-skill-update-url'),
                  controller: updateUrlController,
                  readOnly: installedOnline,
                  style: const TextStyle(fontFamily: 'monospace'),
                  decoration: const InputDecoration(
                    hintText:
                        'https://github.com/owner/repo/tree/main/skills/name',
                  ),
                ),
              ),
              const SizedBox(width: 7),
              DesktopIconButton(
                key: const Key('resource-skill-open-source'),
                tooltip: context.l10n.openSource,
                onPressed: onOpenSource,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
              ),
              if (installedOnline) ...<Widget>[
                const SizedBox(width: 6),
                DesktopActionButton(
                  key: const Key('resource-skill-update'),
                  onPressed: updating ? null : onUpdate,
                  icon: updating
                      ? const SizedBox.square(
                          dimension: 13,
                          child: CircularProgressIndicator(strokeWidth: 1.7),
                        )
                      : Icon(
                          updated ? Icons.check_rounded : Icons.sync_rounded,
                          size: 16,
                        ),
                  label: Text(
                    updating
                        ? context.l10n.updating
                        : updated
                        ? context.l10n.updated
                        : context.l10n.checkUpdate,
                  ),
                ),
              ],
            ],
          ),
          if (installedOnline) ...<Widget>[
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: _FieldLabel(
                    text: context.l10n.installedSkillPackageSKILLMd,
                  ),
                ),
                Text(
                  context.l10n.readOnly,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            _MultilineField(
              key: const Key('resource-content'),
              controller: documentController,
              height: 300,
              monospace: true,
              readOnly: true,
            ),
          ],
        ] else ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.folder_outlined, size: 16, color: colors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.savedAsSKILLMdNameName(name),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(child: _FieldLabel(text: context.l10n.skillMdContent)),
              Text(
                context.l10n.cursorCompatibleFormat,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 7),
          _MultilineField(
            key: const Key('resource-content'),
            controller: documentController,
            hintText: context.l10n.nameMySkillDescriptionUseWhenInstructions,
            height: 340,
            monospace: true,
          ),
        ],
      ],
    );
  }
}
