import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_manager_screen.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bulk manager archives multiple selected clipboard rows', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 7, 12);
    final InMemoryClipboardStore store = InMemoryClipboardStore(
      <ClipboardRecord>[_record('first', now), _record('second', now)],
    );
    final ClipboardViewModel model = ClipboardViewModel(store)..load();
    await tester.pumpWidget(
      MaterialApp(home: ClipboardManagerScreen(viewModel: model)),
    );

    await tester.tap(find.byKey(const Key('clipboard-manager-select-first')));
    await tester.tap(find.byKey(const Key('clipboard-manager-select-second')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('clipboard-bulk-archive')));
    await tester.pump();

    expect(
      store
          .list(limit: 10)
          .every((ClipboardRecord item) => item.tags.contains('archived')),
      isTrue,
    );
  });
}

ClipboardRecord _record(String id, DateTime now) => ClipboardRecord(
  id: id,
  group: '',
  title: id,
  content: '$id content',
  tags: const <String>['clipboard', 'text'],
  pinned: false,
  enabled: true,
  activation: 'taskMatch',
  createdAt: now,
  updatedAt: now,
);
