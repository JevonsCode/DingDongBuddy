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
        SkillVersionStore,
        ResourceFileLocator {
  SynchronizedResourceStore(
    this._delegate,
    this._synchronizer, {
    this.issueCenter,
    this.onChanged,
    SkillVersionHistory? skillVersionHistory,
  }) : _skillVersionHistory =
           skillVersionHistory ??
           (_delegate is ResourceFileLocator &&
                   (_delegate as ResourceFileLocator).resourceFile != null
               ? SkillVersionHistory(
                   Directory(
                     path.join(
                       (_delegate as ResourceFileLocator)
                           .resourceFile!
                           .parent
                           .path,
                       'Skill History',
                     ),
                   ),
                 )
               : SkillVersionHistory.memory()) {
    final Directory? historyRoot = _skillVersionHistory.root;
    if (historyRoot != null &&
        (path.equals(
              path.canonicalize(historyRoot.path),
              path.canonicalize(_synchronizer.packageRoot.path),
            ) ||
            path.isWithin(
              path.canonicalize(_synchronizer.packageRoot.path),
              path.canonicalize(historyRoot.path),
            ))) {
      throw ArgumentError(
        'Skill history must be stored outside the package cleanup root.',
      );
    }
  }

  final ResourceStore _delegate;
  final AgentResourceSynchronizer _synchronizer;
  final IssueCenterController? issueCenter;
  final void Function()? onChanged;
  final SkillVersionHistory _skillVersionHistory;
  List<Resource>? _lastLoaded;
  static final Object _mutationZoneKey = Object();

  @override
  File? get resourceFile {
    final ResourceStore delegate = _delegate;
    return delegate is ResourceFileLocator
        ? (delegate as ResourceFileLocator).resourceFile
        : null;
  }

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final ResourceStore delegate = _delegate;
    final Set<ResourceStore> held =
        Zone.current[_mutationZoneKey] as Set<ResourceStore>? ??
        const <ResourceStore>{};
    if (held.contains(delegate)) return action();
    Future<T> lockedAction() => runZoned(
      action,
      zoneValues: <Object, Object>{
        _mutationZoneKey: <ResourceStore>{...held, delegate},
      },
    );
    if (delegate is ResourceRepository) {
      return delegate.exclusive(lockedAction);
    }
    if (delegate is ExclusiveResourceStore) {
      return (delegate as ExclusiveResourceStore).exclusiveMutation(
        lockedAction,
      );
    }
    return lockedAction();
  }

  @override
  Future<T> exclusiveMutation<T>(Future<T> Function() action) =>
      _exclusive(action);

  @override
  Future<List<Resource>> load() => _exclusive(() async {
    final List<Resource> resources = await _delegate.load();
    final SkillHistoryTransaction baseline = await _skillVersionHistory.prepare(
      const <Resource>[],
      resources,
      source: SkillVersionSource.initial,
      baselineOnly: true,
    );
    await baseline.commit();
    _lastLoaded = List<Resource>.of(resources);
    return resources;
  });

  @override
  Future<void> save(List<Resource> resources) =>
      _exclusive(() => _saveLocked(resources));

  @override
  Future<void> saveWithSkillVersionSource(
    List<Resource> resources, {
    required SkillVersionSource source,
  }) => _exclusive(() => _saveLocked(resources, source: source));

  @override
  Future<List<SkillVersion>> loadSkillVersions(String resourceId) =>
      _exclusive(() async {
        final List<Resource> resources = await _delegate.load();
        final SkillHistoryTransaction baseline = await _skillVersionHistory
            .prepare(
              const <Resource>[],
              resources,
              source: SkillVersionSource.initial,
              baselineOnly: true,
            );
        await baseline.commit();
        return _skillVersionHistory.versions(resourceId);
      });

  @override
  Future<SkillSnapshot> loadSkillSnapshot(String snapshotId) =>
      _exclusive(() => _skillVersionHistory.snapshot(snapshotId));

  @override
  Future<void> restoreSkillVersion(
    String resourceId,
    int version,
  ) => _exclusive(() async {
    final List<Resource> current = await _delegate.load();
    final int index = current.indexWhere(
      (Resource resource) =>
          resource.id == resourceId && resource.type == ResourceType.skill,
    );
    if (index < 0) throw StateError('The Skill no longer exists.');
    final List<SkillVersion> versions = await _skillVersionHistory.versions(
      resourceId,
    );
    final SkillVersion selected = versions.firstWhere(
      (SkillVersion item) => item.number == version,
      orElse: () => throw StateError('The Skill version no longer exists.'),
    );
    final SkillSnapshot snapshot = await _skillVersionHistory.snapshot(
      selected.snapshotId,
    );
    final Resource active = current[index];
    SkillPackageInstallResult? installed;
    Directory? staging;
    final GitHubSkillPackageInstaller installer = GitHubSkillPackageInstaller(
      _synchronizer.packageRoot,
      preserveAllFiles: true,
    );
    try {
      final bool needsNativePackage = active.skillDeliveryByAgent.values.any(
        (SkillDeliveryMode mode) => mode != SkillDeliveryMode.dynamic,
      );
      if (snapshot.hasPackage || needsNativePackage) {
        staging = await _skillVersionHistory.materialize(snapshot);
        installed = await installer.installForResource(
          staging.uri,
          // Native deployment digests exclude their receipt file; snapshot
          // identity still distinguishes every byte retained by history.
          resourceId: _skillVersionHistory.resourceKey(
            '$resourceId:${selected.snapshotId}',
          ),
        );
      }
      final List<Resource> updated = List<Resource>.of(current);
      updated[index] = active.copyWith(
        title: snapshot.title,
        content: snapshot.document,
        updateUrl: snapshot.sourceUrl ?? '',
        packagePath: installed?.directoryPath ?? '',
        skillPackageDigest: installed?.packageDigest,
        updatedAt: DateTime.now(),
      );
      await _saveLocked(
        updated,
        source: SkillVersionSource.restored,
        restoredResourceId: resourceId,
        restoredFrom: version,
        freshBase: current,
      );
    } on Object {
      if (installed != null && installed.directoryPath != active.packagePath) {
        await installer.rollback(installed);
      }
      rethrow;
    } finally {
      if (staging != null && await staging.exists()) {
        await staging.delete(recursive: true);
      }
    }
  });

  Future<void> _saveLocked(
    List<Resource> resources, {
    SkillVersionSource? source,
    String? restoredResourceId,
    int? restoredFrom,
    List<Resource>? freshBase,
  }) async {
    final List<Resource> previous = await _delegate.load();
    final List<Resource> proposed = _mergeConcurrentResources(
      base: freshBase ?? _lastLoaded ?? previous,
      current: previous,
      proposed: resources,
    );
    final SkillHistoryTransaction history = await _skillVersionHistory.prepare(
      previous,
      proposed,
      source: source,
      restoredResourceId: restoredResourceId,
      restoredFrom: restoredFrom,
    );
    await _delegate.save(proposed);
    try {
      final List<AppIssue>? issues =
          _onlyAgentResourceUsageChanged(previous, proposed)
          ? null
          : await _synchronizer.sync(proposed);
      await history.commit();
      if (issues != null) {
        issueCenter?.replaceSource(agentResourceSyncIssueSource, issues);
      }
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
      await history.rollback();
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
    // Disposal follows the durable resource + Agent + history commit. A cleanup
    // failure must not roll back to an artifact that was already partly removed.
    try {
      await _cleanupRemovedPackages(previous, proposed);
    } on FileSystemException {
      // A later replacement/deletion can retry disposal; history stays intact.
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
      if (path.isWithin(managedRoot, path.canonicalize(generated.path)) &&
          !active.contains(path.canonicalize(generated.path)) &&
          await generated.exists()) {
        await generated.delete(recursive: true);
      }
      if (resource.type == ResourceType.skill &&
          resource.updateUrl != null &&
          resource.packagePath == null &&
          !activeSkillNames.contains(_skillName(resource))) {
        final Directory downloaded = Directory(
          path.join(_synchronizer.packageRoot.path, _skillName(resource)),
        );
        if (path.isWithin(managedRoot, path.canonicalize(downloaded.path)) &&
            !active.contains(path.canonicalize(downloaded.path)) &&
            await downloaded.exists()) {
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
