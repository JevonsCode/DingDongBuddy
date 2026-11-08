/// Describes why DingDong surfaced an Agent update.
///
/// A Codex Stop hook means that the current turn stopped. It does not always
/// mean that the whole task is complete; the Agent may be waiting for input.
enum AgentNotificationKind {
  completion('completion'),
  attention('attention');

  const AgentNotificationKind(this.apiValue);

  final String apiValue;

  /// Spellings Agents and hosts use for "the user must act now". Claude Code
  /// reports `permission_prompt`, `idle_prompt` and `elicitation_dialog` as a
  /// Notification hook's `notification_type`; Agents calling dingdong_notify
  /// sometimes describe the kind instead of using the enum value.
  static const Set<String> _attentionAliases = <String>{
    'attention',
    'needs_attention',
    'needs_input',
    'input',
    'input_required',
    'action_required',
    'question',
    'ask',
    'blocked',
    'waiting',
    'approval',
    'permission',
    'permission_prompt',
    'permission_request',
    'idle_prompt',
    'elicitation_dialog',
  };

  static AgentNotificationKind parse(Object? value) =>
      tryParse(value) ?? AgentNotificationKind.completion;

  /// The kind [value] names, or null when it names neither kind.
  static AgentNotificationKind? tryParse(Object? value) {
    final String normalized = value is String
        ? value.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_')
        : '';
    if (normalized.isEmpty) return null;
    if (_attentionAliases.contains(normalized)) {
      return AgentNotificationKind.attention;
    }
    return normalized == AgentNotificationKind.completion.apiValue
        ? AgentNotificationKind.completion
        : null;
  }
}
