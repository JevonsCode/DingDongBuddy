import 'package:dingdong/core/models/clipboard_record.dart';

/// The last ordering key, independent of a changing row offset.
final class ClipboardHistoryCursor {
  const ClipboardHistoryCursor(this.record, {this.sqlKey});
  final ClipboardRecord record;
  final List<Object?>? sqlKey;
}

final class ClipboardHistoryPage {
  const ClipboardHistoryPage(this.records, {this.nextCursor});
  final List<ClipboardRecord> records;
  final ClipboardHistoryCursor? nextCursor;
}

/// History queries used by both desktop list surfaces. Legacy export/capture
/// APIs remain separate and do not determine the amount loaded by the UI.
abstract interface class PagedClipboardStore {
  ClipboardHistoryPage readHistoryPage({
    required int limit,
    ClipboardHistoryCursor? after,
    bool byCopyCount = false,
    bool Function(ClipboardRecord)? matches,
  });

  List<String> historySources();
  ClipboardRecord? historyRecord(String id);
  bool hasHistoryImageReference(String content);
}

int compareClipboardCopyCounts(ClipboardRecord left, ClipboardRecord right) {
  if (left.pinned != right.pinned) return left.pinned ? -1 : 1;
  final count = right.copyCount.compareTo(left.copyCount);
  if (count != 0) return count;
  final updated = right.updatedAt.compareTo(left.updatedAt);
  return updated != 0 ? updated : left.id.compareTo(right.id);
}
