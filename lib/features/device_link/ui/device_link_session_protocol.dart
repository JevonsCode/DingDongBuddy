part of 'device_link_controller.dart';

// Own relay session attachment, handshake, settings, and message dispatch.
extension _DeviceLinkSessionProtocol on DeviceLinkController {
  void _attachSession(String room, {String? deviceId}) {
    final Uri? relayBaseUrl = _relayBaseUrl;
    if (_sessionsByRoom.containsKey(room) || relayBaseUrl == null) return;
    final String secret = deviceId == null
        ? _pendingPairing!.payload.secret
        : _device(deviceId).secret;
    final DeviceLinkSessionHandle handle = _sessionFactory(
      relayUrl: relayBaseUrl,
      room: room,
      secret: secret,
    );
    final _ManagedDeviceSession managed = _ManagedDeviceSession(
      handle: handle,
      room: room,
      deviceId: deviceId,
    );
    _sessionsByRoom[room] = managed;
    managed.subscription = handle.events
        .asyncMap<void>((DeviceLinkSessionEvent event) async {
          try {
            await _handleSessionEvent(managed, event);
          } on Object catch (error, stackTrace) {
            debugPrint('DingDong device message was rejected: $error');
            debugPrintStack(stackTrace: stackTrace);
          }
        })
        .listen(null);
    unawaited(handle.connect());
  }

  Future<void> _handleSessionEvent(
    _ManagedDeviceSession managed,
    DeviceLinkSessionEvent event,
  ) async {
    if (event is DeviceLinkStatusEvent) {
      final String? deviceId = managed.deviceId;
      if (deviceId == null) {
        _pairingStatus = event.status;
      } else {
        _statuses[deviceId] = event.status;
        if (event.status == DeviceConnectionStatus.connected) {
          final LinkedDevice device = _device(deviceId);
          await _replaceDevice(
            device.copyWith(lastSeenAt: DateTime.now().toUtc()),
          );
        }
      }
      _notifyIfActive();
      return;
    }
    if (event is DeviceLinkMessageEvent) {
      await _handleDeviceMessage(managed, event.message);
    }
  }

  Future<void> _handleDeviceMessage(
    _ManagedDeviceSession managed,
    Map<String, Object?> message,
  ) async {
    final String? type = message['type'] as String?;
    if (type == 'hello') {
      await _handleHello(managed, message);
      return;
    }
    final String? deviceId = managed.deviceId;
    if (deviceId == null) return;
    final LinkedDevice device = _device(deviceId);
    switch (type) {
      case 'clipboard.create':
        await _receiveText(managed, device, message);
      case 'file.start':
        await _beginFileUpload(device, message);
      case 'file.chunk':
        await _receiveFileChunk(device, message);
      case 'file.end':
        await _finishFileUpload(device, message);
      case 'file.request':
        await _sendRequestedFile(managed, message['itemId'] as String? ?? '');
      case 'settings.update':
        final Object? vibration = message['vibrationEnabled'];
        final Object? agentNotifications = message['agentNotificationsEnabled'];
        if (vibration is bool || agentNotifications is bool) {
          await _replaceDevice(
            device.copyWith(
              vibrationEnabled: vibration is bool ? vibration : null,
              receiveAgentNotifications: agentNotifications is bool
                  ? agentNotifications
                  : null,
            ),
          );
        }
      case 'agent.seen':
        _handleAgentSeen(message);
    }
  }

  void _handleAgentSeen(Map<String, Object?> message) {
    final Object? rawIds = message['activityIds'];
    if (rawIds is! List) return;
    final List<String> activityIds = rawIds
        .whereType<String>()
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty && id.length <= 160)
        .toSet()
        .take(deviceLinkAgentHistoryLimit)
        .toList(growable: false);
    if (activityIds.isEmpty) return;
    _onAgentSeen?.call(activityIds);
  }

  Future<void> _handleHello(
    _ManagedDeviceSession managed,
    Map<String, Object?> message,
  ) async {
    final Map<String, Object?> remote = Map<String, Object?>.from(
      message['device']! as Map,
    );
    final String remoteId = (remote['id'] as String? ?? '').trim();
    if (remoteId.isEmpty) return;
    LinkedDevice? device = _devices.cast<LinkedDevice?>().firstWhere(
      (LinkedDevice? value) => value?.id == remoteId,
      orElse: () => null,
    );
    if (device == null) {
      final PendingDevicePairing? pairing = _pendingPairing;
      if (pairing == null || pairing.payload.room != managed.room) return;
      device = LinkedDevice(
        id: remoteId,
        name: (remote['name'] as String? ?? _localizations().mobileDevice)
            .trim(),
        kind: LinkedDeviceKind.parse(remote['kind']),
        platform: remote['platform'] as String? ?? '',
        room: pairing.payload.room,
        secret: pairing.payload.secret,
        autoSendClipboard: false,
        receiveAgentNotifications:
            message['agentNotificationsEnabled'] != false,
        vibrationEnabled: message['vibrationEnabled'] != false,
        manuallyDisconnected: false,
        pairedAt: DateTime.now().toUtc(),
        sharedClipboardItemIds: const <String>[],
        lastSeenAt: DateTime.now().toUtc(),
      );
      _devices = List<LinkedDevice>.unmodifiable(<LinkedDevice>[
        ..._devices,
        device,
      ]);
      managed.deviceId = remoteId;
      _statuses[remoteId] = DeviceConnectionStatus.connected;
      _pendingPairing = null;
      _pairingStatus = DeviceConnectionStatus.connected;
      await _persist();
    } else {
      final PendingDevicePairing? pairing = _pendingPairing;
      final bool replacingExistingPair =
          pairing != null && pairing.payload.room == managed.room;
      final String previousRoom = device.room;
      managed.deviceId = remoteId;
      device = device.copyWith(
        name: (remote['name'] as String?)?.trim(),
        kind: LinkedDeviceKind.parse(remote['kind']),
        platform: remote['platform'] as String?,
        room: replacingExistingPair ? pairing.payload.room : null,
        secret: replacingExistingPair ? pairing.payload.secret : null,
        vibrationEnabled: message['vibrationEnabled'] is bool
            ? message['vibrationEnabled']! as bool
            : null,
        manuallyDisconnected: replacingExistingPair ? false : null,
        pairedAt: replacingExistingPair ? DateTime.now().toUtc() : null,
        lastSeenAt: DateTime.now().toUtc(),
      );
      await _replaceDevice(device);
      if (replacingExistingPair) {
        _pendingPairing = null;
        _pairingStatus = DeviceConnectionStatus.connected;
        _statuses[remoteId] = DeviceConnectionStatus.connected;
        if (previousRoom != managed.room) {
          await _removeSession(previousRoom);
        }
      }
    }
    await managed.handle.send(<String, Object?>{
      'type': 'welcome',
      'host': <String, Object?>{..._localDevice.toJson(), 'kind': 'computer'},
      'permissions': <String, Object?>{
        'autoSendClipboard': device.autoSendClipboard,
        'receiveAgentNotifications': device.receiveAgentNotifications,
      },
    });
    await _sendSnapshot(managed);
    _notifyIfActive();
  }
}
