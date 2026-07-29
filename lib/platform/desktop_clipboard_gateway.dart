import 'dart:io';

import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';

/// Rich clipboard adapter shared by the macOS and Windows desktop hosts.
final class DesktopClipboardGateway
    implements
        ClipboardGateway,
        FormattedTextClipboardGateway,
        ImageClipboardGateway {
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
    final Future<Map<String, Object?>?> textFormats = _readTextFormats();
    final String? sourceApplication = await source;
    final Map<String, Object?>? formats = await textFormats;
    return ClipboardSnapshot(
      text: await text,
      htmlData: _typedData(formats?['htmlData']),
      rtfData: _typedData(formats?['rtfData']),
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
  Future<bool> writeImageFile(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) {
        return false;
      }
      if (Platform.isMacOS) {
        try {
          final bool? written = await _monitorChannel.invokeMethod<bool>(
            'writeImageFile',
            <String, Object>{'path': path, 'imageData': bytes},
          );
          if (written == true) {
            return true;
          }
        } on PlatformException {
          // Fall back to bitmap-only clipboard support below.
        } on MissingPluginException {
          // Fall back to bitmap-only clipboard support below.
        }
      }
      await Pasteboard.writeImage(bytes);
      return true;
    } on FileSystemException {
      return false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> writeText(String text) {
    return Clipboard.setData(ClipboardData(text: text));
  }

  @override
  Future<void> writeFormattedText({
    required String plainText,
    Uint8List? htmlData,
    Uint8List? rtfData,
  }) async {
    if ((htmlData?.isEmpty ?? true) && (rtfData?.isEmpty ?? true)) {
      await writeText(plainText);
      return;
    }
    try {
      await _monitorChannel
          .invokeMethod<void>('writeTextFormats', <String, Object>{
            'plainText': plainText,
            if (htmlData?.isNotEmpty ?? false) 'htmlData': htmlData!,
            if (rtfData?.isNotEmpty ?? false) 'rtfData': rtfData!,
          });
    } on PlatformException {
      await writeText(plainText);
    } on MissingPluginException {
      await writeText(plainText);
    }
  }

  static Future<Map<String, Object?>?> _readTextFormats() async {
    try {
      return await _monitorChannel.invokeMapMethod<String, Object?>(
        'readTextFormats',
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  static Uint8List? _typedData(Object? value) => switch (value) {
    final Uint8List data when data.isNotEmpty => data,
    final List<int> data when data.isNotEmpty => Uint8List.fromList(data),
    _ => null,
  };

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
