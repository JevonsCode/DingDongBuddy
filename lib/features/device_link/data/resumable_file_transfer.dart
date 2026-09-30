import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'package:dingdong/features/device_link/domain/file_transfer.dart';
import 'package:path/path.dart' as path;

typedef TransferSender =
    Future<void> Function(String peer, Map<String, Object?> message);

/// Stop-and-wait keeps memory bounded and progress tied to receiver writes.
/// The caller must dispatch replies while an outgoing transfer is running.
class ResumableFileTransfers {
  ResumableFileTransfers({
    required this.directory,
    required this.send,
    required this.isLan,
    required this.onChange,
    required this.onReceived,
    this.replyTimeout = const Duration(seconds: 20),
  });
  final Directory directory;
  final TransferSender send;
  final Future<bool> Function(String peer) isLan;
  final void Function() onChange;
  final Future<void> Function(String peer, File file, FileTransfer transfer)
  onReceived;
  final Duration replyTimeout;
  final Map<String, _Outgoing> _outgoing = {};
  final Map<String, _Incoming> _incoming = {};
  final Map<String, Completer<Map<String, Object?>>> _replies = {};
  final Map<String, FileTransfer> _views = {};
  final Map<String, Future<void>> _operations = {};
  Future<void> _serial(String key, Future<void> Function() operation) async {
    final previous = _operations[key] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) => operation());
    _operations[key] = next;
    try {
      await next;
    } finally {
      if (identical(_operations[key], next)) {
        unawaited(_operations.remove(key));
      }
    }
  }

  bool _disposed = false;
  int _sequence = 0;
  List<FileTransfer> get transfers =>
      List.unmodifiable(_views.values.toList().reversed);
  String _key(String peer, String id) => '$peer\u0000$id';
  void _changed() {
    if (_disposed) return;
    final completed = _views.entries
        .where((entry) => entry.value.terminal)
        .toList();
    for (final entry in completed.take(max(0, completed.length - 20))) {
      _views.remove(entry.key);
      _outgoing.remove(entry.key);
      _incoming.remove(entry.key);
    }
    onChange();
  }

  Future<FileTransfer> sendFile(
    String peer,
    File file, {
    required String name,
    String? itemId,
  }) async {
    if (_disposed) throw StateError('closed');
    final stat = await file.stat();
    if (stat.type != FileSystemEntityType.file) {
      throw StateError('source_unavailable');
    }
    final fingerprint = '${stat.size}:${stat.modified.microsecondsSinceEpoch}';
    final sourceKey = '${file.absolute.path}:$fingerprint';
    final existing = _outgoing.values
        .where(
          (item) =>
              item.view.deviceId == peer &&
              item.file.absolute.path == file.absolute.path &&
              item.fingerprint == fingerprint &&
              !item.view.terminal,
        )
        .firstOrNull;
    final id = await _digest(
      utf8.encode(
        '$sourceKey:${DateTime.now().microsecondsSinceEpoch}:${++_sequence}',
      ),
    );
    final key = _key(peer, id);
    if (existing != null && !existing.view.terminal) {
      await _run(existing, explicitResume: true);
      return existing.view;
    }
    if (_outgoing.values.where((o) => !o.view.terminal).length >= 3) {
      throw StateError('too_many_transfers');
    }
    final view = FileTransfer(
      id: id,
      deviceId: peer,
      name: name,
      size: stat.size,
      sending: true,
      itemId: itemId,
    );
    final outgoing = _Outgoing(view, file, fingerprint);
    _outgoing[key] = outgoing;
    _views[key] = view;
    _changed();
    await _run(outgoing, explicitResume: true);
    return view;
  }

  Future<void> _run(_Outgoing outgoing, {bool explicitResume = false}) async {
    if (_disposed || outgoing.running || outgoing.view.terminal) return;
    outgoing.running = true;
    outgoing.stopped = false;
    final view = outgoing.view;
    RandomAccessFile? reader;
    try {
      view.status = 'preparing';
      view.detail = '';
      view.bytesPerSecond = 0;
      _changed();
      final stat = await outgoing.file.stat();
      if ('${stat.size}:${stat.modified.microsecondsSinceEpoch}' !=
          outgoing.fingerprint) {
        throw const _TransferError('source_changed');
      }
      view.lan = await isLan(view.deviceId);
      if (view.size > relayFileLimit && !view.lan) {
        throw const _TransferError('waiting_lan');
      }
      final ready = await _request(view, {
        'type': 'transfer.offer',
        'name': view.name,
        'size': view.size,
        'fingerprint': outgoing.fingerprint,
        'itemId': view.itemId,
        'resume': explicitResume,
      });
      final offset = ready['offset'];
      if (offset is! int ||
          offset < 0 ||
          offset > view.size ||
          (offset != view.size && offset % transferChunkBytes != 0)) {
        throw const _TransferError('invalid_offset');
      }
      if (outgoing.stopped) return;
      view.advance(offset);
      view.status = 'transferring';
      _changed();
      reader = await outgoing.file.open();
      await reader.setPosition(offset);
      while (view.bytes < view.size) {
        if (outgoing.stopped || _disposed) return;
        final bytes = await reader.read(
          min(transferChunkBytes, view.size - view.bytes),
        );
        if (bytes.isEmpty) throw const _TransferError('source_changed');
        final next = view.bytes + bytes.length;
        final ack = await _request(view, {
          'type': 'transfer.chunk',
          'offset': view.bytes,
          'data': base64Encode(bytes),
          'digest': await _digest(bytes),
        });
        if (outgoing.stopped || _disposed) return;
        if (ack['offset'] != next) throw const _TransferError('invalid_offset');
        view.advance(next);
        _changed();
      }
      if (outgoing.stopped || _disposed) return;
      final finalStat = await outgoing.file.stat();
      if ('${finalStat.size}:${finalStat.modified.microsecondsSinceEpoch}' !=
          outgoing.fingerprint) {
        throw const _TransferError('source_changed');
      }
      view.status = 'verifying';
      _changed();
      final done = await _request(view, {'type': 'transfer.finish'});
      if (outgoing.stopped || _disposed) return;
      if (done['done'] != true) throw const _TransferError('incomplete');
      view.status = 'completed';
      view.bytesPerSecond = 0;
    } catch (error) {
      if (!outgoing.stopped && !_disposed) {
        final code = error is _TransferError ? error.code : 'connection_lost';
        view.status = const ['waiting_lan', 'connection_lost'].contains(code)
            ? 'waiting'
            : code == 'paused'
            ? 'paused'
            : 'failed';
        view.detail = code;
        view.bytesPerSecond = 0;
      }
    } finally {
      await reader?.close();
      outgoing.running = false;
      _changed();
    }
  }

  Future<Map<String, Object?>> _request(
    FileTransfer view,
    Map<String, Object?> message,
  ) async {
    if (_disposed) throw StateError('closed');
    final request = '${DateTime.now().microsecondsSinceEpoch}-${++_sequence}';
    final key = '${_key(view.deviceId, view.id)}\u0000$request';
    final completer = Completer<Map<String, Object?>>();
    _replies[key] = completer;
    // Attach an error handler before transport delivery can synchronously fail.
    final reply = completer.future.timeout(replyTimeout);
    unawaited(reply.catchError((Object error) => <String, Object?>{}));
    try {
      await send(view.deviceId, {
        ...message,
        'id': view.id,
        'request': request,
        'lanOnly': view.size > relayFileLimit,
      });
      final response = await reply;
      if (response['error'] is String) {
        throw _TransferError(response['error']! as String);
      }
      return response;
    } finally {
      _replies.remove(key);
      if (!completer.isCompleted) {
        completer.completeError(StateError('request_closed'));
      }
    }
  }

  Future<void> handle(String peer, Map<String, Object?> message) async {
    if (_disposed) return;
    final id = message['id'];
    if (id is! String || !RegExp(r'^[a-zA-Z0-9_-]{1,128}$').hasMatch(id)) {
      return;
    }
    final key = _key(peer, id);
    if (message['type'] == 'transfer.reply') {
      final completer = _replies['$key\u0000${message['request']}'];
      if (completer != null && !completer.isCompleted) {
        completer.complete(message);
      }
      return;
    }
    if (message['type'] == 'transfer.control') {
      final action = message['action'];
      if (action is String) await control(peer, id, action, remote: true);
      return;
    }
    final request = message['request'];
    if (request is! String || request.length > 128) return;
    await _serial(key, () async {
      try {
        if (message['type'] == 'transfer.offer') {
          await _offer(peer, message);
        } else if (message['type'] == 'transfer.chunk') {
          await _chunk(peer, message);
        } else if (message['type'] == 'transfer.finish') {
          await _finish(peer, message);
        }
      } catch (error) {
        final code = error is _TransferError
            ? error.code
            : error is FileSystemException
            ? 'storage_error'
            : 'transfer_failed';
        final view = _views[key];
        if (view != null && !view.terminal) {
          view.status = code == 'waiting_lan'
              ? 'waiting'
              : code == 'paused'
              ? 'paused'
              : 'failed';
          view.detail = code;
          _changed();
        }
        try {
          await _reply(peer, message, {'error': code});
        } on Object {
          /* Reconnect retries the same request. */
        }
      }
    });
  }

  Future<void> _offer(String peer, Map<String, Object?> message) async {
    final id = message['id']! as String;
    final size = message['size'];
    final name = message['name'];
    final fingerprint = message['fingerprint'];
    if (size is! int ||
        size < 0 ||
        size > 9007199254740991 ||
        name is! String ||
        name.isEmpty ||
        name.length > 512 ||
        fingerprint is! String ||
        fingerprint.length > 256) {
      throw const _TransferError('invalid_metadata');
    }
    final lan = await isLan(peer);
    if (size > relayFileLimit && !lan) {
      throw const _TransferError('waiting_lan');
    }
    final key = _key(peer, id);
    var incoming = _incoming[key];
    if (incoming != null &&
        (incoming.fingerprint != fingerprint || incoming.view.size != size)) {
      throw const _TransferError('source_changed');
    }
    if (incoming?.view.status == 'cancelled') {
      throw const _TransferError('cancelled');
    }
    if (incoming?.view.status == 'paused' && message['resume'] != true) {
      throw const _TransferError('paused');
    }
    if (incoming == null) {
      if (_incoming.values.where((i) => !i.view.terminal).length >= 3) {
        throw const _TransferError('too_many_transfers');
      }
      await directory.create(recursive: true);
      await _prunePartials();
      final stem = await _digest(utf8.encode(key));
      final partial = File(path.join(directory.path, '.$stem.part'));
      final metadata = File(path.join(directory.path, '.$stem.json'));
      var offset = 0;
      if (await metadata.exists() && await partial.exists()) {
        try {
          final saved = jsonDecode(await metadata.readAsString()) as Map;
          if (saved['fingerprint'] == fingerprint && saved['size'] == size) {
            offset = await partial.length();
          }
        } on Object {
          /* Invalid metadata starts a fresh transfer. */
        }
      }
      if (offset > size) offset = 0;
      if (offset != size) offset -= offset % transferChunkBytes;
      final writer = await partial.open(mode: FileMode.append);
      await writer.truncate(offset);
      await writer.setPosition(offset);
      await writer.close();
      await metadata.writeAsString(
        jsonEncode({'fingerprint': fingerprint, 'size': size, 'peer': peer}),
        flush: true,
      );
      final view = FileTransfer(
        id: id,
        deviceId: peer,
        name: name,
        size: size,
        sending: false,
        itemId: message['itemId'] as String?,
        bytes: offset,
      );
      incoming = _Incoming(view, partial, metadata, fingerprint);
      _incoming[key] = incoming;
      _views[key] = view;
    }
    if (!incoming.view.terminal) {
      incoming.view.status = 'transferring';
      incoming.view.detail = '';
    }
    incoming.view.lan = lan;
    _changed();
    await _reply(peer, message, {'offset': incoming.view.bytes});
  }

  Future<void> _chunk(String peer, Map<String, Object?> message) async {
    final incoming = _incoming[_key(peer, message['id']! as String)];
    if (incoming == null) throw const _TransferError('restart_required');
    final view = incoming.view;
    if (view.status == 'paused') throw const _TransferError('paused');
    if (view.terminal) throw const _TransferError('cancelled');
    if (view.size > relayFileLimit && !await isLan(peer)) {
      throw const _TransferError('waiting_lan');
    }
    final data = message['data'];
    final offset = message['offset'];
    if (data is! String ||
        data.length > (transferChunkBytes * 4 / 3).ceil() + 4 ||
        offset is! int) {
      throw const _TransferError('invalid_chunk');
    }
    final bytes = base64Decode(data);
    if (bytes.isEmpty ||
        bytes.length > transferChunkBytes ||
        offset < 0 ||
        offset + bytes.length > view.size ||
        await _digest(bytes) != message['digest']) {
      throw const _TransferError('checksum_failed');
    }
    if (offset == view.bytes) {
      final writer = await incoming.partial.open(mode: FileMode.append);
      try {
        await writer.setPosition(offset);
        await writer.writeFrom(bytes);
      } finally {
        await writer.close();
      }
      view.advance(offset + bytes.length);
      view.status = 'transferring';
      _changed();
    } else if (offset + bytes.length != view.bytes ||
        incoming.lastOffset != offset ||
        incoming.lastDigest != message['digest']) {
      throw const _TransferError('invalid_offset');
    }
    incoming.lastOffset = offset;
    incoming.lastDigest = message['digest'] as String?;
    await _reply(peer, message, {'offset': view.bytes});
  }

  Future<void> _finish(String peer, Map<String, Object?> message) async {
    final incoming = _incoming[_key(peer, message['id']! as String)];
    if (incoming == null) throw const _TransferError('restart_required');
    final view = incoming.view;
    if (view.status == 'completed') {
      await _reply(peer, message, {'done': true});
      return;
    }
    if (view.status == 'paused') throw const _TransferError('paused');
    if (view.status == 'cancelled') throw const _TransferError('cancelled');
    if (view.size > relayFileLimit && !await isLan(peer)) {
      throw const _TransferError('waiting_lan');
    }
    if (view.bytes != view.size ||
        await (incoming.output ?? incoming.partial).length() != view.size) {
      throw const _TransferError('incomplete');
    }
    view.status = 'verifying';
    _changed();
    final base = path
        .basename(view.name.replaceAll('\\', '/'))
        .replaceAll(RegExp(r'[\x00-\x1f<>:"/\\|?*]'), '_');
    var safe = '';
    for (final rune in base.runes) {
      final next = '$safe${String.fromCharCode(rune)}';
      if (utf8.encode(next).length > 180) break;
      safe = next;
    }
    if (safe.isEmpty || safe == '.' || safe == '..') safe = 'file';
    final output = incoming.output ??= await incoming.partial.rename(
      path.join(
        directory.path,
        '${DateTime.now().microsecondsSinceEpoch}-${view.id.substring(0, min(8, view.id.length))}-$safe',
      ),
    );
    await onReceived(peer, output, view);
    view.status = 'completed';
    try {
      await incoming.metadata.delete();
    } on FileSystemException {
      /* Completion is already durable. */
    }
    view.bytesPerSecond = 0;
    _changed();
    await _reply(peer, message, {'done': true});
  }

  Future<void> _reply(
    String peer,
    Map<String, Object?> request,
    Map<String, Object?> fields,
  ) => send(peer, {
    'type': 'transfer.reply',
    'id': request['id'],
    'request': request['request'],
    ...fields,
  });

  Future<void> control(
    String peer,
    String id,
    String action, {
    bool remote = false,
  }) async {
    final key = _key(peer, id);
    final view = _views[key];
    if (view == null ||
        view.terminal ||
        !const ['pause', 'resume', 'cancel'].contains(action)) {
      return;
    }
    if (_incoming.containsKey(key)) {
      await _serial(key, () async {
        if (view.terminal) return;
        view.status = action == 'cancel'
            ? 'cancelled'
            : action == 'pause'
            ? 'paused'
            : 'waiting';
        view.detail = '';
        view.bytesPerSecond = 0;
        if (action == 'cancel') {
          final incoming = _incoming[key]!;
          for (final file in [
            incoming.partial,
            incoming.metadata,
            if (incoming.output != null) incoming.output!,
          ]) {
            if (await file.exists()) await file.delete();
          }
        }
      });
      _changed();
      if (!remote) {
        try {
          await send(peer, {
            'type': 'transfer.control',
            'id': id,
            'action': action,
          });
        } on Object {
          /* Local state is retained offline. */
        }
      }
      return;
    }
    final outgoing = _outgoing[key];
    if (action == 'resume') {
      if (outgoing != null) {
        if (remote) {
          unawaited(_run(outgoing, explicitResume: true));
        } else {
          await _run(outgoing, explicitResume: true);
        }
      } else {
        view.status = 'waiting';
        if (!remote) {
          await send(peer, {
            'type': 'transfer.control',
            'id': id,
            'action': action,
          });
        }
      }
    } else {
      if (outgoing != null) outgoing.stopped = true;
      view.status = action == 'cancel' ? 'cancelled' : 'paused';
      view.detail = '';
      view.bytesPerSecond = 0;
      for (final entry in _replies.entries.where(
        (entry) => entry.key.startsWith('$key\u0000'),
      )) {
        if (!entry.value.isCompleted) {
          entry.value.completeError(const _TransferError('paused'));
        }
      }
      if (action == 'cancel') {
        final incoming = _incoming[key];
        if (incoming != null) {
          if (await incoming.partial.exists()) await incoming.partial.delete();
          if (await incoming.metadata.exists()) {
            await incoming.metadata.delete();
          }
        }
      }
      if (!remote) {
        try {
          await send(peer, {
            'type': 'transfer.control',
            'id': id,
            'action': action,
          });
        } on Object {
          /* Local pause/cancel still succeeds offline. */
        }
      }
    }
    _changed();
  }

  void disconnected(String peer) {
    for (final view in transfers.where(
      (view) =>
          view.deviceId == peer && !view.terminal && view.status != 'paused',
    )) {
      view.status = 'waiting';
      view.detail = 'connection_lost';
      view.bytesPerSecond = 0;
    }
    for (final entry in _replies.entries.where(
      (entry) => entry.key.startsWith('$peer\u0000'),
    )) {
      if (!entry.value.isCompleted) {
        entry.value.completeError(const _TransferError('connection_lost'));
      }
    }
    _changed();
  }

  void retryWaiting(String peer) {
    for (final outgoing in _outgoing.values.where(
      (o) => o.view.deviceId == peer && o.view.status == 'waiting',
    )) {
      unawaited(_run(outgoing));
    }
  }

  Future<void> _prunePartials({String? peer}) async {
    if (!await directory.exists()) return;
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));
    await for (final entry in directory.list()) {
      if (entry is! File ||
          !RegExp(
            r'^\.[a-f0-9]{64}\.json$',
          ).hasMatch(path.basename(entry.path))) {
        continue;
      }
      try {
        final stat = await entry.stat();
        final saved = jsonDecode(await entry.readAsString()) as Map;
        if (peer == null
            ? !stat.modified.isBefore(cutoff)
            : saved['peer'] != peer) {
          continue;
        }
        if (peer == null &&
            _incoming.values.any(
              (item) => item.metadata.path == entry.path && !item.view.terminal,
            )) {
          continue;
        }
        final partial = File(
          '${entry.path.substring(0, entry.path.length - 5)}.part',
        );
        if (await partial.exists()) await partial.delete();
        await entry.delete();
      } on Object {
        /* An active writer or invalid manifest is left untouched. */
      }
    }
  }

  Future<void> forgetPeer(String peer) async {
    for (final view in transfers.where((v) => v.deviceId == peer)) {
      await control(peer, view.id, 'cancel', remote: true);
      final key = _key(peer, view.id);
      _views.remove(key);
      _incoming.remove(key);
      _outgoing.remove(key);
    }
    await _prunePartials(peer: peer);
    _changed();
  }

  Future<void> dispose() async {
    _disposed = true;
    for (final outgoing in _outgoing.values) {
      outgoing.stopped = true;
    }
    for (final reply in _replies.values) {
      if (!reply.isCompleted) reply.completeError(StateError('closed'));
    }
  }
}

Future<String> _digest(List<int> bytes) async => (await Sha256().hash(
  bytes,
)).bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

class _TransferError implements Exception {
  const _TransferError(this.code);
  final String code;
}

class _Outgoing {
  _Outgoing(this.view, this.file, this.fingerprint);
  final FileTransfer view;
  final File file;
  final String fingerprint;
  bool running = false, stopped = false;
}

class _Incoming {
  _Incoming(this.view, this.partial, this.metadata, this.fingerprint);
  final FileTransfer view;
  final File partial, metadata;
  final String fingerprint;
  File? output;
  int? lastOffset;
  String? lastDigest;
}
