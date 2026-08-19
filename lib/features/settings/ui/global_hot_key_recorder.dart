import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:dingdong/features/settings/domain/shortcut_key.dart';
import 'package:dingdong/features/settings/domain/workspace_shortcuts.dart';
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
    if (isShortcutModifierKey(event.logicalKey)) {
      return KeyEventResult.handled;
    }

    final String? key = shortcutKeyForLogicalKey(event.logicalKey);
    if (key == null) {
      setState(() {
        _validationMessage =
            context.l10n.useALetterNumberF1F12ArrowSpaceOrReturn;
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
        _validationMessage = context.l10n.includeAtLeastOneModifierKey;
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
              child: DesktopActionButton(
                key: const Key('settings-global-hot-key'),
                onPressed: _recording ? _cancelRecording : _startRecording,
                label: Text(
                  _recording
                      ? context.l10n.pressAShortcut
                      : widget.value.label(platform),
                ),
                minWidth: 172,
                height: 38,
              ),
            ),
            const SizedBox(width: 8),
            DesktopActionButton(
              key: const Key('settings-global-hot-key-reset'),
              onPressed: widget.value == GlobalHotKey.defaultValue
                  ? null
                  : () => widget.onChanged(GlobalHotKey.defaultValue),
              label: context.l10n.reset,
              compact: true,
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

/// Records a shortcut used only while the DingDong panel is focused.
class WorkspaceShortcutRecorder extends StatefulWidget {
  const WorkspaceShortcutRecorder({
    required this.settingId,
    required this.semanticLabel,
    required this.value,
    required this.defaultValue,
    required this.onChanged,
    super.key,
  });

  final String settingId;
  final String semanticLabel;
  final WorkspaceShortcut value;
  final WorkspaceShortcut defaultValue;
  final Future<bool> Function(WorkspaceShortcut value) onChanged;

  @override
  State<WorkspaceShortcutRecorder> createState() =>
      _WorkspaceShortcutRecorderState();
}

class _WorkspaceShortcutRecorderState extends State<WorkspaceShortcutRecorder> {
  final FocusNode _focusNode = FocusNode(
    debugLabel: 'workspace-shortcut-recorder',
  );
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
    if (isShortcutModifierKey(event.logicalKey)) {
      return KeyEventResult.handled;
    }
    final String? key = shortcutKeyForLogicalKey(event.logicalKey);
    if (key == null) {
      setState(() {
        _validationMessage =
            context.l10n.useALetterNumberF1F12ArrowSpaceOrReturn;
      });
      return KeyEventResult.handled;
    }
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    final bool macOS = defaultTargetPlatform == TargetPlatform.macOS;
    final WorkspaceShortcut candidate = WorkspaceShortcut(
      key: key,
      primary: macOS ? keyboard.isMetaPressed : keyboard.isControlPressed,
      shift: keyboard.isShiftPressed,
      alt: keyboard.isAltPressed,
      secondary: macOS ? keyboard.isControlPressed : keyboard.isMetaPressed,
    );
    if (!candidate.hasModifier) {
      setState(() {
        _validationMessage = context.l10n.includeAtLeastOneModifierKey;
      });
      return KeyEventResult.handled;
    }
    setState(() {
      _recording = false;
      _validationMessage = null;
    });
    _focusNode.unfocus();
    unawaited(_save(candidate));
    return KeyEventResult.handled;
  }

  Future<void> _save(WorkspaceShortcut candidate) async {
    final bool accepted = await widget.onChanged(candidate);
    if (!accepted && mounted) {
      setState(() {
        _validationMessage =
            context.l10n.thisConflictsWithAnotherDingDongOrSystemShortcut;
      });
    }
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
            Semantics(
              button: true,
              label: _recording
                  ? context.l10n.semanticlabelWaitingForAShortcut(
                      widget.semanticLabel,
                    )
                  : '${widget.semanticLabel}, ${widget.value.label(platform)}',
              hint: context.l10n.pressToRecordADifferentShortcut,
              child: ExcludeSemantics(
                child: Focus(
                  focusNode: _focusNode,
                  onKeyEvent: _handleKeyEvent,
                  child: DesktopActionButton(
                    key: Key('settings-workspace-shortcut-${widget.settingId}'),
                    onPressed: _recording ? _cancelRecording : _startRecording,
                    label: Text(
                      _recording
                          ? context.l10n.pressAShortcut
                          : widget.value.label(platform),
                    ),
                    minWidth: 172,
                    height: 38,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              enabled: widget.value != widget.defaultValue,
              label: context.l10n.resetSemanticLabel(widget.semanticLabel),
              child: ExcludeSemantics(
                child: DesktopActionButton(
                  key: Key(
                    'settings-workspace-shortcut-${widget.settingId}-reset',
                  ),
                  onPressed: widget.value == widget.defaultValue
                      ? null
                      : () => unawaited(_save(widget.defaultValue)),
                  label: context.l10n.reset,
                  compact: true,
                ),
              ),
            ),
          ],
        ),
        if (_validationMessage != null) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            _validationMessage!,
            key: Key(
              'settings-workspace-shortcut-${widget.settingId}-validation',
            ),
            textAlign: TextAlign.end,
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
  return shortcutKeyForLogicalKey(key);
}
