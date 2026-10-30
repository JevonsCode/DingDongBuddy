import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:dingdong/features/agent_api/domain/agent_install.dart';
import 'package:flutter/material.dart';

/// Finds the Agents on this computer and installs DingDong's MCP server and
/// Hooks into the ones the person selects, after showing the file changes.
class AgentInstallCard extends StatefulWidget {
  const AgentInstallCard({
    required this.gateway,
    this.onScanCompleted,
    super.key,
  });

  final AgentInstallGateway gateway;
  final ValueChanged<List<AgentInstallClient>>? onScanCompleted;

  @override
  State<AgentInstallCard> createState() => _AgentInstallCardState();
}

class _AgentInstallCardState extends State<AgentInstallCard> {
  List<AgentInstallClient>? _clients;
  final Set<String> _selected = <String>{};
  List<AgentInstallOutcome> _results = const <AgentInstallOutcome>[];
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    unawaited(_scan(selectDefaults: true));
  }

  Future<void> _scan({bool selectDefaults = false}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final List<AgentInstallClient> clients = await widget.gateway.scan();
      if (!mounted) return;
      widget.onScanCompleted?.call(clients);
      setState(() {
        _clients = clients;
        final Set<String> offered = <String>{
          for (final AgentInstallClient c in _visible(clients))
            if (c.state.installable) c.id,
        };
        _selected.retainAll(offered);
        if (selectDefaults) {
          _selected.addAll(<String>[
            for (final AgentInstallClient c in _visible(clients))
              if (c.state.installable) c.id,
          ]);
        }
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Clients worth showing: found on this computer, or set up by hand.
  static List<AgentInstallClient> _visible(List<AgentInstallClient> clients) =>
      <AgentInstallClient>[
        for (final AgentInstallClient c in clients)
          if (c.detected && c.state != AgentInstallState.unsupported) c,
      ];

  Future<void> _install() async {
    final List<String> ids = _selected.toList();
    setState(() => _busy = true);
    try {
      final List<AgentInstallOutcome> plan = await widget.gateway.plan(ids);
      if (!mounted) return;
      setState(() => _busy = false);
      final bool confirmed = await _confirm(
        title: context.l10n.agentInstallPreviewTitle,
        outcomes: plan,
        confirmLabel: context.l10n.agentInstallConfirm,
        dialogKey: const Key('agent-install-preview'),
      );
      if (!confirmed || !mounted) return;
      await _write(() => widget.gateway.apply(ids));
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _remove(AgentInstallClient client) async {
    setState(() => _busy = true);
    try {
      final plan = await widget.gateway.planRemoval([client.id]);
      if (!mounted) return;
      setState(() => _busy = false);
      final confirmed = await _confirm(
        title: context.l10n.agentInstallRemoveTitle(client.name),
        description: widget.gateway.previewOnly
            ? context.l10n.agentInstallRemovePreviewDescription
            : context.l10n.agentInstallRemoveDescription,
        outcomes: plan,
        confirmLabel: context.l10n.agentInstallRemove,
        dialogKey: const Key('agent-install-remove-dialog'),
        danger: true,
      );
      if (!confirmed || !mounted) return;
      await _write(() => widget.gateway.remove([client.id]));
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = '$error';
        });
      }
    }
  }

  Future<void> _write(Future<List<AgentInstallOutcome>> Function() run) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final List<AgentInstallOutcome> results = await run();
      if (!mounted) return;
      setState(() => _results = results);
    } on Object catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
    await _scan();
  }

  Future<bool> _confirm({
    required String title,
    required String confirmLabel,
    required Key dialogKey,
    List<AgentInstallOutcome>? outcomes,
    String? description,
    bool danger = false,
  }) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        final PopupPalette palette = PopupStyle.of(dialogContext);
        final List<AgentInstallOutcome> withChanges = <AgentInstallOutcome>[
          for (final AgentInstallOutcome o
              in outcomes ?? <AgentInstallOutcome>[])
            if (o.changes.isNotEmpty || o.problems.isNotEmpty) o,
        ];
        final bool nothingToDo =
            outcomes != null &&
            withChanges.every((AgentInstallOutcome o) => o.changes.isEmpty);
        return DesktopAlertDialog(
          key: dialogKey,
          title: Text(title),
          maxWidth: 480,
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                description ??
                    (nothingToDo
                        ? dialogContext.l10n.agentInstallNoChanges
                        : widget.gateway.previewOnly
                        ? dialogContext.l10n.agentInstallPreviewOnlyDescription
                        : dialogContext.l10n.agentInstallPreviewDescription),
              ),
              for (final AgentInstallOutcome o in withChanges) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  o.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                for (final AgentInstallChange c in o.changes)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${_actionLabel(dialogContext, c.action)}  ${c.path}'
                      '${c.components.isEmpty ? '' : '\n${c.components.map((component) => _componentLabel(dialogContext, component)).join(' · ')}'}',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                for (final String p in o.problems)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      p,
                      style: TextStyle(
                        color: Theme.of(dialogContext).colorScheme.error,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ],
          ),
          actions: <Widget>[
            DesktopActionButton(
              key: const Key('agent-install-cancel'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
              label: widget.gateway.previewOnly
                  ? dialogContext.l10n.close
                  : dialogContext.l10n.cancel,
            ),
            if (!nothingToDo && !widget.gateway.previewOnly)
              DesktopActionButton(
                key: const Key('agent-install-confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                label: confirmLabel,
                tone: danger
                    ? DesktopActionTone.danger
                    : DesktopActionTone.primary,
              ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  static String _componentLabel(BuildContext context, String component) =>
      switch (component) {
        'mcp' => 'MCP',
        'hooks' => 'Hooks',
        'instructions' => context.l10n.agentInstallInstructions,
        'skills' => 'Skills',
        _ => component,
      };

  static String _actionLabel(BuildContext context, String action) =>
      switch (action) {
        'create' => context.l10n.agentInstallChangeCreate,
        'delete' => context.l10n.agentInstallChangeDelete,
        _ => context.l10n.agentInstallChangeUpdate,
      };

  @override
  Widget build(BuildContext context) {
    final PopupPalette palette = PopupStyle.of(context);
    final List<AgentInstallClient>? clients = _clients;
    final List<AgentInstallClient> visible = clients == null
        ? const <AgentInstallClient>[]
        : _visible(clients);
    return Column(
      key: const Key('agent-install-card'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.agentInstallTitle,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          widget.gateway.previewOnly
              ? context.l10n.agentInstallPreviewOnlyDescription
              : context.l10n.agentInstallDescription,
          key: widget.gateway.previewOnly
              ? const Key('agent-install-preview-only')
              : null,
          style: TextStyle(
            color: palette.textSecondary,
            fontSize: 10.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        if (clients == null)
          Text(
            context.l10n.agentInstallScanning,
            style: TextStyle(color: palette.textSecondary, fontSize: 11),
          )
        else if (visible.isEmpty)
          Text(
            context.l10n.agentInstallNoClients,
            key: const Key('agent-install-empty'),
            style: TextStyle(color: palette.textSecondary, fontSize: 11),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: palette.field,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: <Widget>[
                for (final AgentInstallClient c in visible)
                  _ClientRow(
                    client: c,
                    selected: _selected.contains(c.id),
                    enabled: !_busy,
                    onChanged: c.state.installable
                        ? (bool value) => setState(() {
                            value
                                ? _selected.add(c.id)
                                : _selected.remove(c.id);
                          })
                        : null,
                    onRemove: c.state.removable && !_busy
                        ? () => unawaited(_remove(c))
                        : null,
                  ),
              ],
            ),
          ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            DesktopActionButton(
              key: const Key('agent-install-selected'),
              onPressed: _busy || _selected.isEmpty
                  ? null
                  : () => unawaited(_install()),
              icon: const Icon(Icons.download_done_rounded, size: 16),
              label: widget.gateway.previewOnly
                  ? context.l10n.agentInstallPreviewSelected
                  : context.l10n.agentInstallSelected,
              tone: DesktopActionTone.primary,
              compact: true,
            ),
            DesktopActionButton(
              key: const Key('agent-install-rescan'),
              onPressed: _busy ? null : () => unawaited(_scan()),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: context.l10n.agentInstallRescan,
              compact: true,
            ),
          ],
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _error!,
            key: const Key('agent-install-error'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontSize: 11,
            ),
          ),
        ],
        for (final AgentInstallOutcome r in _results)
          ..._resultLines(context, r),
      ],
    );
  }

  List<Widget> _resultLines(BuildContext context, AgentInstallOutcome r) {
    final PopupPalette palette = PopupStyle.of(context);
    final List<String> lines = <String>[
      ...r.problems,
      if (r.needsHookTrust) context.l10n.agentInstallTrustCodexHooks,
      if (r.needsRestart) context.l10n.agentInstallRestartClient(r.name),
    ];
    return <Widget>[
      for (final String line in lines)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            line,
            style: TextStyle(
              color: r.problems.contains(line)
                  ? Theme.of(context).colorScheme.error
                  : palette.textPrimary,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ),
    ];
  }
}

class _ClientRow extends StatelessWidget {
  const _ClientRow({
    required this.client,
    required this.selected,
    required this.enabled,
    required this.onChanged,
    required this.onRemove,
  });

  final AgentInstallClient client;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool>? onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final PopupPalette palette = PopupStyle.of(context);
    final ValueChanged<bool>? toggle = enabled ? onChanged : null;
    return Semantics(
      checked: onChanged == null ? null : selected,
      enabled: toggle != null,
      child: FocusableActionDetector(
        key: Key('agent-install-client-${client.id}'),
        enabled: toggle != null,
        mouseCursor: toggle == null
            ? MouseCursor.defer
            : SystemMouseCursors.click,
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) => toggle?.call(!selected),
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: toggle == null ? null : () => toggle(!selected),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 10, 7),
            child: Row(
              children: <Widget>[
                SizedBox.square(
                  dimension: 18,
                  child: onChanged != null
                      ? SelectionMark(selected: selected)
                      : client.state == AgentInstallState.connected
                      ? Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: palette.success,
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        client.name,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (client.problem != null)
                        Text(
                          client.problem!,
                          style: TextStyle(
                            color: palette.textTertiary,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
                Text(
                  _stateLabel(context, client.state),
                  key: Key('agent-install-state-${client.id}'),
                  style: TextStyle(
                    color: switch (client.state) {
                      AgentInstallState.connected => palette.success,
                      AgentInstallState.conflict => Theme.of(
                        context,
                      ).colorScheme.error,
                      _ => palette.textSecondary,
                    },
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (onRemove != null) ...<Widget>[
                  const SizedBox(width: 6),
                  DesktopActionButton(
                    key: Key('agent-install-remove-${client.id}'),
                    onPressed: onRemove,
                    label: context.l10n.agentInstallRemove,
                    tone: DesktopActionTone.neutral,
                    compact: true,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _stateLabel(BuildContext context, AgentInstallState state) =>
      switch (state) {
        AgentInstallState.connected => context.l10n.agentInstallStateConnected,
        AgentInstallState.updateAvailable =>
          context.l10n.agentInstallStateUpdateAvailable,
        AgentInstallState.notConnected =>
          context.l10n.agentInstallStateNotConnected,
        AgentInstallState.conflict => context.l10n.agentInstallStateConflict,
        AgentInstallState.manual => context.l10n.agentInstallStateManual,
        AgentInstallState.unsupported =>
          context.l10n.agentInstallStateUnsupported,
      };
}
