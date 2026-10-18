import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Authenticated application envelope used for relay signaling and data
/// messages. WebRTC already applies DTLS; this layer also prevents the relay
/// from reading signaling or notification payloads.
final class SecureMessageCodec {
  SecureMessageCodec.fromBase64Url(String encodedKey)
    : _secretKey = SecretKey(base64Url.decode(base64Url.normalize(encodedKey)));

  final Cipher _cipher = AesGcm.with256bits();
  final SecretKey _secretKey;

  Future<String> seal(Map<String, Object?> message) async {
    final SecretBox box = await _cipher.encrypt(
      utf8.encode(jsonEncode(message)),
      secretKey: _secretKey,
    );
    return base64Url.encode(box.concatenation()).replaceAll('=', '');
  }

  Future<Map<String, Object?>> open(String envelope) async {
    final SecretBox box = SecretBox.fromConcatenation(
      base64Url.decode(base64Url.normalize(envelope)),
      nonceLength: _cipher.nonceLength,
      macLength: _cipher.macAlgorithm.macLength,
    );
    final List<int> clearText = await _cipher.decrypt(
      box,
      secretKey: _secretKey,
    );
    return Map<String, Object?>.from(jsonDecode(utf8.decode(clearText)) as Map);
  }
}
