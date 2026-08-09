import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/device_link/domain/device_link_models.dart';

abstract interface class DeviceLinkStore {
  Future<DeviceLinkDocument?> load();

  Future<void> save(DeviceLinkDocument document);
}

final class DeviceLinkStoreCorruptedException implements Exception {
  const DeviceLinkStoreCorruptedException({
    required this.file,
    required this.cause,
    required this.preservedFile,
    this.preservationError,
  });

  final File file;
  final Object cause;

  /// A byte-for-byte copy of the invalid document, when it could be written.
  final File? preservedFile;

  /// The error raised while creating [preservedFile], if preservation failed.
  /// The original [file] is never modified by a failed load.
  final Object? preservationError;

  @override
  String toString() {
    final String preservation = preservedFile == null
        ? 'The original file was left untouched, but a recovery copy could '
              'not be created${preservationError == null ? '' : ': $preservationError'}.'
        : 'The original file was left untouched and a recovery copy was '
              'preserved at ${preservedFile!.path}.';
    return 'DeviceLinkStoreCorruptedException: ${file.path} is not a valid '
        'device-link document ($cause). $preservation';
  }
}

final class FileDeviceLinkStore implements DeviceLinkStore {
  FileDeviceLinkStore(this.file);

  static final Map<String, Future<void>> _saveBarriers =
      <String, Future<void>>{};
  static int _nextUniqueFileId = 0;

  final File file;

  @override
  Future<DeviceLinkDocument?> load() async {
    if (!await file.exists()) return null;
    final List<int> bytes = await file.readAsBytes();
    try {
      final Object? decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const FormatException('Expected a JSON object.');
      }
      final Map<String, Object?> json = Map<String, Object?>.from(decoded);
      if (json['version'] != 1) {
        throw FormatException(
          'Unsupported device-link document version: ${json['version']}.',
        );
      }
      final Object? rawDevices = json['devices'];
      if (rawDevices is! List ||
          rawDevices.any((Object? value) => value is! Map)) {
        throw const FormatException(
          'Expected devices to be a list of objects.',
        );
      }
      return DeviceLinkDocument.fromJson(json);
    } on Object catch (error, stackTrace) {
      File? preservedFile;
      Object? preservationError;
      try {
        preservedFile = await _preserveCorruptedBytes(bytes);
      } on Object catch (error) {
        preservationError = error;
      }
      Error.throwWithStackTrace(
        DeviceLinkStoreCorruptedException(
          file: file,
          cause: error,
          preservedFile: preservedFile,
          preservationError: preservationError,
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<void> save(DeviceLinkDocument document) {
    final String absolutePath = file.absolute.path;
    final String pathKey = Platform.isWindows
        ? absolutePath.toLowerCase()
        : absolutePath;
    final Future<void> previous =
        _saveBarriers[pathKey] ?? Future<void>.value();
    final Completer<void> gate = Completer<void>();
    final Future<void> currentBarrier = gate.future;
    _saveBarriers[pathKey] = currentBarrier;
    return _saveAfter(
      previous: previous,
      gate: gate,
      currentBarrier: currentBarrier,
      pathKey: pathKey,
      document: document,
    );
  }

  Future<void> _saveAfter({
    required Future<void> previous,
    required Completer<void> gate,
    required Future<void> currentBarrier,
    required String pathKey,
    required DeviceLinkDocument document,
  }) async {
    await previous;
    try {
      await _saveAtomically(document);
    } finally {
      gate.complete();
      if (identical(_saveBarriers[pathKey], currentBarrier)) {
        unawaited(_saveBarriers.remove(pathKey));
      }
    }
  }

  Future<void> _saveAtomically(DeviceLinkDocument document) async {
    await file.parent.create(recursive: true);
    final File temporary = await _reserveUniqueSibling('tmp');
    try {
      await temporary.writeAsString(
        const JsonEncoder.withIndent('  ').convert(document.toJson()),
        flush: true,
      );

      // The temporary file is in the destination directory, so rename is an
      // atomic replacement on supported desktop file systems. Do not add a
      // delete-then-rename fallback: a failed atomic replace must leave the
      // previous document intact, especially when Windows has the file open.
      await temporary.rename(file.path);
    } finally {
      await _deleteIfPresent(temporary);
    }
  }

  Future<File> _preserveCorruptedBytes(List<int> bytes) async {
    await file.parent.create(recursive: true);
    final File preserved = await _reserveUniqueSibling('corrupt');
    try {
      await preserved.writeAsBytes(bytes, flush: true);
      return preserved;
    } on Object {
      await _deleteIfPresent(preserved);
      rethrow;
    }
  }

  Future<File> _reserveUniqueSibling(String marker) async {
    while (true) {
      final int id = _nextUniqueFileId++;
      final File candidate = File('${file.path}.$marker.$pid.$id');
      try {
        return await candidate.create(exclusive: true);
      } on FileSystemException {
        if (!await candidate.exists()) rethrow;
      }
    }
  }

  Future<void> _deleteIfPresent(File candidate) async {
    try {
      if (await candidate.exists()) await candidate.delete();
    } on FileSystemException {
      // Cleanup must not hide the write/rename error. Unique names ensure a
      // stale temporary file cannot collide with a later save.
    }
  }
}

final class MemoryDeviceLinkStore implements DeviceLinkStore {
  MemoryDeviceLinkStore([this.document]);

  DeviceLinkDocument? document;

  @override
  Future<DeviceLinkDocument?> load() async => document;

  @override
  Future<void> save(DeviceLinkDocument value) async {
    document = value;
  }
}
