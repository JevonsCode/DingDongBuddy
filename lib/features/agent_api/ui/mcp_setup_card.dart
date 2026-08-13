import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

/// Built-in, copy-only instructions for connecting an external Agent.
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
          context.localized('Agent setup prompt', '给 Agent 的接入提示词'),
          style: TextStyle(
            color: PopupStyle.of(context).textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          key: const Key('agent-api-setup-prompt'),
          constraints: const BoxConstraints(maxHeight: 250),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PopupStyle.of(context).field,
            borderRadius: BorderRadius.circular(6),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              widget.settingsViewModel.mcpSetupPrompt,
              style: TextStyle(
                color: PopupStyle.of(context).textPrimary,
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.4,
              ),
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
              label: _copied
                  ? context.localized('Copied', '已复制')
                  : context.localized('Copy', '复制'),
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
                label: context.localized('Mark as updated', '标记为已更新'),
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
      label: context.localized(
        'Agent setup prompt needs updating',
        'Agent 接入提示词需要更新',
      ),
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
                    context.localized(
                      'Update the Agent setup prompt',
                      '更新 Agent 接入提示词',
                    ),
                    style: TextStyle(
                      color: palette.warmAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.localized(
                      'Send this prompt to every connected Agent. After they reconnect, mark the update as complete below.',
                      '把这份提示词发给每个已接入的 Agent；它们重新接入完成后，再在下方标记为已更新。',
                    ),
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
