import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:dingdong/features/agent_adapters/domain/agent_adapter.dart';
import 'package:dingdong/features/agent_adapters/domain/agent_adapter_diff.dart';
import 'package:dingdong/features/agent_adapters/domain/codex_completion_hook.dart';
import 'package:dingdong/features/agent_adapters/ui/agent_adapter_controller.dart';
import 'package:flutter/material.dart';

part 'agent_adapter_overview.dart';

class AgentAdapterScreen extends StatefulWidget {
  const AgentAdapterScreen({required this.controller, super.key});

  final AgentAdapterController controller;

  @override
  State<AgentAdapterScreen> createState() => _AgentAdapterScreenState();
}

class _AgentAdapterScreenState extends State<AgentAdapterScreen> {
  final TextEditingController _documentController = TextEditingController();
  String _baseDocument = '';
  String? _activeKey;
  String? _pendingExternalDocument;
  bool _wasCreating = false;
  bool _showAdvanced = false;
  int _comparisonIndex = 1;

  bool get _isDirty => _documentController.text != _baseDocument;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerChanged);
    _documentController.addListener(_documentChanged);
    _synchronizeDocument();
    if (widget.controller.entries.isEmpty && !widget.controller.isLoading) {
      unawaited(widget.controller.load());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    _documentController
      ..removeListener(_documentChanged)
      ..dispose();
    super.dispose();
  }

  void _controllerChanged() {
    final bool wasCreating = _wasCreating;
    _synchronizeDocument();
    if (wasCreating &&
        !widget.controller.isCreating &&
        widget.controller.selectedEntry != null) {
      _showAdvanced = false;
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _documentChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _synchronizeDocument() {
    final AgentAdapterEntry? entry = widget.controller.selectedEntry;
    if (widget.controller.isCreating) {
      if (!_wasCreating) {
        _replaceDocument(widget.controller.newAdapterTemplate(), null);
      }
      _wasCreating = true;
      return;
    }
    _wasCreating = false;
    if (entry == null) {
      return;
    }
    final bool sameEntry = _activeKey == entry.key;
    if (sameEntry && entry.document == _documentController.text) {
      _baseDocument = entry.document;
      _pendingExternalDocument = null;
      return;
    }
    if (sameEntry &&
        _isDirty &&
        entry.document != _baseDocument &&
        _pendingExternalDocument != entry.document) {
      _pendingExternalDocument = entry.document;
      return;
    }
    if (!sameEntry || entry.document != _baseDocument) {
      _replaceDocument(entry.document, entry.key);
    }
  }

  void _replaceDocument(String document, String? id) {
    _activeKey = id;
    _baseDocument = document;
    _pendingExternalDocument = null;
    _comparisonIndex = 1;
    _documentController.value = TextEditingValue(
      text: document,
      selection: TextSelection.collapsed(offset: document.length),
    );
  }

  Future<void> _selectEntry(AgentAdapterEntry entry) async {
    await widget.controller.select(entry);
    if (mounted) {
      setState(() => _showAdvanced = false);
    }
  }

  void _beginCreate() {
    widget.controller.beginCreate();
    setState(() => _showAdvanced = true);
  }

  Future<void> _confirmReset() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => DesktopAlertDialog(
        title: Text(context.l10n.restoreBuiltInVersion),
        content: Text(
          context
              .l10n
              .theUserOverrideWillBeRemovedItsSnapshotsRemainInLocalHistory,
        ),
        actions: <Widget>[
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, false),
            label: context.l10n.cancel,
            compact: true,
          ),
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, true),
            label: context.l10n.restore,
            tone: DesktopActionTone.primary,
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.resetToBuiltIn();
    }
  }

  Future<void> _confirmDelete() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => DesktopAlertDialog(
        title: Text(context.l10n.deleteThisAdapter),
        content: Text(
          context
              .l10n
              .theCustomYAMLFileWillBeDeletedAgentResourcesWillStopSyncing,
        ),
        actions: <Widget>[
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, false),
            label: context.l10n.cancel,
            compact: true,
          ),
          DesktopActionButton(
            onPressed: () => Navigator.pop(context, true),
            label: context.l10n.delete,
            tone: DesktopActionTone.danger,
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.deleteCustom();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AgentAdapterController controller = widget.controller;
    return Material(
      key: const Key('agent-adapter-screen'),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: <Widget>[
          _Header(
            directoryPath: controller.userDirectoryPath,
            isLoading: controller.isLoading,
            onCreate: _beginCreate,
            onRefresh: controller.load,
          ),
          const Divider(height: 1),
          _AdapterCatalogSummary(entries: controller.entries),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  width: 248,
                  child: _AdapterList(
                    entries: controller.entries,
                    selected: controller.selectedEntry,
                    isCreating: controller.isCreating,
                    onSelected: _selectEntry,
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(
                  child:
                      controller.selectedEntry == null && !controller.isCreating
                      ? _EmptyEditor(isLoading: controller.isLoading)
                      : _buildEditor(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditor(BuildContext context) {
    final AgentAdapterController controller = widget.controller;
    final AgentAdapterEntry? entry = controller.selectedEntry;
    final List<AgentAdapterRevision> history = controller.history;
    final int maxComparison = history.length - 1;
    final int comparison = maxComparison < 1
        ? 0
        : _comparisonIndex.clamp(1, maxComparison);
    final String? previousDocument = comparison == 0
        ? null
        : history[comparison].document;
    final List<AgentAdapterDiffLine> diff = previousDocument == null
        ? const <AgentAdapterDiffLine>[]
        : diffAgentAdapterDocuments(previousDocument, _documentController.text);
    final String path =
        entry?.userFile?.path ??
        controller.destinationFor(_documentController.text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (controller.error != null)
          _Notice(
            key: const Key('agent-adapter-action-error'),
            icon: Icons.error_outline_rounded,
            color: Theme.of(context).colorScheme.error,
            text: controller.error!,
          ),
        if (entry?.error != null)
          _Notice(
            key: const Key('agent-adapter-validation-error'),
            icon: Icons.warning_amber_rounded,
            color: Theme.of(context).colorScheme.error,
            text: entry!.error!,
          ),
        if (_pendingExternalDocument != null)
          _ExternalChangeNotice(
            onLoadExternal: () {
              _replaceDocument(_pendingExternalDocument!, _activeKey);
              setState(() {});
            },
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      controller.isCreating
                          ? context.l10n.newAgentAdapter
                          : entry!.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Tooltip(
                      message: path,
                      child: Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontFamily: 'Menlo',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (entry?.isCustomized == true)
                DesktopActionButton(
                  key: const Key('agent-adapter-reset'),
                  onPressed: controller.isSaving ? null : _confirmReset,
                  label: context.l10n.restore,
                  compact: true,
                ),
              if (entry != null && !entry.hasBuiltIn)
                DesktopActionButton(
                  key: const Key('agent-adapter-delete'),
                  onPressed: controller.isSaving ? null : _confirmDelete,
                  label: context.l10n.delete,
                  tone: DesktopActionTone.danger,
                  compact: true,
                ),
              const SizedBox(width: 8),
              DesktopActionButton(
                key: const Key('agent-adapter-toggle-advanced'),
                onPressed: controller.isCreating
                    ? null
                    : () => setState(() => _showAdvanced = !_showAdvanced),
                icon: Icon(
                  _showAdvanced
                      ? Icons.fact_check_outlined
                      : Icons.code_rounded,
                  size: 16,
                ),
                label: _showAdvanced
                    ? context.l10n.status
                    : context.l10n.advancedConfig,
                tone: DesktopActionTone.neutral,
              ),
              const SizedBox(width: 8),
              DesktopActionButton(
                key: const Key('agent-adapter-save'),
                onPressed: controller.isSaving || !_isDirty
                    ? null
                    : () => controller.save(_documentController.text),
                icon: controller.isSaving
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined, size: 16),
                label: context.l10n.save,
                tone: DesktopActionTone.primary,
              ),
            ],
          ),
        ),
        if (!_showAdvanced && !controller.isCreating)
          Expanded(
            child: _AdapterOverview(entry: entry!, controller: controller),
          )
        else ...<Widget>[
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: DesktopTextField(
                key: const Key('agent-adapter-editor'),
                controller: _documentController,
                expands: true,
                maxLines: null,
                minLines: null,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  fontFamily: 'Menlo',
                  fontSize: 12,
                  height: 1.5,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerLowest,
                  contentPadding: const EdgeInsets.all(12),
                  border: const OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 230,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
                  child: Row(
                    children: <Widget>[
                      Text(
                        context.l10n.versionComparison,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (maxComparison >= 1)
                        SizedBox(
                          width: 150,
                          child: DesktopSelectField<int>(
                            key: const Key('agent-adapter-history-selector'),
                            value: comparison,
                            items: <DesktopSelectItem<int>>[
                              DesktopSelectItem<int>(
                                value: 1,
                                label: context.l10n.previousVersion,
                              ),
                              if (maxComparison >= 2)
                                DesktopSelectItem<int>(
                                  value: 2,
                                  label: context.l10n.twoVersionsAgo,
                                ),
                            ],
                            onChanged: (int value) =>
                                setState(() => _comparisonIndex = value),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: previousDocument == null
                      ? Center(
                          child: Text(
                            context
                                .l10n
                                .aComparisonAppearsAfterTheNextSavedOrExternalEdit,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      : _DiffView(lines: diff),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.directoryPath,
    required this.isLoading,
    required this.onCreate,
    required this.onRefresh,
  });

  final String directoryPath;
  final bool isLoading;
  final VoidCallback onCreate;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    context.l10n.agentConnectionConfiguration,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context
                        .l10n
                        .directoryDetectionAndDeclaredPathsVerifyRuntimeConnectionsSeparately,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            DesktopIconButton(
              key: const Key('agent-adapter-refresh'),
              tooltip: '$directoryPath\n${context.l10n.refresh}',
              onPressed: isLoading ? null : () => unawaited(onRefresh()),
              icon: isLoading
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 19),
            ),
            const SizedBox(width: 6),
            DesktopActionButton(
              key: const Key('agent-adapter-new'),
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 17),
              label: context.l10n.newLabel,
              tone: DesktopActionTone.neutral,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdapterList extends StatelessWidget {
  const _AdapterList({
    required this.entries,
    required this.selected,
    required this.isCreating,
    required this.onSelected,
  });

  final List<AgentAdapterEntry> entries;
  final AgentAdapterEntry? selected;
  final bool isCreating;
  final Future<void> Function(AgentAdapterEntry entry) onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const Key('agent-adapter-list'),
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
      children: <Widget>[
        if (isCreating)
          _AdapterRow(
            title: context.l10n.newAgent,
            subtitle: context.l10n.unsaved,
            selected: true,
            installed: null,
            invalid: false,
            onTap: () {},
          ),
        for (final AgentAdapterEntry entry in entries)
          _AdapterRow(
            key: Key('agent-adapter-${entry.id}'),
            title: entry.displayName,
            subtitle: _originLabel(context, entry),
            selected: !isCreating && selected?.key == entry.key,
            installed: entry.installed,
            invalid: !entry.isValid,
            onTap: () => unawaited(onSelected(entry)),
          ),
      ],
    );
  }
}

class _AdapterRow extends StatelessWidget {
  const _AdapterRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.installed,
    required this.invalid,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool? installed;
  final bool invalid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String detectionLabel = switch (installed) {
      true => context.l10n.directoryDetected,
      false => context.l10n.directoryNotDetected,
      null => context.l10n.directoryNotChecked,
    };
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle. $detectionLabel',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Material(
            color: selected
                ? colors.primary.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(5),
            child: InkWell(
              borderRadius: BorderRadius.circular(5),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      invalid
                          ? Icons.warning_amber_rounded
                          : Icons.hub_outlined,
                      size: 17,
                      color: invalid
                          ? colors.error
                          : selected
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: selected ? FontWeight.w600 : null,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    _DetectionBadge(installed: installed),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.icon,
    required this.color,
    required this.text,
    super.key,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.07),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExternalChangeNotice extends StatelessWidget {
  const _ExternalChangeNotice({required this.onLoadExternal});

  final VoidCallback onLoadExternal;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('agent-adapter-external-change'),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
      child: Row(
        children: <Widget>[
          const Icon(Icons.sync_problem_outlined, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context
                  .l10n
                  .theFileChangedOutsideDingDongWhileYouHaveUnsavedEdits,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          DesktopActionButton(
            onPressed: onLoadExternal,
            label: context.l10n.loadExternal,
            compact: true,
          ),
        ],
      ),
    );
  }
}

class _DiffView extends StatelessWidget {
  const _DiffView({required this.lines});

  final List<AgentAdapterDiffLine> lines;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('agent-adapter-diff'),
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(4),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.builder(
        itemCount: lines.length,
        itemExtent: 22,
        itemBuilder: (BuildContext context, int index) {
          final AgentAdapterDiffLine line = lines[index];
          final (
            Color background,
            Color foreground,
            String marker,
          ) = switch (line.kind) {
            AgentAdapterDiffKind.unchanged => (
              Colors.transparent,
              Theme.of(context).colorScheme.onSurfaceVariant,
              ' ',
            ),
            AgentAdapterDiffKind.added => (
              const Color(0xFFEAF6EE),
              const Color(0xFF245F37),
              '+',
            ),
            AgentAdapterDiffKind.removed => (
              const Color(0xFFFFECEB),
              const Color(0xFF8D302A),
              '−',
            ),
          };
          return ColoredBox(
            color: background,
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: 38,
                  child: Text(
                    line.previousLine?.toString() ?? '',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 10,
                      color: foreground.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 38,
                  child: Text(
                    line.currentLine?.toString() ?? '',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 10,
                      color: foreground.withValues(alpha: 0.65),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  marker,
                  style: TextStyle(
                    fontFamily: 'Menlo',
                    fontSize: 11,
                    color: foreground,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    line.text,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontFamily: 'Menlo',
                      fontSize: 11,
                      height: 1.3,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EmptyEditor extends StatelessWidget {
  const _EmptyEditor({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: isLoading
          ? const CircularProgressIndicator()
          : Text(
              context.l10n.selectAnAgentAdapterOrCreateOne,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
    );
  }
}

String _originLabel(BuildContext context, AgentAdapterEntry entry) {
  if (!entry.isValid) {
    return context.l10n.invalidConfiguration;
  }
  return switch (entry.origin) {
    AgentAdapterOrigin.builtIn => context.l10n.builtIn,
    AgentAdapterOrigin.customized => context.l10n.userOverride,
    AgentAdapterOrigin.custom => context.l10n.custom,
  };
}
