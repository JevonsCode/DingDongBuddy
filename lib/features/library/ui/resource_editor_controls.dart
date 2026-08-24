part of 'resource_editor.dart';

// Reusable option rows, actions, field primitives, and resource labels.
class _ResourceOptions extends StatelessWidget {
  const _ResourceOptions({
    required this.updateUrlController,
    required this.pinned,
    required this.enabled,
    required this.showSync,
    required this.showUpdateLink,
    required this.onPinnedChanged,
    required this.onEnabledChanged,
    required this.onSync,
  });

  final TextEditingController updateUrlController;
  final bool pinned;
  final bool enabled;
  final bool showSync;
  final bool showUpdateLink;
  final ValueChanged<bool> onPinnedChanged;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return DesktopDisclosure(
      key: const Key('resource-advanced-settings'),
      leading: const Icon(Icons.tune_rounded, size: 16),
      title: Text(
        context.l10n.otherSettings,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (showUpdateLink) ...<Widget>[
            _FieldLabel(text: context.l10n.updateLink),
            const SizedBox(height: 7),
            Row(
              children: <Widget>[
                Expanded(
                  child: DesktopTextField(
                    key: const Key('resource-update-url'),
                    controller: updateUrlController,
                    decoration: InputDecoration(
                      hintText: context.l10n.httpsOrGitHubFileURL,
                    ),
                  ),
                ),
                if (showSync) ...<Widget>[
                  const SizedBox(width: 8),
                  DesktopIconButton(
                    key: const Key('resource-sync-update'),
                    tooltip: context.l10n.fetchLatestContent,
                    onPressed: onSync,
                    icon: const Icon(Icons.sync_rounded),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 7),
          Row(
            children: <Widget>[
              Expanded(
                child: _InlineToggle(
                  key: const Key('resource-pinned'),
                  label: context.l10n.pinInLibrary,
                  value: pinned,
                  onChanged: onPinnedChanged,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _InlineToggle(
                  key: const Key('resource-enabled'),
                  label: context.l10n.availableToInstalledAgents,
                  value: enabled,
                  onChanged: onEnabledChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorActions extends StatelessWidget {
  const _EditorActions({
    required this.existing,
    required this.onDelete,
    required this.onReset,
    required this.onSave,
    required this.saving,
    required this.saved,
    required this.syncing,
  });

  final bool existing;
  final Future<void> Function()? onDelete;
  final VoidCallback onReset;
  final Future<void> Function() onSave;
  final bool saving;
  final bool saved;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 400) {
          return Row(
            children: <Widget>[
              if (existing)
                DesktopIconButton(
                  tooltip: context.l10n.delete,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              const Spacer(),
              DesktopIconButton(
                tooltip: context.l10n.resetChanges,
                onPressed: onReset,
                icon: const Icon(Icons.undo_rounded),
              ),
              const SizedBox(width: 6),
              DesktopActionButton(
                key: const Key('resource-save'),
                onPressed: saving ? null : onSave,
                child: _SaveButtonLabel(
                  saving: saving,
                  saved: saved,
                  syncing: syncing,
                ),
              ),
            ],
          );
        }
        return Row(
          children: <Widget>[
            if (existing)
              DesktopActionButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                label: Text(context.l10n.delete),
              ),
            const Spacer(),
            DesktopActionButton(
              onPressed: onReset,
              child: Text(context.l10n.reset2),
            ),
            const SizedBox(width: 8),
            DesktopActionButton(
              key: const Key('resource-save'),
              onPressed: saving ? null : onSave,
              child: _SaveButtonLabel(
                saving: saving,
                saved: saved,
                syncing: syncing,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SaveButtonLabel extends StatelessWidget {
  const _SaveButtonLabel({
    required this.saving,
    required this.saved,
    required this.syncing,
  });

  final bool saving;
  final bool saved;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    final String label = saving
        ? context.l10n.saving
        : saved
        ? context.l10n.saved
        : syncing
        ? context.l10n.installSkill
        : context.l10n.save;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: Row(
        key: ValueKey<String>(label),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (saving)
            const SizedBox.square(
              dimension: 13,
              child: CircularProgressIndicator(strokeWidth: 1.8),
            )
          else if (saved)
            const Icon(Icons.check_rounded, size: 16),
          if (saving || saved) const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _FlatChoiceRow<T> extends StatelessWidget {
  const _FlatChoiceRow({
    required this.selected,
    required this.choices,
    required this.onSelected,
  });

  final T selected;
  final List<_Choice<T>> choices;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        for (int index = 0; index < choices.length; index++) ...<Widget>[
          if (index > 0) const SizedBox(width: 6),
          Expanded(
            child: DesktopActionButton(
              key: Key(choices[index].keyName),
              onPressed: choices[index].enabled
                  ? () => onSelected(choices[index].value)
                  : null,
              style: DesktopActionButton.styleFrom(
                minimumSize: const Size(0, 34),
                foregroundColor: choices[index].value == selected
                    ? colors.primary
                    : colors.onSurfaceVariant,
                backgroundColor: choices[index].value == selected
                    ? colors.primary.withValues(alpha: 0.09)
                    : Colors.transparent,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: Text(
                choices[index].label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: choices[index].value == selected
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

final class _Choice<T> {
  const _Choice({
    required this.value,
    required this.keyName,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String keyName;
  final String label;
  final bool enabled;
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[left, const SizedBox(height: 12), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: left),
            const SizedBox(width: 12),
            Expanded(child: right),
          ],
        );
      },
    );
  }
}

class _MultilineField extends StatelessWidget {
  const _MultilineField({
    required this.controller,
    required this.height,
    this.hintText,
    this.monospace = false,
    this.readOnly = false,
    super.key,
  });

  final TextEditingController controller;
  final double height;
  final String? hintText;
  final bool monospace;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: DesktopTextField(
        controller: controller,
        readOnly: readOnly,
        expands: true,
        maxLines: null,
        textAlignVertical: TextAlignVertical.top,
        style: monospace ? const TextStyle(fontFamily: 'monospace') : null,
        decoration: InputDecoration(hintText: hintText),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _InlineToggle extends StatelessWidget {
  const _InlineToggle({
    required this.label,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(4),
    onTap: () => onChanged(!value),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: 10),
          CompactSwitch(value: value, onChanged: onChanged),
        ],
      ),
    ),
  );
}

String _typeLabel(BuildContext context, ResourceType type) {
  return switch (type) {
    ResourceType.prompt => context.l10n.prompt,
    ResourceType.skill => context.l10n.skill,
    ResourceType.mcp => 'MCP',
    ResourceType.knowledge => context.l10n.knowledge,
    ResourceType.clipboard => context.l10n.clipboard,
  };
}

IconData _typeIcon(ResourceType type) {
  return switch (type) {
    ResourceType.prompt => Icons.format_quote_rounded,
    ResourceType.skill => Icons.auto_awesome_outlined,
    ResourceType.mcp => Icons.dns_outlined,
    ResourceType.knowledge => Icons.folder_outlined,
    ResourceType.clipboard => Icons.content_paste_outlined,
  };
}

String _typeDescription(BuildContext context, ResourceType type) {
  return switch (type) {
    ResourceType.prompt =>
      context
          .l10n
          .requiredInstructionsThatAreAppliedAutomaticallyWhenever_7564e51c,
    ResourceType.skill =>
      context
          .l10n
          .matchedByDescriptionThenLoadedAsACompleteSkillPackage_fa102bfe,
    ResourceType.mcp =>
      context
          .l10n
          .aToolConnectionWhoseMCPToolsAreCalledOnlyWhenTheTask_08282426,
    ResourceType.knowledge =>
      context.l10n.importedKnowledgeAvailableToAgentContext,
    ResourceType.clipboard => context.l10n.clipboardItem,
  };
}

String _titleLabel(BuildContext context, ResourceType type) {
  return switch (type) {
    ResourceType.prompt => context.l10n.promptName,
    ResourceType.skill => context.l10n.skillName,
    ResourceType.mcp => context.l10n.serverName,
    ResourceType.knowledge => context.l10n.name,
    ResourceType.clipboard => context.l10n.name,
  };
}

String _titleHint(BuildContext context, ResourceType type) {
  return switch (type) {
    ResourceType.prompt => context.l10n.eGConciseReleaseNotes,
    ResourceType.skill => context.l10n.lowercaseHyphenName,
    ResourceType.mcp => context.l10n.eGFigma,
    ResourceType.knowledge => '',
    ResourceType.clipboard => '',
  };
}
