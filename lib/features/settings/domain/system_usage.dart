enum SystemDataCategory {
  clipboardHistory,
  resourceLibrary,
  agentActivity,
  adapterHistory,
  configuration,
  other;

  String get id => switch (this) {
    SystemDataCategory.clipboardHistory => 'clipboard-history',
    SystemDataCategory.resourceLibrary => 'resource-library',
    SystemDataCategory.agentActivity => 'agent-activity',
    SystemDataCategory.adapterHistory => 'adapter-history',
    SystemDataCategory.configuration => 'configuration',
    SystemDataCategory.other => 'other',
  };

  bool get canClear => switch (this) {
    SystemDataCategory.clipboardHistory ||
    SystemDataCategory.agentActivity ||
    SystemDataCategory.adapterHistory => true,
    SystemDataCategory.resourceLibrary ||
    SystemDataCategory.configuration ||
    SystemDataCategory.other => false,
  };
}

SystemDataCategory? systemDataCategoryFromId(String value) {
  for (final SystemDataCategory category in SystemDataCategory.values) {
    if (category.id == value) {
      return category;
    }
  }
  return null;
}

/// Current process and durable application storage footprint.
final class SystemUsageSnapshot {
  const SystemUsageSnapshot({
    required this.residentMemoryBytes,
    required this.storageBytes,
    this.storageByCategory = const <SystemDataCategory, int>{},
  });

  final int residentMemoryBytes;
  final int storageBytes;
  final Map<SystemDataCategory, int> storageByCategory;

  int bytesFor(SystemDataCategory category) => storageByCategory[category] ?? 0;
}

/// Platform seam for gathering potentially expensive usage information.
abstract interface class SystemUsageSource {
  Future<SystemUsageSnapshot> load();
}

/// Clears only categories that the primary application can update safely.
abstract interface class SystemDataCleaner {
  Future<void> clear(Set<SystemDataCategory> categories);
}
