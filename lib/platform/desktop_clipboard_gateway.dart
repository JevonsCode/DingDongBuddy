import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

/// Rich clipboard adapter shared by the macOS and Windows desktop hosts.
final class DesktopClipboardGateway implements ClipboardGateway {
  DesktopClipboardGateway({Future<String?> Function()? sourceReader})
    : _sourceReader = sourceReader ?? _readSourceApplication;

  static const MethodChannel _monitorChannel = MethodChannel(
    'dingdong/clipboard_monitor',
  );

  final Future<String?> Function() _sourceReader;

  @override
  Future<ClipboardSnapshot> read() async {
    final Future<String?> text = Pasteboard.text;
    final Future<List<String>> files = Pasteboard.files();
    final image = Pasteboard.image;
    final Future<String?> source = _sourceReader();
    final String? sourceApplication = await source;
    return ClipboardSnapshot(
      text: await text,
      filePaths: await files,
      imageBytes: await image,
      source: sourceApplication?.trim().isNotEmpty ?? false
          ? sourceApplication!
          : 'Clipboard',
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

  static Future<String?> _readSourceApplication() async {
    try {
      return await _monitorChannel.invokeMethod<String>('sourceApplication');
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
