import 'package:flutter/foundation.dart';

/// Supported destinations for returning from DingDong to an Agent session.
enum AgentClient {
  codex('codex'),
  claudeCode('claude-code'),
  claudeDesktop('claude-desktop'),
  cursor('cursor'),
  geminiCli('gemini-cli'),
  kiro('kiro'),
  pi('pi'),
  openCode('opencode'),
  openCodeCli('opencode-cli'),
  openCodeDesktop('opencode-desktop'),
  antigravity('antigravity'),
  antigravityCli('antigravity-cli'),
  antigravityIde('antigravity-ide'),
  antigravityApp('antigravity-app'),
  copilot('copilot'),
  copilotCli('copilot-cli'),
  copilotIde('copilot-ide'),
  grokBuild('grok-build'),
  windsurf('windsurf'),
  unknown('unknown');

  const AgentClient(this.apiValue);

  final String apiValue;

  static AgentClient fromSource(String source) {
    final String normalized = source.trim().toLowerCase();
    if (normalized.contains('claude')) {
      if (normalized.contains('desktop')) {
        return AgentClient.claudeDesktop;
      }
      return AgentClient.claudeCode;
    }
    if (normalized.contains('opencode') || normalized.contains('open code')) {
      if (normalized.contains('desktop')) return AgentClient.openCodeDesktop;
      if (normalized.contains('cli') || normalized.contains('terminal')) {
        return AgentClient.openCodeCli;
      }
      return AgentClient.openCode;
    }
    if (normalized.contains('antigravity') || normalized == 'agy') {
      if (normalized.contains('cli') || normalized == 'agy') {
        return AgentClient.antigravityCli;
      }
      if (normalized.contains('ide')) return AgentClient.antigravityIde;
      if (normalized.contains('desktop') || normalized.contains('app')) {
        return AgentClient.antigravityApp;
      }
      return AgentClient.antigravity;
    }
    if (normalized.contains('copilot')) {
      if (normalized.contains('cli') || normalized.contains('terminal')) {
        return AgentClient.copilotCli;
      }
      if (normalized.contains('code') || normalized.contains('ide')) {
        return AgentClient.copilotIde;
      }
      return AgentClient.copilot;
    }
    if (normalized == 'pi' ||
        normalized == 'pi-coding-agent' ||
        normalized == 'pi coding agent') {
      return AgentClient.pi;
    }
    if (normalized == 'grok-build' ||
        normalized == 'grok build' ||
        normalized == 'grok build cli' ||
        normalized == 'grok-build-cli') {
      return AgentClient.grokBuild;
    }
    if (normalized.contains('windsurf')) return AgentClient.windsurf;
    if (normalized.contains('cursor')) {
      return AgentClient.cursor;
    }
    if (normalized.contains('gemini')) {
      return AgentClient.geminiCli;
    }
    if (normalized.contains('kiro')) {
      return AgentClient.kiro;
    }
    if (normalized.contains('codex')) {
      return AgentClient.codex;
    }
    return AgentClient.unknown;
  }

  static AgentClient parse(Object? value) {
    if (value is! String) {
      return AgentClient.unknown;
    }
    final String normalized = value.trim().toLowerCase();
    final AgentClient exact = values.firstWhere(
      (AgentClient client) => client.apiValue == normalized,
      orElse: () => AgentClient.unknown,
    );
    return exact == AgentClient.unknown ? fromSource(normalized) : exact;
  }
}

/// A structured, non-executable destination captured from a trusted Agent hook.
///
/// DingDong deliberately stores identifiers instead of arbitrary URLs or shell
/// commands. The platform launcher maps these values to an allow-listed client.
final class AgentConversationTarget {
  const AgentConversationTarget({
    required this.client,
    this.conversationId,
    this.workspacePath,
    this.hostSessionId,
  });

  factory AgentConversationTarget.fromJson(Map<String, Object?> json) {
    return AgentConversationTarget(
      client: AgentClient.parse(json['client']),
      conversationId: _trimmed(json['conversationId']),
      workspacePath: _trimmed(json['workspacePath']),
      hostSessionId: _trimmed(json['hostSessionId']),
    );
  }

  final AgentClient client;
  final String? conversationId;
  final String? workspacePath;

  /// Claude Desktop's native session ID, distinct from the CLI transcript ID.
  final String? hostSessionId;

  bool get hasDestination =>
      client != AgentClient.unknown &&
      (conversationId != null ||
          workspacePath != null ||
          hostSessionId != null);

  AgentConversationTarget merge(AgentConversationTarget newer) {
    return AgentConversationTarget(
      client: newer.client == AgentClient.unknown ? client : newer.client,
      conversationId: newer.conversationId ?? conversationId,
      workspacePath: newer.workspacePath ?? workspacePath,
      hostSessionId:
          newer.hostSessionId ??
          (newer.client == client || newer.client == AgentClient.unknown
              ? hostSessionId
              : null),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'client': client.apiValue,
    if (conversationId != null) 'conversationId': conversationId,
    if (workspacePath != null) 'workspacePath': workspacePath,
    if (hostSessionId != null) 'hostSessionId': hostSessionId,
  };
}

/// Results from the read-only Agent conversation preflight.
///
/// A background Codex worker is intentionally separate from an unknown or
/// missing conversation: both are non-openable, but only the former should be
/// labeled as a subagent in the activity UI.
final class AgentConversationPreflightResult {
  const AgentConversationPreflightResult({
    this.openableConversationIds = const <String>{},
    this.subagentConversationIds = const <String>{},
  });

  final Set<String> openableConversationIds;
  final Set<String> subagentConversationIds;
}

String? _trimmed(Object? value) {
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Opens an allow-listed Agent destination on the local desktop.
abstract interface class AgentConversationLauncher extends Listenable {
  bool canOpen(AgentConversationTarget target);

  bool isSubagent(AgentConversationTarget target);

  Future<void> open(AgentConversationTarget target);
}
