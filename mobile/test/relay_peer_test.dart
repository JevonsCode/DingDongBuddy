import 'dart:async';

import 'package:dingdong_link_protocol/dingdong_link_protocol.dart';
import 'package:dingdong_mobile/link/relay_peer.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Socket implements LinkSocket {
  final StreamController<dynamic> incoming = StreamController<dynamic>();
  final List<String> frames = <String>[];
  bool closed = false;
  @override
  int? closeCode;
  @override
  String? closeReason;
  @override
  Stream<dynamic> get stream => incoming.stream;
  @override
  void add(String frame) => frames.add(frame);
  @override
  Future<void> close([int? code, String? reason]) async {
    closed = true;
    if (!incoming.isClosed) await incoming.close();
  }
}

void main() {
  test(
    'a quiet connection is pinged and replaced when no pong comes',
    () async {
      final List<_Socket> sockets = <_Socket>[];
      final List<LinkState> states = <LinkState>[];
      final RelayPeer peer = RelayPeer(
        pairing: DevicePairingPayload(
          room: 'AbCdEfGhIjKlMnOpQrStUv',
          secret: 'q2v9Jx0rTzM8bW1kLs7nPf4aYc6eHd3uGi5oRj2lKwE',
          hostId: 'host-1',
          hostName: '电脑',
          relayUrl: Uri.parse('https://relay.example'),
        ),
        hello: () => <String, Object?>{'type': 'hello'},
        settings: () => <String, Object?>{},
        onState: states.add,
        onMessage: (_) async {},
        connector: (Uri uri) async {
          final _Socket socket = _Socket();
          sockets.add(socket);
          return socket;
        },
      )..relayHeartbeat = true;
      peer.connect();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Pretend the session reached "connected" with the computer.
      sockets.single.incoming.add('{"type":"relay","event":"ready"}');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(peer.state, LinkState.waiting);

      // Waiting is not connected: no ping yet.
      final DateTime start = DateTime.now();
      peer.tick(start.add(const Duration(minutes: 2)));
      expect(sockets.single.frames, isEmpty);
      await peer.close();
    },
  );

  test('pong keeps a connected socket; silence reconnects', () async {
    final List<_Socket> sockets = <_Socket>[];
    final DateTime base = DateTime.utc(2026, 11, 29);
    DateTime now = base;
    late RelayPeer peer;
    peer = RelayPeer(
      pairing: DevicePairingPayload(
        room: 'AbCdEfGhIjKlMnOpQrStUv',
        secret: 'q2v9Jx0rTzM8bW1kLs7nPf4aYc6eHd3uGi5oRj2lKwE',
        hostId: 'host-1',
        hostName: '电脑',
        relayUrl: Uri.parse('https://relay.example'),
      ),
      hello: () => <String, Object?>{'type': 'hello'},
      settings: () => <String, Object?>{},
      onState: (_) {},
      onMessage: (_) async {},
      connector: (Uri uri) async {
        final _Socket socket = _Socket();
        sockets.add(socket);
        return socket;
      },
      clock: () => now,
    )..relayHeartbeat = true;
    peer.connect();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    peer.debugMarkConnectedForTest();
    final _Socket first = sockets.single;
    first.incoming.add('{"type":"relay","event":"ready"}');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    peer.tick(base.add(const Duration(seconds: 61)));
    expect(first.frames, <String>['ping']);
    now = base.add(const Duration(seconds: 62));
    first.incoming.add('pong');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    peer.tick(base.add(const Duration(seconds: 70)));
    expect(sockets, hasLength(1), reason: 'the pong proved the socket alive');

    peer.tick(base.add(const Duration(seconds: 140)));
    expect(first.frames, <String>['ping', 'ping']);
    peer.tick(base.add(const Duration(seconds: 165)));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(first.closed, isTrue);
    expect(sockets, hasLength(2), reason: 'no pong within 20 s reconnects');
    await peer.close();
  });
}
