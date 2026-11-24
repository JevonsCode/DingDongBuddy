part of 'device_link_controller.dart';

extension _DeviceLinkResumableTransfer on DeviceLinkController {
  Future<bool> _verifiedLan(String peer) async {
    final device = _devices.where((device) => device.id == peer).firstOrNull;
    final handle = device == null ? null : _sessionsByRoom[device.room]?.handle;
    if (handle is! LanVerifiedDeviceLinkSessionHandle) return false;
    return (handle as LanVerifiedDeviceLinkSessionHandle).verifyLocalNetwork();
  }

  Future<void> _announceFileCapabilities(_ManagedDeviceSession managed) async {
    final id = managed.deviceId;
    if (id == null || managed.fileProtocol < 2 || managed.announcingFiles) {
      return;
    }
    managed.announcingFiles = true;
    try {
      final lan = await _verifiedLan(id);
      if (!_sessionIsCurrent(managed) ||
          !managed.handle.connected ||
          managed.announcedLan == lan) {
        return;
      }
      await managed.handle.send({
        'type': 'file.capabilities',
        'version': 2,
        'lan': lan,
        'lanOnly': lan,
      });
      managed.announcedLan = lan;
    } on Object {
      /* A new transport event/maintenance tick retries this. */
    } finally {
      managed.announcingFiles = false;
    }
  }

  Future<void> _receiveResumableFile(
    String peer,
    File file,
    FileTransfer transfer,
  ) async {
    final device = _device(peer);
    if (transfer.itemId == libraryBundleTransferItemId) {
      final receive = onLibraryBundleReceived;
      if (device.kind != LinkedDeviceKind.computer ||
          receive == null ||
          transfer.size > relayFileLimit) {
        throw const FormatException('Resource bundle transfer is unavailable.');
      }
      await receive(
        transfer.id,
        device.remark.isEmpty ? device.name : device.remark,
        file,
      );
      try {
        await file.delete();
      } on FileSystemException catch (error) {
        debugPrint(
          'DingDong could not remove a received bundle temporary file: $error',
        );
      }
      return;
    }
    final now = DateTime.now().toUtc();
    final record = ClipboardRecord(
      id: 'DEVICE-FILE-${device.id}-${transfer.id}',
      group: '',
      title: sanitizeDeviceLinkFileName(transfer.name),
      content: file.path,
      tags: [
        'clipboard',
        'file',
        'file-url',
        ...clipboardDeviceOriginTags(device),
      ],
      source: _localizations().fromDevice(device.name),
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: now,
      updatedAt: now,
    );
    _clipboardStore.save(record);
    if (device.kind == LinkedDeviceKind.computer) {
      await _systemClipboard?.writeFiles([file.path]);
    }
    onClipboardReceived?.call();
  }
}
