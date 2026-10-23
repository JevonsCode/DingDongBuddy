import 'dart:async';
import 'dart:convert';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/features/plugins/domain/plugin_source.dart';
import 'package:dingdong/features/plugins/ui/plugin_source_note.dart';
import 'package:dingdong/features/screenshot/domain/screenshot_plugin.dart';
import 'package:dingdong/features/settings/domain/global_hot_key.dart';
import 'package:dingdong/features/settings/ui/global_hot_key_recorder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ScreenshotPluginSection extends StatefulWidget {
  const ScreenshotPluginSection({required this.action, super.key});
  final ScreenshotAction action;
  @override
  State<ScreenshotPluginSection> createState() =>
      _ScreenshotPluginSectionState();
}

class _ScreenshotPluginSectionState extends State<ScreenshotPluginSection> {
  Map<String, Object?>? _status;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_run('status'));
  }

  Future<void> _run(
    String action, [
    Map<String, Object?> values = const {},
  ]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.action(action, values);
      if (mounted) {
        setState(() {
          _status = result;
        });
      }
    } on Object catch (error) {
      final known = error is ScreenshotPluginException
          ? error.code
          : error.toString();
      const codes = [
        'shortcut_conflict',
        'invalid_shortcut',
        'persistence_failed',
        'rollback_failed',
        'capture_failed',
        'capture_busy',
      ];
      final code = codes.firstWhere(
        known.contains,
        orElse: () => 'unavailable',
      );
      // A failed mutation may have changed the native state during rollback.
      // Re-read it before displaying any old successful registration.
      try {
        final latest = await widget.action('status', {});
        if (mounted) {
          setState(() {
            _status = latest;
          });
        }
      } on Object {
        if (mounted) {
          setState(() {
            _status = null;
          });
        }
      }
      if (mounted) {
        setState(() {
          _error = code;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final supported = _status?['supported'] == true;
    final enabled = _status?['enabled'] == true;
    final running = _status?['running'] == true;
    final capturing = _status?['capturing'] == true;
    final code = _error ?? _status?['error'] as String?;
    final String? errorText = switch (code) {
      null => null,
      'shortcut_conflict' || 'invalid_shortcut' => l.screenshotConflict,
      'persistence_failed' => l.screenshotPersistenceError,
      'rollback_failed' => l.screenshotRollbackError,
      'capture_failed' => l.screenshotCaptureError,
      'capture_busy' => l.screenshotCapturing,
      _ => l.screenshotUnavailable,
    };
    final config = ScreenshotConfiguration.parse(jsonEncode(_status));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.screenshotPluginTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(l.screenshotPluginDescription),
        const SizedBox(height: 20),
        if (_busy)
          const LinearProgressIndicator(key: Key('screenshot-loading')),
        if (defaultTargetPlatform != TargetPlatform.windows) ...[
          Text(
            l.screenshotUnsupported,
            key: const Key('screenshot-unsupported'),
          ),
        ] else ...[
          CompactSwitchListTile(
            key: const Key('screenshot-enabled'),
            contentPadding: EdgeInsets.zero,
            title: Text(l.screenshotEnable),
            subtitle: Text(l.screenshotEnableDescription),
            value: enabled,
            onChanged: !_busy && supported
                ? (value) => unawaited(_run('configure', {'enabled': value}))
                : null,
          ),
          const SizedBox(height: 16),
          Text(
            capturing
                ? l.screenshotCapturing
                : running
                ? l.screenshotRunning
                : enabled || !supported && _status != null
                ? l.screenshotUnavailable
                : l.screenshotStopped,
            key: const Key('screenshot-runtime-status'),
          ),
          const SizedBox(height: 24),
          Text(
            l.screenshotShortcut,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: ExcludeFocus(
              excluding: _busy || !supported,
              child: AbsorbPointer(
                absorbing: _busy || !supported,
                child: GlobalHotKeyRecorder(
                  keyPrefix: 'screenshot-hot-key',
                  value: config.shortcut,
                  defaultValue: ScreenshotConfiguration.defaultShortcut,
                  onChanged: (GlobalHotKey shortcut) => _run('configure', {
                    'shortcut': shortcut.toPlatformArguments(),
                  }),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              DesktopActionButton(
                key: const Key('screenshot-capture-now'),
                label: l.screenshotCaptureNow,
                icon: Icons.screenshot_monitor_outlined,
                onPressed: !_busy && supported && enabled && running
                    ? () => unawaited(_run('capture'))
                    : null,
              ),
              DesktopActionButton(
                key: const Key('screenshot-refresh'),
                label: l.refreshStatus,
                icon: Icons.refresh,
                tone: DesktopActionTone.neutral,
                onPressed: _busy ? null : () => unawaited(_run('status')),
              ),
            ],
          ),
        ],
        const PluginSourceNote(source: PluginSource.screenshot),
        if (errorText != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              errorText,
              key: const Key('screenshot-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: 24),
        Text(l.screenshotHelp, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
