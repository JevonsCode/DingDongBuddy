import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

/// Short built-in request for connecting a local Agent.
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
  Timer? _copyResetTimer;
  bool _copied = false;

  @override
  void dispose() {
    _copyResetTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool requiresUpdate =
        widget.settingsViewModel.settings.requiresAgentSetupUpdate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (requiresUpdate) ...<Widget>[
          const _AgentSetupUpdateNotice(),
          const SizedBox(height: 14),
        ],
        Text(
          context.l10n.agentSetupPrompt,
          style: TextStyle(
            color: PopupStyle.of(context).textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          context.l10n.pasteAgentSetupInstructionDescription,
          style: TextStyle(
            color: PopupStyle.of(context).textSecondary,
            fontSize: 10.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          key: const Key('agent-api-setup-prompt'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PopupStyle.of(context).field,
            borderRadius: BorderRadius.circular(6),
          ),
          child: SelectableText(
            widget.settingsViewModel.mcpSetupPrompt,
            style: TextStyle(
              color: PopupStyle.of(context).textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            DesktopActionButton(
              key: const Key('agent-api-copy-setup-prompt'),
              onPressed: widget.clipboardGateway == null ? null : _copyPrompt,
              icon: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 16,
              ),
              label: _copied ? context.l10n.copied : context.l10n.copy,
              tone: _copied
                  ? DesktopActionTone.soft
                  : DesktopActionTone.neutral,
              compact: true,
            ),
            if (requiresUpdate)
              DesktopActionButton(
                key: const Key('agent-api-mark-setup-updated'),
                onPressed: () =>
                    unawaited(widget.settingsViewModel.markAgentSetupUpdated()),
                icon: Icons.task_alt_rounded,
                label: context.l10n.markAsUpdated,
                tone: DesktopActionTone.soft,
                compact: true,
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _copyPrompt() async {
    await widget.clipboardGateway!.writeText(
      widget.settingsViewModel.mcpSetupPrompt,
    );
    if (!mounted) {
      return;
    }
    _copyResetTimer?.cancel();
    setState(() => _copied = true);
    _copyResetTimer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() => _copied = false);
      }
    });
  }
}

class _AgentSetupUpdateNotice extends StatelessWidget {
  const _AgentSetupUpdateNotice();

  @override
  Widget build(BuildContext context) {
    final PopupPalette palette = PopupStyle.of(context);
    return Semantics(
      container: true,
      label: context.l10n.agentSetupPromptNeedsUpdating,
      child: Container(
        key: const Key('agent-api-setup-update-notice'),
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: palette.warmSurface,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: palette.warmAccent.withValues(alpha: 0.25)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(Icons.update_rounded, size: 17, color: palette.warmAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.reconnectThisAgent,
                    style: TextStyle(
                      color: palette.warmAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context
                        .l10n
                        .sendTheOneLineSetupRequestToEachAffectedAgentMarkIt_3a68e15f,
                    style: TextStyle(
                      color: palette.textPrimary,
                      fontSize: 10.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
