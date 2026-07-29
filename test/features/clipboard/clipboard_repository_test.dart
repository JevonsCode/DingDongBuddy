import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

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

  test('rich-text representations persist across repository reopen', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-clipboard-rich-text-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final String path = '${directory.path}/clipboard-history.sqlite';
    final Uint8List htmlData = Uint8List.fromList('<b>value</b>'.codeUnits);
    final Uint8List rtfData = Uint8List.fromList(r'{\rtf1 value}'.codeUnits);
    final ClipboardRepository first = ClipboardRepository.open(path);
    first
      ..save(
        ClipboardRecord(
          id: 'rich-text',
          group: 'Clipboard',
          title: 'Rich value',
          content: 'value',
          htmlData: htmlData,
          rtfData: rtfData,
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: DateTime.utc(2026, 7, 12),
          updatedAt: DateTime.utc(2026, 7, 12),
        ),
      )
      ..close();

    final ClipboardRepository reopened = ClipboardRepository.open(path);
    addTearDown(reopened.close);
    final ClipboardRecord stored = reopened.list(limit: 10).single;

    expect(stored.htmlData, htmlData);
    expect(stored.rtfData, rtfData);
    expect(stored.hasFormattedText, isTrue);
  });

  test(
    'multiple clipboard groups round-trip through the legacy column',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-clipboard-groups-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final String path = '${directory.path}/clipboard-history.sqlite';
      final ClipboardRepository first = ClipboardRepository.open(path);
      first.save(
        ClipboardRecord(
          id: 'multi-group',
          group: '项目甲',
          groups: const <String>['项目甲', '项目乙'],
          title: 'Shared note',
          content: 'Shared note',
          tags: const <String>['clipboard', 'text'],
          pinned: false,
          enabled: true,
          activation: 'taskMatch',
          createdAt: DateTime.utc(2026, 7, 12),
          updatedAt: DateTime.utc(2026, 7, 12),
        ),
      );
      first.close();

      final Database raw = sqlite3.open(path);
      final String encoded =
          raw.select('SELECT ZGROUP FROM ZCLIPBOARDRECORD').single['ZGROUP']
              as String;
      raw.close();
      expect(jsonDecode(encoded), <Object?>['项目甲', '项目乙']);

      final ClipboardRepository reopened = ClipboardRepository.open(path);
      addTearDown(reopened.close);
      expect(reopened.list(limit: 10).single.groupNames, <String>[
        '项目甲',
        '项目乙',
      ]);
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

  test(
    'retention excludes legacy and grouped archives from automatic deletion',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-clipboard-archive-retention-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ClipboardRepository repository = ClipboardRepository.open(
        '${directory.path}/clipboard-history.sqlite',
      );
      addTearDown(repository.close);
      final DateTime now = DateTime.utc(2026, 7, 12);
      repository.save(
        _record(
          'legacy-archive',
          now.subtract(const Duration(days: 30)),
          group: 'Archive',
          tags: const <String>['clipboard', 'text', 'archived'],
        ),
      );
      repository.save(
        _record(
          'grouped-archive',
          now.subtract(const Duration(days: 30)),
          group: 'Clipboard',
          groups: const <String>['Clipboard', '项目归档'],
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
        records.any((ClipboardRecord item) => item.id == 'legacy-archive'),
        isTrue,
      );
      expect(
        records.any((ClipboardRecord item) => item.id == 'grouped-archive'),
        isTrue,
      );
      expect(
        records.any((ClipboardRecord item) => item.id == 'expired'),
        isFalse,
      );
      expect(
        records
            .where(
              (ClipboardRecord item) =>
                  !item.tags.contains('archived') &&
                  !item.groupNames.contains('项目归档'),
            )
            .length,
        20,
      );
    },
  );

  test(
    'protected history remains listable beyond the ordinary limit',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-clipboard-protected-list-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ClipboardRepository repository = ClipboardRepository.open(
        '${directory.path}/clipboard-history.sqlite',
      );
      addTearDown(repository.close);
      final DateTime now = DateTime.utc(2026, 7, 12);
      repository.save(
        _record(
          'old-archive',
          now.subtract(const Duration(days: 30)),
          tags: const <String>['clipboard', 'text', 'archived'],
        ),
      );
      for (var index = 0; index < 22; index += 1) {
        repository.save(
          _record('recent-$index', now.add(Duration(seconds: index))),
        );
      }

      final List<ClipboardRecord> records = repository.list(
        limit: 20,
        includeProtectedBeyondLimit: true,
      );

      expect(records, hasLength(21));
      expect(
        records.any((ClipboardRecord item) => item.id == 'old-archive'),
        isTrue,
      );
      expect(
        records.where((ClipboardRecord item) => !item.isArchived),
        hasLength(20),
      );
    },
  );
}

ClipboardRecord _record(
  String id,
  DateTime timestamp, {
  bool pinned = false,
  String group = 'Clipboard',
  List<String> groups = const <String>[],
  List<String> tags = const <String>['clipboard', 'text'],
}) {
  return ClipboardRecord(
    id: id,
    group: group,
    groups: groups,
    title: id,
    content: id,
    tags: tags,
    pinned: pinned,
    enabled: true,
    activation: pinned ? 'always' : 'taskMatch',
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}
