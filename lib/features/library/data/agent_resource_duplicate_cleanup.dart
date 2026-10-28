part of 'agent_resource_synchronizer.dart';

extension DuplicateMcpCleanup on AgentResourceSynchronizer {
  /// Revalidates the configured target and endpoint inside the same locks as
  /// normal synchronization. The caller may save the exact snapshot privately.
  Future<void> removeDuplicateMcp(
    AppIssue issue,
    List<Resource> resources, {
    Future<void> Function(ManagedFileSnapshot snapshot)? beforeRemove,
  }) => SafeManagedFile(managedStateFile).exclusive(() async {
    await _reloadAdapterTargets();
    final List<AgentMcpTarget> targets = mcpTargets
        .where(
          (AgentMcpTarget target) =>
              target.kind != AgentMcpConfigKind.codexToml &&
              path.equals(
                target.file.absolute.path,
                File(issue.targetPath ?? '').absolute.path,
              ),
        )
        .toList(growable: false);
    if (targets.length != 1 ||
        issue.duplicateEntryName == null ||
        issue.kind != AppIssueKind.duplicateMcp) {
      throw StateError('The duplicate target changed. Check the issues again.');
    }
    final AgentMcpTarget target = targets.single;
    final List<Resource> mcps = _mcpResourcesForTarget(
      resources
          .where(
            (Resource resource) =>
                resource.enabled && resource.type == ResourceType.mcp,
          )
          .toList(),
      target,
      await _loadTriggerGroups(),
    );
    await SafeManagedFile(target.file).update((
      ManagedFileSnapshot snapshot,
    ) async {
      if (!snapshot.exists) {
        throw StateError('The Agent configuration no longer exists.');
      }
      final Object? decoded = decodeStrictJson(snapshot.contents);
      final String serversKey = _mcpServersKey(target.kind);
      if (decoded is! Map<String, Object?> ||
          decoded[serversKey] is! Map<String, Object?>) {
        throw const FormatException('The Agent MCP configuration is invalid.');
      }
      final Map<String, Object?> servers = Map<String, Object?>.of(
        decoded[serversKey]! as Map<String, Object?>,
      );
      final bool stillDuplicate = _duplicateMcpIssues(target, servers, mcps)
          .any(
            (AppIssue current) =>
                current.resourceId == issue.resourceId &&
                current.duplicateEntryName == issue.duplicateEntryName,
          );
      if (!stillDuplicate) {
        throw StateError('The duplicate changed. Check the issues again.');
      }
      await beforeRemove?.call(snapshot);
      servers.remove(issue.duplicateEntryName);
      decoded[serversKey] = servers;
      return '${const JsonEncoder.withIndent('  ').convert(decoded)}\n';
    }, validate: decodeStrictJson);
  });
}
