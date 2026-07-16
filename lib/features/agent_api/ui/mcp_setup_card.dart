import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/theme/popup_style.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.localized('Agent setup prompt', '给 Agent 的接入提示词'),
          style: const TextStyle(
            color: PopupStyle.textPrimary,
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
            color: PopupStyle.field,
            borderRadius: BorderRadius.circular(6),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              widget.settingsViewModel.mcpSetupPrompt,
              style: const TextStyle(
                color: PopupStyle.textPrimary,
                fontFamily: 'monospace',
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ),
        ),
        const SizedBox(height: 9),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('agent-api-copy-setup-prompt'),
            onPressed: widget.clipboardGateway == null ? null : _copyPrompt,
            style: TextButton.styleFrom(
              foregroundColor: _copied
                  ? PopupStyle.success
                  : PopupStyle.textSecondary,
              backgroundColor: _copied
                  ? PopupStyle.success.withValues(alpha: 0.10)
                  : PopupStyle.field,
              minimumSize: const Size(0, 32),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            icon: Icon(
              _copied ? Icons.check_rounded : Icons.copy_rounded,
              size: 16,
            ),
            label: Text(
              _copied
                  ? context.localized('Copied', '已复制')
                  : context.localized('Copy', '复制'),
            ),
          ),
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
