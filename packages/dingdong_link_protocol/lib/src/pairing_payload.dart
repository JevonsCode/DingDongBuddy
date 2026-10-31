import 'dart:convert';

/// QR payload. The secret is kept in the URL fragment so it is not sent to
/// the PWA host as part of the HTTP request.
final class DevicePairingPayload {
  const DevicePairingPayload({
    required this.room,
    required this.secret,
    required this.hostId,
    required this.hostName,
    required this.relayUrl,
  });

  factory DevicePairingPayload.decode(String value) {
    final String normalized = base64Url.normalize(value);
    final Map<String, Object?> json = Map<String, Object?>.from(
      jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map,
    );
    // The desktop writes `v`; the PWA also accepts `version`.
    if ((json['v'] ?? json['version']) != 1) {
      throw const FormatException('Unsupported pairing payload version.');
    }
    return DevicePairingPayload(
      room: json['room']! as String,
      secret: json['secret']! as String,
      hostId: json['hostId']! as String,
      hostName: json['hostName']! as String,
      relayUrl: Uri.parse(json['relay']! as String),
    );
  }

  /// Accepts the full QR URL, its `#pair=` fragment, or the raw encoded body.
  factory DevicePairingPayload.parseInput(String value) {
    String encoded = value.trim();
    if (encoded.isEmpty) {
      throw const FormatException('The pairing link is empty.');
    }
    final Uri? uri = Uri.tryParse(encoded);
    final String fragment = uri?.fragment ?? '';
    if (fragment.startsWith('pair=')) {
      encoded = fragment.substring('pair='.length);
    } else {
      encoded = encoded
          .replaceFirst(RegExp(r'^#?pair='), '')
          .replaceFirst(RegExp(r'^.*#pair='), '');
    }
    final DevicePairingPayload payload = DevicePairingPayload.decode(encoded);
    final String relay = payload.relayUrl.toString();
    if (!RegExp(r'^[A-Za-z0-9_-]{20,64}$').hasMatch(payload.room) ||
        !RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(payload.secret) ||
        payload.hostId.trim().isEmpty ||
        payload.hostId.length > 160 ||
        payload.hostName.trim().isEmpty ||
        payload.hostName.length > 80 ||
        relay.length > 2048 ||
        !const <String>{
          'http',
          'https',
          'ws',
          'wss',
        }.contains(payload.relayUrl.scheme) ||
        !payload.relayUrl.hasAuthority ||
        payload.relayUrl.host.isEmpty ||
        payload.relayUrl.userInfo.isNotEmpty ||
        payload.relayUrl.fragment.isNotEmpty) {
      throw const FormatException('The pairing link is invalid.');
    }
    return payload;
  }

  factory DevicePairingPayload.fromJson(Map<String, Object?> json) {
    return DevicePairingPayload(
      room: json['room']! as String,
      secret: json['secret']! as String,
      hostId: json['hostId']! as String,
      hostName: json['hostName']! as String,
      relayUrl: Uri.parse(json['relay']! as String),
    );
  }

  final String room;
  final String secret;
  final String hostId;
  final String hostName;
  final Uri relayUrl;

  Map<String, Object?> toJson() => <String, Object?>{
    'room': room,
    'secret': secret,
    'hostId': hostId,
    'hostName': hostName,
    'relay': relayUrl.toString(),
  };

  String encode() => base64Url
      .encode(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'v': 1,
            'room': room,
            'secret': secret,
            'hostId': hostId,
            'hostName': hostName,
            'relay': relayUrl.toString(),
          }),
        ),
      )
      .replaceAll('=', '');
}
