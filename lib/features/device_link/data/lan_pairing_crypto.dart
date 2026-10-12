import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

/// SRP-6a with the fixed RFC 5054 2048-bit group and SHA-256. The short
/// password never leaves either endpoint, and passive traffic does not provide
/// an offline six-digit password oracle. Protocol version: dingdong-lan-v1.
final class LanPairingCrypto {
  static final BigInt modulus = BigInt.parse(
    'AC6BDB41324A9A9BF166DE5E1389582FAF72B6651987EE07FC3192943DB56050'
    'A37329CBB4A099ED8193E0757767A13DD52312AB4B03310DCD7F48A9DA04FD50'
    'E8083969EDB767B0CF6095179A163AB3661A05FBD5FAAAE82918A9962F0B93B8'
    '55F97993EC975EEAA80D740ADBF4FF747359D041D5C33EA71D281E446B14773B'
    'CA97B43A23FB801676BD207A436C6481F1D2B9078717461A5B9D32E688F87748'
    '544523B524B0D57D5EA77A2775D2ECFA032CFBDBF52FB3786160279004E57AE6'
    'AF874E7303CE53299CCC041C7BC308D82A5698F3A8D0C38271AE35F8E9DBFBB6'
    '94B5C803D89F7AE435DE236D525F54759B65E372FCD68EF20FA7111F9E4AFF73',
    radix: 16,
  );
  static final BigInt generator = BigInt.two;
  static final Random _random = Random.secure();

  static String token([int count = 32]) => base64Url
      .encode(List<int>.generate(count, (_) => _random.nextInt(256)))
      .replaceAll('=', '');

  static String code() => _random.nextInt(1000000).toString().padLeft(6, '0');

  static BigInt privateValue() =>
      BigInt.parse(
        base64Url
            .decode(base64Url.normalize(token()))
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join(),
        radix: 16,
      ) +
      BigInt.one;

  static List<int> _pad(BigInt number) {
    final hex = number.toRadixString(16).padLeft(512, '0');
    return [
      for (var i = 0; i < hex.length; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ];
  }

  static Future<List<int>> _hash(List<int> bytes) async =>
      (await Sha256().hash(bytes)).bytes;

  static Future<BigInt> _number(List<int> bytes) async => BigInt.parse(
    (await _hash(bytes)).map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    radix: 16,
  );

  static Future<BigInt> _x(String salt, String code) async => _number([
    ...base64Url.decode(base64Url.normalize(salt)),
    ...await _hash(utf8.encode('dingdong-lan-v1:$code')),
  ]);

  static Future<BigInt> _k() => _number([..._pad(modulus), ..._pad(generator)]);

  static BigInt readPublic(String value) {
    if (!RegExp(r'^[0-9a-fA-F]{1,512}$').hasMatch(value)) {
      throw const FormatException('Invalid pairing public value');
    }
    final result = BigInt.parse(value, radix: 16);
    if (result <= BigInt.one || result >= modulus) {
      throw const FormatException('Invalid pairing public value');
    }
    return result;
  }

  static Future<BigInt> serverPublic(String salt, String code, BigInt b) async {
    final v = generator.modPow(await _x(salt, code), modulus);
    return ((await _k()) * v + generator.modPow(b, modulus)) % modulus;
  }

  static Future<String> serverKey({
    required String salt,
    required String code,
    required BigInt aPublic,
    required BigInt b,
    required BigInt bPublic,
  }) async {
    final u = await _number([..._pad(aPublic), ..._pad(bPublic)]);
    if (u == BigInt.zero) throw const FormatException('Invalid scramble');
    final v = generator.modPow(await _x(salt, code), modulus);
    final shared = (aPublic * v.modPow(u, modulus)).modPow(b, modulus);
    return base64Url.encode(await _hash(_pad(shared)));
  }

  static Future<String> clientKey({
    required String salt,
    required String code,
    required BigInt a,
    required BigInt bPublic,
  }) async {
    final aPublic = generator.modPow(a, modulus);
    final u = await _number([..._pad(aPublic), ..._pad(bPublic)]);
    if (u == BigInt.zero) throw const FormatException('Invalid scramble');
    final x = await _x(salt, code);
    final base =
        (bPublic - (await _k()) * generator.modPow(x, modulus)) % modulus;
    final shared = base.modPow(a + u * x, modulus);
    return base64Url.encode(await _hash(_pad(shared)));
  }
}
