import 'dart:async';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

typedef JevAction =
    Future<Map<String, Object?>> Function(
      String action,
      Map<String, Object?> arguments,
    );

class JevPluginSection extends StatefulWidget {
  const JevPluginSection({required this.action, super.key});
  final JevAction action;
  @override
  State<JevPluginSection> createState() => _JevPluginSectionState();
}

class _JevPluginSectionState extends State<JevPluginSection> {
  final _keyController = TextEditingController();
  Map<String, Object?>? _status;
  String? _error;
  bool _busy = false;
  bool _verified = false;
  @override
  void initState() {
    super.initState();
    unawaited(_run('status'));
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _run(
    String action, [
    Map<String, Object?> arguments = const {},
  ]) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _verified = false;
    });
    try {
      final result = await widget.action(action, arguments);
      if (!mounted) return;
      setState(() {
        _status = result;
        _verified = result['verificationSucceeded'] == true;
      });
      if (action == 'saveKey' ||
          action == 'uninstall' ||
          action == 'removeKey') {
        _keyController.clear();
      }
    } catch (error) {
      if (!mounted) return;
      // Error text can cross a native window channel; only expose known codes.
      final text = error.toString();
      setState(() {
        _error = [
          'invalid_key',
          'key_required',
          'disabled',
          'not_installed',
          'http_',
          'request_failed',
          'invalid_response',
        ].firstWhere(text.contains, orElse: () => 'local_storage_failed');
      });
      try {
        final latest = await widget.action('status', {});
        if (mounted) setState(() => _status = latest);
      } on Object {
        /* Keep previous state; never replace unavailable usage with zero. */
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final installed = _status?['installed'] == true;
    final configured = _status?['configured'] == true;
    final enabled = _status?['enabled'] == true;
    String errorText() => switch (_error) {
      'invalid_key' || 'key_required' => l.jevKeyError,
      'disabled' || 'not_installed' => l.jevDisabledError,
      'http_' || 'request_failed' || 'invalid_response' => l.jevRequestError,
      _ => l.jevStorageError,
    };
    Widget button(
      String key,
      String label,
      IconData icon,
      VoidCallback? action,
    ) => DesktopActionButton(
      key: Key(key),
      label: label,
      icon: icon,
      style: ButtonStyle(
        textStyle: WidgetStatePropertyAll(
          Theme.of(context).textTheme.labelLarge,
        ),
      ),
      onPressed: _busy ? null : action,
      tone: DesktopActionTone.neutral,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Jev',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (_status != null)
                button(
                  installed ? 'jev-uninstall' : 'jev-install',
                  installed ? l.jevUninstall : l.jevInstall,
                  installed
                      ? Icons.remove_circle_outline
                      : Icons.download_outlined,
                  () => unawaited(_run(installed ? 'uninstall' : 'install')),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(l.jevDescription),
          const SizedBox(height: 6),
          Text(l.jevBundled, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              button('jev-website', l.jevWebsite, Icons.open_in_new, () async {
                await launchUrl(Uri.parse('https://typesafe.ai/'));
              }),
              button('jev-console', l.jevConsole, Icons.open_in_new, () async {
                await launchUrl(Uri.parse('https://console.typesafe.ai/usage'));
              }),
            ],
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                errorText(),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            if (_status == null)
              button(
                'jev-retry',
                l.jevRetry,
                Icons.refresh,
                () => unawaited(_run('status')),
              ),
          ],
          if (installed) ...[
            const SizedBox(height: 18),
            Text(l.jevKeyLabel, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 6),
            DesktopTextField(
              key: const Key('jev-api-key'),
              controller: _keyController,
              obscureText: true,
              enabled: !_busy,
              decoration: InputDecoration(
                hintText: configured ? l.jevKeySaved : l.jevKeyMissing,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                button(
                  'jev-save-key',
                  l.jevSaveKey,
                  Icons.save_outlined,
                  () =>
                      unawaited(_run('saveKey', {'key': _keyController.text})),
                ),
                if (configured)
                  button(
                    'jev-remove-key',
                    l.jevRemoveKey,
                    Icons.key_off_outlined,
                    () => unawaited(_run('removeKey')),
                  ),
              ],
            ),
            CompactSwitchListTile(
              key: const Key('jev-enabled'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.jevEnable),
              subtitle: Text(l.jevEnableHint),
              value: enabled,
              onChanged: _busy || !configured
                  ? null
                  : (value) => unawaited(_run('enable', {'enabled': value})),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                button(
                  'jev-verify',
                  l.jevVerify,
                  Icons.check_circle_outline,
                  enabled && configured
                      ? () => unawaited(_run('verify'))
                      : null,
                ),
                button(
                  'jev-refresh',
                  l.jevRefresh,
                  Icons.refresh,
                  () => unawaited(_run('status')),
                ),
              ],
            ),
            if (_verified)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(liveRegion: true, child: Text(l.jevVerified)),
              ),
            const SizedBox(height: 12),
            Text(l.jevReconnect, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 20),
            Text(
              l.jevUsageTitle,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Text(l.jevUsageHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            _usageTable(context),
            const SizedBox(height: 12),
            Text(
              l.jevUninstallHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _usageTable(BuildContext context) {
    final l = context.l10n;
    final today = Map<String, Object?>.from(_status!['today']! as Map);
    final all = Map<String, Object?>.from(_status!['usage']! as Map);
    final labels = {
      'requests': l.jevRequests,
      'input_tokens': l.jevInput,
      'output_tokens': l.jevOutput,
      'unknown_usage_requests': l.jevUnknown,
    };
    String value(Map<String, Object?> usage, String key) =>
        '${usage[key] ?? '—'}';
    Widget cell(String text, {bool header = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Text(
        text,
        style: header
            ? Theme.of(context).textTheme.labelMedium
            : Theme.of(context).textTheme.bodySmall,
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (all['requests'] == 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(l.jevEmpty),
          ),
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1.4),
            1: FlexColumnWidth(),
            2: FlexColumnWidth(),
          },
          children: [
            TableRow(
              children: [
                cell(''),
                cell(l.jevToday, header: true),
                cell(l.jevAllTime, header: true),
              ],
            ),
            for (final entry in labels.entries)
              TableRow(
                children: [
                  cell(entry.value),
                  cell(value(today, entry.key)),
                  cell(value(all, entry.key)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
