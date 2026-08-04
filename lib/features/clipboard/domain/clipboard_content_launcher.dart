import 'dart:io';

import 'package:dingdong/core/models/clipboard_record.dart';

/// Opens file-backed clipboard content with the operating system.
abstract interface class ClipboardContentLauncher {
  Future<void> open(ClipboardRecord record);
}

/// Whether a clipboard row has a valid system-open target right now.
bool canOpenClipboardContent(ClipboardRecord record) {
  return switch (record.kind) {
    ClipboardKind.url => _externalUri(record.content) != null,
    ClipboardKind.file || ClipboardKind.image => record.filePaths.any(
      (String path) =>
          FileSystemEntity.typeSync(path) != FileSystemEntityType.notFound,
    ),
    ClipboardKind.path => _existingPath(record.content) != null,
    _ => false,
  };
}

/// Resolves the external URI for link records without accepting unsafe or
/// ambiguous schemes.
Uri? clipboardExternalUri(ClipboardRecord record) {
  if (record.kind != ClipboardKind.url) return null;
  return _externalUri(record.content);
}

String? clipboardExistingPath(ClipboardRecord record) {
  if (record.kind != ClipboardKind.path) return null;
  return _existingPath(record.content);
}

Uri? _externalUri(String value) {
  final Uri? uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasAuthority) return null;
  return switch (uri.scheme.toLowerCase()) {
    'http' || 'https' => uri,
    _ => null,
  };
}

String? _existingPath(String value) {
  final String path = value.trim();
  if (path.isEmpty ||
      FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
    return null;
  }
  return path;
}
