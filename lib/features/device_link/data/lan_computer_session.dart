part of 'lan_computer_link.dart';

/// Authenticated TCP session using fresh challenges and per-direction counters.
/// The persisted 256-bit pair key is never sent; captured frames cannot replay
/// into a new connection. Only the pairing's peer side initiates reconnects.
final class LanComputerSession
    implements
        DeviceLinkSessionHandle,
        ConfigurableDeviceLinkSessionHandle,
        LanVerifiedDeviceLinkSessionHandle {
  LanComputerSession._(this.owner, this.device)
    : _codec = SecureMessageCodec.fromBase64Url(device.secret),
      _addressHint = device.lanAddress;
  final LanComputerLink owner;
  final LinkedDevice device;
  String? _addressHint;
  final SecureMessageCodec _codec;
  LanDiscoveryChannel? _discoveryChannel;
  List<InternetAddress> _discovered = const [];
  DateTime? _nextDiscovery;
  int _discoveryFailures = 0;

  final _events = StreamController<DeviceLinkSessionEvent>.broadcast();
  LanWire? _wire;
  bool _closed = false;
  bool _connecting = false;
  Timer? _retry;
  String? _nonce;
  int _sent = 0;
  int _received = 0;
  Future<void> _sendTail = Future.value();
  bool _permitsRoutedAddress(InternetAddress address) =>
      owner._isRoutedAddress(address) &&
      ((device.lanRouted && address.address == _addressHint) ||
          _discovered.contains(address));

  bool _canUseWire(LanWire wire) {
    final address = wire.socket.remoteAddress;
    return wire.routed
        ? _permitsRoutedAddress(address)
        : owner._findEndpoint(device.id, address.address) != null;
  }

  bool get _hasUsableWire => _wire != null && _canUseWire(_wire!);
  @override
  Stream<DeviceLinkSessionEvent> get events => _events.stream;
  @override
  bool get connected => !_closed && _wire != null;
  @override
  DeviceLinkActiveTransport get activeTransport => connected
      ? DeviceLinkActiveTransport.localNetwork
      : DeviceLinkActiveTransport.none;
  @override
  DeviceLinkTransportPreference get transportPreference =>
      DeviceLinkTransportPreference.localNetwork;
  @override
  set transportPreference(DeviceLinkTransportPreference value) {}
  @override
  void updateTransportPreference(DeviceLinkTransportPreference value) {}
  @override
  Future<bool> verifyLocalNetwork() async =>
      connected && !_wire!.routed && _hasUsableWire;

  @override
  Future<void> connect() => _connect();

  Future<void> _connect({bool background = false}) async {
    if (_closed || _connecting || connected) return;
    _connecting = true;
    try {
      await owner.start();
      if (_closed) return;
      _ensureDiscovery();
      if (device.connectionSide == DeviceLinkConnectionSide.host) return;
      final local = owner._findEndpoint(device.id) != null;
      final hint = InternetAddress.tryParse(_addressHint ?? '');
      final routes = {
        ..._discovered,
        if (hint != null && _permitsRoutedAddress(hint)) hint,
      };
      if (!local && routes.isEmpty) return;
      if (!background) {
        _emit(const DeviceLinkStatusEvent(DeviceConnectionStatus.connecting));
      }
      final attempts = <Future<LanWire> Function()>[
        if (local) () => owner._dialPeer(device.id),
        for (final address in routes)
          for (final source in owner._routedSources)
            () => owner._dialRoutedVia(address, source),
      ];
      Object? lastFailure;
      for (final dial in attempts) {
        if (_closed) return;
        try {
          await _authenticate(await dial());
          return;
        } on Exception catch (failure) {
          lastFailure = failure;
        } on StateError catch (failure) {
          lastFailure = failure;
        }
      }
      if (lastFailure != null) throw lastFailure;
    } on Object catch (error) {
      _emit(
        DeviceLinkStatusEvent(
          DeviceConnectionStatus.disconnected,
          error: error,
        ),
      );
    } finally {
      _connecting = false;
      _scheduleRetry();
    }
  }

  Future<void> _authenticate(LanWire wire) async {
    var attached = false;
    try {
      if (_closed) return;
      final clientNonce = LanPairingCrypto.token();
      await wire.write({
        'type': 'connect',
        'room': device.room,
        'id': owner.identity.id,
        'nonce': clientNonce,
      });
      final challenge = await _codec.open(await wire.readProof());
      if (challenge['type'] != 'host-proof' ||
          challenge['clientNonce'] != clientNonce ||
          challenge['hostId'] != device.id) {
        throw const FormatException('host proof');
      }
      final nonce = challenge['nonce'] as String;
      await wire.write({
        'proof': await _codec.seal({
          'type': 'peer-proof',
          'nonce': nonce,
          'clientNonce': clientNonce,
          'id': owner.identity.id,
        }),
      });
      final ack = await _codec.open(await wire.readProof());
      if (ack['type'] != 'ready' || ack['nonce'] != nonce) {
        throw const FormatException('ack');
      }
      if (_closed || !_canUseWire(wire)) return;
      _attach(wire, nonce);
      attached = true;
    } finally {
      if (!attached) wire.close();
    }
  }

  void _ensureDiscovery() {
    final service = owner._discovery;
    final next = _nextDiscovery;
    if (service == null ||
        _closed ||
        _discoveryChannel != null ||
        (next != null && owner._now().isBefore(next))) {
      return;
    }
    final channel = service.watchPair(
      secret: device.secret,
      localId: owner.identity.id,
      peerId: device.id,
      addresses: () => owner.localAddresses,
      onAddresses: (values) {
        if (_closed) return;
        _discoveryFailures = 0;
        final candidates = owner._eligibleCandidates(values).toList();
        final wire = _wire;
        final previous = _discovered;
        _discovered = candidates;
        if (wire != null &&
            wire.routed &&
            previous.contains(wire.socket.remoteAddress) &&
            !candidates.contains(wire.socket.remoteAddress)) {
          _drop();
        }
        if (!connected) unawaited(_connect(background: true));
      },
    );
    _discoveryChannel = channel;
    unawaited(channel.ready.catchError((Object _) {}));
    unawaited(
      channel.done.then((_) {
        if (!identical(_discoveryChannel, channel)) return;
        _discoveryChannel = null;
        _discoveryFailures = (_discoveryFailures + 1).clamp(1, 6);
        _nextDiscovery = owner._now().add(
          Duration(seconds: 1 << _discoveryFailures),
        );
      }),
    );
  }

  Future<void> _accept(LanWire wire) async {
    // The connect request was consumed by the owner; recover its client nonce
    // from the iterator without consuming a second frame.
    final clientNonce = wire.frames.current['nonce'];
    if (clientNonce is! String || clientNonce.length > 64 || _closed) {
      throw const FormatException('nonce');
    }
    final nonce = LanPairingCrypto.token();
    await wire.write({
      'proof': await _codec.seal({
        'type': 'host-proof',
        'nonce': nonce,
        'clientNonce': clientNonce,
        'hostId': owner.identity.id,
      }),
    });
    final proof = await _codec.open(await wire.readProof());
    if (proof['type'] != 'peer-proof' ||
        proof['nonce'] != nonce ||
        proof['clientNonce'] != clientNonce ||
        proof['id'] != device.id ||
        _closed ||
        !_canUseWire(wire)) {
      throw const FormatException('peer proof');
    }
    await wire.write({
      'proof': await _codec.seal({'type': 'ready', 'nonce': nonce}),
    });
    if (_closed) throw StateError('closed');
    _attach(wire, nonce);
  }

  void _attach(LanWire wire, String nonce) {
    _drop();
    _wire = wire;
    _nonce = nonce;
    _sent = 0;
    _received = 0;
    _emit(
      const DeviceLinkTransportEvent(DeviceLinkActiveTransport.localNetwork),
    );
    _emit(const DeviceLinkStatusEvent(DeviceConnectionStatus.connected));
    unawaited(_receive(wire, nonce));
  }

  Future<void> _receive(LanWire wire, String nonce) async {
    try {
      while (await wire.frames.moveNext()) {
        if (_closed || !identical(wire, _wire) || !_canUseWire(wire)) break;
        final frame = await _codec.open(wire.frames.current['data'] as String);
        if (!identical(wire, _wire)) return;
        if (frame['nonce'] != nonce ||
            frame['sequence'] != _received++ ||
            frame['from'] != device.id) {
          throw const FormatException('replayed frame');
        }
        _emit(
          DeviceLinkMessageEvent(
            Map<String, Object?>.from(frame['message'] as Map),
          ),
        );
      }
    } on Object {
      /* Reconnect on the next discovery tick. */
    } finally {
      if (identical(wire, _wire)) _drop();
    }
  }

  @override
  Future<void> send(Map<String, Object?> message) {
    final wire = _wire;
    final nonce = _nonce;
    final operation = _sendTail.then((_) async {
      if (_closed ||
          wire == null ||
          !identical(wire, _wire) ||
          !_canUseWire(wire)) {
        throw StateError('Waiting for local network');
      }
      try {
        final data = await _codec.seal({
          'nonce': nonce,
          'sequence': _sent++,
          'from': owner.identity.id,
          'message': message,
        });
        if (!identical(wire, _wire) || !_canUseWire(wire)) {
          throw StateError('LAN changed');
        }
        await wire.write({'data': data});
      } on Object {
        if (identical(wire, _wire)) _drop();
        rethrow;
      }
    });
    _sendTail = operation.catchError((Object _) {});
    return operation;
  }

  void _emit(DeviceLinkSessionEvent event) {
    if (!_closed) _events.add(event);
  }

  void _drop() {
    final wire = _wire;
    _wire = null;
    _nonce = null;
    wire?.close();
    if (wire != null) {
      _emit(const DeviceLinkTransportEvent(DeviceLinkActiveTransport.none));
      _emit(const DeviceLinkStatusEvent(DeviceConnectionStatus.disconnected));
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_closed || connected || _retry != null) return;
    _retry = Timer(const Duration(seconds: 2), () {
      _retry = null;
      unawaited(_connect(background: true));
    });
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _discoveryChannel?.close();
    _discoveryChannel = null;
    _retry?.cancel();
    _retry = null;
    _drop();
    if (identical(owner._sessions[device.room], this)) {
      owner._sessions.remove(device.room);
    }
    await _events.close();
  }
}
