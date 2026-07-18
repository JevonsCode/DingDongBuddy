import 'package:flutter/services.dart';

/// Returns whether [platform] uses Command as its primary shortcut modifier.
bool usesMetaAsPrimaryModifier(TargetPlatform platform) {
  return platform == TargetPlatform.macOS;
}

/// Returns whether [key] is the primary modifier key for [platform].
bool isPrimaryModifierKey(LogicalKeyboardKey key, TargetPlatform platform) {
  if (usesMetaAsPrimaryModifier(platform)) {
    return key == LogicalKeyboardKey.metaLeft ||
        key == LogicalKeyboardKey.metaRight;
  }
  return key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight;
}

/// Returns whether the primary modifier for [platform] is currently pressed.
bool isPrimaryModifierPressed(
  HardwareKeyboard keyboard,
  TargetPlatform platform,
) {
  return usesMetaAsPrimaryModifier(platform)
      ? keyboard.isMetaPressed
      : keyboard.isControlPressed;
}

/// Formats a shortcut using the platform's primary modifier label.
String primaryShortcutLabel(String key, TargetPlatform platform) {
  return usesMetaAsPrimaryModifier(platform) ? '⌘ $key' : 'Ctrl $key';
}
