enum SystemDataCategory {
  clipboardHistory,
  clipboardImages,
  clipboardText,
  clipboardFiles,
  clipboardArchive,
  resourceLibrary,
  agentActivity,
  adapterHistory,
  configuration,
  other;

  String get id => switch (this) {
    SystemDataCategory.clipboardHistory => 'clipboard-history',
    SystemDataCategory.clipboardImages => 'clipboard-images',
    SystemDataCategory.clipboardText => 'clipboard-text',
    SystemDataCategory.clipboardFiles => 'clipboard-files',
    SystemDataCategory.clipboardArchive => 'clipboard-archive',
    SystemDataCategory.resourceLibrary => 'resource-library',
    SystemDataCategory.agentActivity => 'agent-activity',
    SystemDataCategory.adapterHistory => 'adapter-history',
    SystemDataCategory.configuration => 'configuration',
    SystemDataCategory.other => 'other',
  };

  bool get canClear => switch (this) {
    SystemDataCategory.clipboardImages ||
    SystemDataCategory.clipboardText ||
    SystemDataCategory.clipboardFiles ||
    SystemDataCategory.agentActivity ||
    SystemDataCategory.adapterHistory => true,
    SystemDataCategory.clipboardHistory ||
    SystemDataCategory.clipboardArchive ||
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
    this.itemCountByCategory = const <SystemDataCategory, int>{},
  });

  final int residentMemoryBytes;
  final int storageBytes;
  final Map<SystemDataCategory, int> storageByCategory;
  final Map<SystemDataCategory, int> itemCountByCategory;

  int bytesFor(SystemDataCategory category) => storageByCategory[category] ?? 0;

  int itemsFor(SystemDataCategory category) =>
      itemCountByCategory[category] ?? 0;
}

/// Platform seam for gathering potentially expensive usage information.
abstract interface class SystemUsageSource {
  Future<SystemUsageSnapshot> load();
}

/// Clears only categories that the primary application can update safely.
abstract interface class SystemDataCleaner {
  Future<void> clear(Set<SystemDataCategory> categories);
}

/// Opens a DingDong-owned storage location for inspection.
abstract interface class SystemDataLocationGateway {
  Future<void> open(SystemDataCategory category);
}
