import 'dart:convert';
import 'dart:typed_data';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:sqlite3/sqlite3.dart';

/// SQLite-backed source of truth compatible with the native Core Data table.
abstract interface class ClipboardStore {
  List<ClipboardRecord> list({required int limit});

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
  List<ClipboardRecord> list({required int limit}) =>
      _records.take(limit).toList(growable: false);

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
  List<ClipboardRecord> list({required int limit}) {
    final ResultSet rows = _database.select(
      'SELECT * FROM ZCLIPBOARDRECORD ORDER BY ZUPDATEDAT DESC LIMIT ?',
      <Object?>[limit.clamp(0, 5000)],
    );
    return List<ClipboardRecord>.unmodifiable(
      rows.map((Row row) {
        final List<String> tags = _decodeTags(row['ZTAGSDATA']);
        return ClipboardRecord(
          id: row['ZID'] as String? ?? '',
          group: row['ZGROUP'] as String? ?? 'Clipboard',
          title: row['ZTITLE'] as String? ?? '',
          content: row['ZCONTENT'] as String? ?? '',
          tags: tags,
          source: row['ZSOURCE'] as String?,
          pinned: (row['ZPINNED'] as int? ?? 0) != 0,
          enabled: (row['ZENABLED'] as int? ?? 1) != 0,
          activation: row['ZACTIVATION'] as String? ?? 'taskMatch',
          sortOrder: row['ZSORTORDER'] as int?,
          createdAt: _decodeDate(row['ZCREATEDAT']),
          updatedAt: _decodeDate(row['ZUPDATEDAT']),
        );
      }),
    );
  }

  void trim({
    required int maxItems,
    required int maxAgeDays,
    required DateTime now,
  }) {
    final int boundedItems = maxItems.clamp(20, 5000);
    final int boundedDays = maxAgeDays.clamp(1, 730);
    final double cutoff = _encodeDate(
      now.toUtc().subtract(Duration(days: boundedDays)),
    );
    _database.execute(
      'DELETE FROM ZCLIPBOARDRECORD '
      'WHERE ZPINNED = 0 AND ZUPDATEDAT < ?',
      <Object?>[cutoff],
    );
    _database.execute(
      'DELETE FROM ZCLIPBOARDRECORD '
      'WHERE ZPINNED = 0 AND Z_PK NOT IN ('
      'SELECT Z_PK FROM ZCLIPBOARDRECORD WHERE ZPINNED = 0 '
      'ORDER BY ZUPDATEDAT DESC LIMIT ?)',
      <Object?>[boundedItems],
    );
  }

  @override
  void save(ClipboardRecord record) {
    _database.execute(
      '''
      INSERT INTO ZCLIPBOARDRECORD (
        Z_ENT, Z_OPT, ZENABLED, ZPINNED, ZSORTORDER,
        ZCREATEDAT, ZUPDATEDAT, ZACTIVATION, ZCONTENT, ZGROUP,
        ZID, ZSOURCE, ZTITLE, ZTAGSDATA
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
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
        ZTAGSDATA = excluded.ZTAGSDATA
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
        record.group,
        record.id,
        record.source,
        record.title,
        Uint8List.fromList(utf8.encode(jsonEncode(record.tags))),
      ],
    );
  }

  @override
  void delete(String id) {
    _database.execute('DELETE FROM ZCLIPBOARDRECORD WHERE ZID = ?', <Object?>[
      id,
    ]);
  }

  void close() => _database.close();

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
          ZTAGSDATA BLOB
        )
      ''')
      ..execute(
        'CREATE UNIQUE INDEX IF NOT EXISTS Z_ClipboardRecord_UNIQUE_id '
        'ON ZCLIPBOARDRECORD (ZID COLLATE BINARY ASC)',
      );
  }
}
