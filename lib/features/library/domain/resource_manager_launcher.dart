enum ResourceManagerDestination {
  resources,
  clipboard,
  recentAgents;

  static ResourceManagerDestination parse(Object? value) {
    return values.firstWhere(
      (ResourceManagerDestination destination) => destination.name == value,
      orElse: () => ResourceManagerDestination.resources,
    );
  }
}

/// Opens the full resource management experience in its own desktop window.
abstract interface class ResourceManagerLauncher {
  Future<void> show({
    String? editingResourceId,
    ResourceManagerDestination destination =
        ResourceManagerDestination.resources,
  });
}
