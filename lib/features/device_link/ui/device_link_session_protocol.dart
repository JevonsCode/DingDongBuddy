part of 'device_link_controller.dart';

// Own relay session attachment, handshake, settings, and message dispatch.
extension _DeviceLinkSessionProtocol on DeviceLinkController {
  void _attachDeviceSession(LinkedDevice device) {
    _attachSession(
      device.room,
      deviceId: device.id,
      connectionSide: device.connectionSide,
      transportPreference: device.transportPreference,
      relayUrlOverride: device.relayUrl,
    );
  }

  void _attachSession(
    String room, {
    String? deviceId,
    DeviceLinkConnectionSide connectionSide = DeviceLinkConnectionSide.host,
    DeviceLinkTransportPreference transportPreference =
        DeviceLinkTransportPreference.automatic,
    Uri? relayUrlOverride,
  }) {
    final Uri? relayBaseUrl = relayUrlOverride ?? _relayBaseUrl;
    if (_sessionsByRoom.containsKey(room) || relayBaseUrl == null) return;
    final String secret = deviceId == null
        ? _pendingPairing!.payload.secret
        : _device(deviceId).secret;
    final DeviceLinkSessionFactory factory =
        connectionSide == DeviceLinkConnectionSide.host
        ? _sessionFactory
        : _peerSessionFactory;
    final DeviceLinkSessionHandle handle = factory(
      relayUrl: relayBaseUrl,
      room: room,
      secret: secret,
    );
    if (handle is ConfigurableDeviceLinkSessionHandle) {
      (handle as ConfigurableDeviceLinkSessionHandle).updateTransportPreference(
        transportPreference,
      );
    }
    final _ManagedDeviceSession managed = _ManagedDeviceSession(
      handle: handle,
      room: room,
      deviceId: deviceId,
      connectionSide: connectionSide,
    );
    _sessionsByRoom[room] = managed;
    managed.subscription = handle.events
        .asyncMap<void>((DeviceLinkSessionEvent event) async {
          if (!_sessionIsCurrent(managed)) return;
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

  bool _sessionIsCurrent(_ManagedDeviceSession managed) =>
      managed.active && identical(_sessionsByRoom[managed.room], managed);

  Future<void> _handleSessionEvent(
    _ManagedDeviceSession managed,
    DeviceLinkSessionEvent event,
  ) async {
    if (!_sessionIsCurrent(managed)) return;
    if (event is DeviceLinkStatusEvent) {
      final String? deviceId = managed.deviceId;
      if (deviceId == null) {
        _pairingStatus = event.status;
      } else {
        _statuses[deviceId] = event.status;
        if (event.status == DeviceConnectionStatus.connected) {
          await _updateDevice(
            deviceId,
            (LinkedDevice device) =>
                device.copyWith(lastSeenAt: DateTime.now().toUtc()),
          );
          if (!_sessionIsCurrent(managed)) return;
          await _sendPeerHello(managed);
        } else if (event.status != DeviceConnectionStatus.connecting) {
          managed.helloSent = false;
          _transports[deviceId] = DeviceLinkActiveTransport.none;
        }
      }
      _notifyIfActive();
      return;
    }
    if (event is DeviceLinkPeerPresenceEvent) {
      if (event.present) {
        await _sendPeerHello(managed);
      } else {
        managed.helloSent = false;
      }
      return;
    }
    if (event is DeviceLinkTransportEvent) {
      final String? deviceId = managed.deviceId;
      if (deviceId != null) {
        _transports[deviceId] = event.transport;
        if (event.transport == DeviceLinkActiveTransport.localNetwork &&
            managed.snapshotPending) {
          try {
            await _sendSnapshot(managed);
            if (!_sessionIsCurrent(managed)) return;
            managed.snapshotPending = false;
          } on Object {
            // The direct channel can close between the route event and send.
          }
        }
        _notifyIfActive();
      }
      return;
    }
    if (event is DeviceLinkMessageEvent) {
      await _handleDeviceMessage(managed, event.message);
    }
  }

  Future<void> _sendPeerHello(_ManagedDeviceSession managed) async {
    if (!_sessionIsCurrent(managed) ||
        managed.connectionSide != DeviceLinkConnectionSide.peer ||
        managed.helloSent) {
      return;
    }
    managed.helloSent = true;
    try {
      await managed.handle.send(<String, Object?>{
        'type': 'hello',
        'device': <String, Object?>{
          ..._localDevice.toJson(),
          'kind': 'computer',
        },
        'vibrationEnabled': false,
        'agentNotificationsEnabled': false,
      });
    } on Object {
      managed.helloSent = false;
      rethrow;
    }
  }

  Future<void> _handleDeviceMessage(
    _ManagedDeviceSession managed,
    Map<String, Object?> message,
  ) async {
    if (!_sessionIsCurrent(managed)) return;
    final String? type = message['type'] as String?;
    if (type == 'hello') {
      await _handleHello(managed, message);
      return;
    }
    final String? deviceId = managed.deviceId;
    if (deviceId == null) return;
    final LinkedDevice device = _device(deviceId);
    switch (type) {
      case 'welcome':
        await _handleWelcome(managed, message);
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
        final Object? transport = message['transportPreference'];
        if (vibration is bool ||
            agentNotifications is bool ||
            transport is String) {
          final DeviceLinkTransportPreference? transportPreference =
              transport is String
              ? DeviceLinkTransportPreference.parse(transport)
              : null;
          await _updateDevice(
            deviceId,
            (LinkedDevice current) => current.copyWith(
              vibrationEnabled: vibration is bool ? vibration : null,
              receiveAgentNotifications: agentNotifications is bool
                  ? agentNotifications
                  : null,
              transportPreference: transportPreference,
            ),
          );
          if (!_sessionIsCurrent(managed)) return;
          if (transportPreference != null &&
              managed.handle is ConfigurableDeviceLinkSessionHandle) {
            (managed.handle as ConfigurableDeviceLinkSessionHandle)
                .updateTransportPreference(transportPreference);
          }
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

  Future<void> _handleWelcome(
    _ManagedDeviceSession managed,
    Map<String, Object?> message,
  ) async {
    if (!_sessionIsCurrent(managed) ||
        managed.connectionSide != DeviceLinkConnectionSide.peer) {
      return;
    }
    final Object? rawHost = message['host'];
    if (rawHost is! Map) return;
    final Map<String, Object?> host = Map<String, Object?>.from(rawHost);
    final String hostId = (host['id'] as String? ?? '').trim();
    final String? deviceId = managed.deviceId;
    if (deviceId == null || hostId != deviceId) {
      throw const FormatException('The paired computer identity changed.');
    }
    final Object? rawPermissions = message['permissions'];
    final Map<String, Object?> permissions = rawPermissions is Map
        ? Map<String, Object?>.from(rawPermissions)
        : const <String, Object?>{};
    final DeviceLinkTransportPreference authoritativeTransport =
        DeviceLinkTransportPreference.parse(permissions['transportPreference']);
    await _updateDevice(
      deviceId,
      (LinkedDevice current) => current.copyWith(
        name: (host['name'] as String?)?.trim(),
        kind: LinkedDeviceKind.computer,
        platform: host['platform'] as String?,
        connectionSide: DeviceLinkConnectionSide.peer,
        transportPreference: authoritativeTransport,
        lastSeenAt: DateTime.now().toUtc(),
      ),
    );
    if (!_sessionIsCurrent(managed)) return;
    if (managed.handle is ConfigurableDeviceLinkSessionHandle) {
      (managed.handle as ConfigurableDeviceLinkSessionHandle)
          .updateTransportPreference(authoritativeTransport);
    }
  }

  Future<void> _handleHello(
    _ManagedDeviceSession managed,
    Map<String, Object?> message,
  ) async {
    if (!_sessionIsCurrent(managed)) return;
    final Map<String, Object?> remote = Map<String, Object?>.from(
      message['device']! as Map,
    );
    final String remoteId = (remote['id'] as String? ?? '').trim();
    if (remoteId.isEmpty) return;
    final LinkedDeviceKind remoteKind = LinkedDeviceKind.parse(remote['kind']);
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
        kind: remoteKind,
        platform: remote['platform'] as String? ?? '',
        room: pairing.payload.room,
        secret: pairing.payload.secret,
        relayUrl: pairing.payload.relayUrl,
        connectionSide: DeviceLinkConnectionSide.host,
        autoSendClipboard: false,
        receiveAgentNotifications: remoteKind == LinkedDeviceKind.phone
            ? message['agentNotificationsEnabled'] != false
            : false,
        vibrationEnabled: message['vibrationEnabled'] != false,
        manuallyDisconnected: false,
        pairedAt: DateTime.now().toUtc(),
        sharedClipboardItemIds: const <String>[],
        lastSeenAt: DateTime.now().toUtc(),
      );
      await _addDevice(device);
      if (!_sessionIsCurrent(managed)) return;
      managed.deviceId = remoteId;
      _statuses[remoteId] = DeviceConnectionStatus.connected;
      _transports[remoteId] =
          managed.handle is ConfigurableDeviceLinkSessionHandle
          ? (managed.handle as ConfigurableDeviceLinkSessionHandle)
                .activeTransport
          : DeviceLinkActiveTransport.none;
      _pendingPairing = null;
      _pairingStatus = DeviceConnectionStatus.connected;
    } else {
      final PendingDevicePairing? pairing = _pendingPairing;
      final bool replacingExistingPair =
          pairing != null && pairing.payload.room == managed.room;
      final String previousRoom = device.room;
      managed.deviceId = remoteId;
      await _updateDevice(
        remoteId,
        (LinkedDevice current) => current.copyWith(
          name: (remote['name'] as String?)?.trim(),
          kind: remoteKind,
          platform: remote['platform'] as String?,
          room: replacingExistingPair ? pairing.payload.room : null,
          secret: replacingExistingPair ? pairing.payload.secret : null,
          relayUrl: replacingExistingPair ? pairing.payload.relayUrl : null,
          connectionSide: replacingExistingPair
              ? DeviceLinkConnectionSide.host
              : null,
          vibrationEnabled: message['vibrationEnabled'] is bool
              ? message['vibrationEnabled']! as bool
              : null,
          manuallyDisconnected: replacingExistingPair ? false : null,
          pairedAt: replacingExistingPair ? DateTime.now().toUtc() : null,
          lastSeenAt: DateTime.now().toUtc(),
        ),
      );
      if (!_sessionIsCurrent(managed)) return;
      device = _device(remoteId);
      if (replacingExistingPair) {
        _pendingPairing = null;
        _pairingStatus = DeviceConnectionStatus.connected;
        _statuses[remoteId] = DeviceConnectionStatus.connected;
        _transports[remoteId] =
            managed.handle is ConfigurableDeviceLinkSessionHandle
            ? (managed.handle as ConfigurableDeviceLinkSessionHandle)
                  .activeTransport
            : DeviceLinkActiveTransport.none;
        if (previousRoom != managed.room) {
          await _removeSession(previousRoom);
          if (!_sessionIsCurrent(managed)) return;
        }
      }
    }
    if (!_sessionIsCurrent(managed)) return;
    await managed.handle.send(<String, Object?>{
      'type': 'welcome',
      'host': <String, Object?>{..._localDevice.toJson(), 'kind': 'computer'},
      'permissions': <String, Object?>{
        'autoSendClipboard': device.autoSendClipboard,
        'receiveAgentNotifications': device.receiveAgentNotifications,
        'transportPreference': device.transportPreference.name,
      },
    });
    if (!_sessionIsCurrent(managed)) return;
    try {
      await _sendSnapshot(managed);
      managed.snapshotPending = false;
    } on StateError {
      managed.snapshotPending = true;
    }
    _notifyIfActive();
  }
}
