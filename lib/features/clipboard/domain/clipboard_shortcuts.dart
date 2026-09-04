import 'package:dingdong/core/platform/desktop_platform_policy.dart';
import 'package:flutter/services.dart';

/// Tracks the modifier that started a search-clear hold in either clipboard UI.
enum ClipboardSearchModifier {
  meta,
  control;

  static ClipboardSearchModifier? pressed(HardwareKeyboard keyboard) {
    if (keyboard.isMetaPressed) {
      return meta;
    }
    if (keyboard.isControlPressed) {
      return control;
    }
    return null;
  }

  bool isPressed(HardwareKeyboard keyboard) => switch (this) {
    meta => keyboard.isMetaPressed,
    control => keyboard.isControlPressed,
  };

  bool matches(LogicalKeyboardKey key) => switch (this) {
    meta =>
      key == LogicalKeyboardKey.metaLeft || key == LogicalKeyboardKey.metaRight,
    control =>
      key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight,
  };
}

int? clipboardShortcutIndex(LogicalKeyboardKey key) {
  final int index = const <LogicalKeyboardKey>[
    LogicalKeyboardKey.digit1,
    LogicalKeyboardKey.digit2,
    LogicalKeyboardKey.digit3,
    LogicalKeyboardKey.digit4,
    LogicalKeyboardKey.digit5,
    LogicalKeyboardKey.digit6,
    LogicalKeyboardKey.digit7,
    LogicalKeyboardKey.digit8,
    LogicalKeyboardKey.digit9,
  ].indexOf(key);
  return index < 0 ? null : index;
}

bool isClipboardGroupModifierKey(
  LogicalKeyboardKey key,
  TargetPlatform platform,
) => usesMetaAsPrimaryModifier(platform)
    ? key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight
    : key == LogicalKeyboardKey.altLeft || key == LogicalKeyboardKey.altRight;

bool isClipboardGroupModifierPressed(
  HardwareKeyboard keyboard,
  TargetPlatform platform,
) => usesMetaAsPrimaryModifier(platform)
    ? keyboard.isControlPressed
    : keyboard.isAltPressed;
