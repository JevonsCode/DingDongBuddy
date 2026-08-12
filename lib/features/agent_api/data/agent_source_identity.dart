/// Resolves the user-facing source supplied at the Bridge boundary to the
/// stable Agent Adapter id used by Skill delivery policy.
///
/// Unknown sources deliberately remain unknown. Treating a generic caller as
/// a supported Adapter could expose a dynamic Skill while a native copy is
/// still present, which is less safe than temporarily withholding it.
String? resolveAgentAdapterId(String source) {
  final String normalized = source
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  return switch (normalized) {
    'codex' || 'codex-cli' || 'codex-desktop' || 'openai-codex' => 'codex',
    'claude' || 'claude-code' || 'anthropic-claude' => 'claude-code',
    'cursor' || 'cursor-agent' => 'cursor',
    'gemini' || 'gemini-cli' || 'google-gemini' => 'gemini',
    'grok' || 'grok-build' => 'grok-build',
    'kiro' || 'kiro-cli' => 'kiro',
    'pi' || 'pi-coding-agent' => 'pi',
    _ => null,
  };
}

/// Infers the caller name from stable environment signals set by supported
/// Agent clients. Explicit session identifiers win over generic identity
/// flags so a nested process keeps the identity of the active conversation.
String? inferAgentSourceFromEnvironment(Map<String, String> environment) {
  bool hasValue(String key) => (environment[key] ?? '').trim().isNotEmpty;

  if (hasValue('CODEX_THREAD_ID')) {
    return 'Codex';
  }
  if (hasValue('CLAUDE_SESSION_ID') || environment.containsKey('CLAUDECODE')) {
    return 'Claude Code';
  }
  if (hasValue('CURSOR_SESSION_ID')) {
    return 'Cursor';
  }
  if (hasValue('GEMINI_SESSION_ID')) {
    return 'Gemini CLI';
  }
  if (hasValue('KIRO_SESSION_ID')) {
    return 'Kiro';
  }
  final String aiAgent = (environment['AI_AGENT'] ?? '').trim().toLowerCase();
  final String piFlag = (environment['PI_CODING_AGENT'] ?? '')
      .trim()
      .toLowerCase();
  if (aiAgent == 'pi' || piFlag == 'true' || piFlag == '1') {
    return 'Pi';
  }
  return null;
}
