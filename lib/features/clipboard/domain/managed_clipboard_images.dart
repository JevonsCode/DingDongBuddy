import 'dart:io';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:path/path.dart' as path;

/// Identifies image files created and owned by DingDong for raw image data.
bool isManagedClipboardImage(ClipboardRecord record, Directory imageDirectory) {
  if (!record.tags.contains('image') ||
      !record.tags.contains('file-url') ||
      record.content.trim().isEmpty ||
      record.content.contains('\n')) {
    return false;
  }
  return path.isWithin(
    _normalizedAbsolute(imageDirectory.path),
    _normalizedAbsolute(record.content),
  );
}

/// Removes one DingDong-owned image without touching copied source files.
bool deleteManagedClipboardImage(
  ClipboardRecord record,
  Directory imageDirectory,
) {
  if (!isManagedClipboardImage(record, imageDirectory)) {
    return false;
  }
  try {
    final File image = File(record.content);
    if (!image.existsSync()) {
      return false;
    }
    image.deleteSync();
    return true;
  } on FileSystemException {
    return false;
  }
}

/// Cleans files left behind by interrupted captures or older database trims.
int pruneUnreferencedManagedClipboardImages(
  Iterable<ClipboardRecord> records,
  Directory imageDirectory,
) {
  if (!imageDirectory.existsSync()) {
    return 0;
  }
  final Set<String> referenced = records
      .where(
        (ClipboardRecord record) =>
            isManagedClipboardImage(record, imageDirectory),
      )
      .map((ClipboardRecord record) => _normalizedAbsolute(record.content))
      .toSet();
  var deleted = 0;
  try {
    for (final FileSystemEntity entity in imageDirectory.listSync(
      followLinks: false,
    )) {
      if (entity is Directory ||
          referenced.contains(_normalizedAbsolute(entity.path))) {
        continue;
      }
      try {
        entity.deleteSync();
        deleted += 1;
      } on FileSystemException {
        // A locked orphan can be retried during the next retention pass.
      }
    }
  } on FileSystemException {
    return deleted;
  }
  return deleted;
}

String _normalizedAbsolute(String value) =>
    path.normalize(path.absolute(value));
