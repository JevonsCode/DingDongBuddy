import 'dart:convert';

import 'package:dingdong_link_protocol/dingdong_link_protocol.dart';
import 'package:test/test.dart';

// Produced by the PWA's own docs/app/app-codecs.js (WebCrypto), so these pin
// wire compatibility between the browser, the desktop and the Android app.
const String _secret = 'q2v9Jx0rTzM8bW1kLs7nPf4aYc6eHd3uGi5oRj2lKwE';
const String _pwaEnvelope =
    '0e93Tv4XtS2Q3Xbpoa6ztZLvNKQg18Up8WFPN0DauFzGe67pNiNTFl1SHPtomVcgvGbOVLlEBM38GSNenKmLuJS15Vbun6etd0d5hciRbWoVWCLvEAa3rCdCLMs8GPdU5bjb-gBDJ234NNd69ti7adZt7zKp0MHkR6Lkvy_K4nhX_ujzp8adDRSYP9f9wy0J';
// The PWA-era test host wrote `version`; the desktop writes `v`.
const String _versionFragment =
    'eyJ2ZXJzaW9uIjoxLCJyb29tIjoiQWJDZEVmR2hJaktsTW5PcFFyU3RVdiIsInNlY3JldCI6InEydjlKeDByVHpNOGJXMWtMczduUGY0YVljNmVIZDN1R2k1b1JqMmxLd0UiLCJyZWxheSI6Imh0dHBzOi8vZGluZ2RvbmcueG4tLW04dHh1LmNvbSIsImhvc3RJZCI6Imhvc3QtMSIsImhvc3ROYW1lIjoi5bel5L2c55S16ISRIn0';

void main() {
  test('opens an envelope sealed by the PWA', () async {
    final Map<String, Object?> message = await SecureMessageCodec.fromBase64Url(
      _secret,
    ).open(_pwaEnvelope);
    expect(message['type'], 'agent.completed');
    expect(message['notificationKind'], 'attention');
    expect(message['silent'], isTrue);
  });

  test('sealed envelopes round-trip', () async {
    final SecureMessageCodec codec = SecureMessageCodec.fromBase64Url(_secret);
    final String sealed = await codec.seal(<String, Object?>{'name': '小米'});
    expect((await codec.open(sealed))['name'], '小米');
  });

  test('parses the desktop QR link and the legacy version key', () {
    final DevicePairingPayload desktop = DevicePairingPayload(
      room: 'AbCdEfGhIjKlMnOpQrStUv',
      secret: _secret,
      hostId: 'host-1',
      hostName: '工作电脑',
      relayUrl: Uri.parse('https://dingdong.xn--m8txu.com'),
    );
    final DevicePairingPayload parsed = DevicePairingPayload.parseInput(
      'https://dingdong.xn--m8txu.com/app/#pair=${desktop.encode()}',
    );
    expect(parsed.room, desktop.room);
    expect(parsed.hostName, '工作电脑');
    expect(
      DevicePairingPayload.parseInput('#pair=$_versionFragment').hostName,
      '工作电脑',
    );
  });

  test('rejects damaged pairing links', () {
    expect(
      () => DevicePairingPayload.parseInput('https://example.com/app/'),
      throwsFormatException,
    );
    final String shortSecret = base64Url
        .encode(
          utf8.encode(
            jsonEncode(<String, Object?>{
              'v': 1,
              'room': 'AbCdEfGhIjKlMnOpQrStUv',
              'secret': 'short',
              'hostId': 'h',
              'hostName': 'n',
              'relay': 'https://relay.example',
            }),
          ),
        )
        .replaceAll('=', '');
    expect(
      () => DevicePairingPayload.parseInput('#pair=$shortSecret'),
      throwsFormatException,
    );
  });

  test('relay frames enforce the UTF-8 byte limit', () {
    expect(
      () => encodeDeviceLinkRelayFrame(
        type: 'data',
        envelope: '字' * 100,
        maximumBytes: 200,
      ),
      throwsA(isA<DeviceLinkFrameTooLargeException>()),
    );
  });

  test('builds the peer socket URI and recognises replacement', () {
    final Uri socket = deviceLinkRelaySocketUri(
      Uri.parse('https://dingdong.xn--m8txu.com'),
      'room_1234567890123456789',
      'peer',
    );
    expect(socket.scheme, 'wss');
    expect(socket.host, 'dingdong.xn--m8txu.com');
    expect(socket.path, '/v1/rooms/room_1234567890123456789');
    expect(socket.queryParameters, <String, String>{'side': 'peer'});
    expect(
      deviceLinkConnectionWasReplaced(1008, 'Replaced by a newer connection'),
      isTrue,
    );
    expect(deviceLinkConnectionWasReplaced(1000, null), isFalse);
  });
}
