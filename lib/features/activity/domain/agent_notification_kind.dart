/// Describes why DingDong surfaced an Agent update.
///
/// A Codex Stop hook means that the current turn stopped. It does not always
/// mean that the whole task is complete; the Agent may be waiting for input.
enum AgentNotificationKind {
  completion('completion'),
  attention('attention');

  const AgentNotificationKind(this.apiValue);

  final String apiValue;

  static AgentNotificationKind parse(Object? value) {
    final String normalized = value is String ? value.trim().toLowerCase() : '';
    return values.firstWhere(
      (AgentNotificationKind kind) => kind.apiValue == normalized,
      orElse: () => AgentNotificationKind.completion,
    );
  }
}
