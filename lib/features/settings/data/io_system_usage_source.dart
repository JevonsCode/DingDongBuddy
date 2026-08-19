import 'dart:io';

import 'package:dingdong/features/settings/domain/system_usage.dart';
import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

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
    final Map<SystemDataCategory, int> itemCountByCategory =
        <SystemDataCategory, int>{};
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
    _measureClipboardContent(
      storageByCategory: storageByCategory,
      itemCountByCategory: itemCountByCategory,
    );
    return SystemUsageSnapshot(
      residentMemoryBytes: ProcessInfo.currentRss,
      storageBytes: storageBytes,
      storageByCategory: Map<SystemDataCategory, int>.unmodifiable(
        storageByCategory,
      ),
      itemCountByCategory: Map<SystemDataCategory, int>.unmodifiable(
        itemCountByCategory,
      ),
    );
  }

  void _measureClipboardContent({
    required Map<SystemDataCategory, int> storageByCategory,
    required Map<SystemDataCategory, int> itemCountByCategory,
  }) {
    final File databaseFile = File(
      path.join(applicationDataDirectory.path, 'clipboard-history.sqlite'),
    );
    if (!databaseFile.existsSync()) {
      return;
    }
    Database? database;
    try {
      database = sqlite3.open(databaseFile.path, mode: OpenMode.readOnly);
      final Set<String> archiveImages = <String>{};
      if (_hasTable(database, 'ZCLIPBOARDRECORD')) {
        _measureTable(
          database: database,
          table: 'ZCLIPBOARDRECORD',
          archive: false,
          storageByCategory: storageByCategory,
          itemCountByCategory: itemCountByCategory,
        );
      }
      if (_hasTable(database, 'ZCLIPBOARDARCHIVE')) {
        _measureTable(
          database: database,
          table: 'ZCLIPBOARDARCHIVE',
          archive: true,
          storageByCategory: storageByCategory,
          itemCountByCategory: itemCountByCategory,
          managedImages: archiveImages,
        );
      }
      _measureManagedImages(
        archiveImages: archiveImages,
        storageByCategory: storageByCategory,
      );
    } on SqliteException {
      // A legacy, locked, or concurrently replaced database should not make
      // the rest of the Settings usage report unavailable.
    } finally {
      database?.close();
    }
  }

  bool _hasTable(Database database, String table) => database.select(
    "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1",
    <Object?>[table],
  ).isNotEmpty;

  void _measureTable({
    required Database database,
    required String table,
    required bool archive,
    required Map<SystemDataCategory, int> storageByCategory,
    required Map<SystemDataCategory, int> itemCountByCategory,
    Set<String>? managedImages,
  }) {
    const String contentBytes = '''
      COALESCE(LENGTH(CAST(ZCONTENT AS BLOB)), 0) +
      COALESCE(LENGTH(CAST(ZGROUP AS BLOB)), 0) +
      COALESCE(LENGTH(CAST(ZID AS BLOB)), 0) +
      COALESCE(LENGTH(CAST(ZSOURCE AS BLOB)), 0) +
      COALESCE(LENGTH(CAST(ZTITLE AS BLOB)), 0) +
      COALESCE(LENGTH(CAST(ZACTIVATION AS BLOB)), 0) +
      COALESCE(LENGTH(ZTAGSDATA), 0) +
      COALESCE(LENGTH(ZHTMLDATA), 0) +
      COALESCE(LENGTH(ZRTFDATA), 0)
    ''';
    const String imageTag =
        '''INSTR(CAST(COALESCE(ZTAGSDATA, X'') AS TEXT), '"image"') > 0''';
    const String fileTag =
        '''INSTR(CAST(COALESCE(ZTAGSDATA, X'') AS TEXT), '"file"') > 0 OR INSTR(CAST(COALESCE(ZTAGSDATA, X'') AS TEXT), '"file-url"') > 0''';
    if (archive) {
      final Row totals = database.select('''
        SELECT COUNT(*) AS ITEM_COUNT,
          COALESCE(SUM($contentBytes), 0) AS CONTENT_BYTES
        FROM $table
      ''').single;
      _addMeasurement(
        category: SystemDataCategory.clipboardArchive,
        bytes: totals['CONTENT_BYTES'] as int? ?? 0,
        items: totals['ITEM_COUNT'] as int? ?? 0,
        storageByCategory: storageByCategory,
        itemCountByCategory: itemCountByCategory,
      );
    } else {
      final Row totals = database.select('''
        SELECT
          COALESCE(SUM(CASE WHEN $imageTag THEN $contentBytes ELSE 0 END), 0) AS IMAGE_BYTES,
          SUM(CASE WHEN $imageTag THEN 1 ELSE 0 END) AS IMAGE_COUNT,
          COALESCE(SUM(CASE WHEN NOT ($imageTag) AND ($fileTag) THEN $contentBytes ELSE 0 END), 0) AS FILE_BYTES,
          SUM(CASE WHEN NOT ($imageTag) AND ($fileTag) THEN 1 ELSE 0 END) AS FILE_COUNT,
          COALESCE(SUM(CASE WHEN NOT ($imageTag) AND NOT ($fileTag) THEN $contentBytes ELSE 0 END), 0) AS TEXT_BYTES,
          SUM(CASE WHEN NOT ($imageTag) AND NOT ($fileTag) THEN 1 ELSE 0 END) AS TEXT_COUNT
        FROM $table
      ''').single;
      _addMeasurement(
        category: SystemDataCategory.clipboardImages,
        bytes: totals['IMAGE_BYTES'] as int? ?? 0,
        items: totals['IMAGE_COUNT'] as int? ?? 0,
        storageByCategory: storageByCategory,
        itemCountByCategory: itemCountByCategory,
      );
      _addMeasurement(
        category: SystemDataCategory.clipboardFiles,
        bytes: totals['FILE_BYTES'] as int? ?? 0,
        items: totals['FILE_COUNT'] as int? ?? 0,
        storageByCategory: storageByCategory,
        itemCountByCategory: itemCountByCategory,
      );
      _addMeasurement(
        category: SystemDataCategory.clipboardText,
        bytes: totals['TEXT_BYTES'] as int? ?? 0,
        items: totals['TEXT_COUNT'] as int? ?? 0,
        storageByCategory: storageByCategory,
        itemCountByCategory: itemCountByCategory,
      );
    }
    if (managedImages != null) {
      final ResultSet rows = database.select('''
        SELECT ZCONTENT FROM $table
        WHERE $imageTag
          AND INSTR(CAST(COALESCE(ZTAGSDATA, X'') AS TEXT), '"file-url"') > 0
      ''');
      for (final Row row in rows) {
        final String content = row['ZCONTENT'] as String? ?? '';
        if (_isManagedImagePath(content)) {
          managedImages.add(path.normalize(path.absolute(content)));
        }
      }
    }
  }

  void _addMeasurement({
    required SystemDataCategory category,
    required int bytes,
    required int items,
    required Map<SystemDataCategory, int> storageByCategory,
    required Map<SystemDataCategory, int> itemCountByCategory,
  }) {
    storageByCategory[category] = (storageByCategory[category] ?? 0) + bytes;
    itemCountByCategory[category] =
        (itemCountByCategory[category] ?? 0) + items;
  }

  bool _isManagedImagePath(String value) {
    if (value.trim().isEmpty || value.contains('\n')) return false;
    final String imageDirectory = path.normalize(
      path.absolute(
        path.join(applicationDataDirectory.path, 'Clipboard Images'),
      ),
    );
    return path.isWithin(imageDirectory, path.normalize(path.absolute(value)));
  }

  void _measureManagedImages({
    required Set<String> archiveImages,
    required Map<SystemDataCategory, int> storageByCategory,
  }) {
    final Directory directory = Directory(
      path.join(applicationDataDirectory.path, 'Clipboard Images'),
    );
    if (!directory.existsSync()) return;
    try {
      for (final FileSystemEntity entity in directory.listSync(
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final String normalized = path.normalize(path.absolute(entity.path));
        final SystemDataCategory category = archiveImages.contains(normalized)
            ? SystemDataCategory.clipboardArchive
            : SystemDataCategory.clipboardImages;
        storageByCategory[category] =
            (storageByCategory[category] ?? 0) + entity.lengthSync();
      }
    } on FileSystemException {
      // Files can disappear while the clipboard monitor is pruning them.
    }
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
