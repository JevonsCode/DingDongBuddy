part of 'resource_editor.dart';

// Per-Agent Skill delivery choices and availability presentation.
class _SkillDeliveryEditor extends StatelessWidget {
  const _SkillDeliveryEditor({
    required this.agents,
    required this.deliveryByAgent,
    required this.hooksEnabledByAgent,
    required this.impeccable,
    required this.onDeliveryChanged,
    required this.onHookChanged,
  });

  final List<SkillDeliveryAgentOption> agents;
  final Map<String, SkillDeliveryMode> deliveryByAgent;
  final Map<String, bool> hooksEnabledByAgent;
  final bool impeccable;
  final void Function(String agentId, SkillDeliveryMode mode) onDeliveryChanged;
  final void Function(String agentId, bool enabled) onHookChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final List<SkillDeliveryAgentOption> primaryAgents = agents
        .where(
          (SkillDeliveryAgentOption agent) =>
              agent.available ||
              (deliveryByAgent[agent.id] ?? SkillDeliveryMode.dynamic) !=
                  SkillDeliveryMode.dynamic ||
              (hooksEnabledByAgent[agent.id] ?? false),
        )
        .toList(growable: false);
    final List<SkillDeliveryAgentOption> uninstalledAgents = agents
        .where(
          (SkillDeliveryAgentOption agent) =>
              !agent.available && !primaryAgents.contains(agent),
        )
        .toList(growable: false);
    return DesktopDisclosure(
      key: const Key('skill-delivery-settings'),
      initiallyExpanded: true,
      leading: const Icon(Icons.inventory_2_outlined, size: 16),
      title: Text(
        context.l10n.deliveryByAgent,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            context
                .l10n
                .dynamicLoadsOnDemandThroughDingDongNativeGlobalInstalls_ff4bd6e5,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          if (primaryAgents.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _SkillDeliveryAgentList(
              agents: primaryAgents,
              deliveryByAgent: deliveryByAgent,
              hooksEnabledByAgent: hooksEnabledByAgent,
              impeccable: impeccable,
              onDeliveryChanged: onDeliveryChanged,
              onHookChanged: onHookChanged,
            ),
          ],
          if (uninstalledAgents.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            DesktopDisclosure(
              key: const Key('skill-delivery-uninstalled-agents'),
              title: Text(
                context.l10n.notInstalledAgentsLength(uninstalledAgents.length),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: _SkillDeliveryAgentList(
                agents: uninstalledAgents,
                deliveryByAgent: deliveryByAgent,
                hooksEnabledByAgent: hooksEnabledByAgent,
                impeccable: impeccable,
                onDeliveryChanged: onDeliveryChanged,
                onHookChanged: onHookChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillDeliveryAgentList extends StatelessWidget {
  const _SkillDeliveryAgentList({
    required this.agents,
    required this.deliveryByAgent,
    required this.hooksEnabledByAgent,
    required this.impeccable,
    required this.onDeliveryChanged,
    required this.onHookChanged,
  });

  final List<SkillDeliveryAgentOption> agents;
  final Map<String, SkillDeliveryMode> deliveryByAgent;
  final Map<String, bool> hooksEnabledByAgent;
  final bool impeccable;
  final void Function(String agentId, SkillDeliveryMode mode) onDeliveryChanged;
  final void Function(String agentId, bool enabled) onHookChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      for (int index = 0; index < agents.length; index++) ...<Widget>[
        if (index > 0) const SizedBox(height: 13),
        _SkillDeliveryAgentRow(
          agent: agents[index],
          delivery:
              deliveryByAgent[agents[index].id] ?? SkillDeliveryMode.dynamic,
          hookEnabled: hooksEnabledByAgent[agents[index].id] ?? false,
          impeccable: impeccable,
          onDeliveryChanged: onDeliveryChanged,
          onHookChanged: onHookChanged,
        ),
      ],
    ],
  );
}

class _SkillDeliveryAgentRow extends StatelessWidget {
  const _SkillDeliveryAgentRow({
    required this.agent,
    required this.delivery,
    required this.hookEnabled,
    required this.impeccable,
    required this.onDeliveryChanged,
    required this.onHookChanged,
  });

  final SkillDeliveryAgentOption agent;
  final SkillDeliveryMode delivery;
  final bool hookEnabled;
  final bool impeccable;
  final void Function(String agentId, SkillDeliveryMode mode) onDeliveryChanged;
  final void Function(String agentId, bool enabled) onHookChanged;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                agent.label,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            if (!agent.available)
              Text(
                context.l10n.notInstalled,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _FlatChoiceRow<SkillDeliveryMode>(
          selected: delivery,
          choices: <_Choice<SkillDeliveryMode>>[
            _Choice<SkillDeliveryMode>(
              value: SkillDeliveryMode.dynamic,
              keyName: 'skill-delivery-${agent.id}-dynamic',
              label: context.l10n.dynamicMessage,
            ),
            _Choice<SkillDeliveryMode>(
              value: SkillDeliveryMode.nativeUser,
              keyName: 'skill-delivery-${agent.id}-native-user',
              label: context.l10n.nativeUser,
              enabled: agent.available,
            ),
            _Choice<SkillDeliveryMode>(
              value: SkillDeliveryMode.nativeProject,
              keyName: 'skill-delivery-${agent.id}-native-project',
              label: context.l10n.nativeProject,
              enabled: agent.available,
            ),
          ],
          onSelected: (SkillDeliveryMode mode) =>
              onDeliveryChanged(agent.id, mode),
        ),
        if (agent.id == 'codex' &&
            impeccable &&
            delivery == SkillDeliveryMode.nativeProject) ...<Widget>[
          const SizedBox(height: 5),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  context.l10n.impeccableProjectHookApprovalRequiredInHooks,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 10),
              CompactSwitch(
                key: const Key('skill-hook-codex'),
                value: hookEnabled,
                onChanged: (bool value) => onHookChanged('codex', value),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
