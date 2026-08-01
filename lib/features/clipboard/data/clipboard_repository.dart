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

  void save(ClipboardRecord record);

  void delete(String id);
}

/// Volatile clipboard store used by widget tests and previews.
final class InMemoryClipboardStore implements ClipboardStore {
  InMemoryClipboardStore([
    List<ClipboardRecord> records = const <ClipboardRecord>[],
  ]) : _records = List<ClipboardRecord>.of(records);

  final List<ClipboardRecord> _records;

  @override
  List<ClipboardRecord> list({
    required int limit,
    bool includeProtectedBeyondLimit = false,
  }) => _boundedHistory(
    _records,
    limit: limit,
    includeProtectedBeyondLimit: includeProtectedBeyondLimit,
  );

  @override
  void save(ClipboardRecord record) {
    _records.removeWhere((ClipboardRecord value) => value.id == record.id);
    _records.insert(0, record);
  }

  @override
  void delete(String id) {
    _records.removeWhere((ClipboardRecord record) => record.id == id);
  }
}

/// SQLite-backed source of truth compatible with the native Core Data table.
final class ClipboardRepository implements ClipboardStore {
  ClipboardRepository._(this._database);

  factory ClipboardRepository.open(String path) {
    final Database database = sqlite3.open(path);
    _ensureSchema(database);
    return ClipboardRepository._(database);
  }

  static final DateTime _appleReferenceDate = DateTime.utc(2001);

  final Database _database;

  @override
  List<ClipboardRecord> list({
    required int limit,
    bool includeProtectedBeyondLimit = false,
  }) {
    final int boundedLimit = limit.clamp(0, 5000);
    final ResultSet rows = _database.select(
      includeProtectedBeyondLimit
          ? 'SELECT * FROM ZCLIPBOARDRECORD ORDER BY ZUPDATEDAT DESC'
          : 'SELECT * FROM ZCLIPBOARDRECORD ORDER BY ZUPDATEDAT DESC LIMIT ?',
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
        if (record.pinned || record.isArchived) {
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
    _database.execute(
      '''
      INSERT INTO ZCLIPBOARDRECORD (
        Z_ENT, Z_OPT, ZENABLED, ZPINNED, ZSORTORDER,
        ZCREATEDAT, ZUPDATEDAT, ZACTIVATION, ZCONTENT, ZGROUP,
        ZID, ZSOURCE, ZTITLE, ZTAGSDATA, ZHTMLDATA, ZRTFDATA
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(ZID) DO UPDATE SET
        Z_OPT = Z_OPT + 1,
        ZENABLED = excluded.ZENABLED,
        ZPINNED = excluded.ZPINNED,
        ZSORTORDER = excluded.ZSORTORDER,
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
        _encodeDate(record.createdAt),
        _encodeDate(record.updatedAt),
        record.activation,
        record.content,
        _encodeGroups(record.groupNames),
        record.id,
        record.source,
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

  void deleteAll() {
    _database
      ..execute('DELETE FROM ZCLIPBOARDRECORD')
      ..execute('VACUUM')
      ..execute('PRAGMA wal_checkpoint(TRUNCATE)');
  }

  void close() => _database.close();

  static ClipboardRecord _recordFromRow(Row row) {
    final List<String> tags = _decodeTags(row['ZTAGSDATA']);
    final List<String> groups = _decodeGroups(
      row['ZGROUP'] as String? ?? 'Clipboard',
    );
    return ClipboardRecord(
      id: row['ZID'] as String? ?? '',
      group: groups.isEmpty ? '' : groups.first,
      groups: groups,
      title: row['ZTITLE'] as String? ?? '',
      content: row['ZCONTENT'] as String? ?? '',
      htmlData: _decodeOptionalBytes(row['ZHTMLDATA']),
      rtfData: _decodeOptionalBytes(row['ZRTFDATA']),
      tags: tags,
      source: row['ZSOURCE'] as String?,
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
    if (trimmed.startsWith('[')) {
      try {
        final Object? decoded = jsonDecode(trimmed);
        if (decoded is List<Object?>) {
          return _uniqueGroups(decoded.whereType<String>());
        }
      } on FormatException {
        // Preserve malformed legacy values as one ordinary group.
      }
    }
    return <String>[trimmed];
  }

  static String _encodeGroups(List<String> values) {
    final List<String> groups = _uniqueGroups(values);
    return switch (groups.length) {
      0 => '',
      1 => groups.single,
      _ => jsonEncode(groups),
    };
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
      );
    _ensureColumn(database, 'ZHTMLDATA', 'BLOB');
    _ensureColumn(database, 'ZRTFDATA', 'BLOB');
  }

  static void _ensureColumn(Database database, String name, String type) {
    final bool exists = database
        .select('PRAGMA table_info(ZCLIPBOARDRECORD)')
        .any((Row row) => row['name'] == name);
    if (!exists) {
      database.execute('ALTER TABLE ZCLIPBOARDRECORD ADD COLUMN $name $type');
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
    if (record.pinned || record.isArchived) {
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
