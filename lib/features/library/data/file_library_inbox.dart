import 'dart:io';

import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:dingdong/features/library/domain/library_share_gateway.dart';
import 'package:path/path.dart' as path;

/// Durable bundles received from paired computers, awaiting a user decision.
final class FileLibraryInbox {
  const FileLibraryInbox(this.directory);

  final Directory directory;
  static final _validId = RegExp(r'^[a-zA-Z0-9_-]{1,128}$');

  Directory _entry(String id) {
    if (!_validId.hasMatch(id)) throw ArgumentError.value(id, 'id');
    return Directory(path.join(directory.path, id));
  }

  Future<void> receive(String id, String sender, File file) async {
    final entry = _entry(id);
    if (await entry.exists()) return;
    final contents = await file.readAsString();
    if (LibraryBundle.preview(contents).isEmpty) {
      throw const FormatException('The received resource bundle is empty.');
    }

    await directory.create(recursive: true);
    final staging = await directory.createTemp('.receiving-');
    try {
      await File(
        path.join(staging.path, 'bundle.json'),
      ).writeAsString(contents, flush: true);
      await File(
        path.join(staging.path, 'sender.txt'),
      ).writeAsString(sender, flush: true);
      await staging.rename(entry.path);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  Future<List<ReceivedLibraryBundle>> list() async {
    if (!await directory.exists()) return [];
    final bundles = <ReceivedLibraryBundle>[];
    await for (final entry in directory.list(followLinks: false)) {
      final id = path.basename(entry.path);
      if (entry is! Directory || !_validId.hasMatch(id)) continue;
      try {
        final sender = await File(
          path.join(entry.path, 'sender.txt'),
        ).readAsString();
        final stat = await File(path.join(entry.path, 'bundle.json')).stat();
        if (stat.type == FileSystemEntityType.file) {
          bundles.add((id: id, sender: sender, receivedAt: stat.modified));
        }
      } on FileSystemException {
        if (await entry.exists()) rethrow;
      }
    }
    return bundles..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
  }

  Future<String> read(String id) =>
      File(path.join(_entry(id).path, 'bundle.json')).readAsString();

  Future<void> remove(String id) => _entry(id).delete(recursive: true);
}
