/// One locally observed Agent completion shown in the Dynamic workspace.
final class AgentActivity {
  const AgentActivity({
    required this.id,
    required this.source,
    required this.message,
    required this.completedAt,
    required this.unseen,
  });

  factory AgentActivity.fromJson(Map<String, Object?> json) {
    return AgentActivity(
      id: json['id']! as String,
      source: json['source']! as String,
      message: json['message']! as String,
      completedAt: DateTime.parse(json['completedAt']! as String).toUtc(),
      unseen: json['unseen'] == true,
    );
  }

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

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'source': source,
    'message': message,
    'completedAt': completedAt.toUtc().toIso8601String(),
    'unseen': unseen,
  };
}
