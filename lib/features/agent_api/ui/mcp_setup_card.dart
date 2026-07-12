import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

/// Editable, persistent instructions for connecting an external Agent.
class McpSetupCard extends StatefulWidget {
  const McpSetupCard({
    required this.settingsViewModel,
    this.clipboardGateway,
    super.key,
  });

  final SettingsViewModel settingsViewModel;
  final ClipboardGateway? clipboardGateway;

  @override
  State<McpSetupCard> createState() => _McpSetupCardState();
}

class _McpSetupCardState extends State<McpSetupCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.settingsViewModel.mcpSetupPrompt,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.localized('Agent setup prompt', '给 Agent 的接入提示词'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('agent-api-setup-prompt'),
            controller: _controller,
            minLines: 7,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: () async {
                  await widget.settingsViewModel.resetMcpSetupPrompt();
                  _controller.text = widget.settingsViewModel.mcpSetupPrompt;
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(context.localized('Reset', '恢复默认')),
              ),
              OutlinedButton.icon(
                onPressed: widget.clipboardGateway == null
                    ? null
                    : () =>
                          widget.clipboardGateway!.writeText(_controller.text),
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: Text(context.localized('Copy', '复制')),
              ),
              FilledButton.icon(
                key: const Key('agent-api-save-prompt'),
                onPressed: () => widget.settingsViewModel.setMcpSetupPrompt(
                  _controller.text,
                ),
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(context.localized('Save', '保存')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
