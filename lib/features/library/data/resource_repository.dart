import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_file_service.dart';

/// Public persistence seam used by library features.
abstract interface class ResourceStore {
  Future<List<Resource>> load();

  Future<void> save(List<Resource> resources);
}

/// File-backed source of truth for shared resources.
final class ResourceRepository implements ResourceStore {
  ResourceRepository(this._service);

  final ResourceFileService _service;

  @override
  Future<List<Resource>> load() => _service.readResources();

  @override
  Future<void> save(List<Resource> resources) =>
      _service.writeAtomically(resources);
}

/// Volatile store used by previews and before a platform data path is ready.
final class InMemoryResourceStore implements ResourceStore {
  InMemoryResourceStore([List<Resource> resources = const <Resource>[]])
    : _resources = List<Resource>.of(resources);

  List<Resource> _resources;

  @override
  Future<List<Resource>> load() async => List<Resource>.of(_resources);

  @override
  Future<void> save(List<Resource> resources) async {
    _resources = List<Resource>.of(resources);
  }
}
