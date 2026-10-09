enum AgentPluginHost { codex, claudeCode }

enum AgentPluginInventoryState {
  ready,
  missing,
  unavailable,
  invalid,
  timedOut,
  tooLarge,
}

enum AgentPluginEnablement { enabled, disabled, unknown }

enum AgentPluginSourceKind { local, git, remote, marketplace, unknown }

/// Metadata reported by an Agent's native plugin registry. No configuration,
/// credentials, installation paths, or executable commands belong in this model.
final class AgentPluginEntry {
  const AgentPluginEntry({
    required this.id,
    required this.name,
    required this.host,
    required this.enablement,
    required this.sourceKind,
    this.version,
    this.sourceName,
  });

  final String id;
  final String name;
  final AgentPluginHost host;
  final String? version;
  final AgentPluginEnablement enablement;
  final AgentPluginSourceKind sourceKind;
  final String? sourceName;
}

final class AgentPluginInventoryResult {
  const AgentPluginInventoryResult({
    required this.host,
    required this.state,
    this.plugins = const <AgentPluginEntry>[],
  });

  final AgentPluginHost host;
  final AgentPluginInventoryState state;
  final List<AgentPluginEntry> plugins;
}

abstract interface class AgentPluginInventory {
  Future<List<AgentPluginInventoryResult>> load();
}
