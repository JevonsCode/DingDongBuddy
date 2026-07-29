import 'dart:convert';

import 'package:flutter/foundation.dart';

/// A portable global shortcut understood by both desktop runners.
///
/// [primary] is Command on macOS and Control on Windows. [secondary] is
/// Control on macOS and the Windows key on Windows.
final class GlobalHotKey {
  const GlobalHotKey({
    this.key = 'V',
    this.primary = true,
    this.shift = true,
    this.alt = false,
    this.secondary = false,
  });

  static const GlobalHotKey defaultValue = GlobalHotKey();

  final String key;
  final bool primary;
  final bool shift;
  final bool alt;
  final bool secondary;

  bool get hasModifier => primary || shift || alt || secondary;

  bool get isValid => hasModifier && supportedKeys.contains(key);

  GlobalHotKey sanitized() => isValid ? this : defaultValue;

  String encode() {
    final GlobalHotKey value = sanitized();
    return jsonEncode(<String, Object>{
      'key': value.key,
      'primary': value.primary,
      'shift': value.shift,
      'alt': value.alt,
      'secondary': value.secondary,
    });
  }

  static GlobalHotKey parse(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      return defaultValue;
    }
    try {
      final Object? decoded = jsonDecode(value);
      if (decoded is! Map<String, Object?>) {
        return defaultValue;
      }
      final Object? key = decoded['key'];
      if (key is! String) {
        return defaultValue;
      }
      return GlobalHotKey(
        key: key.toUpperCase(),
        primary: decoded['primary'] == true,
        shift: decoded['shift'] == true,
        alt: decoded['alt'] == true,
        secondary: decoded['secondary'] == true,
      ).sanitized();
    } on FormatException {
      return defaultValue;
    }
  }

  Map<String, Object> toPlatformArguments() {
    final GlobalHotKey value = sanitized();
    return <String, Object>{
      'key': value.key,
      'primary': value.primary,
      'shift': value.shift,
      'alt': value.alt,
      'secondary': value.secondary,
    };
  }

  String label(TargetPlatform platform) {
    final bool macOS = platform == TargetPlatform.macOS;
    final List<String> parts = <String>[
      if (primary) macOS ? '⌘' : 'Ctrl',
      if (secondary) macOS ? '⌃' : 'Win',
      if (alt) macOS ? '⌥' : 'Alt',
      if (shift) macOS ? '⇧' : 'Shift',
      _keyLabel(key),
    ];
    return macOS ? parts.join() : parts.join('+');
  }

  @override
  bool operator ==(Object other) {
    return other is GlobalHotKey &&
        other.key == key &&
        other.primary == primary &&
        other.shift == shift &&
        other.alt == alt &&
        other.secondary == secondary;
  }

  @override
  int get hashCode => Object.hash(key, primary, shift, alt, secondary);

  static const Set<String> supportedKeys = <String>{
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'J',
    'K',
    'L',
    'M',
    'N',
    'O',
    'P',
    'Q',
    'R',
    'S',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y',
    'Z',
    '0',
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    'F1',
    'F2',
    'F3',
    'F4',
    'F5',
    'F6',
    'F7',
    'F8',
    'F9',
    'F10',
    'F11',
    'F12',
    'SPACE',
    'RETURN',
    'LEFT',
    'RIGHT',
    'UP',
    'DOWN',
  };
}

String _keyLabel(String key) {
  return switch (key) {
    'SPACE' => 'Space',
    'RETURN' => 'Return',
    'LEFT' => '←',
    'RIGHT' => '→',
    'UP' => '↑',
    'DOWN' => '↓',
    _ => key,
  };
}
