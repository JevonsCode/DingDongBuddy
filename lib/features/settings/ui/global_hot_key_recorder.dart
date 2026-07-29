import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Records one supported system-wide shortcut from the keyboard.
class GlobalHotKeyRecorder extends StatefulWidget {
  const GlobalHotKeyRecorder({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final GlobalHotKey value;
  final Future<void> Function(GlobalHotKey value) onChanged;

  @override
  State<GlobalHotKeyRecorder> createState() => _GlobalHotKeyRecorderState();
}

class _GlobalHotKeyRecorderState extends State<GlobalHotKeyRecorder> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'global-hot-key-recorder');
  bool _recording = false;
  String? _validationMessage;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _recording = true;
      _validationMessage = null;
    });
    _focusNode.requestFocus();
  }

  void _cancelRecording() {
    setState(() {
      _recording = false;
      _validationMessage = null;
    });
    _focusNode.unfocus();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_recording) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancelRecording();
      return KeyEventResult.handled;
    }
    if (_modifierKeys.contains(event.logicalKey)) {
      return KeyEventResult.handled;
    }

    final String? key = globalHotKeyKeyForLogicalKey(event.logicalKey);
    if (key == null) {
      setState(() {
        _validationMessage = context.localized(
          'Use a letter, number, F1–F12, arrow, Space, or Return.',
          '请使用字母、数字、F1–F12、方向键、空格或回车。',
        );
      });
      return KeyEventResult.handled;
    }

    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool macOS = defaultTargetPlatform == TargetPlatform.macOS;
    final GlobalHotKey candidate = GlobalHotKey(
      key: key,
      primary: macOS ? keyboard.isMetaPressed : keyboard.isControlPressed,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      secondary: macOS ? keyboard.isControlPressed : keyboard.isMetaPressed,
    );
    if (!candidate.hasModifier) {
      setState(() {
        _validationMessage = context.localized(
          'Include at least one modifier key.',
          '请至少包含一个修饰键。',
        );
      });
      return KeyEventResult.handled;
    }

    setState(() {
      _recording = false;
      _validationMessage = null;
    });
    _focusNode.unfocus();
    unawaited(widget.onChanged(candidate));
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final TargetPlatform platform = defaultTargetPlatform;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Focus(
              focusNode: _focusNode,
              onKeyEvent: _handleKeyEvent,
              child: OutlinedButton(
                key: const Key('settings-global-hot-key'),
                onPressed: _recording ? _cancelRecording : _startRecording,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(172, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                child: Text(
                  _recording
                      ? context.localized('Press a shortcut…', '请按下快捷键…')
                      : widget.value.label(platform),
                ),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              key: const Key('settings-global-hot-key-reset'),
              onPressed: widget.value == GlobalHotKey.defaultValue
                  ? null
                  : () => widget.onChanged(GlobalHotKey.defaultValue),
              child: Text(context.localized('Reset', '恢复默认')),
            ),
          ],
        ),
        if (_validationMessage != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            _validationMessage!,
            key: const Key('settings-global-hot-key-validation'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

String? globalHotKeyKeyForLogicalKey(LogicalKeyboardKey key) {
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
