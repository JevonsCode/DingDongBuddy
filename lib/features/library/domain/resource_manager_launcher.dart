/// Opens the full resource management experience in its own desktop window.
abstract interface class ResourceManagerLauncher {
  Future<void> show({String? editingResourceId});
}
