import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/features/agent_plugins/data/local_agent_plugin_inventory.dart';
import 'package:dingdong/features/agent_plugins/domain/agent_plugin_inventory.dart';
import 'package:flutter/material.dart';

class AgentPluginsSection extends StatefulWidget {
  const AgentPluginsSection({this.inventory, super.key});

  final AgentPluginInventory? inventory;

  @override
  State<AgentPluginsSection> createState() => _AgentPluginsSectionState();
}

class _AgentPluginsSectionState extends State<AgentPluginsSection> {
  late final AgentPluginInventory _inventory =
      widget.inventory ?? LocalAgentPluginInventory.production();
  List<AgentPluginInventoryResult>? _results;
  bool _loading = false;

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    List<AgentPluginInventoryResult> results;
    try {
      results = await _inventory.load();
    } on Object {
      results = <AgentPluginInventoryResult>[
        for (final AgentPluginHost host in AgentPluginHost.values)
          AgentPluginInventoryResult(
            host: host,
            state: AgentPluginInventoryState.unavailable,
          ),
      ];
    }
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      key: const Key('agent-plugins-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                l.agentPluginsTitle,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(width: 12),
            DesktopActionButton(
              key: const Key('agent-plugins-refresh'),
              label: _loading
                  ? l.agentPluginsLoading
                  : _results == null
                  ? l.agentPluginsRead
                  : l.agentPluginsRefresh,
              icon: Icons.refresh_rounded,
              tone: DesktopActionTone.neutral,
              onPressed: _loading ? null : _load,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l.agentPluginsReadOnlyNote),
        const SizedBox(height: 6),
        Text(
          l.agentPluginsToolsNote,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (_results == null && !_loading) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            l.agentPluginsNotRead,
            key: const Key('agent-plugins-not-read'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_loading) ...<Widget>[
          const SizedBox(height: 14),
          const LinearProgressIndicator(key: Key('agent-plugins-loading')),
        ],
        if (_results != null) ...<Widget>[
          const SizedBox(height: 14),
          Text(
            l.agentPluginsEnablementNote,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          for (final AgentPluginInventoryResult result in _results!)
            _host(context, result),
        ],
      ],
    );
  }

  Widget _host(BuildContext context, AgentPluginInventoryResult result) {
    final l = context.l10n;
    final String host = switch (result.host) {
      AgentPluginHost.codex => 'Codex',
      AgentPluginHost.claudeCode => 'Claude Code',
    };
    final bool ready = result.state == AgentPluginInventoryState.ready;
    final bool missing = result.state == AgentPluginInventoryState.missing;
    final String? notice = switch (result.state) {
      AgentPluginInventoryState.ready =>
        result.plugins.isEmpty ? l.agentPluginsEmpty : null,
      AgentPluginInventoryState.missing =>
        result.host == AgentPluginHost.codex
            ? l.agentPluginsCodexMissing
            : l.agentPluginsClaudeMissing,
      AgentPluginInventoryState.unavailable => l.agentPluginsUnavailable,
      AgentPluginInventoryState.invalid => l.agentPluginsInvalid,
      AgentPluginInventoryState.timedOut => l.agentPluginsTimedOut,
      AgentPluginInventoryState.tooLarge => l.agentPluginsTooLarge,
    };
    return Padding(
      key: Key('agent-plugins-${result.host.name}'),
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            ready ? '$host · ${result.plugins.length}' : host,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (notice != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                notice,
                key: Key('agent-plugins-${result.host.name}-status'),
                style: TextStyle(
                  color: ready || missing
                      ? Theme.of(context).colorScheme.onSurfaceVariant
                      : Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          for (final AgentPluginEntry plugin in result.plugins)
            _plugin(context, plugin),
        ],
      ),
    );
  }

  Widget _plugin(BuildContext context, AgentPluginEntry plugin) {
    final l = context.l10n;
    final String enabled = switch (plugin.enablement) {
      AgentPluginEnablement.enabled => l.agentPluginsEnabled,
      AgentPluginEnablement.disabled => l.agentPluginsDisabled,
      AgentPluginEnablement.unknown => l.agentPluginsEnablementUnknown,
    };
    final String sourceKind = switch (plugin.sourceKind) {
      AgentPluginSourceKind.local => l.agentPluginsSourceLocal,
      AgentPluginSourceKind.git => l.agentPluginsSourceGit,
      AgentPluginSourceKind.remote => l.agentPluginsSourceRemote,
      AgentPluginSourceKind.marketplace => l.agentPluginsSourceMarketplace,
      AgentPluginSourceKind.unknown => l.agentPluginsSourceUnknown,
    };
    final String source = plugin.sourceName == null
        ? sourceKind
        : '$sourceKind · ${plugin.sourceName}';
    return Container(
      key: ValueKey('agent-plugin-${plugin.host.name}-${plugin.id}'),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.extension_outlined, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  plugin.name,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 5),
                Text(
                  '${l.agentPluginsVersion}: ${plugin.version ?? l.agentPluginsVersionUnknown} · $enabled',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 3),
                Text(
                  '${l.agentPluginsSource}: $source',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
