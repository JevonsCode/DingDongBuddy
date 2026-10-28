import 'dart:io';
import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/features/settings/data/voice_catalog_service.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';
import 'package:dingdong/features/settings/domain/sound_preview_gateway.dart';
import 'package:dingdong/features/settings/domain/voice_catalog.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:dingdong/features/settings/ui/voice_install_dialog.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

enum _VoiceFilter { all, installed, notInstalled }

typedef _VoiceRow = ({CatalogVoice? voice, ReminderAudio? saved});

/// Opened explicitly from settings: no startup network request or auto-import.
class VoiceCatalogDialog extends StatefulWidget {
  const VoiceCatalogDialog({
    required this.viewModel,
    this.service,
    this.directory,
    this.previewGateway,
    super.key,
  });
  final SettingsViewModel viewModel;
  final VoiceCatalogGateway? service;
  final Directory? directory;
  final SoundPreviewGateway? previewGateway;
  @override
  State<VoiceCatalogDialog> createState() => _VoiceCatalogDialogState();
}

class _VoiceCatalogDialogState extends State<VoiceCatalogDialog> {
  late final VoiceCatalogGateway _service =
      widget.service ?? VoiceCatalogService();
  final List<CatalogVoice> _voices = [];
  final TextEditingController _search = TextEditingController();
  bool _loading = false, _more = false;
  int _page = 0;
  _VoiceFilter _filter = _VoiceFilter.all;
  int? _subscribing;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = refresh ? 1 : _page + 1;
      final result = await _service.load(page: page, refresh: refresh);
      if (!mounted) return;
      setState(() {
        if (refresh) _voices.clear();
        final ids = _voices.map((v) => v.number).toSet();
        _voices.addAll(result.voices.where((v) => !ids.contains(v.number)));
        _page = page;
        _more = result.hasMore;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _error = context.l10n.voiceCatalogLoadFailed;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _findIssue() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final voice = await _service.findIssue(_search.text);
      if (!mounted) return;
      setState(() {
        _voices.removeWhere((v) => v.number == voice.number);
        _voices.insert(0, voice);
        _filter = _VoiceFilter.all;
      });
    } on Object {
      if (mounted) {
        setState(() {
          _error = context.l10n.voiceCatalogFindFailed;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _subscribe(CatalogVoice voice) async {
    if (_subscribing != null) return;
    setState(() => _subscribing = voice.number);
    await showDialog<void>(
      context: context,
      builder: (_) => VoiceInstallDialog(
        issueNumber: voice.number,
        viewModel: widget.viewModel,
        service: _service,
        directory: widget.directory,
        previewGateway: widget.previewGateway,
      ),
    );
    if (mounted) setState(() => _subscribing = null);
  }

  Future<void> _unsubscribe(String issueUrl) async {
    final rules = widget.viewModel.settings.notificationRules;
    // No file deletion and no selected-profile edits. Existing active sounds
    // continue playing until the user selects a replacement.
    await widget.viewModel.setNotificationRules(
      rules.copyWith(
        audioLibrary: rules.audioLibrary
            .where((a) => a.sourceIssue != issueUrl)
            .toList(),
      ),
    );
    if (mounted) {
      setState(() {
        _error = widget.viewModel.errorMessage;
      });
    }
  }

  Future<void> _open(Uri uri) async {
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        setState(() {
          _error = context.l10n.voiceCatalogLinkFailed;
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _error = context.l10n.voiceCatalogLinkFailed;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final query = _search.text.trim().toLowerCase();
    final savedVoices = widget.viewModel.settings.notificationRules.audioLibrary
        .where((audio) => audio.sourceIssue != null)
        .toList();
    final savedByIssue = {
      for (final audio in savedVoices) audio.sourceIssue!: audio,
    };
    final loadedIssues = _voices
        .map((voice) => voice.issueUrl.toString())
        .toSet();
    final rows = <_VoiceRow>[
      for (final voice in _voices)
        (voice: voice, saved: savedByIssue[voice.issueUrl.toString()]),
      for (final audio in savedVoices)
        if (!loadedIssues.contains(audio.sourceIssue))
          (voice: null, saved: audio),
    ];
    final visible = rows.where((row) {
      final installed = row.saved != null;
      if (_filter == _VoiceFilter.installed && !installed) return false;
      if (_filter == _VoiceFilter.notInstalled && installed) return false;
      final voice = row.voice;
      final saved = row.saved;
      final text = voice != null
          ? '${voice.title} ${voice.author} ${voice.description} ${voice.issueUrl}'
          : '${voiceDisplayTitle(saved!.name)} ${saved.sourceAuthor ?? ''} ${saved.sourceIssue ?? ''}';
      return query.isEmpty || text.toLowerCase().contains(query);
    }).toList();
    return DesktopAlertDialog(
      maxWidth: 660,
      title: Text(l10n.voiceCatalogTitle),
      content: SizedBox(
        width: 620,
        height: (MediaQuery.sizeOf(context).height - 220).clamp(180.0, 490.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DesktopTextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) {
                      if (_search.text.trim().startsWith('https://')) {
                        _findIssue();
                      }
                    },
                    decoration: InputDecoration(
                      labelText: l10n.voiceCatalogSearch,
                      suffixIcon: DesktopIconButton(
                        tooltip: l10n.voiceCatalogFindIssue,
                        onPressed: _loading ? null : _findIssue,
                        icon: const Icon(Icons.link),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 148,
                  child: DesktopSelectField<_VoiceFilter>(
                    key: const Key('voice-catalog-filter'),
                    value: _filter,
                    semanticLabel: l10n.voiceCatalogFilter,
                    items: [
                      DesktopSelectItem(
                        value: _VoiceFilter.all,
                        label: l10n.all,
                      ),
                      DesktopSelectItem(
                        value: _VoiceFilter.installed,
                        label: l10n.voiceCatalogFilterInstalled,
                      ),
                      DesktopSelectItem(
                        value: _VoiceFilter.notInstalled,
                        label: l10n.notInstalled,
                      ),
                    ],
                    onChanged: (value) => setState(() => _filter = value),
                  ),
                ),
              ],
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_loading) const LinearProgressIndicator(),
            Expanded(
              child: ListView(
                children: [
                  const SizedBox(height: 8),
                  if (!_loading && visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.voiceCatalogEmpty),
                    ),
                  for (final row in visible)
                    Container(
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  row.voice?.title ??
                                      voiceDisplayTitle(row.saved!.name),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                if ((row.voice?.author ??
                                        row.saved?.sourceAuthor)
                                    case final String author) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '@$author',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (row.voice != null ||
                              Uri.tryParse(row.saved!.sourceIssue!) != null)
                            DesktopIconButton(
                              tooltip: 'GitHub',
                              onPressed: () => _open(
                                row.voice?.issueUrl ??
                                    Uri.parse(row.saved!.sourceIssue!),
                              ),
                              icon: const Icon(Icons.open_in_new, size: 17),
                            ),
                          const SizedBox(width: 8),
                          DesktopActionButton(
                            tone: row.saved != null
                                ? DesktopActionTone.neutral
                                : DesktopActionTone.primary,
                            onPressed: _subscribing != null
                                ? null
                                : row.saved != null
                                ? () => _unsubscribe(row.saved!.sourceIssue!)
                                : () => _subscribe(row.voice!),
                            label: row.saved != null
                                ? l10n.voiceCatalogUnsubscribe
                                : l10n.voiceCatalogSubscribe,
                          ),
                        ],
                      ),
                    ),
                  if (_more && _filter != _VoiceFilter.installed)
                    DesktopActionButton(
                      onPressed: _loading || _page >= 10 ? null : () => _load(),
                      child: Text(
                        _page >= 10
                            ? l10n.voiceCatalogPageLimit
                            : l10n.voiceCatalogLoadMore,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        DesktopActionButton(
          onPressed: () => _open(
            voiceCatalogWebsiteUri(
              development: AppDataPaths.current().development,
            ),
          ),
          child: Text(l10n.voiceCatalogWebsite),
        ),
        DesktopActionButton(
          onPressed: _loading ? null : () => _load(refresh: true),
          child: Text(l10n.voiceCatalogRefresh),
        ),
        DesktopActionButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
