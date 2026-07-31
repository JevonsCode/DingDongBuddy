import 'dart:convert';

import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:dingdong/features/settings/domain/shortcut_key.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

typedef DesktopShortcutModifiers = ({
  bool alt,
  bool control,
  bool meta,
  bool shift,
});

/// One shortcut that is active only while the DingDong panel has focus.
///
/// The automatic modifier preserves the safe platform defaults: Control on
/// macOS and Alt on Windows. A recorded custom shortcut stores explicit,
/// portable modifier roles in the same way as [GlobalHotKey].
final class WorkspaceShortcut {
  const WorkspaceShortcut({
    required this.key,
    this.automaticModifier = false,
    this.primary = false,
    this.shift = false,
    this.alt = false,
    this.secondary = false,
  });

  const WorkspaceShortcut.automatic(this.key)
    : automaticModifier = true,
      primary = false,
      shift = false,
      alt = false,
      secondary = false;

  final String key;
  final bool automaticModifier;
  final bool primary;
  final bool shift;
  final bool alt;
  final bool secondary;

  bool get hasModifier =>
      automaticModifier || primary || shift || alt || secondary;

  bool get isValid =>
      hasModifier &&
      GlobalHotKey.supportedKeys.contains(key) &&
      logicalKeyForShortcutKey(key) != null;

  WorkspaceShortcut sanitized(WorkspaceShortcut fallback) {
    return isValid ? this : fallback;
  }

  DesktopShortcutModifiers modifiers(TargetPlatform platform) {
    if (automaticModifier) {
      return (
        alt: platform != TargetPlatform.macOS,
        control: platform == TargetPlatform.macOS,
        meta: false,
        shift: false,
      );
    }
    final bool macOS = platform == TargetPlatform.macOS;
    return (
      alt: alt,
      control: macOS ? secondary : primary,
      meta: macOS ? primary : secondary,
      shift: shift,
    );
  }

  SingleActivator activator(TargetPlatform platform) {
    final DesktopShortcutModifiers resolved = modifiers(platform);
    return SingleActivator(
      logicalKeyForShortcutKey(key)!,
      alt: resolved.alt,
      control: resolved.control,
      meta: resolved.meta,
      shift: resolved.shift,
    );
  }

  bool modifierStateMatches(
    HardwareKeyboard keyboard,
    TargetPlatform platform,
  ) {
    final DesktopShortcutModifiers resolved = modifiers(platform);
    return keyboard.isAltPressed == resolved.alt &&
        keyboard.isControlPressed == resolved.control &&
        keyboard.isMetaPressed == resolved.meta &&
        keyboard.isShiftPressed == resolved.shift;
  }

  bool conflictsWith(WorkspaceShortcut other, TargetPlatform platform) {
    return key == other.key && modifiers(platform) == other.modifiers(platform);
  }

  String label(TargetPlatform platform) {
    final DesktopShortcutModifiers resolved = modifiers(platform);
    final bool macOS = platform == TargetPlatform.macOS;
    final List<String> modifierLabels = <String>[
      if (resolved.meta) macOS ? '⌘' : 'Win',
      if (resolved.control) macOS ? '⌃' : 'Ctrl',
      if (resolved.alt) macOS ? '⌥' : 'Alt',
      if (resolved.shift) macOS ? '⇧' : 'Shift',
    ];
    final String modifierLabel = macOS
        ? modifierLabels.join()
        : modifierLabels.join('+');
    return '$modifierLabel ${_keyLabel(key)}';
  }

  Map<String, Object> toJson() {
    return <String, Object>{
      'key': key,
      'automaticModifier': automaticModifier,
      'primary': primary,
      'shift': shift,
      'alt': alt,
      'secondary': secondary,
    };
  }

  static WorkspaceShortcut fromJson(Object? value, WorkspaceShortcut fallback) {
    if (value is! Map<String, Object?> || value['key'] is! String) {
      return fallback;
    }
    return WorkspaceShortcut(
      key: (value['key']! as String).toUpperCase(),
      automaticModifier: value['automaticModifier'] == true,
      primary: value['primary'] == true,
      shift: value['shift'] == true,
      alt: value['alt'] == true,
      secondary: value['secondary'] == true,
    ).sanitized(fallback);
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceShortcut &&
        other.key == key &&
        other.automaticModifier == automaticModifier &&
        other.primary == primary &&
        other.shift == shift &&
        other.alt == alt &&
        other.secondary == secondary;
  }

  @override
  int get hashCode =>
      Object.hash(key, automaticModifier, primary, shift, alt, secondary);
}

/// The three configurable shortcuts used by the main panel workspaces.
final class WorkspaceShortcuts {
  const WorkspaceShortcuts({
    this.today = defaultToday,
    this.library = defaultLibrary,
    this.clipboard = defaultClipboard,
  });

  static const WorkspaceShortcut defaultToday = WorkspaceShortcut.automatic(
    'Q',
  );
  static const WorkspaceShortcut defaultLibrary = WorkspaceShortcut.automatic(
    'W',
  );
  static const WorkspaceShortcut defaultClipboard = WorkspaceShortcut.automatic(
    'E',
  );
  static const WorkspaceShortcuts defaultValue = WorkspaceShortcuts();

  final WorkspaceShortcut today;
  final WorkspaceShortcut library;
  final WorkspaceShortcut clipboard;

  List<WorkspaceShortcut> get values => <WorkspaceShortcut>[
    today,
    library,
    clipboard,
  ];

  WorkspaceShortcut at(int index) {
    return switch (index) {
      0 => today,
      1 => library,
      2 => clipboard,
      _ => throw RangeError.index(index, values, 'index'),
    };
  }

  WorkspaceShortcuts replace(int index, WorkspaceShortcut value) {
    return switch (index) {
      0 => WorkspaceShortcuts(
        today: value,
        library: library,
        clipboard: clipboard,
      ),
      1 => WorkspaceShortcuts(
        today: today,
        library: value,
        clipboard: clipboard,
      ),
      2 => WorkspaceShortcuts(today: today, library: library, clipboard: value),
      _ => throw RangeError.index(index, values, 'index'),
    };
  }

  WorkspaceShortcuts sanitized(TargetPlatform platform) {
    final WorkspaceShortcuts candidate = WorkspaceShortcuts(
      today: today.sanitized(defaultToday),
      library: library.sanitized(defaultLibrary),
      clipboard: clipboard.sanitized(defaultClipboard),
    );
    for (int left = 0; left < candidate.values.length; left += 1) {
      for (int right = left + 1; right < candidate.values.length; right += 1) {
        if (candidate.values[left].conflictsWith(
          candidate.values[right],
          platform,
        )) {
          return defaultValue;
        }
      }
    }
    return candidate;
  }

  String encode() {
    return jsonEncode(<String, Object>{
      'today': today.toJson(),
      'library': library.toJson(),
      'clipboard': clipboard.toJson(),
    });
  }

  static WorkspaceShortcuts parse(
    Object? value, {
    TargetPlatform platform = TargetPlatform.macOS,
  }) {
    if (value is! String || value.trim().isEmpty) {
      return defaultValue;
    }
    try {
      final Object? decoded = jsonDecode(value);
      if (decoded is! Map<String, Object?>) {
        return defaultValue;
      }
      return WorkspaceShortcuts(
        today: WorkspaceShortcut.fromJson(decoded['today'], defaultToday),
        library: WorkspaceShortcut.fromJson(decoded['library'], defaultLibrary),
        clipboard: WorkspaceShortcut.fromJson(
          decoded['clipboard'],
          defaultClipboard,
        ),
      ).sanitized(platform);
    } on FormatException {
      return defaultValue;
    }
  }

  @override
  bool operator ==(Object other) {
    return other is WorkspaceShortcuts &&
        other.today == today &&
        other.library == library &&
        other.clipboard == clipboard;
  }

  @override
  int get hashCode => Object.hash(today, library, clipboard);
}

DesktopShortcutModifiers globalHotKeyModifiers(
  GlobalHotKey value,
  TargetPlatform platform,
) {
  final bool macOS = platform == TargetPlatform.macOS;
  return (
    alt: value.alt,
    control: macOS ? value.secondary : value.primary,
    meta: macOS ? value.primary : value.secondary,
    shift: value.shift,
  );
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
