import 'dart:io';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/data/clipboard_history_page.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_list_tile.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_manager_screen.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_screen.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'clipboard_pagination_test.dart' show record;

void main() {
  for (final sqlite in [false, true]) {
    group(sqlite ? 'SQLite pages' : 'memory pages', () {
      late ClipboardStore store;
      setUp(() async {
        if (sqlite) {
          final directory = await Directory.systemTemp.createTemp(
            'jvs-a-clipboard-page-',
          );
          final repository = ClipboardRepository.open(
            '${directory.path}/history.sqlite',
          );
          addTearDown(() {
            repository.close();
            directory.deleteSync(recursive: true);
          });
          store = repository;
        } else {
          store = InMemoryClipboardStore();
        }
        for (var i = 0; i < 125; i++) {
          store.save(record(i));
        }
      });

      test(
        'pages cover every record once including equal timestamps and pins',
        () {
          final sameTime = record(0).updatedAt;
          for (var i = 0; i < 125; i++) {
            store.save(
              record(i).copyWith(
                updatedAt: sameTime,
                pinned: i % 3 == 0,
                sortOrder: i % 2 == 0 ? i % 7 : null,
              ),
            );
          }
          final expected = store.list(limit: 5000).map((r) => r.id).toList();
          final ids = <String>[];
          ClipboardHistoryCursor? cursor;
          do {
            final page = store.readHistoryPage(limit: 17, after: cursor);
            expect(page.records.length, lessThanOrEqualTo(17));
            ids.addAll(page.records.map((r) => r.id));
            cursor = page.nextCursor;
          } while (cursor != null);
          expect(ids, expected);
          expect(ids.toSet().length, 125);
        },
      );

      test(
        'queries stop at one page plus lookahead and copy-count pages stay ordered',
        () {
          var evaluated = 0;
          final first = store.readHistoryPage(
            limit: 50,
            matches: (r) {
              evaluated++;
              return true;
            },
          );
          expect(first.records.length, 50);
          expect(evaluated, 51);
          for (var i = 0; i < 125; i++) {
            store.save(
              record(i).copyWith(
                copyCount: i % 9 + 1,
                pinned: i % 5 == 0,
                updatedAt: record(0).updatedAt,
              ),
            );
          }
          final expected = List<ClipboardRecord>.of(store.list(limit: 5000))
            ..sort(compareClipboardCopyCounts);
          final ids = <String>[];
          ClipboardHistoryCursor? cursor;
          do {
            final page = store.readHistoryPage(
              limit: 19,
              after: cursor,
              byCopyCount: true,
            );
            ids.addAll(page.records.map((r) => r.id));
            cursor = page.nextCursor;
          } while (cursor != null);
          expect(ids, expected.map((r) => r.id));
        },
      );

      test(
        'deleting the cursor row or inserting above it does not skip the next page',
        () {
          final first = store.readHistoryPage(limit: 50);
          store.delete(first.records.last.id);
          store.delete(first.records.first.id);
          store.save(
            record(999).copyWith(
              updatedAt: record(0).updatedAt.add(const Duration(minutes: 1)),
            ),
          );
          final next = store.readHistoryPage(
            limit: 50,
            after: first.nextCursor,
          );
          expect(next.records.first.id, record(50).id);
          expect(next.records.last.id, record(99).id);
        },
      );

      test(
        'search covers unloaded Unicode and literal wildcards and resets paging',
        () {
          store.save(
            record(120).copyWith(
              title: 'ÉTÉ 中文 100%_literal',
              tags: ['text', 'deep-tag'],
            ),
          );
          final model = ClipboardViewModel(store)..load();
          addTearDown(model.dispose);
          expect(model.visibleRecords.length, 50);
          expect(model.hasMoreHistory, isTrue);
          model.loadNextPage();
          expect(model.visibleRecords.length, 100);
          model.setQuery('été 中文 100%_');
          expect(model.visibleRecords.single.id, record(120).id);
          expect(model.hasMoreHistory, isFalse);
          model.setQuery('no-such-result');
          expect(model.visibleRecords, isEmpty);
          model.setQuery('deep-tag');
          expect(model.visibleRecords.single.id, record(120).id);
          model.setQuery('');
          expect(model.visibleRecords.length, 50);
          expect(model.visibleRecords.first.id, record(0).id);
          model.loadNextPage();
          model.loadNextPage();
          expect(model.visibleRecords.length, 125);
          expect(model.hasMoreHistory, isFalse);
          model.loadNextPage();
          expect(model.visibleRecords.length, 125);
        },
      );

      test(
        'all source options remain available and sorting and filters reset pages',
        () {
          store.save(record(124).copyWith(copyCount: 500));
          final model = ClipboardViewModel(store)..load();
          addTearDown(model.dispose);
          final safari = model.sourceOptions.singleWhere(
            (s) => s.label.contains('Safari'),
          );
          model.toggleSource(safari.id);
          expect(model.visibleRecords.length, 25);
          expect(
            model.visibleRecords.every(
              (r) => r.sources.any((s) => s.contains('Safari')),
            ),
            isTrue,
          );
          model.setQuery('Content 12');
          expect(model.visibleRecords.length, 5);
          model.clearSources();
          expect(model.visibleRecords.length, 6);
          model.setQuery('');
          model.setSortMode(ClipboardSortMode.copyCount);
          expect(model.visibleRecords.first.id, record(124).id);
          model.loadNextPage();
          expect(model.visibleRecords.length, 100);
          model.setCategory('images');
          expect(model.visibleRecords, isEmpty);
          model.clearFilters();
          expect(model.visibleRecords.length, 50);
          expect(model.visibleRecords.first.id, record(124).id);
        },
      );

      test(
        'deletion backfills the loaded window and refresh and keyboard preserve paging',
        () {
          final model = ClipboardViewModel(store)..load();
          addTearDown(model.dispose);
          model.select(model.visibleRecords.last);
          model.moveSelection(1);
          expect(model.selectedRecord?.id, record(50).id);
          expect(model.visibleRecords.length, 100);
          model.deleteSelected();
          expect(model.visibleRecords.length, 100);
          expect(
            model.visibleRecords.any((r) => r.id == record(50).id),
            isFalse,
          );
          expect(model.visibleRecords.last.id, record(100).id);
          model.loadNextPage();
          expect(model.visibleRecords.length, 124);
          expect(model.visibleRecords.map((r) => r.id).toSet().length, 124);
          model.load();
          expect(model.visibleRecords.length, 50);
          expect(model.hasMoreHistory, isTrue);
        },
      );
    });
  }

  for (final manager in [false, true]) {
    testWidgets(
      '${manager ? 'manager' : 'quick panel'} lazy paging and full-history search',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(manager ? 1200 : 390, 760);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final store = _PagedOnlyStore(
          InMemoryClipboardStore(List.generate(525, record)),
        );
        final model = ClipboardViewModel(store)..load();
        addTearDown(model.dispose);
        await tester.pumpWidget(
          MaterialApp(
            home: manager
                ? ClipboardManagerScreen(viewModel: model)
                : ClipboardScreen(viewModel: model),
          ),
        );
        await tester.pumpAndSettle();
        final list = find.byKey(
          Key(manager ? 'clipboard-manager-list' : 'clipboard-list'),
        );
        final scrollable = find
            .descendant(of: list, matching: find.byType(Scrollable))
            .first;
        final position = tester.state<ScrollableState>(scrollable).position;
        expect(model.visibleRecords.length, 50);
        expect(store.readLimits, [50]);
        if (!manager) {
          expect(
            find.byType(ClipboardListTile).evaluate().length,
            lessThan(30),
          );
        }
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
        expect(model.visibleRecords.length, 100);
        expect(store.readLimits, [50, 50]);
        final search = find.byKey(
          Key(manager ? 'clipboard-manager-search' : 'clipboard-search'),
        );
        await tester.enterText(search, 'Content 520');
        await tester.pumpAndSettle();
        expect(model.visibleRecords.single.id, record(520).id);
        expect(find.text('History 520'), findsOneWidget);
        expect(position.pixels, 0);
        await tester.enterText(search, 'not-present');
        await tester.pumpAndSettle();
        expect(model.visibleRecords, isEmpty);
        await tester.enterText(search, '');
        await tester.pumpAndSettle();
        expect(model.visibleRecords.length, 50);
        final current = tester.state<ScrollableState>(scrollable).position;
        expect(current.pixels, 0);
        expect(find.text('History 0'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

final class _PagedOnlyStore implements ClipboardStore {
  _PagedOnlyStore(this.delegate);
  final InMemoryClipboardStore delegate;
  final List<int> readLimits = [];
  @override
  ClipboardHistoryPage readHistoryPage({
    required int limit,
    ClipboardHistoryCursor? after,
    bool byCopyCount = false,
    bool Function(ClipboardRecord)? matches,
  }) {
    readLimits.add(limit);
    return delegate.readHistoryPage(
      limit: limit,
      after: after,
      byCopyCount: byCopyCount,
      matches: matches,
    );
  }

  @override
  List<ClipboardRecord> list({
    required int limit,
    bool includeProtectedBeyondLimit = false,
  }) => throw StateError('UI must use pages, never the full history API');
  @override
  List<String> historySources() => delegate.historySources();
  @override
  bool hasHistoryImageReference(String content) =>
      delegate.hasHistoryImageReference(content);
  @override
  ClipboardRecord? historyRecord(String id) => delegate.historyRecord(id);
  @override
  int historyCount() => delegate.historyCount();
  @override
  DateTime? latestUpdatedAt() => delegate.latestUpdatedAt();
  @override
  void save(ClipboardRecord record) => delegate.save(record);
  @override
  void delete(String id) => delegate.delete(id);
}
