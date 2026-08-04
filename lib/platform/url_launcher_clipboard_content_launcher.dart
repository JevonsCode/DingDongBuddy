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
    final List<Uri> targets = _targets(record);
    if (targets.isEmpty) {
      throw StateError('Clipboard content is no longer available.');
    }
    for (final Uri uri in targets) {
      if (!await _launch(uri)) {
        throw StateError('Could not open $uri');
      }
    }
  }

  static Future<bool> _launchExternally(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);
}

List<Uri> _targets(ClipboardRecord record) {
  final Uri? externalUri = clipboardExternalUri(record);
  if (externalUri != null) return <Uri>[externalUri];

  final String? path = clipboardExistingPath(record);
  if (path != null) return <Uri>[Uri.file(path)];

  return record.filePaths
      .where(
        (String value) =>
            FileSystemEntity.typeSync(value) != FileSystemEntityType.notFound,
      )
      .map(Uri.file)
      .toList(growable: false);
}
