import 'dart:typed_data';

/// Platform clipboard values normalized before entering domain logic.
final class ClipboardSnapshot {
  const ClipboardSnapshot({
    this.text,
    this.filePaths = const <String>[],
    this.imageBytes,
    this.source = 'Clipboard',
  });

  final String? text;
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
