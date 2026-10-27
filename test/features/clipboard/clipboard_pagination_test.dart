import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'clipboard history initially reads one page rather than the full store',
    () {
      final model = ClipboardViewModel(
        InMemoryClipboardStore(List.generate(125, record)),
      )..load();
      addTearDown(model.dispose);
      expect(model.visibleRecords.length, 50);
    },
  );
}

ClipboardRecord record(int index) => ClipboardRecord(
  id: 'record-${index.toString().padLeft(4, '0')}',
  group: '',
  title: 'History $index',
  content: 'Content $index',
  tags: const ['text'],
  sources: [
    index < 100 ? 'Notes · com.apple.Notes' : 'Safari · com.apple.Safari',
  ],
  pinned: false,
  enabled: true,
  activation: 'taskMatch',
  createdAt: DateTime.utc(2026, 10, 27).subtract(Duration(seconds: index)),
  updatedAt: DateTime.utc(2026, 10, 27).subtract(Duration(seconds: index)),
);
