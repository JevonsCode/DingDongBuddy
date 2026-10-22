import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/device_link/domain/file_transfer.dart';
import 'package:flutter/foundation.dart';

/// Local metadata only; independent of partial bodies and pairing credentials.
final class FileTransferHistory {
  FileTransferHistory(this.file);
  final File file;
  static const limit = 100;
  final Map<String, FileTransfer> _records = {};
  final Expando<String> _remembered = Expando<String>();
  Future<void> _writes = Future.value();
  List<FileTransfer> get records => _records.values.toList()
    ..sort(
      (a, b) =>
          (b.finishedAt ?? b.createdAt).compareTo(a.finishedAt ?? a.createdAt),
    );
  static String key(FileTransfer view) =>
      '${view.deviceId}:${view.sending}:${view.id}';

  Future<void> load() async {
    if (!await file.exists()) return;
    try {
      final entries = jsonDecode(await file.readAsString()) as List;
      for (final entry in entries) {
        try {
          final record = FileTransfer.fromJson(
            Map<String, Object?>.from(entry as Map),
          );
          if (!const [
            'completed',
            'cancelled',
            'failed',
            'sent',
          ].contains(record.status)) {
            continue;
          }
          record.archived = true;
          _records[key(record)] = record;
        } on Object {
          // One invalid record does not discard the rest of the journal.
        }
      }
      _trim();
    } on Object catch (error) {
      debugPrint('DingDong could not read transfer history: $error');
    }
  }

  void remember(FileTransfer view, String deviceName) {
    if (!const [
      'completed',
      'cancelled',
      'failed',
      'sent',
    ].contains(view.status)) {
      return;
    }
    final signature = '${view.status}:${view.bytes}:${view.detail}';
    if (_remembered[view] == signature) return;
    _remembered[view] = signature;
    final id = key(view);
    final previous = _records[id];
    if (previous?.status == view.status &&
        previous?.bytes == view.bytes &&
        previous?.detail == view.detail) {
      return;
    }
    view.finishedAt = DateTime.now().toUtc();
    final record = FileTransfer.fromJson({
      ...view.toJson(),
      'deviceName': deviceName,
      'archived': true,
      'itemId': null,
    });
    _records[id] = record;
    _trim();
    _save();
  }

  void forgetDevice(String id) {
    _records.removeWhere((_, record) => record.deviceId == id);
    _save();
  }

  void _trim() {
    for (final record in records.skip(limit)) {
      _records.remove(key(record));
    }
  }

  void _save() {
    final content = jsonEncode(
      records.map((record) => record.toJson()).toList(),
    );
    _writes = _writes
        .then((_) async {
          await file.parent.create(recursive: true);
          final temporary = File('${file.path}.tmp');
          await temporary.writeAsString(content, flush: true);
          await temporary.rename(file.path);
        })
        .catchError((Object error) {
          // History must not turn a successful file delivery into a failed one.
          debugPrint('DingDong could not save transfer history: $error');
        });
  }

  Future<void> flush() => _writes;
}
