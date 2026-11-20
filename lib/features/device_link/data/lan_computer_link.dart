import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/device_link/data/device_link_session.dart';
import 'package:dingdong/features/device_link/data/lan_link_local_discovery.dart';
import 'package:dingdong/features/device_link/data/lan_network_policy.dart';
import 'package:dingdong/features/device_link/data/lan_pairing_crypto.dart';
import 'package:dingdong/features/device_link/data/lan_unicast_discovery.dart';
import 'package:dingdong/features/device_link/data/lan_wire.dart';
import 'package:dingdong/features/device_link/data/secure_message_codec.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:dingdong/features/device_link/domain/lan_computer_management.dart';
import 'package:flutter/foundation.dart';

part 'lan_computer_session.dart';

/// No DNS, HTTP proxy, public rendezvous, STUN, TURN or relay is used here.
/// Discovery packets carry device metadata only. Secrets travel after SRP.
final class LanComputerLink extends ChangeNotifier {
  LanComputerLink({this.discoveryPort = 45893})
    : _unicastDiscoveryPort = discoveryPort,
      _routedDiscoveryPort = discoveryPort,
      _linkLocalBroadcastTestPort = null,
      _now = DateTime.now,
      _readSubnets = readLanSubnets;
  @visibleForTesting
  LanComputerLink.loopbackTest({
    DateTime Function()? now,
    int unicastDiscoveryPort = 45893,
    int routedDiscoveryPort = 45893,
    int? linkLocalBroadcastTestPort,
    Future<List<LanSubnet>> Function()? subnetReader,
  }) : discoveryPort = 0,
       // Test-only named parameter; keep runtime port state private.
       // ignore: prefer_initializing_formals
       _unicastDiscoveryPort = unicastDiscoveryPort,
       // ignore: prefer_initializing_formals
       _routedDiscoveryPort = routedDiscoveryPort,
       // ignore: prefer_initializing_formals
       _linkLocalBroadcastTestPort = linkLocalBroadcastTestPort,
       _now = now ?? DateTime.now,
       _readSubnets =
           subnetReader ??
           (() async => [LanSubnet(InternetAddress.loopbackIPv4, 8)]);
  final int discoveryPort;
  final int _unicastDiscoveryPort;
  final int _routedDiscoveryPort;
  final int? _linkLocalBroadcastTestPort;
  late final _linkLocalDiscovery = LanLinkLocalDiscovery(
    discoveryPort,
    _receiveDiscovery,
    loopbackTestPort: _linkLocalBroadcastTestPort,
  );
  late final _unicastDiscovery = LanUnicastDiscovery(_receiveDiscovery);
  @visibleForTesting
  int? get discoveryListenPort => _udp?.port;
  @visibleForTesting
  RawDatagramSocket? get discoverySocketForTest => _udp;
  @visibleForTesting
  int? get routedListenPort => _routedServer?.port;
  final DateTime Function() _now;
  final Future<List<LanSubnet>> Function() _readSubnets;
  static final _group = InternetAddress('239.255.68.68');
  static const _lifetime = Duration(minutes: 5);
  static const _routedProtocol = 'dingdong-lan-directed-v1';
  static const _routedTimeout = Duration(seconds: 3);
  final Map<String, _Endpoint> _endpoints = {};
  final Set<String> _manualDiscoveryAddresses = {};
  final Map<String, LanComputerSession> _sessions = {};
  final Set<LanWire> _handshakes = {};
  RawDatagramSocket? _udp;
  ServerSocket? _server;
  ServerSocket? _routedServer;
  List<NetworkInterface> _interfaces = [];
  List<LanSubnet> _subnets = [];
  Timer? _timer;
  Future<void>? _starting;
  bool _closed = false;
  bool _ticking = false;
  int _ticks = 0;
  int _attempts = 0;
  int _generation = 0;
  String? _code;
  DateTime? _expires;
  String? error;
  late LocalDeviceIdentity identity;
  late Future<void> Function(LinkedDevice) onPaired;

  String? get pairingCode =>
      _expires != null && _now().isBefore(_expires!) ? _code : null;
  List<NearbyComputer> get nearby =>
      {for (final e in _endpoints.values.where((e) => e.fresh)) e.id: e}.values
          .map(
            (e) => NearbyComputer(id: e.id, name: e.name, pairing: e.pairing),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

  List<String> get localAddresses => List.unmodifiable(
    _subnets
        .where((subnet) => isLanAddress(subnet.address) || discoveryPort == 0)
        .map((subnet) => subnet.address.address)
        .toSet(),
  );

  String? connectedAddressOf(String id) {
    for (final session in _sessions.values) {
      if (session.device.id == id && session.connected) {
        return session._wire?.socket.remoteAddress.address;
      }
    }
    return null;
  }

  Future<String> validateLocalAddress(
    String value, {
    bool allowRouted = false,
  }) async {
    final text = value.trim();
    if (!RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$').hasMatch(text)) {
      throw const FormatException('LAN IPv4 required');
    }
    final address = InternetAddress.tryParse(text);
    if (address == null || address.type != InternetAddressType.IPv4) {
      throw const FormatException('LAN IPv4 required');
    }
    await start();
    await _refreshInterfaces();
    final isOwnAddress =
        discoveryPort != 0 &&
        _subnets.any((s) => s.address.address == address.address);
    final permittedRoute =
        allowRouted &&
        _isRoutedAddress(address) &&
        !_subnets.any((subnet) => subnet.contains(address));
    if (isOwnAddress || (!_allowedHint(address) && !permittedRoute)) {
      throw const FormatException('Peer must be on a local physical subnet');
    }
    return address.address;
  }

  bool _allowedHint(InternetAddress address) =>
      _allowed(address) &&
      _subnets.any((s) {
        if (!s.contains(address)) return false;
        if (s.prefix >= 31) return true;
        final integer = address.rawAddress.fold(0, (n, b) => (n << 8) | b);
        final hostMask = (1 << (32 - s.prefix)) - 1;
        final host = integer & hostMask;
        return host != 0 && host != hostMask;
      });

  void rememberAddress(String id, String address) {
    for (final session in _sessions.values) {
      if (session.device.id == id) session._addressHint = address;
    }
  }

  Future<void> start() async {
    if (_closed) throw StateError('LAN service closed');
    if (_starting != null) return _starting;
    if (_server != null && _udp != null) return;
    _starting = _server == null ? _start() : _openDiscoverySocket();
    try {
      await _starting;
    } catch (failure) {
      if (!_closed) {
        error = lanDiscoveryFailureCode(failure);
        notifyListeners();
      }
      rethrow;
    } finally {
      _starting = null;
    }
  }

  Future<void> _start() async {
    try {
      final listenAddress = discoveryPort == 0
          ? InternetAddress.loopbackIPv4
          : InternetAddress.anyIPv4;
      final server = await ServerSocket.bind(listenAddress, 0);
      if (_closed) {
        await server.close();
        return;
      }
      _server = server;
      await _openDiscoverySocket();
      if (_closed) return;
      server.listen(
        (socket) => unawaited(_accept(socket)),
        onError: (Object _) {
          error = 'network';
          notifyListeners();
        },
      );
      _timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => unawaited(_tick()),
      );
      await _startRoutedListener(listenAddress);
      if (_closed) return;
      error = null;
      _announce();
    } catch (_) {
      _linkLocalDiscovery.reset();
      _unicastDiscovery.reset();
      _udp?.close();
      _udp = null;
      await _server?.close();
      _server = null;
      await _routedServer?.close();
      _routedServer = null;
      rethrow;
    }
  }

  Future<void> _openDiscoverySocket() async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      discoveryPort,
      reuseAddress: true,
    );
    if (_closed) {
      socket.close();
      return;
    }
    _udp = socket;
    _interfaces = []; // Multicast membership belongs to the socket.
    try {
      socket
        ..writeEventsEnabled = false
        ..multicastHops = 1
        ..multicastLoopback = false;
      await _refreshInterfaces();
      if (_closed) return;
      socket.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          Datagram? packet;
          while ((packet = socket.receive()) != null) {
            _receiveDiscovery(packet!);
          }
        },
        onError: (Object failure) => _discoveryStopped(socket, failure),
        onDone: () => _discoveryStopped(socket),
      );
    } on Object {
      _udp = null;
      socket.close();
      rethrow;
    }
  }

  void _discoveryStopped(RawDatagramSocket socket, [Object? failure]) {
    if (_closed || !identical(_udp, socket)) return;
    _udp = null;
    error = failure == null ? 'network' : lanDiscoveryFailureCode(failure);
    if (failure != null) debugPrint('DingDong LAN discovery: $failure');
    notifyListeners();
  }

  Future<void> _startRoutedListener(InternetAddress listenAddress) async {
    // TCP on the discovery port is used only for explicitly addressed peers.
    // A TCP bind conflict must leave existing multicast and UDP lookup usable.
    try {
      final server = await ServerSocket.bind(listenAddress, discoveryPort);
      if (_closed) {
        await server.close();
        return;
      }
      _routedServer = server;
      server.listen(
        (socket) => unawaited(_accept(socket, routed: true)),
        onError: (Object failure) => debugPrint('DingDong IP lookup: $failure'),
      );
    } on SocketException catch (failure) {
      debugPrint('DingDong IP lookup: $failure');
    }
  }

  Future<void> _refreshInterfaces() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    try {
      _subnets = await _readSubnets();
    } on Object {
      _subnets = [];
      _interfaces = [];
      _linkLocalDiscovery.reset();
      _unicastDiscovery.reset();
      rethrow;
    }
    if (_closed) return;
    final next = interfaces
        .where(
          (i) =>
              !RegExp(
                r'tailscale|zerotier|wireguard|tun|tap|vpn',
                caseSensitive: false,
              ).hasMatch(i.name) &&
              i.addresses.any(
                (a) => _subnets.any((s) => s.address.address == a.address),
              ),
        )
        .toList();
    for (final iface in next) {
      if (_interfaces.any(
        (old) =>
            old.index == iface.index &&
            old.addresses.map((a) => a.address).join() ==
                iface.addresses.map((a) => a.address).join(),
      )) {
        continue;
      }
      try {
        _udp?.joinMulticast(_group, iface);
      } on SocketException {
        /* next NIC */
      }
    }
    _interfaces = next;
    await _linkLocalDiscovery.refresh(next, _subnets);
    if (_udp != null) error = null;
  }

  Future<void> _tick() async {
    if (_closed || _ticking) return;
    _ticking = true;
    try {
      if (_udp == null) {
        await start();
      } else if (++_ticks % 15 == 0) {
        await _refreshInterfaces();
      }
      if (_code != null && pairingCode == null) cancelPairing();
      _endpoints.removeWhere((_, e) => !e.fresh);
      _announce();
      for (final session in _sessions.values.toList()) {
        if (session.connected && !session._hasUsableWire) session._drop();
        if (!session.connected) unawaited(session._connect(background: true));
      }
      notifyListeners();
    } on Object catch (failure) {
      error = lanDiscoveryFailureCode(failure);
    } finally {
      _ticking = false;
    }
  }

  Map<String, Object?> get advertisement => {
    'protocol': 'dingdong-lan-v1',
    'id': identity.id,
    'name': identity.name,
    'port': _server?.port,
    'pairing': pairingCode != null,
  };

  void _announce() {
    final socket = _udp;
    if (_server == null || _closed) return;
    final bytes = utf8.encode(jsonEncode(advertisement));
    _linkLocalDiscovery.announce(bytes);
    if (socket != null && discoveryPort != 0) {
      for (final iface in _interfaces) {
        for (final address in iface.addresses.where(
          (a) => _subnets.any((s) => s.address.address == a.address),
        )) {
          try {
            socket.setRawOption(
              RawSocketOption(
                RawSocketOption.levelIPv4,
                RawSocketOption.IPv4MulticastInterface,
                address.rawAddress,
              ),
            );
            socket.send(bytes, _group, discoveryPort);
          } on SocketException {
            /* An adapter may disappear during enumeration. */
          }
        }
      }
    }
    // A router or adapter can pass multicast in only one direction. Reply to
    // actual discovery senders and keep their view of us fresh across retries.
    // Destinations stay transient, bounded and subject to the same LAN policy.
    final targets = <InternetAddress, Set<int>>{};
    void addTarget(InternetAddress address, int port) {
      (targets[address] ??= {}).add(port);
    }

    for (final endpoint in _endpoints.values) {
      if (!endpoint.fresh ||
          endpoint.routed ||
          !_allowed(endpoint.address) ||
          endpoint.discoveryPort <= 0) {
        continue;
      }
      addTarget(endpoint.address, endpoint.discoveryPort);
    }
    for (final text in _manualDiscoveryAddresses) {
      final address = InternetAddress(text);
      if (_allowedHint(address)) addTarget(address, _unicastDiscoveryPort);
    }
    // Bootstrap discovery from a saved IP even when multicast is unavailable.
    // The peer still supplies its current TCP port and proves the original key.
    for (final session in _sessions.values) {
      final hint = InternetAddress.tryParse(session._addressHint ?? '');
      if (hint != null && _allowedHint(hint)) {
        addTarget(hint, _unicastDiscoveryPort);
      }
    }
    _unicastDiscovery.announce(bytes, targets);
  }

  void _receiveDiscovery(Datagram packet) {
    if (!_allowed(packet.address) || packet.data.length > 2048) return;
    try {
      final json = jsonDecode(utf8.decode(packet.data)) as Map;
      if (json['protocol'] != 'dingdong-lan-v1') return;
      final id = json['id'];
      final name = json['name'];
      final port = json['port'];
      if (id is! String ||
          id.isEmpty ||
          id.length > 160 ||
          id == identity.id ||
          name is! String ||
          name.length > 160 ||
          port is! int ||
          port < 1 ||
          port > 65535) {
        return;
      }
      final endpointKey = '$id@${packet.address.address}';
      if (_endpoints.length >= 128 && !_endpoints.containsKey(endpointKey)) {
        return;
      }
      final isNew = !_endpoints.containsKey(endpointKey);
      _endpoints[endpointKey] = _Endpoint(
        id,
        name,
        packet.address,
        port,
        json['pairing'] == true,
        packet.port,
      );
      if (isNew) _announce();
      notifyListeners();
    } on Object {
      /* Untrusted LAN datagram. */
    }
  }

  /// A typed address can be searched locally or on a reachable private route.
  Future<void> discoverAddress(String value) async {
    final address = InternetAddress(
      await validateLocalAddress(value, allowRouted: true),
    );
    if (!_allowedHint(address)) {
      await _discoverRouted(address);
      return;
    }
    if (_manualDiscoveryAddresses.length >= 16) {
      _manualDiscoveryAddresses.remove(_manualDiscoveryAddresses.first);
    }
    _manualDiscoveryAddresses.add(address.address);
    _announce();
    notifyListeners();
  }

  Future<void> _discoverRouted(InternetAddress address) async {
    _endpoints.removeWhere(
      (_, endpoint) => endpoint.routed && endpoint.address == address,
    );
    notifyListeners();
    final wire = await _dialRouted(address);
    try {
      await wire.write({'type': 'lookup', 'protocol': _routedProtocol});
      final result = await wire.read(timeout: _routedTimeout);
      final id = result['id'];
      final name = result['name'];
      if (result['protocol'] != _routedProtocol ||
          id is! String ||
          id.isEmpty ||
          id.length > 160 ||
          id == identity.id ||
          name is! String ||
          name.length > 160) {
        throw const SocketException('Computer is unavailable for IP pairing');
      }
      if (_closed) return;
      _endpoints['$id@${address.address}/routed'] = _Endpoint(
        id,
        name,
        address,
        _routedDiscoveryPort,
        true,
        0,
        routed: true,
      );
      notifyListeners();
    } on FormatException {
      throw const SocketException('Computer is unavailable for IP pairing');
    } finally {
      wire.close();
    }
  }

  Future<void> refresh() async {
    final wasRunning = _udp != null && _starting == null;
    try {
      await start();
      if (wasRunning) await _refreshInterfaces();
    } catch (failure) {
      // Adapter metadata is useful even when the discovery socket cannot bind.
      // Keep multicast membership separate so the next start can still join it.
      try {
        _subnets = await _readSubnets();
      } on Object {
        // Preserve the discovery failure when adapter metadata is unavailable.
      }
      error = lanDiscoveryFailureCode(failure);
      if (!_closed) notifyListeners();
      rethrow;
    }
    _announce();
  }

  Future<void> beginPairing() async {
    await start();
    _generation++;
    _attempts = 0;
    _code = LanPairingCrypto.code();
    _expires = _now().add(_lifetime);
    _announce();
    notifyListeners();
  }

  void cancelPairing() {
    _generation++;
    _code = null;
    _expires = null;
    _announce();
    notifyListeners();
  }

  LanComputerSession session(LinkedDevice device) {
    final session = LanComputerSession._(this, device);
    _sessions[device.room] = session;
    return session;
  }

  Future<LanWire> _dial(_Endpoint endpoint) async {
    if (!endpoint.fresh || !_allowed(endpoint.address)) {
      throw const SocketException('Not on the local network');
    }
    return LanWire(
      await Socket.connect(
        endpoint.address,
        endpoint.port,
        timeout: const Duration(seconds: 3),
        sourceAddress: _subnets
            .firstWhere((s) => s.contains(endpoint.address))
            .address,
      ),
    );
  }

  Future<LanWire> _dialRouted(InternetAddress address) async {
    if (!_isRoutedAddress(address)) {
      throw const SocketException('Private IPv4 address required');
    }
    return LanWire(
      await Socket.connect(
        address,
        _routedDiscoveryPort,
        timeout: _routedTimeout,
      ),
      routed: true,
    );
  }

  Future<LanWire> _dialPeer(String id, {bool pairing = false}) async {
    Object? lastError;
    for (final endpoint
        in _endpoints.values
            .where(
              (e) => e.id == id && e.fresh && (pairing ? e.pairing : !e.routed),
            )
            .take(8)
            .toList()) {
      try {
        return endpoint.routed
            ? await _dialRouted(endpoint.address)
            : await _dial(endpoint);
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? const SocketException('No reachable LAN address');
  }

  Future<void> join(String id, String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) throw const FormatException('code');
    await start();
    final wire = await _dialPeer(id, pairing: true);
    try {
      final a = LanPairingCrypto.privateValue();
      await wire.write({
        'type': 'pair',
        'a': LanPairingCrypto.generator
            .modPow(a, LanPairingCrypto.modulus)
            .toRadixString(16),
      });
      final challenge = await wire.read();
      final salt = challenge['salt'] as String;
      if (salt.length > 64) throw const FormatException('salt');
      final key = await LanPairingCrypto.clientKey(
        salt: salt,
        code: code,
        a: a,
        bPublic: LanPairingCrypto.readPublic(challenge['b'] as String),
      );
      final codec = SecureMessageCodec.fromBase64Url(key);
      await wire.write({
        'proof': await codec.seal({
          'type': 'pair-client',
          'hostId': id,
          'device': identity.toJson(),
        }),
      });
      final result = await codec.open((await wire.read())['proof'] as String);
      if (result['type'] != 'pair-host') throw const FormatException('proof');
      final host = LocalDeviceIdentity.fromJson(
        Map<String, Object?>.from(result['device'] as Map),
      );
      if (host.id != id) throw const FormatException('identity');
      final room = result['room'] as String;
      final secret = result['secret'] as String;
      if (room.length > 100 ||
          base64Url.decode(base64Url.normalize(secret)).length != 32) {
        throw const FormatException('credentials');
      }
      await onPaired(
        _device(host, room, secret, DeviceLinkConnectionSide.peer, wire),
      );
      if (wire.routed) {
        _endpoints.remove('$id@${wire.socket.remoteAddress.address}/routed');
      }
    } finally {
      wire.close();
    }
  }

  Future<void> _accept(Socket socket, {bool routed = false}) async {
    final address = socket.remoteAddress;
    final permitted = routed
        ? _isRoutedAddress(address) &&
              (pairingCode != null ||
                  _sessions.values.any(
                    (session) =>
                        session.device.connectionSide ==
                            DeviceLinkConnectionSide.host &&
                        session._permitsRoutedAddress(address),
                  ))
        : _allowed(address) &&
              _endpoints.values.any(
                (e) => !e.routed && e.fresh && e.address == address,
              );
    if (_closed ||
        !permitted ||
        _handshakes.length >= 8 ||
        (routed && _handshakes.where((wire) => wire.routed).length >= 2)) {
      socket.destroy();
      return;
    }
    final wire = LanWire(socket, routed: routed);
    _handshakes.add(wire);
    var transferred = false;
    try {
      final request = routed
          ? await wire.read(timeout: _routedTimeout)
          : await wire.read();
      if (request['type'] == 'pair') {
        await _pair(wire, request);
      } else if (routed &&
          request['type'] == 'lookup' &&
          request['protocol'] == _routedProtocol &&
          pairingCode != null) {
        await wire.write({
          'protocol': _routedProtocol,
          'id': identity.id,
          'name': identity.name,
        });
      } else if (request['type'] == 'connect') {
        final session = _sessions[request['room']];
        if (session != null &&
            session.device.connectionSide == DeviceLinkConnectionSide.host &&
            session.device.id == request['id'] &&
            session._canUseWire(wire)) {
          await session._accept(wire);
          transferred = true;
        }
      }
    } on Object {
      /* Fail closed; never expose codes, proofs or credentials. */
    } finally {
      _handshakes.remove(wire);
      if (!transferred) wire.close();
    }
  }

  Future<void> _pair(LanWire wire, Map<String, Object?> request) async {
    final code = pairingCode;
    if (code == null || _attempts >= 5) return;
    final generation = _generation;
    _attempts++; // Charge attempts before any expensive or asynchronous work.
    if (_attempts == 5) {
      _code = null;
      notifyListeners();
    }
    final salt = LanPairingCrypto.token(16);
    final b = LanPairingCrypto.privateValue();
    final aPublic = LanPairingCrypto.readPublic(request['a'] as String);
    final bPublic = await LanPairingCrypto.serverPublic(salt, code, b);
    final key = await LanPairingCrypto.serverKey(
      salt: salt,
      code: code,
      aPublic: aPublic,
      b: b,
      bPublic: bPublic,
    );
    await wire.write({'salt': salt, 'b': bPublic.toRadixString(16)});
    final codec = SecureMessageCodec.fromBase64Url(key);
    final proof = await codec.open((await wire.read())['proof'] as String);
    if (proof['type'] != 'pair-client' ||
        proof['hostId'] != identity.id ||
        generation != _generation ||
        _expires == null ||
        !_now().isBefore(_expires!)) {
      return;
    }
    final peer = LocalDeviceIdentity.fromJson(
      Map<String, Object?>.from(proof['device'] as Map),
    );
    if (peer.id == identity.id ||
        peer.id.isEmpty ||
        peer.id.length > 160 ||
        peer.name.length > 160) {
      return;
    }
    if (!wire.routed &&
        _findEndpoint(peer.id, wire.socket.remoteAddress.address) == null) {
      return;
    }
    cancelPairing(); // Consume atomically before persistence or concurrent proofs.
    final room = LanPairingCrypto.token(18);
    final secret = LanPairingCrypto.token();
    await onPaired(
      _device(peer, room, secret, DeviceLinkConnectionSide.host, wire),
    );
    await wire.write({
      'proof': await codec.seal({
        'type': 'pair-host',
        'device': identity.toJson(),
        'room': room,
        'secret': secret,
      }),
    });
  }

  LinkedDevice _device(
    LocalDeviceIdentity peer,
    String room,
    String secret,
    DeviceLinkConnectionSide side,
    LanWire wire,
  ) => LinkedDevice(
    id: peer.id,
    name: peer.name,
    kind: LinkedDeviceKind.computer,
    platform: peer.platform,
    room: room,
    secret: secret,
    lanRouted: wire.routed,
    lanAddress: wire.routed ? wire.socket.remoteAddress.address : null,
    connectionSide: side,
    transportPreference: DeviceLinkTransportPreference.localNetwork,
    autoSendClipboard: false,
    receiveAgentNotifications: false,
    vibrationEnabled: false,
    manuallyDisconnected: false,
    pairedAt: DateTime.now().toUtc(),
  );

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    _linkLocalDiscovery.reset();
    _unicastDiscovery.reset();
    _udp?.close();
    _udp = null;
    await _server?.close();
    _server = null;
    await _routedServer?.close();
    _routedServer = null;
    for (final wire in _handshakes.toList()) {
      wire.close();
    }
    for (final session in _sessions.values.toList()) {
      await session.close();
    }
    _endpoints.clear();
  }

  /// IPv4 LAN only. Public, carrier NAT/VPN, loopback and DNS names fail closed.
  static bool isLanAddress(InternetAddress address) {
    final b = address.rawAddress;
    return b.length == 4 &&
        (b[0] == 10 ||
            (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
            (b[0] == 192 && b[1] == 168) ||
            (b[0] == 169 && b[1] == 254));
  }

  bool _allowed(InternetAddress address) =>
      (isLanAddress(address) && _subnets.any((s) => s.contains(address))) ||
      (discoveryPort == 0 && address.isLoopback);

  bool _isRoutedAddress(InternetAddress address) =>
      (isLanAddress(address) && !address.isLinkLocal) ||
      (discoveryPort == 0 &&
          address.type == InternetAddressType.IPv4 &&
          address.isLoopback);

  _Endpoint? _findEndpoint(String id, [String? address]) {
    for (final endpoint in _endpoints.values) {
      if (endpoint.id == id &&
          !endpoint.routed &&
          endpoint.fresh &&
          _allowed(endpoint.address) &&
          (address == null || endpoint.address.address == address)) {
        return endpoint;
      }
    }
    return null;
  }

  @visibleForTesting
  void receiveAdvertisement(List<int> bytes, InternetAddress source) =>
      _receiveDiscovery(
        Datagram(Uint8List.fromList(bytes), source, discoveryPort),
      );
}

final class _Endpoint {
  _Endpoint(
    this.id,
    this.name,
    this.address,
    this.port,
    this.pairing,
    this.discoveryPort, {
    this.routed = false,
  });
  final String id;
  final String name;
  final InternetAddress address;
  final int port;
  final bool pairing;
  final int discoveryPort;
  final bool routed;
  final DateTime seen = DateTime.now();
  bool get fresh =>
      DateTime.now().difference(seen) <
      (routed ? LanComputerLink._lifetime : const Duration(seconds: 8));
}
