part of 'device_link_controller.dart';

// Serialize device mutations and clean up sessions and partial uploads.
extension _DeviceLinkPersistence on DeviceLinkController {
  Future<void> _updateDevice(
    String deviceId,
    LinkedDevice Function(LinkedDevice device) update,
  ) async {
    await _replaceDevice(update(_device(deviceId)));
  }

  Future<void> _replaceDevice(LinkedDevice next) async {
    _devices = List<LinkedDevice>.unmodifiable(
      _devices.map(
        (LinkedDevice device) => device.id == next.id ? next : device,
      ),
    );
    await _persist();
    _notifyIfActive();
  }

  LinkedDevice _device(String id) =>
      _devices.firstWhere((LinkedDevice device) => device.id == id);

  _ManagedDeviceSession _sessionForDevice(String deviceId) {
    final LinkedDevice device = _device(deviceId);
    final _ManagedDeviceSession? session = _sessionsByRoom[device.room];
    if (session == null || !session.handle.connected) {
      throw StateError('The selected device is offline.');
    }
    return session;
  }

  Future<void> _removeSession(String room) async {
    final _ManagedDeviceSession? session = _sessionsByRoom.remove(room);
    if (session == null) return;
    await session.subscription?.cancel();
    final String? deviceId = session.deviceId;
    if (deviceId != null) {
      await _discardIncomingFileUploadsForDevice(deviceId);
    }
    await session.handle.close();
  }

  String _incomingFileKey(String deviceId, String transferId) =>
      '$deviceId\u0000$transferId';

  Future<void> _pruneIncomingFileUploads() async {
    final DateTime cutoff = DateTime.now().toUtc().subtract(
      _incomingFileUploadIdleTimeout,
    );
    final List<String> expired = _incomingFiles.entries
        .where(
          (MapEntry<String, _IncomingFileUpload> entry) =>
              entry.value.lastActivityAt.isBefore(cutoff),
        )
        .map((MapEntry<String, _IncomingFileUpload> entry) => entry.key)
        .toList(growable: false);
    for (final String key in expired) {
      await _discardIncomingFileUpload(key);
    }
  }

  Future<void> _discardIncomingFileUploadsForDevice(String deviceId) async {
    final List<String> keys = _incomingFiles.entries
        .where(
          (MapEntry<String, _IncomingFileUpload> entry) =>
              entry.value.deviceId == deviceId,
        )
        .map((MapEntry<String, _IncomingFileUpload> entry) => entry.key)
        .toList(growable: false);
    for (final String key in keys) {
      await _discardIncomingFileUpload(key);
    }
  }

  Future<void> _discardIncomingFileUpload(String key) async {
    final _IncomingFileUpload? upload = _incomingFiles.remove(key);
    if (upload == null) return;
    try {
      await upload.writer.close();
    } on Object {
      // Continue with best-effort cleanup of the partial file.
    }
    try {
      if (await upload.partialFile.exists()) {
        await upload.partialFile.delete();
      }
    } on FileSystemException {
      // A disappearing temporary file is already cleaned up.
    }
  }

  Future<void> _persist() => _store.save(
    DeviceLinkDocument(localDevice: _localDevice, devices: _devices),
  );
}
