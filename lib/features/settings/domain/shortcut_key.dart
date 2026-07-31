import 'package:flutter/services.dart';

/// Converts Flutter logical keys to the stable names persisted by DingDong.
String? shortcutKeyForLogicalKey(LogicalKeyboardKey key) {
  final int letterIndex = _letterKeys.indexOf(key);
  if (letterIndex >= 0) {
    return String.fromCharCode('A'.codeUnitAt(0) + letterIndex);
  }
  final int digitIndex = _digitKeys.indexOf(key);
  if (digitIndex >= 0) {
    return '$digitIndex';
  }
  final int functionIndex = _functionKeys.indexOf(key);
  if (functionIndex >= 0) {
    return 'F${functionIndex + 1}';
  }
  return switch (key) {
    LogicalKeyboardKey.space => 'SPACE',
    LogicalKeyboardKey.enter || LogicalKeyboardKey.numpadEnter => 'RETURN',
    LogicalKeyboardKey.arrowLeft => 'LEFT',
    LogicalKeyboardKey.arrowRight => 'RIGHT',
    LogicalKeyboardKey.arrowUp => 'UP',
    LogicalKeyboardKey.arrowDown => 'DOWN',
    _ => null,
  };
}

/// Resolves a persisted DingDong key name back to a Flutter logical key.
LogicalKeyboardKey? logicalKeyForShortcutKey(String value) {
  final String key = value.toUpperCase();
  if (key.length == 1) {
    final int codeUnit = key.codeUnitAt(0);
    final int letterIndex = codeUnit - 'A'.codeUnitAt(0);
    if (letterIndex >= 0 && letterIndex < _letterKeys.length) {
      return _letterKeys[letterIndex];
    }
    final int digitIndex = codeUnit - '0'.codeUnitAt(0);
    if (digitIndex >= 0 && digitIndex < _digitKeys.length) {
      return _digitKeys[digitIndex];
    }
  }
  if (key.startsWith('F')) {
    final int? functionNumber = int.tryParse(key.substring(1));
    if (functionNumber != null &&
        functionNumber >= 1 &&
        functionNumber <= _functionKeys.length) {
      return _functionKeys[functionNumber - 1];
    }
  }
  return switch (key) {
    'SPACE' => LogicalKeyboardKey.space,
    'RETURN' => LogicalKeyboardKey.enter,
    'LEFT' => LogicalKeyboardKey.arrowLeft,
    'RIGHT' => LogicalKeyboardKey.arrowRight,
    'UP' => LogicalKeyboardKey.arrowUp,
    'DOWN' => LogicalKeyboardKey.arrowDown,
    _ => null,
  };
}

bool isShortcutModifierKey(LogicalKeyboardKey key) {
  return _modifierKeys.contains(key);
}

const List<LogicalKeyboardKey> _letterKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.keyA,
  LogicalKeyboardKey.keyB,
  LogicalKeyboardKey.keyC,
  LogicalKeyboardKey.keyD,
  LogicalKeyboardKey.keyE,
  LogicalKeyboardKey.keyF,
  LogicalKeyboardKey.keyG,
  LogicalKeyboardKey.keyH,
  LogicalKeyboardKey.keyI,
  LogicalKeyboardKey.keyJ,
  LogicalKeyboardKey.keyK,
  LogicalKeyboardKey.keyL,
  LogicalKeyboardKey.keyM,
  LogicalKeyboardKey.keyN,
  LogicalKeyboardKey.keyO,
  LogicalKeyboardKey.keyP,
  LogicalKeyboardKey.keyQ,
  LogicalKeyboardKey.keyR,
  LogicalKeyboardKey.keyS,
  LogicalKeyboardKey.keyT,
  LogicalKeyboardKey.keyU,
  LogicalKeyboardKey.keyV,
  LogicalKeyboardKey.keyW,
  LogicalKeyboardKey.keyX,
  LogicalKeyboardKey.keyY,
  LogicalKeyboardKey.keyZ,
];

const List<LogicalKeyboardKey> _digitKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.digit0,
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

const List<LogicalKeyboardKey> _functionKeys = <LogicalKeyboardKey>[
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
];

final Set<LogicalKeyboardKey> _modifierKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.meta,
  LogicalKeyboardKey.metaLeft,
  LogicalKeyboardKey.metaRight,
  LogicalKeyboardKey.control,
  LogicalKeyboardKey.controlLeft,
  LogicalKeyboardKey.controlRight,
  LogicalKeyboardKey.alt,
  LogicalKeyboardKey.altLeft,
  LogicalKeyboardKey.altRight,
  LogicalKeyboardKey.shift,
  LogicalKeyboardKey.shiftLeft,
  LogicalKeyboardKey.shiftRight,
};
