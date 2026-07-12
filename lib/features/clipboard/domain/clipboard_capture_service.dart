// ignore_for_file: prefer_initializing_formals

import 'dart:io';
import 'dart:math';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_classifier.dart';
import 'package:path/path.dart' as path;

/// Converts one platform clipboard snapshot into durable classified history.
final class ClipboardCaptureService {
  ClipboardCaptureService({
    required ClipboardGateway gateway,
    required ClipboardStore store,
    Directory? imageStoreDirectory,
    String Function()? idGenerator,
    DateTime Function()? now,
  }) : _gateway = gateway,
       _store = store,
       _imageStoreDirectory = imageStoreDirectory,
       _idGenerator = idGenerator ?? _generateUuid,
       _now = now ?? _utcNow;

  final ClipboardGateway _gateway;
  final ClipboardStore _store;
  final Directory? _imageStoreDirectory;
  final String Function() _idGenerator;
  final DateTime Function() _now;

  Future<ClipboardRecord?> capture() async {
    final ClipboardSnapshot snapshot = await _gateway.read();
    final List<String> filePaths = snapshot.filePaths
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    if (filePaths.isNotEmpty) {
      return _storeFileRecord(filePaths, snapshot.source);
    }
    if (snapshot.imageBytes != null && snapshot.imageBytes!.isNotEmpty) {
      final ClipboardRecord? image = await _storeImageRecord(
        snapshot.imageBytes!,
        snapshot.source,
      );
      if (image != null) {
        return image;
      }
    }
    final String? text = snapshot.text?.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    final ClipboardClassification classification = ClipboardClassifier.classify(
      text,
    );
    final DateTime timestamp = _now().toUtc();
    final ClipboardRecord record = ClipboardRecord(
      id: _idGenerator(),
      group: classification.group,
      title: classification.title,
      content: text,
      tags: classification.tags,
      source: snapshot.source,
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    _store.save(record);
    return record;
  }

  ClipboardRecord _storeFileRecord(List<String> files, String source) {
    final Set<String> extensions = files
        .map((String value) => path.extension(value).replaceFirst('.', ''))
        .where((String value) => value.isNotEmpty)
        .map((String value) => value.toLowerCase())
        .toSet();
    final bool allImages =
        extensions.isNotEmpty &&
        files.every(
          (String value) => _imageExtensions.contains(
            path.extension(value).replaceFirst('.', '').toLowerCase(),
          ),
        );
    final String firstName = path.basename(files.first);
    final String title = files.length == 1
        ? firstName
        : '${files.length} items · $firstName';
    final List<String> tags = <String>{
      'clipboard',
      'file',
      'file-url',
      if (allImages) 'image',
      ...extensions.map((String value) => 'ext:$value'),
    }.toList()..sort();
    return _saveRecord(
      group: '',
      title: title,
      content: files.join('\n'),
      tags: tags,
      source: source,
    );
  }

  Future<ClipboardRecord?> _storeImageRecord(
    List<int> bytes,
    String source,
  ) async {
    final Directory? directory = _imageStoreDirectory;
    if (directory == null) {
      return null;
    }
    final String id = _idGenerator();
    await directory.create(recursive: true);
    final File target = File(path.join(directory.path, 'clipboard-$id.png'));
    final File temporary = File('${target.path}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(target.path);
    } on Object {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      return null;
    }
    return _saveRecord(
      id: id,
      group: '',
      title: path.basename(target.path),
      content: target.path,
      tags: const <String>['clipboard', 'ext:png', 'file', 'file-url', 'image'],
      source: source,
    );
  }

  ClipboardRecord _saveRecord({
    String? id,
    required String group,
    required String title,
    required String content,
    required List<String> tags,
    required String source,
  }) {
    final DateTime timestamp = _now().toUtc();
    final ClipboardRecord record = ClipboardRecord(
      id: id ?? _idGenerator(),
      group: group,
      title: title,
      content: content,
      tags: tags,
      source: source,
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    _store.save(record);
    return record;
  }
}

const Set<String> _imageExtensions = <String>{
  'avif',
  'bmp',
  'gif',
  'heic',
  'heif',
  'jpeg',
  'jpg',
  'png',
  'tif',
  'tiff',
  'webp',
};

DateTime _utcNow() => DateTime.now().toUtc();

String _generateUuid() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final String hex = bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
          '${hex.substring(20)}'
      .toUpperCase();
}
