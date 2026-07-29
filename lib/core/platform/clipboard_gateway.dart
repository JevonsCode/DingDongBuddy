import 'dart:typed_data';

/// Platform clipboard values normalized before entering domain logic.
final class ClipboardSnapshot {
  const ClipboardSnapshot({
    this.text,
    this.htmlData,
    this.rtfData,
    this.filePaths = const <String>[],
    this.imageBytes,
    this.source = 'Clipboard',
  });

  final String? text;
  final Uint8List? htmlData;
  final Uint8List? rtfData;
  final List<String> filePaths;
  final Uint8List? imageBytes;
  final String source;
}

/// Public system boundary for reading and restoring clipboard content.
abstract interface class ClipboardGateway {
  Future<ClipboardSnapshot> read();

  Future<void> writeText(String text);

  Future<void> writeFiles(List<String> paths);
}

/// Optional platform capability for restoring the original rich-text
/// representations alongside their plain-text fallback.
abstract interface class FormattedTextClipboardGateway {
  Future<void> writeFormattedText({
    required String plainText,
    Uint8List? htmlData,
    Uint8List? rtfData,
  });
}

/// Optional platform capability for restoring one image with both bitmap and
/// source-file representations. This keeps image pasting compatible with
/// editors while preserving Finder-style file clipboard behavior.
abstract interface class ImageClipboardGateway {
  Future<bool> writeImageFile(String path);
}
