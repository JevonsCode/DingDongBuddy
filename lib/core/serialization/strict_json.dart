import 'dart:convert';

/// Decodes JSON after rejecting duplicate keys in every object.
///
/// [jsonDecode] intentionally keeps the final value for duplicate keys. That
/// behavior is unsafe for user-managed configuration because it hides which
/// value DingDong preserved, so a lightweight syntax pass rejects ambiguity
/// before the SDK decoder builds the object graph.
Object? decodeStrictJson(String source) {
  _StrictJsonScanner(source).scan();
  return jsonDecode(source);
}

final class _StrictJsonScanner {
  _StrictJsonScanner(this.source);

  final String source;
  var _index = 0;

  void scan() {
    _skipWhitespace();
    _value();
    _skipWhitespace();
    if (_index != source.length) {
      _fail('Unexpected trailing JSON content');
    }
  }

  void _value() {
    if (_index >= source.length) {
      _fail('Unexpected end of JSON input');
    }
    switch (source.codeUnitAt(_index)) {
      case 0x7B:
        _object();
      case 0x5B:
        _array();
      case 0x22:
        _string();
      case 0x74:
        _literal('true');
      case 0x66:
        _literal('false');
      case 0x6E:
        _literal('null');
      default:
        _number();
    }
  }

  void _object() {
    _index += 1;
    _skipWhitespace();
    if (_consume(0x7D)) {
      return;
    }
    final Set<String> keys = <String>{};
    while (true) {
      _skipWhitespace();
      final int keyOffset = _index;
      if (_peek() != 0x22) {
        _fail('Expected a JSON object key');
      }
      final String key = _string();
      if (!keys.add(key)) {
        throw FormatException('Duplicate JSON key "$key".', source, keyOffset);
      }
      _skipWhitespace();
      _expect(0x3A, 'Expected ":" after a JSON object key');
      _skipWhitespace();
      _value();
      _skipWhitespace();
      if (_consume(0x7D)) {
        return;
      }
      _expect(0x2C, 'Expected "," between JSON object entries');
    }
  }

  void _array() {
    _index += 1;
    _skipWhitespace();
    if (_consume(0x5D)) {
      return;
    }
    while (true) {
      _value();
      _skipWhitespace();
      if (_consume(0x5D)) {
        return;
      }
      _expect(0x2C, 'Expected "," between JSON array values');
      _skipWhitespace();
    }
  }

  String _string() {
    final int start = _index;
    _expect(0x22, 'Expected a JSON string');
    while (_index < source.length) {
      final int code = source.codeUnitAt(_index);
      _index += 1;
      if (code == 0x22) {
        return jsonDecode(source.substring(start, _index)) as String;
      }
      if (code < 0x20) {
        _fail('Unescaped control character in JSON string');
      }
      if (code != 0x5C) {
        continue;
      }
      if (_index >= source.length) {
        _fail('Incomplete JSON string escape');
      }
      final int escaped = source.codeUnitAt(_index);
      _index += 1;
      if (escaped == 0x75) {
        for (var count = 0; count < 4; count += 1) {
          if (_index >= source.length || !_isHex(source.codeUnitAt(_index))) {
            _fail('Invalid JSON Unicode escape');
          }
          _index += 1;
        }
      } else if (!const <int>{
        0x22,
        0x5C,
        0x2F,
        0x62,
        0x66,
        0x6E,
        0x72,
        0x74,
      }.contains(escaped)) {
        _fail('Invalid JSON string escape');
      }
    }
    _fail('Unterminated JSON string');
  }

  void _literal(String literal) {
    if (!source.startsWith(literal, _index)) {
      _fail('Invalid JSON value');
    }
    _index += literal.length;
  }

  void _number() {
    if (_consume(0x2D) && _index >= source.length) {
      _fail('Invalid JSON number');
    }
    if (_consume(0x30)) {
      if (_isDigit(_peek())) {
        _fail('Invalid leading zero in JSON number');
      }
    } else {
      if (!_isDigitOneToNine(_peek())) {
        _fail('Invalid JSON value');
      }
      while (_isDigit(_peek())) {
        _index += 1;
      }
    }
    if (_consume(0x2E)) {
      if (!_isDigit(_peek())) {
        _fail('Invalid JSON fraction');
      }
      while (_isDigit(_peek())) {
        _index += 1;
      }
    }
    if (_peek() == 0x65 || _peek() == 0x45) {
      _index += 1;
      if (_peek() == 0x2B || _peek() == 0x2D) {
        _index += 1;
      }
      if (!_isDigit(_peek())) {
        _fail('Invalid JSON exponent');
      }
      while (_isDigit(_peek())) {
        _index += 1;
      }
    }
  }

  void _skipWhitespace() {
    while (const <int>{0x20, 0x09, 0x0A, 0x0D}.contains(_peek())) {
      _index += 1;
    }
  }

  bool _consume(int code) {
    if (_peek() != code) {
      return false;
    }
    _index += 1;
    return true;
  }

  void _expect(int code, String message) {
    if (!_consume(code)) {
      _fail(message);
    }
  }

  int _peek() => _index < source.length ? source.codeUnitAt(_index) : -1;

  bool _isDigit(int code) => code >= 0x30 && code <= 0x39;

  bool _isDigitOneToNine(int code) => code >= 0x31 && code <= 0x39;

  bool _isHex(int code) =>
      _isDigit(code) ||
      (code >= 0x41 && code <= 0x46) ||
      (code >= 0x61 && code <= 0x66);

  Never _fail(String message) {
    throw FormatException(message, source, _index);
  }
}
