import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_disclosure.dart';
import 'package:dingdong/features/plugins/domain/plugin_source.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Visible attribution requested by the user, in addition to source comments
/// and the distributed license notices. This never installs upstream code.
class PluginSourceNote extends StatefulWidget {
  const PluginSourceNote({required this.source, super.key});
  final PluginSource source;

  @override
  State<PluginSourceNote> createState() => _PluginSourceNoteState();
}

class _PluginSourceNoteState extends State<PluginSourceNote> {
  bool _checking = false;
  bool _failed = false;
  PluginUpstreamState? _state;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _failed = false;
      _state = null;
    });
    try {
      final state = await widget.source.checkForChanges();
      if (mounted) setState(() => _state = state);
    } on Object {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final source = widget.source;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: DesktopDisclosure(
        title: Text(
          l.pluginOpenSource,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${source.name} · ${source.displayVersion} · ${source.license}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              l.pluginSelectionSourceNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                DesktopActionButton(
                  label: l.pluginViewSource,
                  icon: Icons.open_in_new_rounded,
                  onPressed: () async {
                    try {
                      if (!await launchUrl(Uri.parse(source.url))) {
                        if (mounted) setState(() => _failed = true);
                      }
                    } on Object {
                      if (mounted) setState(() => _failed = true);
                    }
                  },
                ),
                DesktopActionButton(
                  label: l.pluginCheckUpstream,
                  icon: Icons.sync_rounded,
                  onPressed: _checking ? null : () => unawaited(_check()),
                ),
                DesktopActionButton(
                  label: l.pluginLicenses,
                  icon: Icons.description_outlined,
                  onPressed: () => showLicensePage(
                    context: context,
                    applicationName: 'DingDong',
                  ),
                ),
              ],
            ),
            if (_checking) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_failed || _state != null) ...[
              const SizedBox(height: 10),
              Text(
                _failed
                    ? l.pluginUpstreamUnavailable
                    : _state == PluginUpstreamState.changed
                    ? l.pluginUpstreamChanged
                    : l.pluginUpstreamCurrent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
