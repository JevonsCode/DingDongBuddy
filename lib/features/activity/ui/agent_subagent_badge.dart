import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:flutter/material.dart';

/// Compact, non-interactive marker for a Codex background subagent.
///
/// This deliberately uses a rectangular decoration instead of Material ink so
/// the marker does not introduce a hover halo in either activity list.
final class AgentSubagentBadge extends StatelessWidget {
  const AgentSubagentBadge({
    this.compact = false,
    this.foregroundColor,
    this.backgroundColor,
    this.borderColor,
    super.key,
  });

  final bool compact;
  final Color? foregroundColor;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final Color foreground = foregroundColor ?? PopupStyle.accent;
    final Color background = backgroundColor ?? PopupStyle.accentSoft;
    return Tooltip(
      message: context.localized('Codex subagent', 'Codex 子代理'),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(compact ? 4 : 5),
          border: Border.all(
            color: borderColor ?? foreground.withValues(alpha: 0.22),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 5,
            vertical: compact ? 1.5 : 2,
          ),
          child: Text(
            'sub',
            key: const Key('agent-subagent-badge-label'),
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 8 : 9,
              height: 1.1,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }
}

/// Non-interactive marker for a conversation target that cannot be resolved.
///
/// The target may be missing from the local Agent index or may not be
/// openable anymore. It deliberately does not imply that the target is a
/// background subagent.
final class AgentUnknownConversationIcon extends StatelessWidget {
  const AgentUnknownConversationIcon({
    this.compact = false,
    this.color,
    super.key,
  });

  final bool compact;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final String message = context.localized(
      'Unknown Agent conversation',
      '未知 Agent 会话',
    );
    return Tooltip(
      message: message,
      child: Semantics(
        label: message,
        child: Icon(
          Icons.help_outline_rounded,
          size: compact ? 13 : 16,
          color: color ?? PopupStyle.textTertiary,
        ),
      ),
    );
  }
}
