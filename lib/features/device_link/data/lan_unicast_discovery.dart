import 'dart:async';
import 'dart:io';

/// Dart closes a datagram socket after a send error. Use a separate socket per
/// address so a failed probe cannot close the LAN listener or other probes.
final class LanUnicastDiscovery {
  LanUnicastDiscovery(this._onReply);

  final void Function(Datagram) _onReply;
  final _senders = <InternetAddress, _UnicastSender>{};

  void announce(List<int> bytes, Map<InternetAddress, Set<int>> targets) {
    for (final address in _senders.keys.toList()) {
      if (!targets.containsKey(address)) _senders.remove(address)?.close();
    }
    for (final MapEntry(:key, :value) in targets.entries) {
      final sender = _senders.putIfAbsent(
        key,
        () => _UnicastSender(key, _onReply, _forget),
      );
      unawaited(sender.announce(bytes, value));
    }
  }

  void _forget(_UnicastSender sender) {
    if (identical(_senders[sender.address], sender)) {
      _senders.remove(sender.address);
    }
  }

  void reset() {
    for (final sender in _senders.values) {
      sender.close();
    }
    _senders.clear();
  }
}

final class _UnicastSender {
  _UnicastSender(this.address, this._onReply, this._onFailure);

  final InternetAddress address;
  final void Function(Datagram) _onReply;
  final void Function(_UnicastSender) _onFailure;
  late final _binding = _bind();
  RawDatagramSocket? _socket;
  bool _closed = false;

  Future<RawDatagramSocket?> _bind() async {
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      if (_closed) {
        socket.close();
        return null;
      }
      _socket = socket;
      socket.writeEventsEnabled = false;
      socket.setRawOption(
        RawSocketOption.fromInt(
          RawSocketOption.levelIPv4,
          Platform.isLinux ? 2 : 4, // IP_TTL.
          1,
        ),
      );
      socket.listen(
        (event) {
          if (event != RawSocketEvent.read) return;
          while (!_closed) {
            final packet = socket.receive();
            if (packet == null) break;
            if (packet.address == address) _onReply(packet);
          }
        },
        onError: (Object _) => _failed(),
        onDone: _failed,
      );
      return socket;
    } on SocketException {
      _failed();
      return null;
    }
  }

  Future<void> announce(List<int> bytes, Set<int> ports) async {
    final socket = await _binding;
    if (_closed || socket == null) return;
    try {
      for (final port in ports) {
        if (socket.send(bytes, address, port) == 0) break;
      }
    } on SocketException {
      _failed();
    }
  }

  void _failed() {
    if (_closed) return;
    close();
    _onFailure(this);
  }

  void close() {
    _closed = true;
    _socket?.close();
    _socket = null;
  }
}
