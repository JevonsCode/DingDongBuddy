import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/device_link/data/device_link_session.dart';
import 'package:dingdong/features/device_link/data/lan_computer_link.dart';
import 'package:dingdong/features/device_link/data/lan_network_policy.dart';
import 'package:dingdong/features/device_link/data/lan_pairing_crypto.dart';
import 'package:dingdong/features/device_link/data/lan_wire.dart';
import 'package:dingdong/features/device_link/data/secure_message_codec.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'a second instance gets an actionable discovery-port collision error',
    () async {
      final occupied = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: false,
      );
      addTearDown(occupied.close);
      final link = LanComputerLink(discoveryPort: occupied.port)
        ..identity = const LocalDeviceIdentity(
          id: 'busy',
          name: 'Busy fixture',
          platform: 'test',
        );
      addTearDown(link.close);
      await expectLater(link.start(), throwsA(isA<SocketException>()));
      expect(link.error, 'address_in_use');
    },
  );
  test(
    'manual IP discovers and pairs two unpaired computers without multicast',
    () async {
      final host = _service('manual-host');
      addTearDown(host.close);
      await host.beginPairing();
      final peer =
          LanComputerLink.loopbackTest(
              unicastDiscoveryPort: host.discoveryListenPort!,
            )
            ..identity = const LocalDeviceIdentity(
              id: 'manual-peer',
              name: 'Manual fixture peer',
              platform: 'test',
            );
      LinkedDevice? paired;
      peer.onPaired = (value) async {
        paired = value;
      };
      addTearDown(peer.close);
      expect(host.nearby, isEmpty);
      await peer.discoverAddress('127.0.0.1');
      await _until(() => peer.nearby.any((e) => e.id == 'manual-host'));
      await peer.join('manual-host', host.pairingCode!);
      expect(paired?.kind, LinkedDeviceKind.computer);
      expect(paired?.id, 'manual-host');
    },
  );
  test(
    'saved IP bootstraps authenticated LAN sessions without multicast',
    () async {
      final host = _service('hint-host');
      addTearDown(host.close);
      await host.start();
      final peer =
          LanComputerLink.loopbackTest(
              unicastDiscoveryPort: host.discoveryListenPort!,
            )
            ..identity = const LocalDeviceIdentity(
              id: 'hint-peer',
              name: 'Fixture peer',
              platform: 'test',
            )
            ..onPaired = (_) async {};
      addTearDown(peer.close);
      final secret = LanPairingCrypto.token();
      LinkedDevice trusted(String id, String side, {String? address}) =>
          LinkedDevice.fromJson({
            'id': id,
            'name': 'Fixture $id',
            'kind': 'computer',
            'platform': 'test',
            'room': 'hint-room',
            'secret': secret,
            'connectionSide': side,
            'pairedAt': '2026-10-26T00:00:00Z',
            'lanAddress': address,
          });
      final hostSession = host.session(trusted('hint-peer', 'host'));
      final peerSession = peer.session(
        trusted('hint-host', 'peer', address: '127.0.0.1'),
      );
      expect(host.nearby, isEmpty);
      expect(peer.nearby, isEmpty);
      await peerSession.connect();
      await _until(() => hostSession.connected && peerSession.connected);
      expect(await peerSession.verifyLocalNetwork(), isTrue);
      expect(peer.connectedAddressOf('hint-host'), '127.0.0.1');
      final received = hostSession.events
          .where((e) => e is DeviceLinkMessageEvent)
          .first;
      await peerSession.send({
        'type': 'fixture-check',
        'value': 'authenticated',
      });
      expect(
        (await received as DeviceLinkMessageEvent).message['value'],
        'authenticated',
      );
    },
  );

  test(
    'manual addresses must belong to an actual local adapter subnet',
    () async {
      final link =
          LanComputerLink.loopbackTest(
              subnetReader: () async => [
                LanSubnet(InternetAddress('192.168.31.180'), 24),
              ],
            )
            ..identity = const LocalDeviceIdentity(
              id: 'fixture',
              name: 'Fixture',
              platform: 'test',
            );
      addTearDown(link.close);
      expect(
        await link.validateLocalAddress(' 192.168.31.153 '),
        '192.168.31.153',
      );
      expect(link.localAddresses, ['192.168.31.180']);
      for (final invalid in [
        'wrong-ip',
        '8.8.8.8',
        '192.168.1.8',
        '100.64.0.1',
        '192.168.31.0',
        '192.168.31.255',
        '::1',
        '',
      ]) {
        await expectLater(
          link.validateLocalAddress(invalid),
          throwsFormatException,
          reason: invalid,
        );
      }
    },
  );

  test('discovery replies and stays alive without outbound multicast', () async {
    // Real UDP loopback fixtures: no physical multicast interface is selected.
    final remote = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(remote.close);
    final received = <Map>[];
    final subscription = remote.listen((event) {
      if (event != RawSocketEvent.read) return;
      Datagram? packet;
      while ((packet = remote.receive()) != null) {
        received.add(jsonDecode(utf8.decode(packet!.data)) as Map);
      }
    });
    addTearDown(subscription.cancel);
    final link = LanComputerLink.loopbackTest()
      ..identity = const LocalDeviceIdentity(
        id: 'local',
        name: 'local',
        platform: 'test',
      );
    addTearDown(link.close);
    await link.start();
    final advertisement = utf8.encode(
      jsonEncode({
        'protocol': 'dingdong-lan-v1',
        'id': 'remote',
        'name': 'remote',
        'port': 12345,
        'pairing': false,
      }),
    );
    remote.send(
      advertisement,
      InternetAddress.loopbackIPv4,
      link.discoveryListenPort!,
    );
    await _until(() => link.nearby.isNotEmpty);
    await _until(() => received.isNotEmpty);
    expect(received.first, link.advertisement);
    await _until(() => received.length >= 2);
    expect(received.every((packet) => packet['id'] == 'local'), isTrue);
  });

  test(
    'successful adapter refresh clears a previous discovery error',
    () async {
      final link = _service('local');
      addTearDown(link.close);
      await link.start();
      link.error = 'network'; // Explicit transient network-error fixture.
      await link.refresh();
      expect(link.error, isNull);
    },
  );

  test('background reconnects do not flash connecting and offline', () async {
    final pair = await _Pair.create();
    addTearDown(pair.close);
    await pair.host.beginPairing();
    pair.discover();
    await pair.peer.join('host', pair.host.pairingCode!);
    pair.host.session(pair.hostDevice!);
    final session = pair.peer.session(
      pair.peerDevice!.copyWith(secret: LanPairingCrypto.token()),
    );
    final statuses = <DeviceConnectionStatus>[];
    final subscription = session.events.listen((event) {
      if (event is DeviceLinkStatusEvent) statuses.add(event.status);
    });
    addTearDown(subscription.cancel);
    await session.connect();
    await Future<void>.delayed(const Duration(milliseconds: 2300));
    expect(
      statuses.where((status) => status == DeviceConnectionStatus.connecting),
      hasLength(1),
    );
    expect(statuses.last, DeviceConnectionStatus.disconnected);
    await session.connect();
    await Future<void>.delayed(Duration.zero);
    expect(
      statuses.where((status) => status == DeviceConnectionStatus.connecting),
      hasLength(2),
      reason: 'an explicit reconnect still provides feedback',
    );
  });

  if (const bool.fromEnvironment('DINGDONG_LAN_SMOKE')) {
    test(
      'production adapter inventory and multicast listener start locally',
      () async {
        final subnets = await readLanSubnets();
        expect(
          subnets,
          isNotEmpty,
          reason: 'Run this opt-in smoke test on a physical LAN',
        );
        final link = LanComputerLink()
          ..identity = const LocalDeviceIdentity(
            id: 'local-smoke',
            name: 'LAN smoke',
            platform: 'test',
          );
        addTearDown(link.close);
        await link.beginPairing();
        expect(link.pairingCode, matches(r'^\d{6}$'));
        expect(link.error, isNull);
        final local = subnets.first.address;
        link.receiveAdvertisement(
          utf8.encode(
            jsonEncode({...link.advertisement, 'id': 'nearby-smoke'}),
          ),
          local,
        );
        expect(link.nearby.single.id, 'nearby-smoke');
        link.receiveAdvertisement(
          utf8.encode(jsonEncode({...link.advertisement, 'id': 'internet'})),
          InternetAddress('8.8.8.8'),
        );
        expect(link.nearby, hasLength(1));
      },
    );
  }
  test(
    'SRP SHA-256 agrees with an independently calculated Python vector',
    () async {
      final a = BigInt.parse(
        '0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20',
        radix: 16,
      );
      final b = BigInt.parse(
        '2122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f40',
        radix: 16,
      );
      const salt = 'AAECAwQFBgcICQoLDA0ODw==';
      final bPublic = await LanPairingCrypto.serverPublic(salt, '012345', b);
      const expected = 'hDZZXM_EwllXB_30V2mxSrI-yMSdBxtj3jKwj89pcIU=';
      expect(
        await LanPairingCrypto.clientKey(
          salt: salt,
          code: '012345',
          a: a,
          bPublic: bPublic,
        ),
        expected,
      );
      expect(
        await LanPairingCrypto.serverKey(
          salt: salt,
          code: '012345',
          aPublic: LanPairingCrypto.generator.modPow(
            a,
            LanPairingCrypto.modulus,
          ),
          b: b,
          bPublic: bPublic,
        ),
        expected,
      );
    },
  );

  test('startup failures retry without requiring a manual refresh', () async {
    var attempts = 0;
    final link =
        LanComputerLink.loopbackTest(
            subnetReader: () async {
              if (++attempts == 1) {
                throw const SocketException('transient adapter failure');
              }
              return [LanSubnet(InternetAddress.loopbackIPv4, 8)];
            },
          )
          ..identity = const LocalDeviceIdentity(
            id: 'host',
            name: 'host',
            platform: 'test',
          );
    addTearDown(link.close);
    final session = link.session(
      LinkedDevice(
        id: 'peer',
        name: 'peer',
        kind: LinkedDeviceKind.computer,
        platform: 'test',
        room: 'room',
        secret: LanPairingCrypto.token(),
        autoSendClipboard: false,
        receiveAgentNotifications: false,
        vibrationEnabled: false,
        manuallyDisconnected: false,
        pairedAt: DateTime.now(),
      ),
    );
    await session.connect();
    await _until(() => attempts >= 2 && link.advertisement['port'] != null);
    expect(link.error, isNull);
  });

  test(
    'an unreachable advertised adapter does not starve another LAN route',
    () async {
      final pair = await _Pair.create();
      addTearDown(pair.close);
      await pair.host.beginPairing();
      pair.discover();
      await pair.peer.join('host', pair.host.pairingCode!);
      final peer = _service('fresh-peer');
      addTearDown(peer.close);
      peer.identity = pair.peer.identity;
      await peer.start();
      final bad = {...pair.host.advertisement, 'port': 1};
      peer.receiveAdvertisement(
        utf8.encode(jsonEncode(bad)),
        InternetAddress('127.0.0.2'),
      );
      peer.receiveAdvertisement(
        utf8.encode(jsonEncode(pair.host.advertisement)),
        InternetAddress.loopbackIPv4,
      );
      final hostSession = pair.host.session(pair.hostDevice!);
      final session = peer.session(pair.peerDevice!);
      final errors = <Object?>[];
      session.events.listen((e) {
        if (e is DeviceLinkStatusEvent && e.error != null) errors.add(e.error);
      });
      await session.connect();
      await _until(() => session.connected && hostSession.connected);
      expect(session.connected, isTrue, reason: errors.toString());
      expect(hostSession.connected, isTrue);
    },
  );
  test(
    'pairing expires after five minutes even before the maintenance tick',
    () async {
      var now = DateTime.utc(2026, 10, 12);
      final host = LanComputerLink.loopbackTest(now: () => now)
        ..identity = const LocalDeviceIdentity(
          id: 'host',
          name: 'host',
          platform: 'test',
        );
      addTearDown(host.close);
      await host.beginPairing();
      expect(host.pairingCode, isNotNull);
      now = now.add(const Duration(minutes: 5));
      expect(host.pairingCode, isNull);
      expect(host.advertisement['pairing'], isFalse);
    },
  );
  test('adapter prefixes exclude routed private and VPN addresses', () {
    final subnets = parseWindowsLanSubnets(
      '[{"IPAddress":"192.168.31.153","PrefixLength":24}]',
    );
    expect(subnets.single.contains(InternetAddress('192.168.31.154')), isTrue);
    expect(subnets.single.contains(InternetAddress('192.168.32.154')), isFalse);
    expect(subnets.single.contains(InternetAddress('10.2.0.1')), isFalse);
    final mac = parseMacLanSubnets(
      'en0: flags=8863<UP,BROADCAST,RUNNING>\n\tinet 192.168.31.2 netmask 0xffffff00 broadcast 192.168.31.255\nutun0: flags=8051<UP>\n\tinet 10.1.1.1 netmask 0xffffff00\n',
    );
    expect(mac, hasLength(1));
    expect(mac.single.contains(InternetAddress('10.1.1.2')), isFalse);
  });
  test(
    'six digit PAKE agrees, wrong code cannot decrypt server proof',
    () async {
      final a = LanPairingCrypto.privateValue();
      final b = LanPairingCrypto.privateValue();
      final salt = LanPairingCrypto.token(16);
      final bPublic = await LanPairingCrypto.serverPublic(salt, '012345', b);
      final host = await LanPairingCrypto.serverKey(
        salt: salt,
        code: '012345',
        aPublic: LanPairingCrypto.generator.modPow(a, LanPairingCrypto.modulus),
        b: b,
        bPublic: bPublic,
      );
      final peer = await LanPairingCrypto.clientKey(
        salt: salt,
        code: '012345',
        a: a,
        bPublic: bPublic,
      );
      final wrong = await LanPairingCrypto.clientKey(
        salt: salt,
        code: '012346',
        a: a,
        bPublic: bPublic,
      );
      expect(peer, host);
      expect(wrong, isNot(host));
      final sealed = await SecureMessageCodec.fromBase64Url(
        host,
      ).seal({'proof': true});
      await expectLater(
        SecureMessageCodec.fromBase64Url(wrong).open(sealed),
        throwsA(anything),
      );
      for (final invalid in [
        '0',
        '1',
        LanPairingCrypto.modulus.toRadixString(16),
        'z',
        'f' * 513,
      ]) {
        expect(
          () => LanPairingCrypto.readPublic(invalid),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'public, loopback, carrier NAT and IPv6 cannot enter production discovery',
    () {
      for (final address in [
        '8.8.8.8',
        '127.0.0.1',
        '100.126.255.30',
        '0.0.0.0',
        '224.0.0.1',
        '::1',
        '2001:4860:4860::8888',
      ]) {
        expect(
          LanComputerLink.isLanAddress(InternetAddress(address)),
          isFalse,
          reason: address,
        );
      }
      for (final address in [
        '10.0.1.5',
        '172.16.1.5',
        '192.168.31.5',
        '169.254.1.5',
      ]) {
        expect(LanComputerLink.isLanAddress(InternetAddress(address)), isTrue);
      }
    },
  );

  test(
    'discovery never contains the short code or stored pair credentials',
    () async {
      final pair = await _Pair.create();
      addTearDown(pair.close);
      await pair.host.beginPairing();
      final code = pair.host.pairingCode!;
      expect(code, matches(r'^\d{6}$'));
      expect(pair.host.advertisement.keys.toSet(), {
        'protocol',
        'id',
        'name',
        'port',
        'pairing',
      });
      expect(jsonEncode(pair.host.advertisement), isNot(contains(code)));
      expect(pair.host.advertisement['pairing'], isTrue);
      pair.host.cancelPairing();
      expect(pair.host.pairingCode, isNull);
    },
  );

  test(
    'real sockets pair once, exchange encrypted content and reconnect after restart',
    () async {
      final pair = await _Pair.create();
      addTearDown(pair.close);
      await pair.host.beginPairing();
      pair.discover();
      final code = pair.host.pairingCode!;
      await pair.peer.join('host', code);
      expect(pair.host.pairingCode, isNull);
      expect(pair.hostDevice!.secret, pair.peerDevice!.secret);
      expect(pair.hostDevice!.room, pair.peerDevice!.room);
      expect(pair.hostDevice!.relayUrl, isNull);
      expect(
        pair.peerDevice!.transportPreference,
        DeviceLinkTransportPreference.localNetwork,
      );
      expect(pair.peerDevice!.autoSendClipboard, isFalse);
      await expectLater(pair.peer.join('host', code), throwsA(anything));
      final hostSession = pair.host.session(pair.hostDevice!);
      final peerSession = pair.peer.session(pair.peerDevice!);
      final incoming = <Map<String, Object?>>[];
      final subscription = hostSession.events.listen((e) {
        if (e is DeviceLinkMessageEvent) incoming.add(e.message);
      });
      addTearDown(subscription.cancel);
      await peerSession.connect();
      await _until(() => hostSession.connected && peerSession.connected);
      pair.peer.receiveAdvertisement(
        utf8.encode(jsonEncode(pair.host.advertisement)),
        InternetAddress('127.0.0.2'),
      );
      expect(
        await peerSession.verifyLocalNetwork(),
        isTrue,
        reason: 'another NIC must not invalidate the active address',
      );
      await Future.wait(
        List.generate(12, (i) => peerSession.send({'text': '秘密-$i'})),
      );
      await _until(() => incoming.length == 12);
      expect(
        incoming.map((m) => m['text']).toList(),
        List.generate(12, (i) => '秘密-$i'),
      );
      peerSession.updateTransportPreference(
        DeviceLinkTransportPreference.serviceRelay,
      );
      expect(
        peerSession.transportPreference,
        DeviceLinkTransportPreference.localNetwork,
      );
      expect(
        peerSession.activeTransport,
        DeviceLinkActiveTransport.localNetwork,
      );

      // Recreate the host service (new TCP port), then let the peer's periodic
      // discovery/reconnect loop reconnect using persisted credentials alone.
      final oldPort = pair.host.advertisement['port'];
      await pair.host.close();
      await _until(() => !peerSession.connected);
      pair.host = _service('host');
      await pair.host.start();
      pair.host.session(pair.hostDevice!);
      pair.discover();
      expect(pair.host.advertisement['port'], isNot(oldPort));
      await _until(() => peerSession.connected);
      pair.peer.receiveAdvertisement(
        utf8.encode(jsonEncode(pair.host.advertisement)),
        InternetAddress('127.0.0.2'),
      );
      expect(
        await peerSession.verifyLocalNetwork(),
        isTrue,
        reason: 'another NIC must not invalidate the active address',
      );
      expect(pair.host.pairingCode, isNull);
      await peerSession.close();
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      expect(
        peerSession.connected,
        isFalse,
        reason: 'manual close must not reconnect',
      );
    },
  );

  test(
    'five wrong attempts retire code; explicit generation restores pairing',
    () async {
      final pair = await _Pair.create();
      addTearDown(pair.close);
      await pair.host.beginPairing();
      pair.discover();
      final code = pair.host.pairingCode!;
      final wrong = code == '000000' ? '000001' : '000000';
      for (var attempt = 0; attempt < 5; attempt++) {
        await expectLater(pair.peer.join('host', wrong), throwsA(anything));
      }
      expect(pair.host.pairingCode, isNull);
      expect(pair.hostDevice, isNull);
      expect(pair.peerDevice, isNull);
      await pair.host.beginPairing();
      pair.discover();
      await pair.peer.join('host', pair.host.pairingCode!);
      expect(pair.peerDevice, isNotNull);
    },
  );

  test(
    'a saved pair with the wrong secret never establishes a connection',
    () async {
      final pair = await _Pair.create();
      addTearDown(pair.close);
      await pair.host.beginPairing();
      pair.discover();
      await pair.peer.join('host', pair.host.pairingCode!);
      final host = pair.host.session(pair.hostDevice!);
      final peer = pair.peer.session(
        pair.peerDevice!.copyWith(secret: LanPairingCrypto.token()),
      );
      await peer.connect();
      expect(host.connected, isFalse);
      expect(peer.connected, isFalse);
    },
  );

  test(
    'oversized or non-JSON socket frames are rejected before dispatch',
    () async {
      final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(server.close);
      final accepted = server.first;
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        server.port,
      );
      final wire = LanWire(await accepted);
      addTearDown(wire.close);
      addTearDown(socket.destroy);
      final read = wire.read();
      final assertion = expectLater(read, throwsFormatException);
      socket.add(List.filled(LanWire.maximumFrameBytes + 1, 65));
      await socket.flush();
      await assertion;
    },
  );
}

LanComputerLink _service(String id) => LanComputerLink.loopbackTest()
  ..identity = LocalDeviceIdentity(id: id, name: id, platform: 'test')
  ..onPaired = (_) async {};

final class _Pair {
  _Pair(this.host, this.peer);
  LanComputerLink host;
  final LanComputerLink peer;
  LinkedDevice? hostDevice;
  LinkedDevice? peerDevice;
  static Future<_Pair> create() async {
    final result = _Pair(_service('host'), _service('peer'));
    result.host.onPaired = (d) async {
      result.hostDevice = d;
    };
    result.peer.onPaired = (d) async {
      result.peerDevice = d;
    };
    await result.host.start();
    await result.peer.start();
    result.discover();
    return result;
  }

  void discover() {
    host.receiveAdvertisement(
      utf8.encode(jsonEncode(peer.advertisement)),
      InternetAddress.loopbackIPv4,
    );
    peer.receiveAdvertisement(
      utf8.encode(jsonEncode(host.advertisement)),
      InternetAddress.loopbackIPv4,
    );
  }

  Future<void> close() async {
    await host.close();
    await peer.close();
  }
}

Future<void> _until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 6));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Condition did not become true');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
