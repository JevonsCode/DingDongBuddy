part of 'device_link_controller.dart';

// Validate clipboard payloads and stream bounded file uploads and downloads.
extension _DeviceLinkFileTransfer on DeviceLinkController {
  Future<void> _sendClipboardRecord(
    ClipboardRecord record,
    String deviceId, {
    required bool manual,
  }) async {
    final Map<String, Object?> payload = _recordPayload(record);
    final _ManagedDeviceSession managed = _sessionForDevice(deviceId);
    await managed.handle.send(<String, Object?>{
      'type': 'clipboard.upsert',
      'manual': manual,
      'item': payload,
    });
    await _rememberSharedClipboardItem(deviceId, record.id);
  }

  Future<void> _sendSnapshot(_ManagedDeviceSession managed) async {
    final String? deviceId = managed.deviceId;
    final LinkedDevice? device = deviceId == null ? null : _device(deviceId);
    final List<String> allowedIds =
        device?.sharedClipboardItemIds ?? const <String>[];
    final Map<String, ClipboardRecord> recordsById = <String, ClipboardRecord>{
      for (final ClipboardRecord record in _clipboardStore.list(
        limit: 5000,
        includeProtectedBeyondLimit: true,
      ))
        record.id: record,
    };
    final List<ClipboardRecord> records = allowedIds
        .map((String id) => recordsById[id])
        .whereType<ClipboardRecord>()
        .take(deviceLinkClipboardHistoryLimit)
        .toList(growable: false);
    await managed.handle.send(<String, Object?>{
      'type': 'clipboard.snapshot',
      'items': const <Object?>[],
    });
    for (final ClipboardRecord record in records.reversed) {
      try {
        await managed.handle.send(<String, Object?>{
          'type': 'clipboard.upsert',
          'manual': false,
          'snapshot': true,
          'item': _recordPayload(record),
        });
      } on DeviceLinkTextTooLargeException catch (error) {
        debugPrint(
          'DingDong skipped oversized clipboard snapshot item '
          '${record.id}: $error',
        );
      } on DeviceLinkFrameTooLargeException catch (error) {
        debugPrint(
          'DingDong skipped clipboard snapshot frame ${record.id}: $error',
        );
      }
    }
    await _sendAgentState(managed);
  }

  Future<void> _rememberSharedClipboardItem(
    String deviceId,
    String recordId,
  ) async {
    final LinkedDevice device = _device(deviceId);
    final List<String> ids = <String>[
      recordId,
      ...device.sharedClipboardItemIds.where((String id) => id != recordId),
    ].take(deviceLinkClipboardHistoryLimit).toList(growable: false);
    await _replaceDevice(device.copyWith(sharedClipboardItemIds: ids));
  }

  Map<String, Object?> _recordPayload(ClipboardRecord record) {
    final File? file = _firstExistingFile(record);
    final bool fileBacked = file != null;
    if (!record.sensitive && !fileBacked) {
      final int contentBytes = utf8.encode(record.content).length;
      if (contentBytes > deviceLinkMaximumTextBytes) {
        throw DeviceLinkTextTooLargeException(actualBytes: contentBytes);
      }
    }
    return <String, Object?>{
      'id': record.id,
      'title': record.title,
      'kind': record.kind.name,
      'sensitive': record.sensitive,
      'createdAt': record.createdAt.toUtc().toIso8601String(),
      'updatedAt': record.updatedAt.toUtc().toIso8601String(),
      'sources': record.sources,
      if (!record.sensitive && !fileBacked) 'content': record.content,
      if (fileBacked) ...<String, Object?>{
        'fileName': path.basename(file.path),
        'fileSize': file.lengthSync(),
        'downloadable': file.lengthSync() <= deviceLinkMaximumFileBytes,
      },
    };
  }

  Future<void> _receiveText(
    _ManagedDeviceSession managed,
    LinkedDevice device,
    Map<String, Object?> message,
  ) async {
    final String content = (message['content'] as String? ?? '').trim();
    if (content.isEmpty) return;
    final int contentBytes = utf8.encode(content).length;
    if (contentBytes > deviceLinkMaximumTextBytes) {
      await managed.handle.send(<String, Object?>{
        'type': 'request.rejected',
        'requestType': 'clipboard.create',
        if (message['requestId'] is String)
          'requestId': message['requestId']! as String,
        'code': 'text_too_large',
        'maximumBytes': deviceLinkMaximumTextBytes,
      });
      return;
    }
    final ClipboardClassification classification = ClipboardClassifier.classify(
      content,
    );
    final DateTime now = DateTime.now().toUtc();
    final ClipboardRecord record = ClipboardRecord(
      id: 'DEVICE-${now.microsecondsSinceEpoch}-${_randomToken(6)}',
      group: classification.group,
      title: (message['title'] as String?)?.trim().isNotEmpty == true
          ? (message['title']! as String).trim()
          : classification.title,
      content: content,
      tags: <String>[...classification.tags, 'device-origin:${device.id}'],
      source: _localizations().fromDevice(device.name),
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: now,
      updatedAt: now,
    );
    _clipboardStore.save(record);
    onClipboardReceived?.call();
  }

  Future<void> _beginFileUpload(
    LinkedDevice device,
    Map<String, Object?> message,
  ) async {
    final Object? rawTransferId = message['transferId'];
    final Object? rawName = message['name'];
    final Object? rawSize = message['size'];
    final String transferId = rawTransferId is String
        ? rawTransferId.trim()
        : '';
    final int size = rawSize is int ? rawSize : -1;
    if (transferId.isEmpty ||
        transferId.length > 160 ||
        (rawName != null && rawName is! String) ||
        size < 0 ||
        size > deviceLinkMaximumFileBytes) {
      return;
    }
    final String uploadName = rawName is String
        ? rawName
        : _localizations().sharedFile;
    await _pruneIncomingFileUploads();
    final String key = _incomingFileKey(device.id, transferId);
    await _discardIncomingFileUpload(key);
    if (_incomingFiles.length >= deviceLinkMaximumConcurrentFileUploads) {
      return;
    }
    await _transferDirectory.create(recursive: true);
    final File partial = File(
      path.join(
        _transferDirectory.path,
        '.dingdong-incoming-${_randomToken(12)}.part',
      ),
    );
    final RandomAccessFile writer = await partial.open(mode: FileMode.write);
    if (_disposed ||
        _incomingFiles.length >= deviceLinkMaximumConcurrentFileUploads) {
      await writer.close();
      await partial.delete();
      return;
    }
    _incomingFiles[key] = _IncomingFileUpload(
      deviceId: device.id,
      name: sanitizeDeviceLinkFileName(
        uploadName,
        fallback: _localizations().sharedFile,
      ),
      expectedBytes: size,
      partialFile: partial,
      writer: writer,
      lastActivityAt: DateTime.now().toUtc(),
    );
  }

  Future<void> _receiveFileChunk(
    LinkedDevice device,
    Map<String, Object?> message,
  ) async {
    final Object? rawTransferId = message['transferId'];
    final String transferId = rawTransferId is String
        ? rawTransferId.trim()
        : '';
    final String key = _incomingFileKey(device.id, transferId);
    final _IncomingFileUpload? upload = _incomingFiles[key];
    if (upload == null) return;
    final Object? rawIndex = message['index'];
    final Object? rawData = message['data'];
    final int index = rawIndex is int ? rawIndex : -1;
    final String data = rawData is String ? rawData : '';
    if (index != upload.nextIndex || data.isEmpty) {
      await _discardIncomingFileUpload(key);
      return;
    }
    try {
      final Uint8List bytes = base64Decode(data);
      if (bytes.isEmpty ||
          bytes.length > _fileChunkBytes ||
          upload.receivedBytes + bytes.length > upload.expectedBytes) {
        await _discardIncomingFileUpload(key);
        return;
      }
      await upload.writer.writeFrom(bytes);
      upload
        ..receivedBytes += bytes.length
        ..nextIndex += 1
        ..lastActivityAt = DateTime.now().toUtc();
    } on Object {
      await _discardIncomingFileUpload(key);
      rethrow;
    }
  }

  Future<void> _finishFileUpload(
    LinkedDevice device,
    Map<String, Object?> message,
  ) async {
    final Object? rawTransferId = message['transferId'];
    final String transferId = rawTransferId is String
        ? rawTransferId.trim()
        : '';
    final String key = _incomingFileKey(device.id, transferId);
    final _IncomingFileUpload? upload = _incomingFiles.remove(key);
    if (upload == null) {
      return;
    }
    await upload.writer.close();
    if (upload.receivedBytes != upload.expectedBytes) {
      await upload.partialFile.delete();
      return;
    }
    final String outputName =
        '${DateTime.now().millisecondsSinceEpoch}-${_randomToken(5)}-${upload.name}';
    final File output = File(path.join(_transferDirectory.path, outputName));
    try {
      await upload.partialFile.rename(output.path);
    } on Object {
      if (await upload.partialFile.exists()) {
        await upload.partialFile.delete();
      }
      rethrow;
    }
    final DateTime now = DateTime.now().toUtc();
    _clipboardStore.save(
      ClipboardRecord(
        id: 'DEVICE-FILE-${now.microsecondsSinceEpoch}-${_randomToken(6)}',
        group: '',
        title: upload.name,
        content: output.path,
        tags: <String>[
          'clipboard',
          'file',
          'file-url',
          'device-origin:${device.id}',
        ],
        source: _localizations().fromDevice(device.name),
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: now,
        updatedAt: now,
      ),
    );
    onClipboardReceived?.call();
  }

  Future<void> _sendRequestedFile(
    _ManagedDeviceSession managed,
    String itemId,
  ) async {
    final String? deviceId = managed.deviceId;
    if (deviceId == null ||
        !_device(deviceId).sharedClipboardItemIds.contains(itemId)) {
      return;
    }
    ClipboardRecord? record;
    for (final ClipboardRecord candidate in _clipboardStore.list(
      limit: 5000,
      includeProtectedBeyondLimit: true,
    )) {
      if (candidate.id == itemId) {
        record = candidate;
        break;
      }
    }
    final File? file = record == null ? null : _firstExistingFile(record);
    if (file == null || file.lengthSync() > deviceLinkMaximumFileBytes) return;
    final String transferId = 'download-${_randomToken(12)}';
    await managed.handle.send(<String, Object?>{
      'type': 'file.start',
      'transferId': transferId,
      'itemId': record!.id,
      'name': path.basename(file.path),
      'size': file.lengthSync(),
    });
    final RandomAccessFile input = await file.open();
    var index = 0;
    try {
      while (true) {
        final Uint8List chunk = await input.read(_fileChunkBytes);
        if (chunk.isEmpty) break;
        await managed.handle.send(<String, Object?>{
          'type': 'file.chunk',
          'transferId': transferId,
          'index': index,
          'data': base64Encode(chunk),
        });
        index += 1;
        if (index % 16 == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 8));
        }
      }
    } finally {
      await input.close();
    }
    await managed.handle.send(<String, Object?>{
      'type': 'file.end',
      'transferId': transferId,
      'itemId': record.id,
    });
  }
}
