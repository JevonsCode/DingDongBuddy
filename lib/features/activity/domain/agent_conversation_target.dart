/// Supported destinations for returning from DingDong to an Agent session.
enum AgentClient {
  codex('codex'),
  claudeCode('claude-code'),
  cursor('cursor'),
  geminiCli('gemini-cli'),
  kiro('kiro'),
  unknown('unknown');

  const AgentClient(this.apiValue);

  final String apiValue;

  static AgentClient fromSource(String source) {
    final String normalized = source.trim().toLowerCase();
    if (normalized.contains('claude')) {
      return AgentClient.claudeCode;
    }
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
  });

  factory AgentConversationTarget.fromJson(Map<String, Object?> json) {
    return AgentConversationTarget(
      client: AgentClient.parse(json['client']),
      conversationId: _trimmed(json['conversationId']),
      workspacePath: _trimmed(json['workspacePath']),
    );
  }

  final AgentClient client;
  final String? conversationId;
  final String? workspacePath;

  bool get hasDestination =>
      client != AgentClient.unknown &&
      (conversationId != null || workspacePath != null);

  AgentConversationTarget merge(AgentConversationTarget newer) {
    return AgentConversationTarget(
      client: newer.client == AgentClient.unknown ? client : newer.client,
      conversationId: newer.conversationId ?? conversationId,
      workspacePath: newer.workspacePath ?? workspacePath,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'client': client.apiValue,
    if (conversationId != null) 'conversationId': conversationId,
    if (workspacePath != null) 'workspacePath': workspacePath,
  };
}

String? _trimmed(Object? value) {
  if (value is! String) {
    return null;
  }
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Opens an allow-listed Agent destination on the local desktop.
abstract interface class AgentConversationLauncher {
  bool canOpen(AgentConversationTarget target);

  Future<void> open(AgentConversationTarget target);
}
