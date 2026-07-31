import 'dart:io';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_content_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

typedef ExternalFileLauncher = Future<bool> Function(Uri uri);

/// Opens clipboard files with their operating-system default applications.
final class UrlLauncherClipboardContentLauncher
    implements ClipboardContentLauncher {
  UrlLauncherClipboardContentLauncher({ExternalFileLauncher? launch})
    : _launch = launch ?? _launchExternally;

  final ExternalFileLauncher _launch;

  @override
  Future<void> open(ClipboardRecord record) async {
    final List<String> paths = record.filePaths
        .where(
          (String path) =>
              FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound,
        )
        .toList(growable: false);
    if (paths.isEmpty) {
      throw StateError('Clipboard file is no longer available.');
    }
    for (final String path in paths) {
      final Uri uri = Uri.file(path);
      if (!await _launch(uri)) {
        throw StateError('Could not open $uri');
      }
    }
  }

  static Future<bool> _launchExternally(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}
