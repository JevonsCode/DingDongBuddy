import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/device_link/data/device_link_session.dart';
import 'package:dingdong/features/device_link/data/lan_computer_link.dart';
import 'package:dingdong/features/device_link/data/lan_discovery_service.dart';
import 'package:dingdong/features/device_link/data/lan_pairing_crypto.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _Relay relay;
  late LanDiscoveryService discovery;
  setUp(() async {
    relay = _Relay(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    discovery = LanDiscoveryService(relay.base);
  });
  tearDown(() => relay.close());

  test('plaintext discovery endpoints require a local development server', () {
    for (final url in [
      'ws://192.168.1.1',
      'http://example.test',
      'ftp://localhost',
      'https://user@host.test',
    ]) {
      expect(() => LanDiscoveryService(Uri.parse(url)), throwsFormatException);
      expect(LanDiscoveryService.tryCreate(Uri.parse(url)), isNull);
    }
    expect(LanDiscoveryService.tryCreate(null), isNull);
    expect(
      () => LanDiscoveryService(Uri.parse('wss://host.test')),
      returnsNormally,
    );
  });

  test(
    'code-only pairing makes a direct TCP pair and restores legacy records with stale IPs',
    () async {
      LanComputerLink endpoint(String id, {int port = 0}) =>
          LanComputerLink.loopbackTest(
            discoveryBaseUrl: relay.base,
            routedDiscoveryPort: port,
          )..identity = LocalDeviceIdentity(id: id, name: id, platform: 'test');
      final host = endpoint('computer-host');
      addTearDown(host.close);
      late LinkedDevice hostRecord;
      host.onPaired = (device) async => hostRecord = device;
      await host.beginPairing();
      expect(host.codeLookupAvailable, isTrue);
      final peer = endpoint('computer-peer', port: host.routedListenPort!);
      addTearDown(peer.close);
      late LinkedDevice peerRecord;
      peer.onPaired = (device) async => peerRecord = device;
      expect(peer.nearby, isEmpty);
      final code = host.pairingCode!;
      final retired = relay.onLeft.stream.firstWhere((side) => side == 'host');
      await peer.joinByCode(code);
      await retired.timeout(const Duration(seconds: 3));
      expect(relay.releases, ['/v1/discovery/invite-${code.substring(0, 2)}']);
      expect(hostRecord.id, peer.identity.id);
      expect(peerRecord.id, host.identity.id);
      expect(hostRecord.secret, peerRecord.secret);
      expect(hostRecord.lanRouted && peerRecord.lanRouted, isTrue);
      expect(host.pairingCode, isNull);
      await host.close();
      await peer.close();

      // Legacy same-subnet records do not grant permission to dial a routed hint.
      // Only fresh, authenticated candidate exchange can reconnect these records.
      LinkedDevice legacy(LinkedDevice saved) => LinkedDevice.fromJson({
        ...saved.toJson()..remove('lanRouted'),
        'lanAddress': '127.0.0.2',
      });
      final restoredHost = endpoint('computer-host');
      addTearDown(restoredHost.close);
      await restoredHost.start();
      final restoredPeer = endpoint(
        'computer-peer',
        port: restoredHost.routedListenPort!,
      );
      addTearDown(restoredPeer.close);
      final hostSession = restoredHost.session(legacy(hostRecord));
      final peerSession = restoredPeer.session(legacy(peerRecord));
      final ready = peerSession.events.firstWhere(
        (event) =>
            event is DeviceLinkStatusEvent &&
            event.status == DeviceConnectionStatus.connected,
      );
      await Future.wait([hostSession.connect(), peerSession.connect()]);
      await ready.timeout(const Duration(seconds: 10));
      expect(hostSession.connected, isTrue);
      expect(restoredPeer.nearby, isEmpty);
      expect(await peerSession.verifyLocalNetwork(), isFalse);
      final received = hostSession.events
          .where((event) => event is DeviceLinkMessageEvent)
          .first;
      await peerSession.send({'value': 'direct payload'});
      expect(
        ((await received) as DeviceLinkMessageEvent).message['value'],
        'direct payload',
      );
      expect(relay.frames.map((frame) => frame['type']).toSet(), {
        'hello',
        'challenge',
        'proof',
        'offer',
        'who',
        'addresses',
      });
    },
  );

  test(
    'four failed admissions leave the fifth correct guess usable for direct pairing',
    () async {
      final host =
          LanComputerLink.loopbackTest(
              discoveryBaseUrl: relay.base,
              routedDiscoveryPort: 0,
            )
            ..identity = const LocalDeviceIdentity(
              id: 'host',
              name: 'host',
              platform: 'test',
            )
            ..onPaired = (_) async {};
      addTearDown(host.close);
      await host.beginPairing();
      final code = host.pairingCode!;
      final wrong =
          code.substring(0, 2) + (code.endsWith('1111') ? '0000' : '1111');
      for (var i = 0; i < 4; i++) {
        final proof = relay.onFrame.stream.firstWhere(
          (frame) => frame['type'] == 'proof',
        );
        final left = relay.onLeft.stream.firstWhere((role) => role == 'peer');
        final lookup = discovery.lookupInvite(wrong);
        await proof;
        lookup.close();
        await left;
        await expectLater(lookup.result, throwsA(isA<SocketException>()));
      }
      final peer =
          LanComputerLink.loopbackTest(
              discoveryBaseUrl: relay.base,
              routedDiscoveryPort: host.routedListenPort!,
            )
            ..identity = const LocalDeviceIdentity(
              id: 'peer',
              name: 'peer',
              platform: 'test',
            );
      addTearDown(peer.close);
      LinkedDevice? paired;
      peer.onPaired = (device) async => paired = device;
      await peer.joinByCode(code);
      expect(paired?.id, 'host');
      expect(host.pairingCode, isNull);
    },
  );

  test(
    'unverified departures consume the displayed invitation without releasing its service lease',
    () async {
      final host =
          LanComputerLink.loopbackTest(
              discoveryBaseUrl: relay.base,
              routedDiscoveryPort: 0,
            )
            ..identity = const LocalDeviceIdentity(
              id: 'host',
              name: 'host',
              platform: 'test',
            );
      addTearDown(host.close);
      await host.beginPairing();
      final prefix = host.pairingCode!.substring(0, 2);
      final uri = relay.base.replace(
        scheme: 'ws',
        path: '/v1/discovery/invite-$prefix',
        queryParameters: {'side': 'peer'},
      );
      final retired = relay.onLeft.stream.firstWhere((side) => side == 'host');
      for (var i = 0; i < 5; i++) {
        final peer = await WebSocket.connect(uri.toString());
        final left = relay.onLeft.stream.firstWhere((side) => side == 'peer');
        await peer.close();
        await left;
      }
      await retired.timeout(const Duration(seconds: 3));
      expect(host.pairingCode, isNull);
      expect(relay.releases, isEmpty);
      expect(relay.leases, contains(uri.path));
    },
  );

  test(
    'a successful invitation reveals only its prefix and opaque handshake on the service',
    () async {
      final host = discovery.hostInvite(
        code: '038491',
        hostId: 'desktop-host',
        addresses: () => [
          'computer.example',
          '8.8.8.8',
          '100.64.1.1',
          '169.254.0.1',
          '127.0.0.1',
          '10.0.0.1',
          '10.0.0.1',
          for (var i = 2; i <= 10; i++) '10.0.0.$i',
        ],
      );
      addTearDown(host.close);
      await host.ready;
      final lookup = discovery.lookupInvite('038491');
      addTearDown(lookup.close);
      final result = await lookup.result;
      expect(result.hostId, 'desktop-host');
      expect(result.addresses, [for (var i = 1; i <= 8; i++) '10.0.0.$i']);
      expect(relay.paths.toSet(), {'/v1/discovery/invite-03'});
      expect(relay.frames.map((frame) => frame.keys.toSet()), [
        {'type', 'a'},
        {'type', 'b', 'salt'},
        {'type', 'box'},
        {'type', 'box'},
      ]);
      expect(relay.frames.map((frame) => frame['type']), [
        'hello',
        'challenge',
        'proof',
        'offer',
      ]);
      expect(jsonEncode(relay.frames), isNot(contains('desktop-host')));
      expect(jsonEncode(relay.frames), isNot(contains('10.0.0.')));
    },
  );

  test(
    'HTTP conflict has a distinct result when reserving a public prefix',
    () async {
      final host = discovery.hostInvite(
        code: '908491',
        hostId: 'first',
        addresses: () => [],
      );
      addTearDown(host.close);
      await host.ready;
      final duplicate = discovery.hostInvite(
        code: '900001',
        hostId: 'second',
        addresses: () => [],
      );
      await expectLater(
        duplicate.ready,
        throwsA(isA<LanDiscoverySlotOccupied>()),
      );
      await duplicate.done;
    },
  );

  test(
    'an established host can release a nameplate once, while a disconnect preserves the reservation',
    () async {
      LanDiscoveryChannel host() => discovery.hostInvite(
        code: '170001',
        hostId: 'host',
        addresses: () => [],
      );
      final first = host();
      await first.ready;
      final collision = host();
      await expectLater(
        collision.ready,
        throwsA(isA<LanDiscoverySlotOccupied>()),
      );
      collision.releaseInvite();
      expect(relay.releases, isEmpty);
      first.releaseInvite();
      first.releaseInvite();
      await first.done;
      expect(relay.releases, ['/v1/discovery/invite-17']);
      final second = host();
      await second.ready;
      final left = relay.onLeft.stream.firstWhere((side) => side == 'host');
      second.close();
      await left;
      second.releaseInvite();
      final offline = host();
      await expectLater(
        offline.ready,
        throwsA(isA<LanDiscoverySlotOccupied>()),
      );
      expect(relay.releases, hasLength(1));
      final lookup = discovery.lookupInvite('170001');
      await expectLater(lookup.result, throwsA(isA<SocketException>()));
    },
  );

  test(
    'a different password in the same prefix never obtains an offer',
    () async {
      var addressReads = 0;
      var failed = 0;
      var verified = 0;
      final host = discovery.hostInvite(
        onUnverifiedAttemptFinished: () => failed++,
        onProofVerified: () => verified++,
        code: '038491',
        hostId: 'desktop',
        addresses: () {
          addressReads++;
          return ['10.0.0.1'];
        },
      );
      addTearDown(host.close);
      await host.ready;
      final proof = relay.onFrame.stream.firstWhere(
        (frame) => frame['type'] == 'proof',
      );
      final left = relay.onLeft.stream.firstWhere((side) => side == 'peer');
      final lookup = discovery.lookupInvite('030000');
      await proof;
      lookup.close();
      await left;
      await expectLater(lookup.result, throwsA(isA<SocketException>()));
      final correct = discovery.lookupInvite('038491');
      addTearDown(correct.close);
      expect((await correct.result).hostId, 'desktop');
      host.close();
      expect(addressReads, 1);
      expect(failed, 1);
      expect(verified, 1);
      expect(
        relay.frames.where((frame) => frame['type'] == 'offer'),
        hasLength(1),
      );
    },
  );

  test(
    'closing and reopening a host keeps the invitation attempt budget',
    () async {
      final budget = LanDiscoveryInviteBudget();
      LanDiscoveryChannel host() => discovery.hostInvite(
        code: '101111',
        hostId: 'host-device',
        addresses: () => ['10.0.0.1'],
        budget: budget,
      );
      for (var i = 0; i < 5; i++) {
        final channel = host();
        await channel.ready;
        final lookup = discovery.lookupInvite('101111');
        expect((await lookup.result).hostId, 'host-device');
        final left = relay.onLeft.stream.firstWhere((side) => side == 'host');
        channel.releaseInvite();
        await left;
      }
      expect(budget.exhausted, isTrue);
      final channel = host();
      await expectLater(channel.ready, throwsA(isA<SocketException>()));
      expect(relay.paths, hasLength(10));
    },
  );

  test(
    'paired addresses update in both directions after an adapter changes',
    () async {
      final secret = LanPairingCrypto.token();
      var hostAddress = '10.20.0.5';
      final seenByHost = StreamController<List<String>>.broadcast();
      final seenByPeer = StreamController<List<String>>.broadcast();
      addTearDown(seenByHost.close);
      addTearDown(seenByPeer.close);
      final initialHost = seenByHost.stream.first;
      final initialPeer = seenByPeer.stream.first;
      final host = discovery.watchPair(
        secret: secret,
        localId: 'host-device',
        peerId: 'peer-device',
        addresses: () => [hostAddress],
        onAddresses: seenByHost.add,
      );
      final peer = discovery.watchPair(
        secret: secret,
        localId: 'peer-device',
        peerId: 'host-device',
        addresses: () => ['10.20.0.2'],
        onAddresses: seenByPeer.add,
      );
      addTearDown(host.close);
      addTearDown(peer.close);
      expect(await initialHost, ['10.20.0.2']);
      expect(await initialPeer, ['10.20.0.5']);
      hostAddress = '10.30.0.3';
      final updated = seenByPeer.stream.first;
      host.refresh();
      expect(await updated, [hostAddress]);
      expect(relay.paths.toSet(), hasLength(1));
      expect(
        relay.paths.first,
        matches(r'^/v1/discovery/pair-[A-Za-z0-9_-]{43}$'),
      );
      expect(relay.paths.first, isNot(contains(secret)));
      final observed = jsonEncode(relay.frames);
      expect(observed, isNot(contains('device')));
      expect(observed, isNot(contains('10.20.')));
      expect(observed, isNot(contains('10.30.')));
      expect(relay.frames.map((frame) => frame['type']).toSet(), {
        'who',
        'addresses',
      });
    },
  );

  test(
    'cancelling a paired connection before asynchronous key derivation skips its upgrade',
    () async {
      final channel = discovery.watchPair(
        secret: LanPairingCrypto.token(),
        localId: 'a',
        peerId: 'b',
        addresses: () => [],
        onAddresses: (_) => fail('closed channel received addresses'),
      );
      channel.close();
      await channel.done;
      await expectLater(channel.ready, throwsA(isA<SocketException>()));
      expect(relay.paths, isEmpty);
    },
  );
}

/// A loopback WebSocket forwarder with the same join/leave events as the
/// deployed service. It deliberately imposes no password-attempt limit.
final class _Relay {
  _Relay(this.server) {
    server.listen((request) {
      final handler = _accept(request);
      handlers.add(handler);
      unawaited(handler.whenComplete(() => handlers.remove(handler)));
    });
  }
  final HttpServer server;
  bool closing = false;
  final handlers = <Future<void>>{};
  Uri get base => Uri.parse('http://127.0.0.1:${server.port}');
  final rooms = <String, Map<String, WebSocket>>{};
  final leases = <String>{};
  final releases = <String>[];
  final paths = <String>[];
  final frames = <Map<String, dynamic>>[];
  final onFrame = StreamController<Map<String, dynamic>>.broadcast();
  final onLeft = StreamController<String>.broadcast();

  Future<void> _accept(HttpRequest request) async {
    final path = request.uri.path;
    paths.add(path);
    final side = request.uri.queryParameters['side']!;
    final other = side == 'host' ? 'peer' : 'host';
    final room = rooms.putIfAbsent(path, () => {});
    final invite = path.contains('/invite-');
    if (room.containsKey(side) ||
        (invite && side == 'host' && !leases.add(path))) {
      request.response.statusCode = 409;
      await request.response.close();
      return;
    }
    if (invite && side == 'peer' && room['host'] == null) {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    room[side] = socket;
    void notify(WebSocket dest, String event) {
      if (!closing && dest.readyState == WebSocket.open) {
        dest.add(jsonEncode({'type': 'relay', 'event': event}));
      }
    }

    notify(socket, 'ready');
    final partner = room[other];
    if (partner != null) {
      notify(socket, '${other}_joined');
      notify(partner, '${side}_joined');
    }
    await for (final raw in socket) {
      final frame = jsonDecode(raw as String) as Map<String, dynamic>;
      if (frame['type'] == 'release' &&
          side == 'host' &&
          invite &&
          identical(socket, room[side])) {
        releases.add(path);
        leases.remove(path);
        final sockets = room.values.toList();
        room.clear();
        for (final active in sockets) {
          await active.close(1000, 'Invitation released');
        }
        break;
      }
      frames.add(frame);
      room[other]?.add(raw);
      onFrame.add(frame);
    }
    if (identical(room[side], socket)) {
      room.remove(side);
      final remaining = room[other];
      if (remaining != null) notify(remaining, '${side}_left');
    }
    onLeft.add(side);
  }

  Future<void> close() async {
    closing = true;
    for (final room in rooms.values) {
      for (final socket in room.values.toList()) {
        await socket.close();
      }
    }
    await server.close(force: true);
    await Future.wait(handlers.toList());
    await onLeft.close();
    await onFrame.close();
  }
}
