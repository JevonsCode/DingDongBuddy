/// One item the computer shared (`clipboard.upsert.item`), shaped by the
/// desktop's `_recordPayload` (lib/features/device_link/ui/
/// device_link_file_transfer.dart).
final class ClipboardItem {
  const ClipboardItem({
    required this.id,
    required this.title,
    required this.kind,
    required this.sensitive,
    required this.content,
    required this.fileName,
    required this.fileSize,
    required this.downloadable,
    required this.source,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String kind;
  final bool sensitive;
  final String? content;
  final String? fileName;
  final int? fileSize;
  final bool downloadable;
  final String? source;
  final DateTime? updatedAt;

  bool get isFile => fileName != null;

  static ClipboardItem? parse(Object? value) {
    if (value is! Map) return null;
    final Object? id = value['id'];
    if (id is! String || id.isEmpty || id.length > 200) return null;
    final Object? sources = value['sources'];
    return ClipboardItem(
      id: id,
      title: value['title'] is String ? value['title']! as String : '',
      kind: value['kind'] is String ? value['kind']! as String : 'text',
      sensitive: value['sensitive'] == true,
      content: value['content'] is String ? value['content']! as String : null,
      fileName: value['fileName'] is String
          ? value['fileName']! as String
          : null,
      fileSize: value['fileSize'] is int ? value['fileSize']! as int : null,
      downloadable: value['downloadable'] != false,
      source: sources is List && sources.isNotEmpty && sources.last is String
          ? sources.last as String
          : null,
      updatedAt:
          DateTime.tryParse('${value['updatedAt'] ?? ''}') ??
          DateTime.tryParse('${value['createdAt'] ?? ''}'),
    );
  }

  /// UI snapshot form. Text is clipped; "copy" fetches the full content from
  /// the background isolate so snapshots stay small.
  Map<String, Object?> toSnapshot() => <String, Object?>{
    'id': id,
    'title': title,
    'kind': kind,
    'sensitive': sensitive,
    'preview': content == null
        ? null
        : content!.length > 600
        ? content!.substring(0, 600)
        : content,
    'hasContent': content != null,
    'fileName': fileName,
    'fileSize': fileSize,
    'downloadable': downloadable,
    'source': source,
    'updatedAt': updatedAt?.toUtc().toIso8601String(),
  };
}
