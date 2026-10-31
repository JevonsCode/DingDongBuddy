import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dingdong_link_protocol/dingdong_link_protocol.dart';
import 'package:flutter/foundation.dart' show debugPrint;

enum LinkState {
  connecting,
  waiting,
  connected,
  offline,
  replaced,
  disconnected,
}

/// Minimal socket surface so the peer can be driven by a fake in tests.
abstract interface class LinkSocket {
  Stream<dynamic> get stream;
  void add(String frame);
  Future<void> close([int? code, String? reason]);
  int? get closeCode;
  String? get closeReason;
}

typedef LinkSocketConnector = Future<LinkSocket> Function(Uri uri);

Future<LinkSocket> connectIoSocket(Uri uri) async {
  final WebSocket socket = await WebSocket.connect(
    uri.toString(),
  ).timeout(const Duration(seconds: 15));
  // Keeps NAT and Cloudflare idle timers from silently dropping the socket
  // and makes a dead connection fail within roughly two intervals.
  socket.pingInterval = const Duration(seconds: 25);
  return _IoLinkSocket(socket);
}

final class _IoLinkSocket implements LinkSocket {
  _IoLinkSocket(this._socket);
  final WebSocket _socket;
  @override
  Stream<dynamic> get stream => _socket;
  @override
  void add(String frame) => _socket.add(frame);
  @override
  Future<void> close([int? code, String? reason]) =>
      _socket.close(code, reason);
  @override
  int? get closeCode => _socket.closeCode;
  @override
  String? get closeReason => _socket.closeReason;
}

/// One encrypted relay session with a paired computer, joining as the `peer`
/// side like the PWA (docs/app/app-connection.js). It never answers WebRTC
/// offers; after `welcome` it asks the desktop to keep this device on the
/// relay so the desktop stops offering a data channel.
final class RelayPeer {
  RelayPeer({
    required this.pairing,
    required this._hello,
    required this._settings,
    required this._onState,
    required this._onMessage,
    this._connector = connectIoSocket,
    Duration initialRetry = const Duration(seconds: 1),
    this._maximumRetry = const Duration(seconds: 30),
  }) : _initialRetry = initialRetry,
       _retry = initialRetry,
       _codec = SecureMessageCodec.fromBase64Url(pairing.secret);

  final DevicePairingPayload pairing;
  final Map<String, Object?> Function() _hello;
  final Map<String, Object?> Function() _settings;
  final void Function(LinkState state) _onState;
  final Future<void> Function(Map<String, Object?> message) _onMessage;
  final LinkSocketConnector _connector;
  final Duration _initialRetry;
  final Duration _maximumRetry;
  final SecureMessageCodec _codec;

  LinkSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retryTimer;
  Duration _retry;
  int _generation = 0;
  bool _closed = false;
  bool _helloSent = false;
  Future<void> _inbound = Future<void>.value();
  LinkState _state = LinkState.offline;

  LinkState get state => _state;
  bool get isConnected => _state == LinkState.connected;

  void connect() {
    if (_closed || _socket != null || _state == LinkState.connecting) return;
    _retryTimer?.cancel();
    unawaited(_open());
  }

  /// Retries immediately, e.g. when the user taps "重新连接".
  void nudge() {
    if (_closed) return;
    if (_state == LinkState.replaced || _state == LinkState.offline) {
      _retry = _initialRetry;
      _retryTimer?.cancel();
      _setState(LinkState.offline);
      connect();
    }
  }

  /// The network came back: skip the remaining backoff. A replaced session
  /// still waits for the user.
  void networkAvailable() {
    if (_closed || _state != LinkState.offline) return;
    _retry = _initialRetry;
    _retryTimer?.cancel();
    connect();
  }

  Future<void> close({LinkState finalState = LinkState.disconnected}) async {
    _closed = true;
    _generation += 1;
    _retryTimer?.cancel();
    await _subscription?.cancel();
    final LinkSocket? socket = _socket;
    _socket = null;
    await socket?.close(1000, 'Companion closed');
    _setState(finalState);
  }

  Future<void> send(Map<String, Object?> message) async {
    final LinkSocket? socket = _socket;
    if (socket == null ||
        (_state != LinkState.connected && message['type'] != 'hello')) {
      throw StateError('电脑当前不在线');
    }
    final String frame = encodeDeviceLinkRelayFrame(
      type: 'data',
      envelope: await _codec.seal(message),
    );
    if (!identical(socket, _socket)) throw StateError('连接已经变化，请重试');
    socket.add(frame);
  }

  Future<void> _open() async {
    final int generation = ++_generation;
    _helloSent = false;
    _setState(LinkState.connecting);
    final LinkSocket socket;
    try {
      socket = await _connector(
        deviceLinkRelaySocketUri(pairing.relayUrl, pairing.room, 'peer'),
      );
    } on Object {
      if (generation == _generation && !_closed) _scheduleRetry();
      return;
    }
    if (generation != _generation || _closed) {
      await socket.close(1000, 'Superseded');
      return;
    }
    _socket = socket;
    _subscription = socket.stream.listen(
      (dynamic data) {
        if (data is! String) return;
        _inbound = _inbound
            .then((_) => _handleFrame(data, generation))
            .catchError((Object error) => _log('frame failed: $error'));
      },
      onDone: () => _ended(generation, socket),
      onError: (Object _) => _ended(generation, socket),
      cancelOnError: true,
    );
  }

  void _ended(int generation, LinkSocket socket) {
    if (generation != _generation || _closed) return;
    _socket = null;
    _subscription = null;
    _helloSent = false;
    if (deviceLinkConnectionWasReplaced(socket.closeCode, socket.closeReason)) {
      // Another client took this room's peer side; reconnecting would start
      // a replacement loop, so wait for the user.
      _setState(LinkState.replaced);
      return;
    }
    _scheduleRetry();
  }

  void _scheduleRetry() {
    _setState(LinkState.offline);
    final Duration delay = _retry;
    _retry = Duration(
      milliseconds: min(
        _maximumRetry.inMilliseconds,
        (_retry.inMilliseconds * 1.7).round(),
      ),
    );
    _retryTimer = Timer(delay, () {
      if (!_closed && _socket == null) unawaited(_open());
    });
  }

  Future<void> _handleFrame(String raw, int generation) async {
    if (generation != _generation) return;
    if (utf8.encode(raw).length > deviceLinkMaximumRelayFrameBytes) return;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return;
    }
    if (decoded is! Map) return;
    final Object? type = decoded['type'];
    if (type == 'relay') {
      _log('relay event ${decoded['event']}');
      switch (decoded['event']) {
        case 'ready':
          if (_state == LinkState.connecting) _setState(LinkState.waiting);
        case 'host_joined':
          _retry = _initialRetry;
          await _sendHello();
        case 'host_left':
          _helloSent = false;
          _setState(LinkState.waiting);
      }
      return;
    }
    // "signal" frames carry WebRTC offers; the companion stays on the relay.
    if (type != 'data' || decoded['payload'] is! String) return;
    final Map<String, Object?> message;
    try {
      message = await _codec.open(decoded['payload']! as String);
    } on Object catch (error) {
      _log('dropped an envelope that did not decrypt: ${error.runtimeType}');
      return;
    }
    if (generation != _generation) return;
    if (message['type'] == 'welcome') {
      _setState(LinkState.connected);
      await send(<String, Object?>{
        'type': 'settings.update',
        ..._settings(),
        'transportPreference': 'serviceRelay',
      });
    }
    await _onMessage(message);
  }

  Future<void> _sendHello() async {
    if (_helloSent) return;
    _helloSent = true;
    try {
      await send(_hello());
    } on Object {
      _helloSent = false;
    }
  }

  void _log(String text) =>
      debugPrint('DingDongRelay[${pairing.hostName}] $text');

  void _setState(LinkState next) {
    if (_state == next) return;
    _log('${_state.name} -> ${next.name} (generation $_generation)');
    _state = next;
    _onState(next);
  }
}
