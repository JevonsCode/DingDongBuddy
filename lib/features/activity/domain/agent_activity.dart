/// One locally observed Agent completion shown in the Dynamic workspace.
final class AgentActivity {
  const AgentActivity({
    required this.id,
    required this.source,
    required this.message,
    required this.completedAt,
    required this.unseen,
  });

  final String id;
  final String source;
  final String message;
  final DateTime completedAt;
  final bool unseen;

  AgentActivity seen() => AgentActivity(
    id: id,
    source: source,
    message: message,
    completedAt: completedAt,
    unseen: false,
  );
}
