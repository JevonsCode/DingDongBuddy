import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/device_link/data/device_link_session.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:window_manager/window_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native peers deliver encrypted content through relay and WebRTC routes',
    (WidgetTester tester) async {
      await windowManager.ensureInitialized();
      await windowManager.show();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Text('Device transport acceptance (test data)')),
        ),
      );

      // The relay is an explicit local fixture. Production session code,
      // encryption, sockets and native WebRTC data channels are real.
      final _LocalRelay relay = await _LocalRelay.start();
      final String secret = base64UrlEncode(
        List<int>.generate(32, (i) => i + 11),
      );
      final WebRtcDeviceLinkSession host = WebRtcDeviceLinkSession(
        relayUrl: relay.url,
        room: 'release-acceptance-native-room',
        secret: secret,
        transportPreference: DeviceLinkTransportPreference.serviceRelay,
      );
      final WebRtcDeviceLinkSession peer = WebRtcDeviceLinkSession(
        relayUrl: relay.url,
        room: 'release-acceptance-native-room',
        secret: secret,
        side: DeviceLinkConnectionSide.peer,
        transportPreference: DeviceLinkTransportPreference.serviceRelay,
      );
      final List<Map<String, Object?>> receivedByHost =
          <Map<String, Object?>>[];
      final List<Map<String, Object?>> receivedByPeer =
          <Map<String, Object?>>[];
      final List<Object> failures = <Object>[];
      final List<StreamSubscription<DeviceLinkSessionEvent>> subscriptions = [
        for (final (session, messages) in [
          (host, receivedByHost),
          (peer, receivedByPeer),
        ])
          session.events.listen((event) {
            if (event is DeviceLinkMessageEvent) messages.add(event.message);
            if (event is DeviceLinkStatusEvent && event.error != null) {
              failures.add(event.error!);
            }
          }),
      ];
      addTearDown(() async {
        await Future.wait([host.close(), peer.close()]);
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        await relay.close();
      });

      await host.connect();
      await peer.connect();
      await _until(tester, () => host.connected && peer.connected, failures);
      expect(host.activeTransport, DeviceLinkActiveTransport.serviceRelay);
      await host.send(<String, Object?>{
        'type': 'clipboard.create',
        'content': 'Relay transport test fixture',
      });
      await _until(tester, () => receivedByPeer.length == 1, failures);
      expect(receivedByPeer.single['content'], 'Relay transport test fixture');
      expect(
        relay.frames.any((frame) => frame.contains('Relay transport test')),
        isFalse,
      );

      peer.updateTransportPreference(DeviceLinkTransportPreference.automatic);
      host.updateTransportPreference(DeviceLinkTransportPreference.automatic);
      await _until(
        tester,
        () =>
            host.activeTransport == DeviceLinkActiveTransport.localNetwork &&
            peer.activeTransport == DeviceLinkActiveTransport.localNetwork,
        failures,
      );
      await peer.send(<String, Object?>{
        'type': 'clipboard.create',
        'content': 'Native data channel test fixture',
      });
      await _until(tester, () => receivedByHost.length == 1, failures);
      expect(
        receivedByHost.single['content'],
        'Native data channel test fixture',
      );
      expect(
        relay.frames.any((frame) => frame.contains('Native data channel')),
        isFalse,
      );

      host.updateTransportPreference(
        DeviceLinkTransportPreference.localNetwork,
      );
      peer.updateTransportPreference(
        DeviceLinkTransportPreference.serviceRelay,
      );
      await _until(tester, () => !host.connected, failures);
      await expectLater(
        host.send(<String, Object?>{
          'type': 'clipboard.create',
          'content': 'Must not silently fall back in LAN-only mode',
        }),
        throwsStateError,
      );
      expect(receivedByPeer, hasLength(1));

      host.updateTransportPreference(DeviceLinkTransportPreference.automatic);
      await _until(tester, () => host.connected && peer.connected, failures);
      expect(host.activeTransport, DeviceLinkActiveTransport.serviceRelay);
      await host.send(<String, Object?>{
        'type': 'clipboard.create',
        'content': 'Explicit automatic fallback test fixture',
      });
      await _until(tester, () => receivedByPeer.length == 2, failures);
      expect(
        receivedByPeer.last['content'],
        'Explicit automatic fallback test fixture',
      );
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _until(
  WidgetTester tester,
  bool Function() ready,
  List<Object> errors,
) async {
  for (int attempt = 0; attempt < 200 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(ready(), isTrue, reason: 'Native transport failed to settle: $errors');
}

final class _LocalRelay {
  _LocalRelay(this.server);

  final HttpServer server;
  final Map<String, WebSocket> sockets = <String, WebSocket>{};
  final List<String> frames = <String>[];
  bool closed = false;

  Uri get url => Uri.parse('http://127.0.0.1:${server.port}');

  static Future<_LocalRelay> start() async {
    final relay = _LocalRelay(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    relay.server.listen(relay.accept);
    return relay;
  }

  Future<void> accept(HttpRequest request) async {
    final String side = request.uri.queryParameters['side'] ?? 'host';
    final String other = side == 'host' ? 'peer' : 'host';
    final WebSocket socket = await WebSocketTransformer.upgrade(request);
    sockets[side] = socket;
    if (sockets[other] case final WebSocket counterpart) {
      counterpart.add(jsonEncode({'type': 'relay', 'event': '${side}_joined'}));
      socket.add(jsonEncode({'type': 'relay', 'event': '${other}_joined'}));
    }
    socket.listen(
      (Object? frame) {
        if (closed || frame is! String) return;
        frames.add(frame);
        sockets[other]?.add(frame);
      },
      onDone: () {
        if (closed) return;
        sockets.remove(side);
        sockets[other]?.add(
          jsonEncode({'type': 'relay', 'event': '${side}_left'}),
        );
      },
    );
  }

  Future<void> close() async {
    closed = true;
    for (final socket in sockets.values.toList()) {
      await socket.close();
    }
    await server.close(force: true);
  }
}
