import 'dart:io';

import 'package:dingdong/features/settings/domain/system_usage.dart';
import 'package:path/path.dart' as path;

/// Reads process RSS and recursively totals DingDong's application data files.
final class IoSystemUsageSource implements SystemUsageSource {
  const IoSystemUsageSource(this.applicationDataDirectory);

  final Directory applicationDataDirectory;

  @override
  Future<SystemUsageSnapshot> load() async {
    int storageBytes = 0;
    final Map<SystemDataCategory, int> storageByCategory =
        <SystemDataCategory, int>{
          for (final SystemDataCategory category in SystemDataCategory.values)
            category: 0,
        };
    if (await applicationDataDirectory.exists()) {
      await for (final FileSystemEntity entity in applicationDataDirectory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            final int bytes = await entity.length();
            final SystemDataCategory category = _categoryFor(entity);
            storageBytes += bytes;
            storageByCategory[category] = storageByCategory[category]! + bytes;
          } on FileSystemException {
            // A concurrently removed cache file should not fail Settings.
          }
        }
      }
    }
    return SystemUsageSnapshot(
      residentMemoryBytes: ProcessInfo.currentRss,
      storageBytes: storageBytes,
      storageByCategory: Map<SystemDataCategory, int>.unmodifiable(
        storageByCategory,
      ),
    );
  }

  SystemDataCategory _categoryFor(File file) {
    final String relative = path.relative(
      file.path,
      from: applicationDataDirectory.path,
    );
    final List<String> segments = path.split(relative);
    final String topLevel = segments.isEmpty ? relative : segments.first;
    if (topLevel == 'Clipboard Images' ||
        topLevel.startsWith('clipboard-history.sqlite')) {
      return SystemDataCategory.clipboardHistory;
    }
    if (topLevel == 'Skill Packages' ||
        topLevel.startsWith('resource-library.json') ||
        topLevel.startsWith('trigger-groups.json') ||
        topLevel.startsWith('agent-sync-state.json')) {
      return SystemDataCategory.resourceLibrary;
    }
    if (topLevel.startsWith('agent-activity.json')) {
      return SystemDataCategory.agentActivity;
    }
    if (topLevel == 'Agent Adapter History') {
      return SystemDataCategory.adapterHistory;
    }
    if (topLevel == 'Agent Adapters' ||
        topLevel.startsWith('agent-launchers.json') ||
        topLevel.startsWith('clipboard-category-rules.json') ||
        topLevel.startsWith('clipboard-group-order.json') ||
        topLevel == 'api-port') {
      return SystemDataCategory.configuration;
    }
    return SystemDataCategory.other;
  }
}
