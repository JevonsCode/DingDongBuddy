// THESIS: Optional features have one discoverable home in Resource Manager.
// OWN-WORLD: Existing neutral desktop surfaces, continuous rows and blue actions.
// STORY: Find Jev or selection tools, open their controls, choose whether to enable.
// FIRST VIEWPORT: Plugins heading, two named rows, a Manage action on each row.
// FORM: Narrow extension of the established resource workspace; no new visual world.
// FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, and DESIGN.md
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/features/agent_plugins/domain/agent_plugin_inventory.dart';
import 'package:dingdong/features/agent_plugins/ui/agent_plugins_section.dart';
import 'package:dingdong/features/jev/ui/jev_plugin_section.dart';
import 'package:dingdong/features/selection/ui/selection_plugin_section.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum _Plugin { jev, selection }

class PluginsScreen extends StatefulWidget {
  const PluginsScreen({
    this.jevAction,
    this.selectionViewModel,
    this.agentPluginInventory,
    super.key,
  });

  final JevAction? jevAction;
  final SettingsViewModel? selectionViewModel;
  final AgentPluginInventory? agentPluginInventory;

  @override
  State<PluginsScreen> createState() => _PluginsScreenState();
}

class _PluginsScreenState extends State<PluginsScreen> {
  _Plugin? _selected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox.expand(
      child: SingleChildScrollView(
        key: ValueKey('plugins-${_selected?.name ?? 'catalog'}'),
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selected == null) ...[
                  Text(
                    l.plugins,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l.agentPluginsPageDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    l.agentPluginsDingDongExtensions,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  _entry(
                    context,
                    plugin: _Plugin.jev,
                    title: 'Jev',
                    description: l.jevDescription,
                    icon: Icons.auto_awesome_outlined,
                  ),
                  if (defaultTargetPlatform == TargetPlatform.macOS)
                    _entry(
                      context,
                      plugin: _Plugin.selection,
                      title: l.systemSelectionTools,
                      description: l.systemSelectionToolsDescription,
                      icon: Icons.text_fields_rounded,
                    ),
                  const SizedBox(height: 28),
                  AgentPluginsSection(inventory: widget.agentPluginInventory),
                ] else ...[
                  DesktopActionButton(
                    key: const Key('plugins-back'),
                    label: l.pluginBack,
                    icon: Icons.arrow_back,
                    tone: DesktopActionTone.neutral,
                    onPressed: () => setState(() => _selected = null),
                  ),
                  const SizedBox(height: 24),
                  if (_selected == _Plugin.jev)
                    if (widget.jevAction case final action?)
                      JevPluginSection(action: action)
                    else
                      Text(l.pluginUnavailable),
                  if (_selected == _Plugin.selection)
                    if (widget.selectionViewModel case final model?)
                      SelectionPluginSection(viewModel: model)
                    else
                      Text(l.pluginUnavailable),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _entry(
    BuildContext context, {
    required _Plugin plugin,
    required String title,
    required String description,
    required IconData icon,
  }) => DecoratedBox(
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 5),
                Text(description, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Semantics(
            label: '${context.l10n.pluginOpen} $title',
            child: DesktopActionButton(
              key: Key('plugin-open-${plugin.name}'),
              label: context.l10n.pluginOpen,
              icon: Icons.chevron_right,
              tone: DesktopActionTone.neutral,
              onPressed: () => setState(() => _selected = plugin),
            ),
          ),
        ],
      ),
    ),
  );
}
