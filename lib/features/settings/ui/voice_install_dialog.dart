import 'dart:async';
import 'dart:io';

import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_disclosure.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/features/settings/data/voice_catalog_service.dart';
import 'package:dingdong/features/settings/domain/sound_preview_gateway.dart';
import 'package:dingdong/features/settings/domain/voice_catalog.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

/// Shows a fresh public submission and installs it only after confirmation.
class VoiceInstallDialog extends StatefulWidget {
  const VoiceInstallDialog({
    required this.issueNumber,
    required this.viewModel,
    this.service,
    this.directory,
    this.previewGateway,
    super.key,
  });

  final int issueNumber;
  final SettingsViewModel viewModel;
  final VoiceCatalogGateway? service;
  final Directory? directory;
  final SoundPreviewGateway? previewGateway;

  @override
  State<VoiceInstallDialog> createState() => _VoiceInstallDialogState();
}

class _VoiceInstallDialogState extends State<VoiceInstallDialog> {
  late final VoiceCatalogGateway _service =
      widget.service ?? VoiceCatalogService();
  CatalogVoice? _voice;
  String? _error;
  bool _loading = true, _busy = false, _installed = false;
  bool _justInstalled = false;
  bool _previewInFlight = false;
  Directory? _previewDirectory;
  DateTime? _previewPlayingUntil;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    final directory = _previewDirectory;
    if (directory != null && !_previewInFlight) {
      unawaited(_removePreviewAfterPlayback(directory));
    }
    super.dispose();
  }

  Future<void> _removePreview(Directory directory) async {
    try {
      if (await directory.exists()) await directory.delete(recursive: true);
    } on FileSystemException {
      // Preview files are temporary and never registered as installed sounds.
    }
  }

  Future<void> _removePreviewAfterPlayback(Directory directory) async {
    final remaining = _previewPlayingUntil?.difference(DateTime.now());
    if (remaining != null && remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
    await _removePreview(directory);
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final voice = await _service.findIssue(
        'https://github.com/$voiceCatalogRepository/issues/${widget.issueNumber}',
      );
      if (mounted) {
        setState(() {
          _voice = voice;
          _installed = widget.viewModel.settings.notificationRules.audioLibrary
              .any((audio) => audio.sourceIssue == voice.issueUrl.toString());
        });
      }
    } on Object {
      if (mounted) setState(() => _error = context.l10n.voiceCatalogLoadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _preview() async {
    if (_voice == null || _busy || widget.previewGateway == null) return;
    setState(() {
      _busy = true;
      _previewInFlight = true;
      _error = null;
    });
    Directory? directory;
    try {
      directory = _previewDirectory ??= await Directory.systemTemp.createTemp(
        'dingdong-voice-preview-',
      );
      if (!mounted) return;
      final audio = await _service.subscribe(_voice!, directory);
      if (mounted) {
        // Native preview returns before playback necessarily finishes.
        _previewPlayingUntil = DateTime.now().add(const Duration(seconds: 4));
        await widget.previewGateway!.preview(
          sound: 'custom',
          customSoundPath: audio.path,
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.voiceInstallPreviewFailed);
      }
    } finally {
      _previewInFlight = false;
      if (!mounted && directory != null) {
        await _removePreviewAfterPlayback(directory);
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install() async {
    final voice = _voice;
    if (voice == null || _busy) return;
    final existing = widget.viewModel.settings.notificationRules.audioLibrary;
    if (existing.length >= 64 &&
        !existing.any((a) => a.sourceIssue == voice.issueUrl.toString())) {
      setState(() => _error = context.l10n.voiceCatalogFull);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final directory =
          widget.directory ??
          Directory(
            '${AppDataPaths.current().applicationSupportDirectory.path}/Reminder Sounds',
          );
      final audio = await _service.subscribe(voice, directory);
      if (!mounted) return;
      final rules = widget.viewModel.settings.notificationRules;
      if (rules.audioLibrary.length >= 64 &&
          !rules.audioLibrary.any((a) => a.sourceIssue == audio.sourceIssue)) {
        throw const FormatException('Library full.');
      }
      await widget.viewModel.setNotificationRules(
        rules.copyWith(
          audioLibrary: [
            ...rules.audioLibrary.where(
              (a) => a.sourceIssue != audio.sourceIssue,
            ),
            audio,
          ],
        ),
      );
      if (mounted) {
        setState(() {
          _error = widget.viewModel.errorMessage;
          _installed = _error == null;
          _justInstalled = _installed;
        });
      }
    } on Object {
      if (mounted) {
        setState(() => _error = context.l10n.voiceCatalogSubscribeFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final voice = _voice;
    return DesktopAlertDialog(
      title: Text(l10n.voiceInstallTitle),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (voice != null) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        voice.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${voice.author}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (widget.previewGateway != null)
                  DesktopIconButton(
                    tooltip: l10n.previewSound,
                    semanticLabel: l10n.previewSound,
                    onPressed: _busy ? null : _preview,
                    icon: const Icon(Icons.volume_up_outlined, size: 20),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            DesktopDisclosure(
              title: Text(l10n.voiceInstallDetails),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.voiceInstallContributorInfo,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(voice.description),
                  const SizedBox(height: 8),
                  SelectableText(
                    '${l10n.voiceInstallLicense}: ${voice.license}',
                  ),
                  const SizedBox(height: 8),
                  SelectableText('${l10n.source}: ${voice.source}'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _justInstalled
                  ? l10n.voiceInstallSuccess
                  : _installed
                  ? l10n.voiceInstallPresent
                  : l10n.voiceInstallConfirm,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        if (voice == null && _error != null)
          DesktopActionButton(
            onPressed: _loading ? null : _load,
            label: l10n.voiceCatalogRefresh,
          ),
        DesktopActionButton(
          onPressed: () => Navigator.of(context).pop(),
          label: _installed ? l10n.close : l10n.cancel,
        ),
        DesktopActionButton(
          onPressed: _loading || _busy || voice == null ? null : _install,
          tone: DesktopActionTone.primary,
          label: _busy
              ? l10n.voiceCatalogDownloading
              : _installed
              ? l10n.voiceInstallReinstall
              : l10n.voiceCatalogSubscribe,
        ),
      ],
    );
  }
}
