part of 'resource_editor.dart';

// Shared editor chrome: headings, type selection, and prompt authoring.
class _ResourceEditorHeading extends StatelessWidget {
  const _ResourceEditorHeading({required this.resource, required this.type});

  final Resource? resource;
  final ResourceType type;

  @override
  Widget build(BuildContext context) {
    final Widget heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          resource == null
              ? context.l10n.addAgentConfiguration
              : context.l10n.configurationDetails,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          _typeDescription(context, type),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    final Resource? current = resource;
    if (current == null) {
      return heading;
    }
    final Widget usage = ResourceUsageSummary(
      key: const Key('resource-detail-usage-summary'),
      resource: current,
      style: ResourceUsageSummaryStyle.detail,
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[heading, const SizedBox(height: 12), usage],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: heading),
            const SizedBox(width: 20),
            usage,
          ],
        );
      },
    );
  }
}

class _EmptyEditor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.tune_rounded,
            size: 24,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 10),
          Text(
            context.l10n.selectAConfigurationToInspectOrEdit,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceTypePicker extends StatelessWidget {
  const _ResourceTypePicker({required this.selected, required this.onSelected});

  final ResourceType selected;
  final ValueChanged<ResourceType> onSelected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      key: const Key('resource-type'),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          for (final ResourceType type in const <ResourceType>[
            ResourceType.prompt,
            ResourceType.skill,
            ResourceType.mcp,
          ])
            Expanded(
              child: _TypeOption(
                key: Key('resource-type-${type.name}'),
                type: type,
                selected: type == selected,
                onTap: () => onSelected(type),
              ),
            ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final ResourceType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? colors.primary : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                _typeIcon(type),
                size: 16,
                color: selected ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Text(
                _typeLabel(context, type),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? colors.onSurface : colors.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});

  final ResourceType type;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Brightness brightness = Theme.of(context).brightness;
    final bool isMcp = type == ResourceType.mcp;
    return Container(
      key: const Key('resource-type-badge'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: isMcp
            ? PopupStyle.mcpSurface(brightness)
            : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            _typeIcon(type),
            size: 14,
            color: isMcp
                ? PopupStyle.mcpAccent(brightness)
                : colors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            _typeLabel(context, type),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isMcp
                  ? PopupStyle.mcpAccent(brightness)
                  : colors.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentSessionNameField extends StatelessWidget {
  const _AgentSessionNameField({
    required this.controller,
    required this.hideInAgentConversation,
    required this.onHideInAgentConversationChanged,
  });

  final TextEditingController controller;
  final bool hideInAgentConversation;
  final ValueChanged<bool> onHideInAgentConversationChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _FieldLabel(text: context.l10n.agentSessionLoadingName),
            ),
            Tooltip(
              message: context
                  .l10n
                  .loadThisResourceWithoutShowingItsNameInTheAgent_ec7e075b,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    context.l10n.hideInConversation,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  CompactSwitch(
                    key: const Key('resource-hide-in-agent-conversation'),
                    value: hideInAgentConversation,
                    onChanged: onHideInAgentConversationChanged,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        DesktopTextField(
          key: const Key('resource-agent-session-name'),
          controller: controller,
          maxLength: maximumAgentSessionNameCharacters,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          inputFormatters: <TextInputFormatter>[
            LengthLimitingTextInputFormatter(maximumAgentSessionNameCharacters),
          ],
          decoration: InputDecoration(
            hintText: context.l10n.leaveEmptyToUseTheResourceTitle,
            counterText: '',
          ),
        ),
        const SizedBox(height: 5),
        Text(
          context.l10n.upTo7CharactersThisNameIsShownFirstInTheAgent_b892681f,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _PromptEditor extends StatelessWidget {
  const _PromptEditor({
    required this.controller,
    required this.activation,
    required this.onActivationChanged,
  });

  final TextEditingController controller;
  final ResourceActivation activation;
  final ValueChanged<ResourceActivation> onActivationChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FieldLabel(text: context.l10n.whenItApplies),
        const SizedBox(height: 7),
        _FlatChoiceRow<ResourceActivation>(
          selected: activation,
          choices: <_Choice<ResourceActivation>>[
            _Choice<ResourceActivation>(
              value: ResourceActivation.always,
              keyName: 'resource-activation-always',
              label: context.l10n.always,
            ),
            _Choice<ResourceActivation>(
              value: ResourceActivation.taskMatch,
              keyName: 'resource-activation-task-match',
              label: context.l10n.agentDecides,
            ),
            _Choice<ResourceActivation>(
              value: ResourceActivation.manual,
              keyName: 'resource-activation-manual',
              label: context.l10n.manual,
            ),
          ],
          onSelected: onActivationChanged,
        ),
        const SizedBox(height: 16),
        _FieldLabel(text: context.l10n.instructions),
        const SizedBox(height: 7),
        _MultilineField(
          key: const Key('resource-content'),
          controller: controller,
          hintText: context.l10n.describeTheBehaviorTheAgentShouldFollow,
          height: 220,
        ),
      ],
    );
  }
}
