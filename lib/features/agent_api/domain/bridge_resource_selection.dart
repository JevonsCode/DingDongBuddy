/// Already enabled, scoped and delivery-eligible metadata. No resource bodies,
/// tool configurations or private history may enter this contract.
final class BridgeResourceCandidate {
  const BridgeResourceCandidate({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.version,
  });
  final String id;
  final String type;
  final String title;
  final String description;
  final String version;
}

final class BridgeResourceSelectionRequest {
  const BridgeResourceSelectionRequest({
    required this.task,
    required this.source,
    required this.workspacePath,
    required this.repositoryUrl,
    required this.conversationId,
    required this.candidates,
    this.taskContext = '',
  });
  final String task;
  final String taskContext;
  final String source;
  final String workspacePath;
  final String repositoryUrl;
  final String conversationId;
  final List<BridgeResourceCandidate> candidates;
}

/// Null means retain the original deterministic catalog. An empty set is a
/// confident selection of no optional resources. Required resources bypass it.
typedef BridgeResourceSelector =
    Future<Set<String>?> Function(BridgeResourceSelectionRequest request);
