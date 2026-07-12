import 'dart:io';

import 'package:dingdong/features/settings/domain/system_usage.dart';

/// Reads process RSS and recursively totals DingDong's application data files.
final class IoSystemUsageSource implements SystemUsageSource {
  const IoSystemUsageSource(this.applicationDataDirectory);

  final Directory applicationDataDirectory;

  @override
  Future<SystemUsageSnapshot> load() async {
    int storageBytes = 0;
    if (await applicationDataDirectory.exists()) {
      await for (final FileSystemEntity entity in applicationDataDirectory.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            storageBytes += await entity.length();
          } on FileSystemException {
            // A concurrently removed cache file should not fail Settings.
          }
        }
      }
    }
    return SystemUsageSnapshot(
      residentMemoryBytes: ProcessInfo.currentRss,
      storageBytes: storageBytes,
    );
  }
}
