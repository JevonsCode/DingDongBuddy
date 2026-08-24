part of 'agent_resource_synchronizer.dart';

// Resolve Agent adapter metadata into normalized prompt, Skill, and MCP targets.
final class _AgentResourceTargets {
  const _AgentResourceTargets({
    required this.skillRoots,
    required this.projectSkillRoots,
    required this.promptTargets,
    required this.mcpTargets,
    required this.skillClientNames,
    required this.projectSkillClientNames,
    required this.skillTargets,
    required this.externalSkillCatalogs,
  });

  final List<Directory> skillRoots;
  final List<String> projectSkillRoots;
  final List<AgentPromptTarget> promptTargets;
  final List<AgentMcpTarget> mcpTargets;
  final Map<String, String> skillClientNames;
  final Map<String, String> projectSkillClientNames;
  final List<AgentSkillTarget> skillTargets;
  final List<AgentSkillCatalog> externalSkillCatalogs;
}

_AgentResourceTargets _targetsForAdapters(
  List<AgentAdapter> adapters,
  String home,
) {
  final List<AgentAdapter> installed = adapters
      .where((AgentAdapter adapter) => adapter.isInstalled(home))
      .toList(growable: false);
  final Map<String, ({AgentMcpConfigKind kind, String client})>
  mcpTargetOwners = <String, ({AgentMcpConfigKind kind, String client})>{};
  final Map<String, ({bool routing, String client})> promptTargetOwners =
      <String, ({bool routing, String client})>{};
  for (final AgentAdapter adapter in installed) {
    if (adapter.resolvedMcpFilePath(home) case final String mcpPath) {
      final String normalized = path.normalize(mcpPath);
      final ({AgentMcpConfigKind kind, String client})? existing =
          mcpTargetOwners[normalized];
      if (existing != null && existing.kind != adapter.mcpKind) {
        throw FormatException(
          'Agent Adapters "${existing.client}" and "${adapter.displayName}" '
          'use conflicting MCP formats for $normalized.',
        );
      }
      mcpTargetOwners[normalized] = (
        kind: adapter.mcpKind!,
        client: adapter.displayName,
      );
    }
    if (adapter.resolvedPromptFilePath(home) case final String promptPath) {
      final String normalized = path.normalize(promptPath);
      final ({bool routing, String client})? existing =
          promptTargetOwners[normalized];
      if (existing != null &&
          existing.routing != adapter.includeBridgeRoutingInstructions) {
        throw FormatException(
          'Agent Adapters "${existing.client}" and "${adapter.displayName}" '
          'use conflicting Prompt routing settings for $normalized.',
        );
      }
      promptTargetOwners[normalized] = (
        routing: adapter.includeBridgeRoutingInstructions,
        client: adapter.displayName,
      );
    }
  }
  final List<Directory> skillRoots = installed
      .map((AgentAdapter adapter) => adapter.resolvedGlobalSkillPath(home))
      .whereType<String>()
      .map(Directory.new)
      .toList(growable: false);
  final List<String> projectSkillRoots = installed
      .where((AgentAdapter adapter) => adapter.projectSkillPath != null)
      .map((AgentAdapter adapter) => adapter.resolvedProjectSkillPath())
      .toList(growable: false);
  final List<AgentPromptTarget> promptTargets = installed
      .map((AgentAdapter adapter) {
        final String? file = adapter.resolvedPromptFilePath(home);
        return file == null
            ? null
            : AgentPromptTarget(
                File(file),
                includeBridgeRoutingInstructions:
                    adapter.includeBridgeRoutingInstructions,
                clientName: adapter.displayName,
              );
      })
      .whereType<AgentPromptTarget>()
      .toList(growable: false);
  final List<AgentMcpTarget> mcpTargets = installed
      .map((AgentAdapter adapter) {
        final String? file = adapter.resolvedMcpFilePath(home);
        return file == null
            ? null
            : AgentMcpTarget(
                File(file),
                adapter.mcpKind!,
                clientName: adapter.displayName,
              );
      })
      .whereType<AgentMcpTarget>()
      .toList(growable: false);
  return _AgentResourceTargets(
    skillRoots: skillRoots,
    projectSkillRoots: projectSkillRoots,
    promptTargets: promptTargets,
    mcpTargets: mcpTargets,
    skillClientNames: <String, String>{
      for (final AgentAdapter adapter in installed)
        if (adapter.resolvedGlobalSkillPath(home) case final String root)
          path.normalize(root): adapter.displayName,
    },
    projectSkillClientNames: <String, String>{
      for (final AgentAdapter adapter in installed)
        if (adapter.projectSkillPath != null)
          path.normalize(adapter.resolvedProjectSkillPath()):
              adapter.displayName,
    },
    skillTargets: installed
        .where(
          (AgentAdapter adapter) =>
              adapter.globalSkillPath != null &&
              adapter.projectSkillPath != null,
        )
        .map(
          (AgentAdapter adapter) => AgentSkillTarget(
            agentId: adapter.id,
            clientName: adapter.displayName,
            globalRoot: Directory(adapter.resolvedGlobalSkillPath(home)!),
            projectRelativeRoot: adapter.resolvedProjectSkillPath(),
          ),
        )
        .toList(growable: false),
    externalSkillCatalogs: <AgentSkillCatalog>[
      if (installed.any((AgentAdapter adapter) => adapter.id == 'claude-code'))
        ClaudeCodePluginSkillCatalog(
          settingsFile: File(path.join(home, '.claude', 'settings.json')),
          installedPluginsFile: File(
            path.join(home, '.claude', 'plugins', 'installed_plugins.json'),
          ),
        ),
    ],
  );
}

/// Adds transactional synchronization without changing callers of ResourceStore.
