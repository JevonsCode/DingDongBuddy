import 'dart:io';

import 'package:dingdong/features/library/domain/library_import_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'file-backed import history keeps newest entries and round-trips',
    () async {
      final Directory directory = Directory.systemTemp.createTempSync(
        'dingdong-import-history-',
      );
      addTearDown(() => directory.deleteSync(recursive: true));
      final File file = File('${directory.path}/history.json');
      final FileLibraryImportHistoryStore store = FileLibraryImportHistoryStore(
        file,
      );
      final DateTime first = DateTime.utc(2026, 8, 1);
      final DateTime second = DateTime.utc(2026, 8, 2);

      await store.record(
        LibraryImportHistoryEntry(
          source: 'first.json',
          kind: LibraryImportSourceKind.file,
          importedCount: 2,
          duplicateIds: const <String>['duplicate'],
          conflictIds: const <String>[],
          onlineTitles: const <String>[],
          createdAt: first,
        ),
      );
      await store.record(
        LibraryImportHistoryEntry(
          source: 'https://example.com/library.json',
          kind: LibraryImportSourceKind.link,
          importedCount: 1,
          duplicateIds: const <String>[],
          conflictIds: const <String>['conflict'],
          onlineTitles: const <String>['Review'],
          createdAt: second,
        ),
      );

      final List<LibraryImportHistoryEntry> entries = await store.load();
      expect(entries.map((LibraryImportHistoryEntry item) => item.source), [
        'https://example.com/library.json',
        'first.json',
      ]);
      expect(entries.first.kind, LibraryImportSourceKind.link);
      expect(entries.first.skippedCount, 1);
      expect(entries.first.onlineTitles, <String>['Review']);
    },
  );
}
