import 'dart:io';

import 'lan_network_policy.dart';

/// Broadcast fallback for macOS adapters with a self-assigned IPv4 address.
/// Each socket is bound to its own adapter and receives unicast replies.
final class LanLinkLocalDiscovery {
  LanLinkLocalDiscovery(this._port, this._onReply, {int? loopbackTestPort})
    // The named test parameter is public while the stored field is private.
    // ignore: prefer_initializing_formals
    : _loopbackTestPort = loopbackTestPort;

  final int _port;
  final int? _loopbackTestPort;
  final void Function(Datagram) _onReply;
  final _sockets = <(InternetAddress, int?), RawDatagramSocket>{};
  static final _broadcast = InternetAddress('169.254.255.255');
  int _generation = 0;

  Future<void> refresh(
    List<NetworkInterface> interfaces,
    List<LanSubnet> subnets,
  ) async {
    if (!Platform.isMacOS && _loopbackTestPort == null) return;
    final generation = ++_generation;
    final linkLocal = {
      for (final subnet in subnets)
        if (subnet.prefix == 16 &&
            subnet.address.type == InternetAddressType.IPv4 &&
            subnet.address.isLinkLocal)
          subnet.address,
    };
    final targets = <(InternetAddress, int?)>{
      if (_loopbackTestPort != null)
        (InternetAddress.loopbackIPv4, null)
      else
        for (final interface in interfaces)
          for (final address in interface.addresses)
            if (linkLocal.contains(address)) (address, interface.index),
    };
    for (final key in _sockets.keys.toList()) {
      if (!targets.contains(key)) _sockets.remove(key)?.close();
    }
    for (final key in targets) {
      if (_sockets.containsKey(key)) continue;
      RawDatagramSocket? socket;
      try {
        final sender = await RawDatagramSocket.bind(key.$1, 0);
        socket = sender;
        if (generation != _generation) {
          sender.close();
          return;
        }
        sender
          ..broadcastEnabled = true
          ..writeEventsEnabled = false;
        sender.setRawOption(
          RawSocketOption.fromInt(
            RawSocketOption.levelIPv4,
            Platform.isLinux ? 2 : 4, // IP_TTL.
            1,
          ),
        );
        final interfaceIndex = key.$2;
        if (interfaceIndex != null) {
          sender.setRawOption(
            RawSocketOption.fromInt(
              RawSocketOption.levelIPv4,
              25, // IP_BOUND_IF on macOS.
              interfaceIndex,
            ),
          );
        }
        sender.listen(
          (event) {
            if (event != RawSocketEvent.read) return;
            while (true) {
              final packet = sender.receive();
              if (packet == null) break;
              if (packet.address.isLinkLocal ||
                  (_loopbackTestPort != null && packet.address.isLoopback)) {
                _onReply(packet);
              }
            }
          },
          onError: (Object _) {
            if (identical(_sockets[key], sender)) _sockets.remove(key);
            sender.close();
          },
        );
        _sockets[key] = sender;
      } on SocketException {
        socket?.close();
        if (generation != _generation) return;
      }
    }
  }

  void announce(List<int> bytes) {
    final testPort = _loopbackTestPort;
    final address = testPort == null
        ? _broadcast
        : InternetAddress.loopbackIPv4;
    for (final sender in _sockets.values) {
      try {
        sender.send(bytes, address, testPort ?? _port);
      } on SocketException {
        // The adapter may have disconnected since the last refresh.
      }
    }
  }

  void reset() {
    _generation++;
    for (final socket in _sockets.values) {
      socket.close();
    }
    _sockets.clear();
  }
}
