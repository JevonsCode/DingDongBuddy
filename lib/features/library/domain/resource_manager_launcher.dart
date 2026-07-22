enum ResourceManagerDestination {
  resources,
  clipboard,
  recentAgents,
  issues;

  static ResourceManagerDestination parse(Object? value) {
    return values.firstWhere(
      (ResourceManagerDestination destination) => destination.name == value,
      orElse: () => ResourceManagerDestination.resources,
    );
  }
}

/// Multi-window signal emitted after the resource manager commits a library
/// change to shared storage.
const String resourceLibraryChangedMethod = 'resource_library_changed';

/// Opens the full resource management experience in its own desktop window.
abstract interface class ResourceManagerLauncher {
  Future<void> show({
    String? editingResourceId,
    ResourceManagerDestination destination =
        ResourceManagerDestination.resources,
  });
}
