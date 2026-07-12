/// Current process and durable application storage footprint.
final class SystemUsageSnapshot {
  const SystemUsageSnapshot({
    required this.residentMemoryBytes,
    required this.storageBytes,
  });

  final int residentMemoryBytes;
  final int storageBytes;
}

/// Platform seam for gathering potentially expensive usage information.
abstract interface class SystemUsageSource {
  Future<SystemUsageSnapshot> load();
}
