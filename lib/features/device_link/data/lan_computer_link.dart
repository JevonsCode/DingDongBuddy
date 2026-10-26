import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/device_link/data/device_link_session.dart';
import 'package:dingdong/features/device_link/data/lan_network_policy.dart';
import 'package:dingdong/features/device_link/data/lan_pairing_crypto.dart';
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
      _now = DateTime.now,
      _readSubnets = readLanSubnets;
  @visibleForTesting
  LanComputerLink.loopbackTest({
    DateTime Function()? now,
    int unicastDiscoveryPort = 45893,
    Future<List<LanSubnet>> Function()? subnetReader,
  }) : discoveryPort = 0,
       // Test-only named parameter; keep runtime port state private.
       // ignore: prefer_initializing_formals
       _unicastDiscoveryPort = unicastDiscoveryPort,
       _now = now ?? DateTime.now,
       _readSubnets =
           subnetReader ??
           (() async => [LanSubnet(InternetAddress.loopbackIPv4, 8)]);
  final int discoveryPort;
  final int _unicastDiscoveryPort;
  @visibleForTesting
  int? get discoveryListenPort => _udp?.port;
  final DateTime Function() _now;
  final Future<List<LanSubnet>> Function() _readSubnets;
  static final _group = InternetAddress('239.255.68.68');
  static const _lifetime = Duration(minutes: 5);
  final Map<String, _Endpoint> _endpoints = {};
  final Map<String, LanComputerSession> _sessions = {};
  final Set<LanWire> _handshakes = {};
  RawDatagramSocket? _udp;
  ServerSocket? _server;
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

  Future<String> validateLocalAddress(String value) async {
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
    if (!_allowedHint(address) ||
        (discoveryPort != 0 &&
            _subnets.any((s) => s.address.address == address.address))) {
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
    _starting = _start();
    try {
      await _starting;
    } finally {
      _starting = null;
    }
  }

  Future<void> _start() async {
    try {
      _server = await ServerSocket.bind(
        discoveryPort == 0
            ? InternetAddress.loopbackIPv4
            : InternetAddress.anyIPv4,
        0,
      );
      _udp = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
      );
      if (_closed) {
        _udp?.close();
        await _server?.close();
        return;
      }
      _udp!
        ..writeEventsEnabled = false
        ..multicastHops = 1
        ..multicastLoopback = false;
      _udp!.setRawOption(
        RawSocketOption.fromInt(
          RawSocketOption.levelIPv4,
          Platform.isLinux ? 2 : 4, // IP_TTL for directed discovery as well.
          1,
        ),
      );
      await _refreshInterfaces();
      _udp!.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          Datagram? packet;
          while ((packet = _udp?.receive()) != null) {
            _receiveDiscovery(packet!);
          }
        },
        onError: (Object _) {
          error = 'network';
          notifyListeners();
        },
      );
      _server!.listen(
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
      error = null;
      _announce();
    } on Object {
      _udp?.close();
      _udp = null;
      await _server?.close();
      _server = null;
      error = 'network';
      notifyListeners();
      rethrow;
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
      rethrow;
    }
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
    error = null;
  }

  Future<void> _tick() async {
    if (_closed || _ticking) return;
    _ticking = true;
    try {
      if (++_ticks % 15 == 0) await _refreshInterfaces();
      if (_code != null && pairingCode == null) cancelPairing();
      _endpoints.removeWhere((_, e) => !e.fresh);
      _announce();
      for (final session in _sessions.values.toList()) {
        if (session.connected && !session._hasLocalPeer) session._drop();
        if (!session.connected) unawaited(session._connect(background: true));
      }
      notifyListeners();
    } on Object {
      error = 'network';
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
    if (socket == null || _server == null || _closed) {
      return;
    }
    final bytes = utf8.encode(jsonEncode(advertisement));
    for (final iface in _interfaces.where((_) => discoveryPort != 0)) {
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
    // A router or adapter can pass multicast in only one direction. Reply to
    // actual discovery senders and keep their view of us fresh across retries.
    // Destinations stay transient, bounded and subject to the same LAN policy.
    final sent = <(String, int)>{};
    for (final endpoint in _endpoints.values) {
      if (!endpoint.fresh ||
          !_allowed(endpoint.address) ||
          endpoint.discoveryPort <= 0 ||
          !sent.add((endpoint.address.address, endpoint.discoveryPort))) {
        continue;
      }
      try {
        socket.send(bytes, endpoint.address, endpoint.discoveryPort);
      } on SocketException {
        // The next discovery tick will retry while the endpoint stays fresh.
      }
    }
    // Bootstrap discovery from a saved IP even when multicast is unavailable.
    // The peer still supplies its current TCP port and proves the original key.
    for (final session in _sessions.values) {
      final hint = InternetAddress.tryParse(session._addressHint ?? '');
      if (hint == null ||
          !_allowedHint(hint) ||
          !sent.add((hint.address, _unicastDiscoveryPort))) {
        continue;
      }
      try {
        socket.send(bytes, hint, _unicastDiscoveryPort);
      } on SocketException {
        // Keep automatic discovery and retry on the next tick.
      }
    }
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

  Future<void> refresh() async {
    final wasRunning = _server != null && _starting == null;
    await start();
    if (wasRunning) await _refreshInterfaces();
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

  Future<LanWire> _dialPeer(String id, {bool pairing = false}) async {
    Object? lastError;
    for (final endpoint
        in _endpoints.values
            .where((e) => e.id == id && e.fresh && (!pairing || e.pairing))
            .take(8)
            .toList()) {
      try {
        return await _dial(endpoint);
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? const SocketException('No reachable LAN address');
  }

  Future<void> join(String id, String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) throw const FormatException('code');
    await start();
    final endpoint = _findEndpoint(id);
    if (endpoint == null || !endpoint.pairing || !endpoint.fresh) {
      throw StateError('not_found');
    }
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
        _device(host, room, secret, DeviceLinkConnectionSide.peer),
      );
    } finally {
      wire.close();
    }
  }

  Future<void> _accept(Socket socket) async {
    // Only peers seen on link-scoped discovery can open a local session.
    if (_closed ||
        !_allowed(socket.remoteAddress) ||
        _handshakes.length >= 8 ||
        !_endpoints.values.any(
          (e) => e.fresh && e.address.address == socket.remoteAddress.address,
        )) {
      socket.destroy();
      return;
    }
    final wire = LanWire(socket);
    _handshakes.add(wire);
    var transferred = false;
    try {
      final request = await wire.read();
      if (request['type'] == 'pair') {
        await _pair(wire, request);
      } else if (request['type'] == 'connect') {
        final session = _sessions[request['room']];
        if (session != null &&
            session.device.connectionSide == DeviceLinkConnectionSide.host &&
            session.device.id == request['id'] &&
            session._hasLocalPeer &&
            _findEndpoint(session.device.id, socket.remoteAddress.address) !=
                null) {
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
    final endpoint = _findEndpoint(peer.id, wire.socket.remoteAddress.address);
    if (endpoint == null ||
        !endpoint.fresh ||
        endpoint.address.address != wire.socket.remoteAddress.address) {
      return;
    }
    cancelPairing(); // Consume atomically before persistence or concurrent proofs.
    final room = LanPairingCrypto.token(18);
    final secret = LanPairingCrypto.token();
    await onPaired(_device(peer, room, secret, DeviceLinkConnectionSide.host));
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
  ) => LinkedDevice(
    id: peer.id,
    name: peer.name,
    kind: LinkedDeviceKind.computer,
    platform: peer.platform,
    room: room,
    secret: secret,
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
    _udp?.close();
    _udp = null;
    await _server?.close();
    _server = null;
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

  _Endpoint? _findEndpoint(String id, [String? address]) {
    for (final endpoint in _endpoints.values) {
      if (endpoint.id == id &&
          endpoint.fresh &&
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
    this.discoveryPort,
  );
  final String id;
  final String name;
  final InternetAddress address;
  final int port;
  final bool pairing;
  final int discoveryPort;
  final DateTime seen = DateTime.now();
  bool get fresh =>
      DateTime.now().difference(seen) < const Duration(seconds: 8);
}
