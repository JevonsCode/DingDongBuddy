import 'dart:convert';
import 'dart:typed_data';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:sqlite3/sqlite3.dart';

/// SQLite-backed source of truth compatible with the native Core Data table.
abstract interface class ClipboardStore {
  List<ClipboardRecord> list({
    required int limit,
    bool includeProtectedBeyondLimit = false,
  });

  DateTime? latestUpdatedAt();

  int historyCount();

  void save(ClipboardRecord record);

  void delete(String id);
}

/// A durable snapshot that is independent from its clipboard-history source.
final class ClipboardArchiveEntry {
  const ClipboardArchiveEntry({
    required this.record,
    required this.sourceClipboardId,
    required this.archivedAt,
  });

  final ClipboardRecord record;
  final String sourceClipboardId;
  final DateTime archivedAt;
}

/// Permanent archive storage. Automatic clipboard retention must never call
/// any mutating method on this interface.
abstract interface class ClipboardArchiveStore {
  List<ClipboardArchiveEntry> listArchives();

  void saveArchive(ClipboardArchiveEntry entry);

  void deleteArchive(String id);
}

/// Volatile archive store used by widget tests and previews.
final class InMemoryClipboardArchiveStore implements ClipboardArchiveStore {
  InMemoryClipboardArchiveStore([
    List<ClipboardArchiveEntry> entries = const <ClipboardArchiveEntry>[],
  ]) : _entries = List<ClipboardArchiveEntry>.of(entries);

  final List<ClipboardArchiveEntry> _entries;

  @override
  List<ClipboardArchiveEntry> listArchives() =>
      List<ClipboardArchiveEntry>.unmodifiable(
        _entries..sort(
          (ClipboardArchiveEntry left, ClipboardArchiveEntry right) =>
              compareClipboardRecords(left.record, right.record),
        ),
      );

  @override
  void saveArchive(ClipboardArchiveEntry entry) {
    _entries.removeWhere(
      (ClipboardArchiveEntry value) => value.record.id == entry.record.id,
    );
    _entries.insert(0, entry);
  }

  @override
  void deleteArchive(String id) {
    _entries.removeWhere(
      (ClipboardArchiveEntry entry) => entry.record.id == id,
    );
  }
}

/// Volatile clipboard store used by widget tests and previews.
final class InMemoryClipboardStore
    implements ClipboardStore, ClipboardArchiveStore {
  InMemoryClipboardStore([
    List<ClipboardRecord> records = const <ClipboardRecord>[],
  ]) {
    for (final ClipboardRecord record in records.reversed) {
      _saveWithArchiveSplit(record);
    }
  }

  final List<ClipboardRecord> _records = <ClipboardRecord>[];
  final List<ClipboardArchiveEntry> _archives = <ClipboardArchiveEntry>[];

  @override
  List<ClipboardRecord> list({
    required int limit,
    bool includeProtectedBeyondLimit = false,
  }) {
    final List<ClipboardRecord> sorted = List<ClipboardRecord>.of(_records)
      ..sort(compareClipboardRecords);
    return _boundedHistory(
      sorted,
      limit: limit,
      includeProtectedBeyondLimit: includeProtectedBeyondLimit,
    );
  }

  @override
  DateTime? latestUpdatedAt() {
    DateTime? latest;
    for (final ClipboardRecord record in _records) {
      if (latest == null || record.updatedAt.isAfter(latest)) {
        latest = record.updatedAt;
      }
    }
    return latest;
  }

  @override
  int historyCount() => _records.length;

  @override
  void save(ClipboardRecord record) {
    _saveWithArchiveSplit(record);
  }

  void _saveWithArchiveSplit(ClipboardRecord record) {
    final List<String> archiveGroups = record.groupNames
        .where(_isArchiveGroup)
        .toList(growable: false);
    final List<String> historyGroups = record.groupNames
        .where((String group) => !_isArchiveGroup(group))
        .toList(growable: false);
    final ClipboardRecord history = archiveGroups.isEmpty
        ? record
        : record.copyWith(groups: historyGroups);
    _records.removeWhere((ClipboardRecord value) => value.id == record.id);
    _records.insert(0, history);
    if (archiveGroups.isEmpty) return;
    final String archiveId = 'ARCHIVE-${record.id}';
    saveArchive(
      ClipboardArchiveEntry(
        record: ClipboardRecord(
          id: archiveId,
          group: archiveGroups.first,
          groups: archiveGroups,
          title: record.title,
          content: record.content,
          htmlData: record.htmlData,
          rtfData: record.rtfData,
          tags: record.tags,
          sources: record.sources,
          copyCount: record.copyCount,
          pinned: record.pinned,
          enabled: record.enabled,
          activation: record.activation,
          sortOrder: record.sortOrder,
          createdAt: record.createdAt,
          updatedAt: record.updatedAt,
        ),
        sourceClipboardId: record.id,
        archivedAt: record.updatedAt,
      ),
    );
  }

  @override
  void delete(String id) {
    _records.removeWhere((ClipboardRecord record) => record.id == id);
  }

  @override
  List<ClipboardArchiveEntry> listArchives() =>
      List<ClipboardArchiveEntry>.unmodifiable(
        List<ClipboardArchiveEntry>.of(_archives)..sort(
          (ClipboardArchiveEntry left, ClipboardArchiveEntry right) =>
              compareClipboardRecords(left.record, right.record),
        ),
      );

  @override
  void saveArchive(ClipboardArchiveEntry entry) {
    _archives.removeWhere(
      (ClipboardArchiveEntry value) => value.record.id == entry.record.id,
    );
    _archives.insert(0, entry);
  }

  @override
  void deleteArchive(String id) {
    _archives.removeWhere(
      (ClipboardArchiveEntry entry) => entry.record.id == id,
    );
  }
}

/// SQLite-backed source of truth compatible with the native Core Data table.
final class ClipboardRepository
    implements ClipboardStore, ClipboardArchiveStore {
  ClipboardRepository._(this._database);

  factory ClipboardRepository.open(String path) {
    final Database database = sqlite3.open(path);
    _ensureSchema(database);
    final ClipboardRepository repository = ClipboardRepository._(database);
    repository._migrateLegacyGroupedRecords();
    return repository;
  }

  static final DateTime _appleReferenceDate = DateTime.utc(2001);

  final Database _database;

  @override
  List<ClipboardRecord> list({
    required int limit,
    bool includeProtectedBeyondLimit = false,
  }) {
    final int boundedLimit = limit.clamp(0, 5000);
    const String orderBy = '''
      ORDER BY ZPINNED DESC,
        CASE
          WHEN ZPINNED = 1 AND ZSORTORDER IS NULL THEN 1
          ELSE 0
        END ASC,
        CASE
          WHEN ZPINNED = 0 AND ZSORTORDER IS NULL THEN 0
          WHEN ZPINNED = 0 THEN 1
          ELSE 0
        END ASC,
        CASE WHEN ZSORTORDER IS NULL THEN 0 ELSE ZSORTORDER END ASC,
        ZUPDATEDAT DESC,
        ZID ASC
    ''';
    final ResultSet rows = _database.select(
      includeProtectedBeyondLimit
          ? 'SELECT * FROM ZCLIPBOARDRECORD $orderBy'
          : 'SELECT * FROM ZCLIPBOARDRECORD $orderBy LIMIT ?',
      includeProtectedBeyondLimit ? const <Object?>[] : <Object?>[boundedLimit],
    );
    final Iterable<ClipboardRecord> records = rows.map(_recordFromRow);
    return includeProtectedBeyondLimit
        ? _boundedHistory(
            records,
            limit: boundedLimit,
            includeProtectedBeyondLimit: true,
          )
        : List<ClipboardRecord>.unmodifiable(records);
  }

  @override
  DateTime? latestUpdatedAt() {
    final Object? value = _database
        .select('SELECT MAX(ZUPDATEDAT) AS LATEST FROM ZCLIPBOARDRECORD')
        .single['LATEST'];
    return value == null ? null : _decodeDate(value);
  }

  @override
  int historyCount() {
    return _database
            .select('SELECT COUNT(*) AS ITEM_COUNT FROM ZCLIPBOARDRECORD')
            .single['ITEM_COUNT']
        as int;
  }

  List<ClipboardRecord> trim({
    required int maxItems,
    required int maxAgeDays,
    required DateTime now,
  }) {
    final int boundedItems = maxItems.clamp(20, 5000);
    final int boundedDays = maxAgeDays.clamp(1, 730);
    final DateTime cutoff = now.toUtc().subtract(Duration(days: boundedDays));
    _database.execute('BEGIN IMMEDIATE');
    try {
      final ResultSet rows = _database.select(
        'SELECT * FROM ZCLIPBOARDRECORD ORDER BY ZUPDATEDAT DESC',
      );
      final List<int> primaryKeysToDelete = <int>[];
      final List<ClipboardRecord> recordsToDelete = <ClipboardRecord>[];
      var ordinaryItemCount = 0;
      for (final Row row in rows) {
        final ClipboardRecord record = _recordFromRow(row);
        if (record.pinned) {
          continue;
        }
        ordinaryItemCount += 1;
        if (record.updatedAt.isBefore(cutoff) ||
            ordinaryItemCount > boundedItems) {
          primaryKeysToDelete.add(row['Z_PK']! as int);
          recordsToDelete.add(record);
        }
      }
      final PreparedStatement deleteStatement = _database.prepare(
        'DELETE FROM ZCLIPBOARDRECORD WHERE Z_PK = ?',
      );
      try {
        for (final int primaryKey in primaryKeysToDelete) {
          deleteStatement.execute(<Object?>[primaryKey]);
        }
      } finally {
        deleteStatement.close();
      }
      _database.execute('COMMIT');
      return List<ClipboardRecord>.unmodifiable(recordsToDelete);
    } on Object {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  @override
  void save(ClipboardRecord record) {
    final List<String> archiveGroups = record.groupNames
        .where(_isArchiveGroup)
        .toList(growable: false);
    if (archiveGroups.isNotEmpty) {
      _database.execute('BEGIN IMMEDIATE');
      try {
        final List<String> historyGroups = record.groupNames
            .where((String group) => !_isArchiveGroup(group))
            .toList(growable: false);
        _saveSource(record.copyWith(groups: historyGroups));
        final ResultSet existing = _database.select(
          'SELECT * FROM ZCLIPBOARDARCHIVE WHERE ZSOURCECLIPBOARDID = ? '
          'ORDER BY ZARCHIVEDAT ASC LIMIT 1',
          <Object?>[record.id],
        );
        if (existing.isEmpty) {
          saveArchive(
            ClipboardArchiveEntry(
              record: ClipboardRecord(
                id: 'ARCHIVE-${record.id}',
                group: archiveGroups.first,
                groups: archiveGroups,
                title: record.title,
                content: record.content,
                htmlData: record.htmlData,
                rtfData: record.rtfData,
                tags: record.tags,
                sources: record.sources,
                copyCount: record.copyCount,
                pinned: record.pinned,
                enabled: record.enabled,
                activation: record.activation,
                sortOrder: record.sortOrder,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt,
              ),
              sourceClipboardId: record.id,
              archivedAt: record.updatedAt,
            ),
          );
        } else {
          final Row row = existing.single;
          final ClipboardRecord archived = _recordFromRow(row);
          saveArchive(
            ClipboardArchiveEntry(
              record: archived.copyWith(
                groups: _uniqueGroups(<String>[
                  ...archived.groupNames,
                  ...archiveGroups,
                ]),
                updatedAt: record.updatedAt,
              ),
              sourceClipboardId: record.id,
              archivedAt: _decodeDate(row['ZARCHIVEDAT']),
            ),
          );
        }
        _database.execute('COMMIT');
        return;
      } on Object {
        _database.execute('ROLLBACK');
        rethrow;
      }
    }
    _saveSource(record);
  }

  void _saveSource(ClipboardRecord record) {
    _database.execute(
      '''
      INSERT INTO ZCLIPBOARDRECORD (
        Z_ENT, Z_OPT, ZENABLED, ZPINNED, ZSORTORDER, ZCOPYCOUNT,
        ZCREATEDAT, ZUPDATEDAT, ZACTIVATION, ZCONTENT, ZGROUP,
        ZID, ZSOURCE, ZTITLE, ZTAGSDATA, ZHTMLDATA, ZRTFDATA
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(ZID) DO UPDATE SET
        Z_OPT = Z_OPT + 1,
        ZENABLED = excluded.ZENABLED,
        ZPINNED = excluded.ZPINNED,
        ZSORTORDER = excluded.ZSORTORDER,
        ZCOPYCOUNT = excluded.ZCOPYCOUNT,
        ZCREATEDAT = excluded.ZCREATEDAT,
        ZUPDATEDAT = excluded.ZUPDATEDAT,
        ZACTIVATION = excluded.ZACTIVATION,
        ZCONTENT = excluded.ZCONTENT,
        ZGROUP = excluded.ZGROUP,
        ZSOURCE = excluded.ZSOURCE,
        ZTITLE = excluded.ZTITLE,
        ZTAGSDATA = excluded.ZTAGSDATA,
        ZHTMLDATA = excluded.ZHTMLDATA,
        ZRTFDATA = excluded.ZRTFDATA
    ''',
      <Object?>[
        1,
        1,
        record.enabled ? 1 : 0,
        record.pinned ? 1 : 0,
        record.sortOrder,
        record.copyCount,
        _encodeDate(record.createdAt),
        _encodeDate(record.updatedAt),
        record.activation,
        record.content,
        _encodeGroups(record.groupNames),
        record.id,
        _encodeSources(record.sources),
        record.title,
        Uint8List.fromList(utf8.encode(jsonEncode(record.tags))),
        record.htmlData,
        record.rtfData,
      ],
    );
  }

  @override
  void delete(String id) {
    _database.execute('DELETE FROM ZCLIPBOARDRECORD WHERE ZID = ?', <Object?>[
      id,
    ]);
  }

  @override
  List<ClipboardArchiveEntry> listArchives() {
    final ResultSet rows = _database.select('''
      SELECT * FROM ZCLIPBOARDARCHIVE
      ORDER BY ZPINNED DESC,
        CASE
          WHEN ZPINNED = 1 AND ZSORTORDER IS NULL THEN 1
          ELSE 0
        END ASC,
        CASE
          WHEN ZPINNED = 0 AND ZSORTORDER IS NULL THEN 0
          WHEN ZPINNED = 0 THEN 1
          ELSE 0
        END ASC,
        CASE WHEN ZSORTORDER IS NULL THEN 0 ELSE ZSORTORDER END ASC,
        ZUPDATEDAT DESC,
        ZID ASC
      ''');
    return List<ClipboardArchiveEntry>.unmodifiable(
      rows.map(
        (Row row) => ClipboardArchiveEntry(
          record: _recordFromRow(row),
          sourceClipboardId: row['ZSOURCECLIPBOARDID'] as String? ?? '',
          archivedAt: _decodeDate(row['ZARCHIVEDAT']),
        ),
      ),
    );
  }

  @override
  void saveArchive(ClipboardArchiveEntry entry) {
    final ClipboardRecord record = entry.record;
    _database.execute(
      '''
      INSERT INTO ZCLIPBOARDARCHIVE (
        Z_OPT, ZENABLED, ZPINNED, ZSORTORDER, ZCOPYCOUNT,
        ZCREATEDAT, ZUPDATEDAT, ZARCHIVEDAT, ZACTIVATION, ZCONTENT, ZGROUP,
        ZID, ZSOURCECLIPBOARDID, ZSOURCE, ZTITLE, ZTAGSDATA, ZHTMLDATA, ZRTFDATA
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(ZID) DO UPDATE SET
        Z_OPT = Z_OPT + 1,
        ZENABLED = excluded.ZENABLED,
        ZPINNED = excluded.ZPINNED,
        ZSORTORDER = excluded.ZSORTORDER,
        ZCOPYCOUNT = excluded.ZCOPYCOUNT,
        ZCREATEDAT = excluded.ZCREATEDAT,
        ZUPDATEDAT = excluded.ZUPDATEDAT,
        ZARCHIVEDAT = excluded.ZARCHIVEDAT,
        ZACTIVATION = excluded.ZACTIVATION,
        ZCONTENT = excluded.ZCONTENT,
        ZGROUP = excluded.ZGROUP,
        ZSOURCECLIPBOARDID = excluded.ZSOURCECLIPBOARDID,
        ZSOURCE = excluded.ZSOURCE,
        ZTITLE = excluded.ZTITLE,
        ZTAGSDATA = excluded.ZTAGSDATA,
        ZHTMLDATA = excluded.ZHTMLDATA,
        ZRTFDATA = excluded.ZRTFDATA
      ''',
      <Object?>[
        1,
        record.enabled ? 1 : 0,
        record.pinned ? 1 : 0,
        record.sortOrder,
        record.copyCount,
        _encodeDate(record.createdAt),
        _encodeDate(record.updatedAt),
        _encodeDate(entry.archivedAt),
        record.activation,
        record.content,
        _encodeGroups(record.groupNames),
        record.id,
        entry.sourceClipboardId,
        _encodeSources(record.sources),
        record.title,
        Uint8List.fromList(utf8.encode(jsonEncode(record.tags))),
        record.htmlData,
        record.rtfData,
      ],
    );
  }

  @override
  void deleteArchive(String id) {
    _database.execute('DELETE FROM ZCLIPBOARDARCHIVE WHERE ZID = ?', <Object?>[
      id,
    ]);
  }

  void deleteAll() {
    _database
      ..execute('DELETE FROM ZCLIPBOARDRECORD')
      ..execute('VACUUM')
      ..execute('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  /// Deletes only clipboard-history rows of the requested kinds. Permanent
  /// archive snapshots live in a different table and are never touched.
  List<ClipboardRecord> deleteHistoryKinds(Set<ClipboardKind> kinds) {
    if (kinds.isEmpty) return const <ClipboardRecord>[];
    final List<ClipboardRecord> deleted = <ClipboardRecord>[];
    _database.execute('BEGIN IMMEDIATE');
    try {
      final ResultSet rows = _database.select(
        'SELECT * FROM ZCLIPBOARDRECORD ORDER BY ZUPDATEDAT DESC',
      );
      final PreparedStatement statement = _database.prepare(
        'DELETE FROM ZCLIPBOARDRECORD WHERE Z_PK = ?',
      );
      try {
        for (final Row row in rows) {
          final ClipboardRecord record = _recordFromRow(row);
          if (!kinds.contains(record.kind)) continue;
          statement.execute(<Object?>[row['Z_PK']]);
          deleted.add(record);
        }
      } finally {
        statement.close();
      }
      _database.execute('COMMIT');
      return List<ClipboardRecord>.unmodifiable(deleted);
    } on Object {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  void close() => _database.close();

  /// Copies every legacy custom-group record into the permanent archive and
  /// removes only the custom grouping metadata from clipboard history. Both
  /// writes share one transaction, so a crash cannot leave half a migration.
  void _migrateLegacyGroupedRecords() {
    _database.execute('BEGIN IMMEDIATE');
    try {
      final ResultSet rows = _database.select(
        "SELECT * FROM ZCLIPBOARDRECORD WHERE TRIM(COALESCE(ZGROUP, '')) <> ''",
      );
      for (final Row row in rows) {
        final ClipboardRecord source = _recordFromRow(row);
        final List<String> archiveGroups = source.groupNames
            .where(_isArchiveGroup)
            .toList(growable: false);
        if (archiveGroups.isEmpty) {
          continue;
        }
        final String archiveId = 'ARCHIVE-${source.id}';
        final ClipboardRecord snapshot = ClipboardRecord(
          id: archiveId,
          group: archiveGroups.first,
          groups: archiveGroups,
          title: source.title,
          content: source.content,
          htmlData: source.htmlData,
          rtfData: source.rtfData,
          tags: source.tags,
          sources: source.sources,
          copyCount: source.copyCount,
          pinned: source.pinned,
          enabled: source.enabled,
          activation: source.activation,
          sortOrder: source.sortOrder,
          createdAt: source.createdAt,
          updatedAt: source.updatedAt,
        );
        final bool exists = _database.select(
          'SELECT 1 FROM ZCLIPBOARDARCHIVE WHERE ZID = ? LIMIT 1',
          <Object?>[archiveId],
        ).isNotEmpty;
        if (!exists) {
          saveArchive(
            ClipboardArchiveEntry(
              record: snapshot,
              sourceClipboardId: source.id,
              archivedAt: source.updatedAt,
            ),
          );
        }
        final List<String> remainingGroups = source.groupNames
            .where((String group) => !_isArchiveGroup(group))
            .toList(growable: false);
        _database.execute(
          'UPDATE ZCLIPBOARDRECORD SET ZGROUP = ?, Z_OPT = Z_OPT + 1 '
          'WHERE Z_PK = ?',
          <Object?>[_encodeGroups(remainingGroups), row['Z_PK']],
        );
      }
      _database.execute('COMMIT');
    } on Object {
      _database.execute('ROLLBACK');
      rethrow;
    }
  }

  static ClipboardRecord _recordFromRow(Row row) {
    final List<String> tags = _decodeTags(row['ZTAGSDATA']);
    final List<String> groups = _decodeGroups(row['ZGROUP'] as String? ?? '[]');
    return ClipboardRecord(
      id: row['ZID'] as String? ?? '',
      group: groups.isEmpty ? '' : groups.first,
      groups: groups,
      title: row['ZTITLE'] as String? ?? '',
      content: row['ZCONTENT'] as String? ?? '',
      htmlData: _decodeOptionalBytes(row['ZHTMLDATA']),
      rtfData: _decodeOptionalBytes(row['ZRTFDATA']),
      tags: tags,
      sources: _decodeSources(row['ZSOURCE']),
      copyCount: _decodeCopyCount(row['ZCOPYCOUNT']),
      pinned: (row['ZPINNED'] as int? ?? 0) != 0,
      enabled: (row['ZENABLED'] as int? ?? 1) != 0,
      activation: row['ZACTIVATION'] as String? ?? 'taskMatch',
      sortOrder: row['ZSORTORDER'] as int?,
      createdAt: _decodeDate(row['ZCREATEDAT']),
      updatedAt: _decodeDate(row['ZUPDATEDAT']),
    );
  }

  static DateTime _decodeDate(Object? value) {
    final num seconds = value as num? ?? 0;
    return _appleReferenceDate.add(
      Duration(
        microseconds: (seconds * Duration.microsecondsPerSecond).round(),
      ),
    );
  }

  static double _encodeDate(DateTime value) {
    return value.toUtc().difference(_appleReferenceDate).inMicroseconds /
        Duration.microsecondsPerSecond;
  }

  static List<String> _decodeTags(Object? value) {
    final List<int> bytes = switch (value) {
      final Uint8List data => data,
      final List<int> data => data,
      _ => const <int>[],
    };
    if (bytes.isEmpty) {
      return const <String>[];
    }
    final List<Object?> values =
        jsonDecode(utf8.decode(bytes)) as List<Object?>;
    return List<String>.unmodifiable(values.cast<String>());
  }

  static Uint8List? _decodeOptionalBytes(Object? value) {
    final Uint8List bytes = switch (value) {
      final Uint8List data => data,
      final List<int> data => Uint8List.fromList(data),
      _ => Uint8List(0),
    };
    return bytes.isEmpty ? null : bytes;
  }

  static List<String> _decodeGroups(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }
    // Releases before the multi-group migration stored one group as a plain
    // string. Keep those records visible instead of treating them as empty.
    if (!trimmed.startsWith('[')) {
      return <String>[trimmed];
    }
    try {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is List<Object?>) {
        return _uniqueGroups(decoded.whereType<String>());
      }
    } on FormatException {
      // Preserve malformed legacy values as one ordinary group.
      return <String>[trimmed];
    }
    return <String>[trimmed];
  }

  static String _encodeGroups(List<String> values) {
    final List<String> groups = _uniqueGroups(values);
    return groups.isEmpty ? '' : jsonEncode(groups);
  }

  static List<String> _decodeSources(Object? value) {
    final String trimmed = (value as String? ?? '').trim();
    if (trimmed.isEmpty) {
      return const <String>[];
    }
    if (!trimmed.startsWith('[')) {
      return <String>[trimmed];
    }
    try {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is List<Object?>) {
        return _uniqueSources(decoded.whereType<String>());
      }
    } on FormatException {
      // A malformed legacy value still represents one useful source label.
    }
    return <String>[trimmed];
  }

  static String _encodeSources(List<String> values) {
    final List<String> sources = _uniqueSources(values);
    return sources.isEmpty ? '' : jsonEncode(sources);
  }

  static int _decodeCopyCount(Object? value) {
    final int count = value as int? ?? 1;
    return count < 1 ? 1 : count;
  }

  static void _ensureSchema(Database database) {
    database
      ..execute('PRAGMA journal_mode = WAL')
      ..execute('''
        CREATE TABLE IF NOT EXISTS ZCLIPBOARDRECORD (
          Z_PK INTEGER PRIMARY KEY AUTOINCREMENT,
          Z_ENT INTEGER,
          Z_OPT INTEGER,
          ZENABLED INTEGER,
          ZPINNED INTEGER,
          ZSORTORDER INTEGER,
          ZCOPYCOUNT INTEGER DEFAULT 1,
          ZCREATEDAT TIMESTAMP,
          ZUPDATEDAT TIMESTAMP,
          ZACTIVATION VARCHAR,
          ZCONTENT VARCHAR,
          ZGROUP VARCHAR,
          ZID VARCHAR,
          ZSOURCE VARCHAR,
          ZTITLE VARCHAR,
          ZTAGSDATA BLOB,
          ZHTMLDATA BLOB,
          ZRTFDATA BLOB
        )
      ''')
      ..execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS Z_ClipboardRecord_UNIQUE_id '
        'ON ZCLIPBOARDRECORD (ZID COLLATE BINARY ASC)',
      )
      ..execute('''
        CREATE TABLE IF NOT EXISTS ZCLIPBOARDARCHIVE (
          Z_PK INTEGER PRIMARY KEY AUTOINCREMENT,
          Z_OPT INTEGER,
          ZENABLED INTEGER,
          ZPINNED INTEGER,
          ZSORTORDER INTEGER,
          ZCOPYCOUNT INTEGER DEFAULT 1,
          ZCREATEDAT TIMESTAMP,
          ZUPDATEDAT TIMESTAMP,
          ZARCHIVEDAT TIMESTAMP,
          ZACTIVATION VARCHAR,
          ZCONTENT VARCHAR,
          ZGROUP VARCHAR,
          ZID VARCHAR,
          ZSOURCECLIPBOARDID VARCHAR,
          ZSOURCE VARCHAR,
          ZTITLE VARCHAR,
          ZTAGSDATA BLOB,
          ZHTMLDATA BLOB,
          ZRTFDATA BLOB
        )
      ''')
      ..execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS Z_ClipboardArchive_UNIQUE_id '
        'ON ZCLIPBOARDARCHIVE (ZID COLLATE BINARY ASC)',
      )
      ..execute(
        'CREATE INDEX IF NOT EXISTS Z_ClipboardArchive_source_id '
        'ON ZCLIPBOARDARCHIVE (ZSOURCECLIPBOARDID COLLATE BINARY ASC)',
      );
    _ensureColumn(database, 'ZCLIPBOARDRECORD', 'ZHTMLDATA', 'BLOB');
    _ensureColumn(database, 'ZCLIPBOARDRECORD', 'ZRTFDATA', 'BLOB');
    _ensureColumn(
      database,
      'ZCLIPBOARDRECORD',
      'ZCOPYCOUNT',
      'INTEGER DEFAULT 1',
    );
    _ensureColumn(database, 'ZCLIPBOARDARCHIVE', 'ZHTMLDATA', 'BLOB');
    _ensureColumn(database, 'ZCLIPBOARDARCHIVE', 'ZRTFDATA', 'BLOB');
    _ensureColumn(
      database,
      'ZCLIPBOARDARCHIVE',
      'ZCOPYCOUNT',
      'INTEGER DEFAULT 1',
    );
  }

  static void _ensureColumn(
    Database database,
    String table,
    String name,
    String type,
  ) {
    final bool exists = database
        .select('PRAGMA table_info($table)')
        .any((Row row) => row['name'] == name);
    if (!exists) {
      database.execute('ALTER TABLE $table ADD COLUMN $name $type');
    }
  }
}

List<ClipboardRecord> _boundedHistory(
  Iterable<ClipboardRecord> records, {
  required int limit,
  required bool includeProtectedBeyondLimit,
}) {
  final int boundedLimit = limit.clamp(0, 5000);
  if (!includeProtectedBeyondLimit) {
    return List<ClipboardRecord>.unmodifiable(records.take(boundedLimit));
  }
  final List<ClipboardRecord> result = <ClipboardRecord>[];
  var ordinaryCount = 0;
  for (final ClipboardRecord record in records) {
    if (record.pinned) {
      result.add(record);
    } else if (ordinaryCount < boundedLimit) {
      ordinaryCount += 1;
      result.add(record);
    }
  }
  return List<ClipboardRecord>.unmodifiable(result);
}

List<String> _uniqueGroups(Iterable<String> values) {
  final Set<String> seen = <String>{};
  return values
      .map((String value) => value.trim())
      .where(
        (String value) => value.isNotEmpty && seen.add(value.toLowerCase()),
      )
      .toList(growable: false);
}

List<String> _uniqueSources(Iterable<String> values) {
  final Set<String> seen = <String>{};
  return values
      .map((String value) => value.trim())
      .where(
        (String value) => value.isNotEmpty && seen.add(value.toLowerCase()),
      )
      .toList(growable: false);
}

bool _isArchiveGroup(String value) =>
    value.trim().toLowerCase() == 'archive' ||
    !isAutomaticClipboardGroup(value);
