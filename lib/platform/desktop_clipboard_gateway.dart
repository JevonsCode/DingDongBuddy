import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

/// Rich clipboard adapter shared by the macOS and Windows desktop hosts.
final class DesktopClipboardGateway implements ClipboardGateway {
  @override
  Future<ClipboardSnapshot> read() async {
    final Future<String?> text = Pasteboard.text;
    final Future<List<String>> files = Pasteboard.files();
    final image = Pasteboard.image;
    return ClipboardSnapshot(
      text: await text,
      filePaths: await files,
      imageBytes: await image,
    );
  }

  @override
  Future<void> writeFiles(List<String> paths) async {
    await Pasteboard.writeFiles(paths);
  }

  @override
  Future<void> writeText(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }
}
