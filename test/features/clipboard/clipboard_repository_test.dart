import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test(
    'opens the native Core Data clipboard table without losing fields',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-clipboard-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final String path = '${directory.path}/clipboard-history.sqlite';
      final Database database = sqlite3.open(path);
      database
        ..execute('''
        CREATE TABLE ZCLIPBOARDRECORD (
          Z_PK INTEGER PRIMARY KEY,
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
          'INSERT INTO ZCLIPBOARDRECORD VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          <Object?>[
            1,
            1,
            1,
            1,
            1,
            null,
            788918400,
            788922000,
            'taskMatch',
            'https://example.com/image.png',
            'Images',
            'BF489B14-F135-4359-A2D4-261A87626333',
            'Finder',
            'Example image',
            utf8.encode('["clipboard","image","sensitive"]'),
          ],
        );
      database.close();

      final ClipboardRepository repository = ClipboardRepository.open(path);
      addTearDown(repository.close);
      final List<ClipboardRecord> records = repository.list(limit: 5000);

      expect(records, hasLength(1));
      expect(records.single.title, 'Example image');
      expect(records.single.kind, ClipboardKind.image);
      expect(records.single.pinned, isTrue);
      expect(records.single.sensitive, isTrue);
      expect(records.single.createdAt, DateTime.utc(2026));
    },
  );

  test(
    'saving a clipboard record persists it across repository reopen',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-clipboard-save-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final String path = '${directory.path}/clipboard-history.sqlite';
      final ClipboardRecord record = ClipboardRecord(
        id: '71A1DCAB-DBD9-46A9-B05D-C62923FD3AE7',
        group: 'Commands',
        title: 'Run tests',
        content: 'flutter test',
        tags: const <String>['clipboard', 'command'],
        source: 'Terminal',
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: DateTime.utc(2026, 7, 12),
        updatedAt: DateTime.utc(2026, 7, 12),
      );
      final ClipboardRepository first = ClipboardRepository.open(path);
      first
        ..save(record)
        ..close();

      final ClipboardRepository reopened = ClipboardRepository.open(path);
      addTearDown(reopened.close);
      final ClipboardRecord stored = reopened.list(limit: 10).single;

      expect(stored.id, record.id);
      expect(stored.content, 'flutter test');
      expect(stored.kind, ClipboardKind.command);
      expect(stored.source, 'Terminal');
    },
  );

  test(
    'retention keeps pinned history and the newest bounded unpinned rows',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-clipboard-retention-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ClipboardRepository repository = ClipboardRepository.open(
        '${directory.path}/clipboard-history.sqlite',
      );
      addTearDown(repository.close);
      final DateTime now = DateTime.utc(2026, 7, 12);
      repository.save(
        _record(
          'pinned-old',
          now.subtract(const Duration(days: 30)),
          pinned: true,
        ),
      );
      repository.save(
        _record('expired', now.subtract(const Duration(days: 30))),
      );
      for (var index = 0; index < 22; index += 1) {
        repository.save(
          _record('recent-$index', now.add(Duration(seconds: index))),
        );
      }

      repository.trim(maxItems: 20, maxAgeDays: 7, now: now);
      final List<ClipboardRecord> records = repository.list(limit: 5000);

      expect(
        records.any((ClipboardRecord item) => item.id == 'pinned-old'),
        isTrue,
      );
      expect(
        records.any((ClipboardRecord item) => item.id == 'expired'),
        isFalse,
      );
      expect(
        records.where((ClipboardRecord item) => !item.pinned),
        hasLength(20),
      );
      expect(
        records.any((ClipboardRecord item) => item.id == 'recent-0'),
        isFalse,
      );
      expect(
        records.any((ClipboardRecord item) => item.id == 'recent-21'),
        isTrue,
      );
    },
  );
}

ClipboardRecord _record(String id, DateTime timestamp, {bool pinned = false}) {
  return ClipboardRecord(
    id: id,
    group: 'Clipboard',
    title: id,
    content: id,
    tags: const <String>['clipboard', 'text'],
    pinned: pinned,
    enabled: true,
    activation: pinned ? 'always' : 'taskMatch',
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
