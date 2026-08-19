import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/managed_clipboard_images.dart';
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
      expect(records.single.groupNames, <String>['Images']);
      expect(records.single.pinned, isTrue);
      expect(records.single.sensitive, isTrue);
      expect(records.single.createdAt, DateTime.utc(2026));
      expect(records.single.sources, <String>['Finder']);
      expect(records.single.copyCount, 1);
      expect(repository.historyCount(), 1);
      expect(repository.latestUpdatedAt(), records.single.updatedAt);
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
        sources: const <String>['Terminal', 'Browser'],
        copyCount: 3,
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
      expect(stored.source, 'Browser');
      expect(stored.sources, <String>['Terminal', 'Browser']);
      expect(stored.copyCount, 3);
      expect(reopened.historyCount(), 1);
      expect(reopened.latestUpdatedAt(), record.updatedAt);
    },
  );

  test('repository orders pinned and manually sorted clipboard rows', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-clipboard-order-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final String path = '${directory.path}/clipboard-history.sqlite';
    final DateTime now = DateTime.utc(2026, 7, 12);
    ClipboardRecord record(
      String id, {
      required bool pinned,
      int? sortOrder,
      String group = 'Clipboard',
    }) => ClipboardRecord(
      id: id,
      group: group,
      title: id,
      content: id,
      tags: const <String>['clipboard', 'text'],
      pinned: pinned,
      enabled: true,
      activation: pinned ? 'always' : 'taskMatch',
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now.subtract(Duration(seconds: id.hashCode.abs() % 10)),
    );
    final ClipboardRepository repository = ClipboardRepository.open(path);
    addTearDown(repository.close);
    repository
      ..save(record('newest', pinned: false))
      ..save(record('manual', pinned: false, sortOrder: 1))
      ..save(record('pinned', pinned: true, sortOrder: 9))
      ..saveArchive(
        ClipboardArchiveEntry(
          record: record(
            'archived',
            pinned: false,
            sortOrder: 1,
            group: 'Saved',
          ),
          sourceClipboardId: 'source-archived',
          archivedAt: now,
        ),
      )
      ..saveArchive(
        ClipboardArchiveEntry(
          record: record(
            'archived-pinned',
            pinned: true,
            sortOrder: 9,
            group: 'Saved',
          ),
          sourceClipboardId: 'source-archived-pinned',
          archivedAt: now,
        ),
      );

    expect(repository.list(limit: 10).map((item) => item.id), <String>[
      'pinned',
      'newest',
      'manual',
    ]);
    expect(repository.listArchives().map((entry) => entry.record.id), <String>[
      'archived-pinned',
      'archived',
    ]);
  });

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

  test('custom groups create an independent archive copy', () async {
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
        sources: const <String>['Terminal', 'Browser'],
        copyCount: 4,
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: DateTime.utc(2026, 7, 12),
        updatedAt: DateTime.utc(2026, 7, 12),
      ),
    );
    first.close();

    final Database raw = sqlite3.open(path);
    final String historyGroups =
        raw.select('SELECT ZGROUP FROM ZCLIPBOARDRECORD').single['ZGROUP']
            as String;
    final String encoded =
        raw.select('SELECT ZGROUP FROM ZCLIPBOARDARCHIVE').single['ZGROUP']
            as String;
    raw.close();
    expect(historyGroups, isEmpty);
    expect(jsonDecode(encoded), <Object?>['项目甲', '项目乙']);

    final ClipboardRepository reopened = ClipboardRepository.open(path);
    addTearDown(reopened.close);
    expect(reopened.list(limit: 10).single.groupNames, isEmpty);
    expect(reopened.listArchives().single.record.groupNames, <String>[
      '项目甲',
      '项目乙',
    ]);
    expect(reopened.listArchives().single.sourceClipboardId, 'multi-group');
    expect(reopened.listArchives().single.record.sources, <String>[
      'Terminal',
      'Browser',
    ]);
    expect(reopened.listArchives().single.record.copyCount, 4);
  });

  test(
    'clipboard and archive deletion are isolated in both directions',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-clipboard-delete-isolation-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ClipboardRepository repository = ClipboardRepository.open(
        '${directory.path}/clipboard-history.sqlite',
      );
      addTearDown(repository.close);
      final DateTime now = DateTime.utc(2026, 8, 6);

      repository.save(_record('source-a', now, group: 'PageID'));
      final ClipboardArchiveEntry archiveA = repository.listArchives().single;
      repository.delete('source-a');
      expect(repository.list(limit: 10), isEmpty);
      expect(repository.listArchives().single.record.id, archiveA.record.id);

      repository.save(_record('source-b', now, group: 'iDev ID'));
      final ClipboardArchiveEntry archiveB = repository
          .listArchives()
          .firstWhere(
            (ClipboardArchiveEntry entry) =>
                entry.sourceClipboardId == 'source-b',
          );
      repository.deleteArchive(archiveB.record.id);
      expect(
        repository.list(limit: 10).map((ClipboardRecord record) => record.id),
        contains('source-b'),
      );
      expect(
        repository.listArchives().map(
          (ClipboardArchiveEntry entry) => entry.record.id,
        ),
        isNot(contains(archiveB.record.id)),
      );
    },
  );

  test('legacy grouped rows migrate atomically and idempotently', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-clipboard-legacy-archive-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final String path = '${directory.path}/clipboard-history.sqlite';
    final DateTime now = DateTime.utc(2026, 8, 6);
    final ClipboardRepository initial = ClipboardRepository.open(path);
    initial
      ..save(_record('legacy-source', now))
      ..close();
    final Database raw = sqlite3.open(path);
    raw
      ..execute(
        'UPDATE ZCLIPBOARDRECORD SET ZGROUP = ? WHERE ZID = ?',
        <Object?>['["Clipboard","PageID","iDev ID"]', 'legacy-source'],
      )
      ..close();

    final ClipboardRepository migrated = ClipboardRepository.open(path);
    expect(migrated.list(limit: 10).single.groupNames, <String>['Clipboard']);
    expect(migrated.listArchives(), hasLength(1));
    expect(migrated.listArchives().single.record.groupNames, <String>[
      'PageID',
      'iDev ID',
    ]);
    expect(migrated.listArchives().single.record.content, 'legacy-source');
    migrated.close();

    final ClipboardRepository reopened = ClipboardRepository.open(path);
    addTearDown(reopened.close);
    expect(reopened.listArchives(), hasLength(1));
    expect(reopened.listArchives().single.sourceClipboardId, 'legacy-source');
  });

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

      final List<ClipboardRecord> deleted = repository.trim(
        maxItems: 20,
        maxAgeDays: 7,
        now: now,
      );
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
      expect(
        deleted.map((ClipboardRecord item) => item.id),
        containsAll(<String>['expired', 'recent-0', 'recent-1']),
      );
      expect(
        deleted.any((ClipboardRecord item) => item.id == 'pinned-old'),
        isFalse,
      );
    },
  );

  test(
    'deleteAll removes protected history as an explicit user action',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-clipboard-delete-all-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final ClipboardRepository repository = ClipboardRepository.open(
        '${directory.path}/clipboard-history.sqlite',
      );
      addTearDown(repository.close);
      final DateTime now = DateTime.utc(2026, 7, 12);
      repository
        ..save(_record('ordinary', now))
        ..save(_record('pinned', now, pinned: true))
        ..save(
          _record(
            'archived',
            now,
            tags: const <String>['clipboard', 'text', 'archived'],
          ),
        );

      repository.deleteAll();

      expect(
        repository.list(limit: 5000, includeProtectedBeyondLimit: true),
        isEmpty,
      );
    },
  );

  test(
    'retention protects current archive groups but not obsolete archive tags',
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
          'tag-only-archive',
          now.subtract(const Duration(days: 30)),
          group: 'Clipboard',
          tags: const <String>['clipboard', 'text', 'archived'],
        ),
      );
      repository.save(
        _record(
          'archive-group',
          now.subtract(const Duration(days: 30)),
          group: 'Archive',
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
        records.any((ClipboardRecord item) => item.id == 'tag-only-archive'),
        isFalse,
      );
      final List<ClipboardArchiveEntry> archives = repository.listArchives();
      expect(
        archives.any(
          (ClipboardArchiveEntry item) =>
              item.sourceClipboardId == 'archive-group',
        ),
        isTrue,
      );
      expect(
        archives.any(
          (ClipboardArchiveEntry item) =>
              item.sourceClipboardId == 'grouped-archive',
        ),
        isTrue,
      );
      expect(
        records.any((ClipboardRecord item) => item.id == 'expired'),
        isFalse,
      );
      expect(records, hasLength(20));
    },
  );

  test(
    'obsolete archive tags no longer escape the ordinary history limit',
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

      expect(records, hasLength(20));
      expect(
        records.any((ClipboardRecord item) => item.id == 'old-archive'),
        isFalse,
      );
      expect(
        records.where((ClipboardRecord item) => !item.isArchived),
        hasLength(20),
      );
    },
  );

  test(
    'image retention deletes expired managed data and preserves archives',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-clipboard-image-retention-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final Directory images = Directory('${directory.path}/images')
        ..createSync();
      final File expiredImage = File('${images.path}/clipboard-expired.png')
        ..writeAsBytesSync(<int>[1]);
      final File archivedImage = File('${images.path}/clipboard-archived.png')
        ..writeAsBytesSync(<int>[2]);
      final File orphanImage = File('${images.path}/clipboard-orphan.png')
        ..writeAsBytesSync(<int>[3]);
      final ClipboardRepository repository = ClipboardRepository.open(
        '${directory.path}/clipboard-history.sqlite',
      );
      addTearDown(repository.close);
      final DateTime now = DateTime.utc(2026, 7, 12);
      repository
        ..save(
          ClipboardRecord(
            id: 'expired-image',
            group: '',
            title: 'Expired image',
            content: expiredImage.path,
            tags: const <String>['clipboard', 'file', 'file-url', 'image'],
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now.subtract(const Duration(days: 30)),
            updatedAt: now.subtract(const Duration(days: 30)),
          ),
        )
        ..save(
          ClipboardRecord(
            id: 'archived-image',
            group: 'Archive',
            title: 'Archived image',
            content: archivedImage.path,
            tags: const <String>['clipboard', 'file', 'file-url', 'image'],
            pinned: false,
            enabled: true,
            activation: 'taskMatch',
            createdAt: now.subtract(const Duration(days: 30)),
            updatedAt: now.subtract(const Duration(days: 30)),
          ),
        );

      final List<ClipboardRecord> deleted = repository.trim(
        maxItems: 20,
        maxAgeDays: 7,
        now: now,
      );
      final List<ClipboardRecord> archives = repository
          .listArchives()
          .map((ClipboardArchiveEntry entry) => entry.record)
          .toList(growable: false);
      for (final ClipboardRecord record in deleted) {
        if (!archives.any(
          (ClipboardRecord archive) => archive.content == record.content,
        )) {
          deleteManagedClipboardImage(record, images);
        }
      }
      pruneUnreferencedManagedClipboardImages(<ClipboardRecord>[
        ...repository.list(limit: 5000, includeProtectedBeyondLimit: true),
        ...archives,
      ], images);

      expect(expiredImage.existsSync(), isFalse);
      expect(orphanImage.existsSync(), isFalse);
      expect(archivedImage.existsSync(), isTrue);
      expect(
        repository.listArchives().map(
          (ClipboardArchiveEntry entry) => entry.sourceClipboardId,
        ),
        contains('archived-image'),
      );
    },
  );

  test('history kind cleanup never deletes archive snapshots', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-clipboard-kind-cleanup-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final ClipboardRepository repository = ClipboardRepository.open(
      '${directory.path}/clipboard-history.sqlite',
    );
    addTearDown(repository.close);
    final DateTime now = DateTime.utc(2026, 8, 6);
    repository
      ..save(
        _record(
          'archived-image',
          now,
          group: 'Project Alpha',
          tags: const <String>['clipboard', 'file', 'file-url', 'image'],
        ),
      )
      ..save(_record('plain-text', now))
      ..save(
        _record(
          'plain-file',
          now,
          tags: const <String>['clipboard', 'file', 'file-url'],
        ),
      );

    final List<ClipboardRecord> deleted = repository.deleteHistoryKinds(
      <ClipboardKind>{ClipboardKind.image, ClipboardKind.text},
    );

    expect(
      deleted.map((ClipboardRecord record) => record.id),
      containsAll(<String>['archived-image', 'plain-text']),
    );
    expect(
      repository.list(limit: 20).map((ClipboardRecord record) => record.id),
      <String>['plain-file'],
    );
    expect(repository.listArchives(), hasLength(1));
    expect(
      repository.listArchives().single.sourceClipboardId,
      'archived-image',
    );
  });
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
