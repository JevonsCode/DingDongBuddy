import 'dart:async';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_file_service.dart';

/// Public persistence seam used by library features.
abstract interface class ResourceStore {
  Future<List<Resource>> load();

  Future<void> save(List<Resource> resources);
}

/// Optional atomic mutation seam for high-frequency usage metadata. It avoids
/// replacing newer delivery/scope configuration with a stale Bridge snapshot.
abstract interface class ResourceUsageStore {
  Future<List<Resource>> recordUsage(Set<String> resourceIds, DateTime usedAt);
}

/// Optional atomic mutation seam for resources returned as task candidates.
/// Candidate delivery is tracked separately from confirmed loading or calls.
abstract interface class ResourceCandidateStore {
  Future<List<Resource>> recordCandidates(
    Set<String> resourceIds,
    DateTime candidateAt,
  );
}

/// Optional atomic mutation seam for confirmed tool invocations. This remains
/// separate from activation metadata so availability never impersonates use.
abstract interface class ResourceInvocationStore {
  Future<List<Resource>> recordInvocation(
    Set<String> resourceIds,
    DateTime invokedAt,
  );
}

/// Serializes read-modify-write workflows against every window/process that
/// uses the same file-backed resource library.
abstract interface class ExclusiveResourceStore {
  Future<T> exclusiveMutation<T>(Future<T> Function() action);
}

abstract interface class ResourceFileLocator {
  File? get resourceFile;
}

/// File-backed source of truth for shared resources.
final class ResourceRepository
    implements ResourceStore, ExclusiveResourceStore, ResourceFileLocator {
  ResourceRepository(this._service);

  final ResourceFileService _service;

  @override
  File get resourceFile => _service.file;

  Future<T> exclusive<T>(Future<T> Function() action) =>
      _service.exclusive(action);

  @override
  Future<T> exclusiveMutation<T>(Future<T> Function() action) =>
      exclusive(action);

  @override
  Future<List<Resource>> load() => _service.readResources();

  @override
  Future<void> save(List<Resource> resources) =>
      _service.writeAtomically(resources);
}

/// Volatile store used by previews and before a platform data path is ready.
final class InMemoryResourceStore
    implements
        ResourceStore,
        ResourceCandidateStore,
        ResourceUsageStore,
        ResourceInvocationStore,
        ExclusiveResourceStore,
        ResourceFileLocator {
  InMemoryResourceStore([List<Resource> resources = const <Resource>[]])
    : _resources = List<Resource>.of(resources);

  List<Resource> _resources;
  Future<void> _mutationBarrier = Future<void>.value();

  @override
  File? get resourceFile => null;

  @override
  Future<T> exclusiveMutation<T>(Future<T> Function() action) async {
    final Future<void> previous = _mutationBarrier;
    final Completer<void> gate = Completer<void>();
    _mutationBarrier = gate.future;
    await previous;
    try {
      return await action();
    } finally {
      gate.complete();
    }
  }

  @override
  Future<List<Resource>> load() async => List<Resource>.of(_resources);

  @override
  Future<void> save(List<Resource> resources) async {
    _resources = List<Resource>.of(resources);
  }

  @override
  Future<List<Resource>> recordUsage(
    Set<String> resourceIds,
    DateTime usedAt,
  ) async {
    _resources = _resources
        .map(
          (Resource resource) => resourceIds.contains(resource.id)
              ? resource.copyWith(
                  usageCount: resource.usageCount + 1,
                  lastUsedAt: usedAt,
                )
              : resource,
        )
        .toList(growable: false);
    return List<Resource>.of(_resources);
  }

  @override
  Future<List<Resource>> recordCandidates(
    Set<String> resourceIds,
    DateTime candidateAt,
  ) async {
    _resources = _resources
        .map(
          (Resource resource) => resourceIds.contains(resource.id)
              ? resource.copyWith(
                  candidateCount: resource.candidateCount + 1,
                  lastCandidateAt: candidateAt,
                )
              : resource,
        )
        .toList(growable: false);
    return List<Resource>.of(_resources);
  }

  @override
  Future<List<Resource>> recordInvocation(
    Set<String> resourceIds,
    DateTime invokedAt,
  ) async {
    _resources = _resources
        .map(
          (Resource resource) => resourceIds.contains(resource.id)
              ? resource.copyWith(
                  invocationCount: resource.invocationCount + 1,
                  lastInvokedAt: invokedAt,
                )
              : resource,
        )
        .toList(growable: false);
    return List<Resource>.of(_resources);
  }
}
