part of 'agent_resource_synchronizer.dart';

// Persist synchronized resources and trigger groups with serialized writes.
final class SynchronizedResourceStore
    implements
        ResourceStore,
        ResourceCandidateStore,
        ResourceDeliveryStore,
        ResourceUsageStore,
        ResourceInvocationStore,
        ExclusiveResourceStore,
        ResourceFileLocator {
  SynchronizedResourceStore(
    this._delegate,
    this._synchronizer, {
    this.issueCenter,
    this.onChanged,
  });

  final ResourceStore _delegate;
  final AgentResourceSynchronizer _synchronizer;
  final IssueCenterController? issueCenter;
  final void Function()? onChanged;
  List<Resource>? _lastLoaded;

  @override
  File? get resourceFile {
    final ResourceStore delegate = _delegate;
    return delegate is ResourceFileLocator
        ? (delegate as ResourceFileLocator).resourceFile
        : null;
  }

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final ResourceStore delegate = _delegate;
    if (delegate is ResourceRepository) {
      return delegate.exclusive(action);
    }
    return action();
  }

  @override
  Future<T> exclusiveMutation<T>(Future<T> Function() action) =>
      _exclusive(action);

  @override
  Future<List<Resource>> load() async {
    final List<Resource> resources = await _delegate.load();
    _lastLoaded = List<Resource>.of(resources);
    return resources;
  }

  @override
  Future<void> save(List<Resource> resources) =>
      _exclusive(() => _saveLocked(resources));

  Future<void> _saveLocked(List<Resource> resources) async {
    final List<Resource> previous = await _delegate.load();
    final List<Resource> proposed = _mergeConcurrentResources(
      base: _lastLoaded ?? previous,
      current: previous,
      proposed: resources,
    );
    await _delegate.save(proposed);
    if (_onlyAgentResourceUsageChanged(previous, proposed)) {
      _lastLoaded = List<Resource>.of(proposed);
      onChanged?.call();
      return;
    }
    try {
      final List<AppIssue> issues = await _synchronizer.sync(proposed);
      await _cleanupRemovedPackages(previous, proposed);
      issueCenter?.replaceSource(agentResourceSyncIssueSource, issues);
    } on Object catch (error, stackTrace) {
      final List<AppIssue> issues = error is AppIssueException
          ? error.issues
          : <AppIssue>[
              AppIssue(
                id: _issueId(AppIssueKind.syncFailed, null, null),
                source: agentResourceSyncIssueSource,
                kind: AppIssueKind.syncFailed,
                severity: AppIssueSeverity.error,
                title: 'Agent resource sync failed',
                detail: error.toString(),
              ),
            ];
      await _delegate.save(previous);
      _lastLoaded = List<Resource>.of(previous);
      try {
        await _synchronizer.sync(previous);
      } on Object {
        // Preserve the original save failure; the resource file is rolled back.
      }
      await _cleanupRemovedPackages(proposed, previous);
      issueCenter?.replaceSource(agentResourceSyncIssueSource, issues);
      Error.throwWithStackTrace(error, stackTrace);
    }
    _lastLoaded = List<Resource>.of(proposed);
    onChanged?.call();
  }

  @override
  Future<List<Resource>> recordUsage(
    Set<String> resourceIds,
    DateTime usedAt,
  ) => _exclusive(() async {
    final List<Resource> latest = await _delegate.load();
    final List<Resource> updated = latest
        .map(
          (Resource resource) => resourceIds.contains(resource.id)
              ? resource.copyWith(
                  usageCount: resource.usageCount + 1,
                  lastUsedAt: usedAt,
                )
              : resource,
        )
        .toList(growable: false);
    await _delegate.save(updated);
    _lastLoaded = List<Resource>.of(updated);
    onChanged?.call();
    return updated;
  });

  @override
  Future<List<Resource>> recordCandidates(
    Set<String> resourceIds,
    DateTime candidateAt,
  ) => _exclusive(() async {
    final List<Resource> latest = await _delegate.load();
    final List<Resource> updated = latest
        .map(
          (Resource resource) => resourceIds.contains(resource.id)
              ? resource.copyWith(
                  candidateCount: resource.candidateCount + 1,
                  lastCandidateAt: candidateAt,
                )
              : resource,
        )
        .toList(growable: false);
    await _delegate.save(updated);
    _lastLoaded = List<Resource>.of(updated);
    onChanged?.call();
    return updated;
  });

  @override
  Future<List<Resource>> recordDelivery({
    required Set<String> usedResourceIds,
    required Set<String> candidateResourceIds,
    required DateTime deliveredAt,
  }) => _exclusive(() async {
    final List<Resource> latest = await _delegate.load();
    final List<Resource> updated = latest
        .map((Resource resource) {
          final bool used = usedResourceIds.contains(resource.id);
          final bool candidate = candidateResourceIds.contains(resource.id);
          if (!used && !candidate) {
            return resource;
          }
          return resource.copyWith(
            usageCount: used ? resource.usageCount + 1 : resource.usageCount,
            lastUsedAt: used ? deliveredAt : resource.lastUsedAt,
            candidateCount: candidate
                ? resource.candidateCount + 1
                : resource.candidateCount,
            lastCandidateAt: candidate ? deliveredAt : resource.lastCandidateAt,
          );
        })
        .toList(growable: false);
    await _delegate.save(updated);
    _lastLoaded = List<Resource>.of(updated);
    onChanged?.call();
    return updated;
  });

  @override
  Future<List<Resource>> recordInvocation(
    Set<String> resourceIds,
    DateTime invokedAt,
  ) => _exclusive(() async {
    final List<Resource> latest = await _delegate.load();
    final List<Resource> updated = latest
        .map(
          (Resource resource) => resourceIds.contains(resource.id)
              ? resource.copyWith(
                  invocationCount: resource.invocationCount + 1,
                  lastInvokedAt: invokedAt,
                )
              : resource,
        )
        .toList(growable: false);
    await _delegate.save(updated);
    _lastLoaded = List<Resource>.of(updated);
    onChanged?.call();
    return updated;
  });

  Future<void> _cleanupRemovedPackages(
    List<Resource> previous,
    List<Resource> current,
  ) async {
    final Set<String> active = current
        .map((Resource resource) => resource.packagePath)
        .whereType<String>()
        .map(path.canonicalize)
        .toSet();
    final String managedRoot = path.canonicalize(
      _synchronizer.packageRoot.path,
    );
    for (final String packagePath
        in previous
            .map((Resource resource) => resource.packagePath)
            .whereType<String>()) {
      final String canonical = path.canonicalize(packagePath);
      if (active.contains(canonical) ||
          !path.isWithin(managedRoot, canonical)) {
        continue;
      }
      final Directory directory = Directory(canonical);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
    final Set<String> currentIds = current
        .map((Resource resource) => resource.id)
        .toSet();
    final Set<String> activeSkillNames = current
        .where((Resource resource) => resource.type == ResourceType.skill)
        .map(_skillName)
        .toSet();
    for (final Resource resource in previous) {
      if (currentIds.contains(resource.id)) {
        continue;
      }
      final Directory generated = Directory(
        path.join(_synchronizer.packageRoot.path, resource.id),
      );
      if (await generated.exists()) {
        await generated.delete(recursive: true);
      }
      if (resource.type == ResourceType.skill &&
          resource.updateUrl != null &&
          resource.packagePath == null &&
          !activeSkillNames.contains(_skillName(resource))) {
        final Directory downloaded = Directory(
          path.join(_synchronizer.packageRoot.path, _skillName(resource)),
        );
        if (await downloaded.exists()) {
          await downloaded.delete(recursive: true);
        }
      }
    }
  }
}

/// Keeps native Agent MCP files in sync when a trigger group changes without
/// requiring an unrelated resource edit to occur first.
final class SynchronizedTriggerGroupStore implements TriggerGroupStore {
  SynchronizedTriggerGroupStore(
    this._delegate,
    this._resourceStore,
    this._synchronizer, {
    this.issueCenter,
  });

  final TriggerGroupStore _delegate;
  final ResourceStore _resourceStore;
  final AgentResourceSynchronizer _synchronizer;
  final IssueCenterController? issueCenter;

  @override
  Future<List<TriggerGroup>> load() => _delegate.load();

  @override
  Future<void> save(List<TriggerGroup> groups) async {
    final List<TriggerGroup> previous = await _delegate.load();
    await _delegate.save(groups);
    try {
      final List<AppIssue> issues = await _synchronizer.sync(
        await _resourceStore.load(),
      );
      issueCenter?.replaceSource(agentResourceSyncIssueSource, issues);
    } on Object catch (error, stackTrace) {
      final List<AppIssue> issues = error is AppIssueException
          ? error.issues
          : <AppIssue>[
              AppIssue(
                id: _issueId(AppIssueKind.syncFailed, null, null),
                source: agentResourceSyncIssueSource,
                kind: AppIssueKind.syncFailed,
                severity: AppIssueSeverity.error,
                title: 'Agent resource sync failed',
                detail: error.toString(),
              ),
            ];
      await _delegate.save(previous);
      try {
        await _synchronizer.sync(await _resourceStore.load());
      } on Object {
        // Preserve the original save failure; the trigger-group file is
        // rolled back even if native configuration recovery also fails.
      }
      issueCenter?.replaceSource(agentResourceSyncIssueSource, issues);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }
}
