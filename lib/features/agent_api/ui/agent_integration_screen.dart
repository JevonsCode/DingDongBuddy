import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/features/agent_adapters/ui/agent_adapter_controller.dart';
import 'package:dingdong/features/agent_adapters/ui/agent_adapter_screen.dart';
import 'package:dingdong/features/agent_api/domain/agent_install.dart';
import 'package:dingdong/features/agent_api/ui/agent_install_card.dart';
import 'package:flutter/material.dart';

/// The same installer is used from the popup and Resource Manager.
class AgentIntegrationScreen extends StatefulWidget {
  const AgentIntegrationScreen({
    required this.gateway,
    this.adapterController,
    super.key,
  });

  final AgentInstallGateway gateway;
  final AgentAdapterController? adapterController;

  @override
  State<AgentIntegrationScreen> createState() => _AgentIntegrationScreenState();
}

class _AgentIntegrationScreenState extends State<AgentIntegrationScreen> {
  bool _advanced = false;

  @override
  Widget build(BuildContext context) {
    if (_advanced) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: DesktopActionButton(
                icon: Icons.arrow_back_rounded,
                label: context.l10n.agentConnections,
                onPressed: () => setState(() => _advanced = false),
              ),
            ),
          ),
          Expanded(
            child: AgentAdapterScreen(controller: widget.adapterController!),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.agentConnections,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 24),
                AgentInstallCard(gateway: widget.gateway),
                if (widget.adapterController != null) ...[
                  const SizedBox(height: 24),
                  DesktopActionButton(
                    key: const Key('agent-integration-advanced'),
                    label: context.l10n.agentInstallAdvancedAdapters,
                    onPressed: () => setState(() => _advanced = true),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
