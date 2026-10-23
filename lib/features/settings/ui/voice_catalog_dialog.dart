import 'dart:io';
import 'package:dingdong/app/app_data_paths.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/settings/data/voice_catalog_service.dart';
import 'package:dingdong/features/settings/domain/voice_catalog.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opened explicitly from settings: no startup network request or auto-import.
class VoiceCatalogDialog extends StatefulWidget {
  const VoiceCatalogDialog({
    required this.viewModel,
    this.service,
    this.directory,
    super.key,
  });
  final SettingsViewModel viewModel;
  final VoiceCatalogGateway? service;
  final Directory? directory;
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

  Future<void> _subscribe(CatalogVoice voice) async {
    if (_subscribing != null) return;
    if (widget.viewModel.settings.notificationRules.audioLibrary.length >= 64) {
      setState(() {
        _error = context.l10n.voiceCatalogFull;
      });
      return;
    }
    setState(() {
      _subscribing = voice.number;
      _error = null;
    });
    try {
      final directory =
          widget.directory ??
          Directory(
            '${AppDataPaths.current().applicationSupportDirectory.path}/Reminder Sounds',
          );
      final audio = await _service.subscribe(voice, directory);
      // Closing the dialog cancels the settings change. An inert content-addressed
      // file may remain; it is never selected, executed or automatically updated.
      if (!mounted) return;
      final rules = widget.viewModel.settings.notificationRules;
      if (rules.audioLibrary.length >= 64) {
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
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _error = context.l10n.voiceCatalogSubscribeFailed;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _subscribing = null;
        });
      }
    }
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
    final visible = _voices.where(
      (v) =>
          query.isEmpty ||
          '${v.title} ${v.author} ${v.description} ${v.issueUrl}'
              .toLowerCase()
              .contains(query),
    );
    final savedVoices = widget.viewModel.settings.notificationRules.audioLibrary
        .where((audio) => audio.sourceIssue != null)
        .toList();
    final subscriptions = widget
        .viewModel
        .settings
        .notificationRules
        .audioLibrary
        .map((a) => a.sourceIssue)
        .toSet();
    return AlertDialog(
      title: Text(l10n.voiceCatalogTitle),
      content: SizedBox(
        width: 620,
        height: (MediaQuery.sizeOf(context).height - 220).clamp(180.0, 490.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_search.text.trim().startsWith('https://')) _findIssue();
              },
              decoration: InputDecoration(
                labelText: l10n.voiceCatalogSearch,
                suffixIcon: IconButton(
                  tooltip: l10n.voiceCatalogFindIssue,
                  onPressed: _loading ? null : _findIssue,
                  icon: const Icon(Icons.link),
                ),
              ),
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
                  Text(l10n.voiceCatalogHelp),
                  if (savedVoices.isNotEmpty)
                    ExpansionTile(
                      title: Text(l10n.voiceCatalogSubscribed),
                      children: [
                        SizedBox(
                          height: (savedVoices.length * 56.0).clamp(0.0, 168.0),
                          child: ListView(
                            children: [
                              for (final audio in savedVoices)
                                ListTile(
                                  title: Text(
                                    audio.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    [
                                      audio.sourceAuthor,
                                      audio.sourceLicense,
                                      audio.sourceAttribution,
                                    ].whereType<String>().join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: IconButton(
                                    tooltip: l10n.voiceCatalogUnsubscribe,
                                    onPressed: _subscribing != null
                                        ? null
                                        : () =>
                                              _unsubscribe(audio.sourceIssue!),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 12),

                  if (!_loading && visible.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l10n.voiceCatalogEmpty),
                    ),
                  for (final voice in visible)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              voice.title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            Text(
                              '@${voice.author} · ${voice.createdAt.toLocal().toIso8601String().split('T').first}',
                            ),
                            if (voice.description.isNotEmpty)
                              Text(
                                voice.description,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            Text(
                              voice.license,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              voice.source,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                FilledButton(
                                  onPressed: _subscribing != null
                                      ? null
                                      : subscriptions.contains(
                                          voice.issueUrl.toString(),
                                        )
                                      ? () => _unsubscribe(
                                          voice.issueUrl.toString(),
                                        )
                                      : () => _subscribe(voice),
                                  child: Text(
                                    _subscribing == voice.number
                                        ? l10n.voiceCatalogDownloading
                                        : subscriptions.contains(
                                            voice.issueUrl.toString(),
                                          )
                                        ? l10n.voiceCatalogUnsubscribe
                                        : l10n.voiceCatalogSubscribe,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _open(voice.issueUrl),
                                  child: Text(
                                    '👍 ${voice.likes}  👎 ${voice.dislikes} · GitHub',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_more)
                    TextButton(
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
        TextButton(
          onPressed: () => _open(Uri.parse(voiceCatalogWebsite)),
          child: Text(l10n.voiceCatalogWebsite),
        ),
        TextButton(
          onPressed: _loading ? null : () => _load(refresh: true),
          child: Text(l10n.voiceCatalogRefresh),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
      ],
    );
  }
}
