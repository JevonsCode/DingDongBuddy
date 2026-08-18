import 'package:dingdong/core/serialization/strict_json.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes valid nested JSON values', () {
    expect(
      decodeStrictJson(
        '{"enabled":true,"values":[null,-1.5e2,{"name":"api"}]}',
      ),
      <String, Object?>{
        'enabled': true,
        'values': <Object?>[
          null,
          -150.0,
          <String, Object?>{'name': 'api'},
        ],
      },
    );
  });

  test('rejects duplicate keys in nested objects', () {
    expect(
      () => decodeStrictJson('{"outer":{"name":1,"name":2}}'),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('Duplicate JSON key'),
        ),
      ),
    );
  });

  test('rejects duplicate keys that become equal after unescaping', () {
    expect(
      () => decodeStrictJson(r'{"api":1,"\u0061pi":2}'),
      throwsA(isA<FormatException>()),
    );
  });

  test('allows the same key in separate objects', () {
    expect(decodeStrictJson('[{"name":"first"},{"name":"second"}]'), <Object?>[
      <String, Object?>{'name': 'first'},
      <String, Object?>{'name': 'second'},
    ]);
  });
}
