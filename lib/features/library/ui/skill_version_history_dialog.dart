import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/features/library/domain/skill_version.dart';
import 'package:dingdong/features/library/domain/skill_version_diff.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Local history and comparison of any two saved Skill versions.
final class SkillVersionHistoryDialog extends StatefulWidget {
  const SkillVersionHistoryDialog({
    required this.title,
    required this.loadVersions,
    required this.loadSnapshot,
    required this.onRestore,
    super.key,
  });

  final String title;
  final Future<List<SkillVersion>> Function() loadVersions;
  final Future<SkillSnapshot> Function(String snapshotId) loadSnapshot;
  final Future<void> Function(int version) onRestore;

  @override
  State<SkillVersionHistoryDialog> createState() =>
      _SkillVersionHistoryDialogState();
}

class _SkillVersionHistoryDialogState extends State<SkillVersionHistoryDialog> {
  List<SkillVersion> _versions = const <SkillVersion>[];
  int? _from;
  int? _to;
  SkillVersionDiff? _diff;
  SkillSnapshot? _preview;
  String? _file;
  String? _error;
  bool _loading = true;
  bool _comparing = false;
  bool _restoring = false;
  int _comparisonRequest = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<SkillVersion> versions = (await widget.loadVersions()).toList()
        ..sort(
          (SkillVersion a, SkillVersion b) => a.number.compareTo(b.number),
        );
      if (!mounted) return;
      setState(() {
        _versions = versions;
        _to = versions.lastOrNull?.number;
        _from = versions.length > 1
            ? versions[versions.length - 2].number
            : _to;
        _loading = false;
      });
      await _compare();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = context.l10n.skillVersionLoadError(error.toString());
        });
      }
    }
  }

  Future<void> _compare() async {
    if (_to == null || _from == null) return;
    final int request = ++_comparisonRequest;
    final SkillVersion from = _versions.firstWhere((v) => v.number == _from);
    final SkillVersion to = _versions.firstWhere((v) => v.number == _to);
    setState(() {
      _comparing = true;
      _error = null;
    });
    try {
      final List<SkillSnapshot> snapshots = await Future.wait(
        <Future<SkillSnapshot>>[
          widget.loadSnapshot(from.snapshotId),
          widget.loadSnapshot(to.snapshotId),
        ],
      );
      if (!mounted || request != _comparisonRequest) return;
      final SkillVersionDiff diff = SkillVersionDiff(
        snapshots[0],
        snapshots[1],
      );
      setState(() {
        _diff = diff;
        _preview = snapshots[1];
        _file = diff.files.any((f) => f.path == _file)
            ? _file
            : diff.files.firstOrNull?.path;
        _comparing = false;
      });
    } on Object catch (error) {
      if (mounted && request == _comparisonRequest) {
        setState(() {
          _comparing = false;
          _error = context.l10n.skillVersionCompareError(error.toString());
        });
      }
    }
  }

  Future<void> _restore() async {
    final int? target = _to;
    if (target == null || _restoring) return;
    final bool confirmed =
        await showDialog<bool>(
          context: context,
          builder: (BuildContext context) => DesktopAlertDialog(
            title: Text(context.l10n.skillVersionConfirmRestore(target)),
            content: Text(context.l10n.skillVersionRestoreExplanation),
            actions: <Widget>[
              DesktopActionButton(
                label: context.l10n.cancel,
                onPressed: () => Navigator.pop(context, false),
              ),
              DesktopActionButton(
                label: context.l10n.restore,
                tone: DesktopActionTone.primary,
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    setState(() {
      _restoring = true;
      _error = null;
    });
    try {
      await widget.onRestore(target);
      if (mounted) Navigator.pop(context, true);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _restoring = false;
          _error = context.l10n.skillVersionRestoreError(error.toString());
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_restoring,
      child: DesktopDialogFrame(
        dialogKey: const Key('skill-version-history-dialog'),
        width: 1040,
        maxHeight: 760,
        bodyPadding: EdgeInsets.zero,
        header: DesktopDialogHeader(
          title: Text(context.l10n.skillVersionHistory),
          subtitle: Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onClose: _restoring ? null : () => Navigator.pop(context),
          closeTooltip: context.l10n.close,
        ),
        body: SizedBox(
          height: 580,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _versions.isEmpty
              ? _message(
                  _error ?? context.l10n.skillVersionNoHistory,
                  retry: _error != null,
                )
              : LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints box) {
                    final Widget comparison = _comparison();
                    return box.maxWidth >= 720
                        ? Row(
                            children: <Widget>[
                              SizedBox(width: 220, child: _historyList()),
                              VerticalDivider(
                                width: 1,
                                color: colors.outlineVariant,
                              ),
                              Expanded(child: comparison),
                            ],
                          )
                        : Column(
                            children: <Widget>[
                              SizedBox(
                                height: 92,
                                child: _historyList(horizontal: true),
                              ),
                              const Divider(height: 1),
                              Expanded(child: comparison),
                            ],
                          );
                  },
                ),
        ),
        footer: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: <Widget>[
              DesktopActionButton(
                label: context.l10n.close,
                onPressed: _restoring ? null : () => Navigator.pop(context),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: DesktopActionButton(
                  key: const Key('skill-version-restore'),
                  label: _restoring
                      ? context.l10n.skillVersionRestoring
                      : context.l10n.skillVersionRestore,
                  tone: DesktopActionTone.primary,
                  onPressed:
                      _restoring ||
                          _loading ||
                          _comparing ||
                          _to == null ||
                          _error != null
                      ? null
                      : _restore,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyList({bool horizontal = false}) => ListView.separated(
    scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
    padding: const EdgeInsets.symmetric(vertical: 6),
    itemCount: _versions.length,
    separatorBuilder: (_, _) => const SizedBox(height: 2),
    itemBuilder: (BuildContext context, int index) {
      final SkillVersion version = _versions.reversed.elementAt(index);
      final bool selected = version.number == _to;
      final ColorScheme colors = Theme.of(context).colorScheme;
      final String source = switch (version.source) {
        SkillVersionSource.initial => context.l10n.skillVersionInitial,
        SkillVersionSource.manual => context.l10n.skillVersionManual,
        SkillVersionSource.online => context.l10n.skillVersionOnline,
        SkillVersionSource.restored => context.l10n.skillVersionRestored(
          version.restoredFrom ?? version.number,
        ),
      };
      return Container(
        width: horizontal ? 200 : null,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: DesktopActionButton(
          key: Key('skill-version-row-${version.number}'),
          height: 76,
          semanticLabel: 'v${version.number}, $source',
          style: DesktopActionButton.styleFrom(
            side: BorderSide.none,
            backgroundColor: selected
                ? colors.surfaceContainerHighest
                : Colors.transparent,
          ),
          onPressed: _restoring
              ? null
              : () {
                  setState(() => _to = version.number);
                  unawaited(_compare());
                },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'v${version.number}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  if (index == 0)
                    Text(
                      context.l10n.skillVersionCurrent,
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
              Text(
                DateFormat(
                  'yyyy-MM-dd HH:mm:ss',
                ).format(version.createdAt.toLocal()),
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _comparison() => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints box) {
            final List<Widget> selectors = <Widget>[
              _selector(from: true),
              const SizedBox(width: 12, height: 8),
              _selector(from: false),
            ];
            return box.maxWidth < 380
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: selectors,
                  )
                : Row(
                    children: <Widget>[
                      Expanded(child: selectors[0]),
                      selectors[1],
                      Expanded(child: selectors[2]),
                    ],
                  );
          },
        ),
        const SizedBox(height: 14),
        if (_comparing)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (_error != null)
          Expanded(child: _message(_error!, retry: true))
        else if (_versions.length == 1) ...<Widget>[
          Text(context.l10n.skillVersionOne),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                _preview?.document ?? '',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.6,
                ),
              ),
            ),
          ),
        ] else if (_diff != null) ...<Widget>[
          if (_diff!.titleChanged)
            _metadata(
              context.l10n.skillVersionName,
              _diff!.before.title,
              _diff!.after.title,
            ),
          if (_diff!.sourceChanged)
            _metadata(
              context.l10n.skillVersionSource,
              _diff!.before.sourceUrl ?? '—',
              _diff!.after.sourceUrl ?? '—',
            ),
          if (_diff!.packageChanged)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(context.l10n.skillVersionPackageChanged),
            ),
          if (_diff!.files.isEmpty)
            Expanded(
              child: _diff!.isEmpty
                  ? _message(context.l10n.skillVersionNoChanges)
                  : const SizedBox.shrink(),
            )
          else ...<Widget>[
            Text(
              context.l10n.skillVersionFiles(_diff!.files.length),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: 6),
            DesktopSelectField<String>(
              key: const Key('skill-version-file'),
              value: _file!,
              semanticLabel: context.l10n.skillVersionFiles(
                _diff!.files.length,
              ),
              items: _diff!.files
                  .map(
                    (SkillFileDiff file) => DesktopSelectItem<String>(
                      value: file.path,
                      label: '${_kindLabel(file.kind)} · ${file.path}',
                    ),
                  )
                  .toList(),
              onChanged: (String value) => setState(() => _file = value),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: _fileDiff(_diff!.files.firstWhere((f) => f.path == _file)),
            ),
          ],
        ],
      ],
    ),
  );

  String _kindLabel(SkillChangeKind kind) => switch (kind) {
    SkillChangeKind.added => context.l10n.skillVersionAdded,
    SkillChangeKind.removed => context.l10n.skillVersionRemoved,
    SkillChangeKind.modified => context.l10n.skillVersionModified,
  };

  Widget _metadata(String label, String before, String after) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: SelectableText(
      '$label: $before → $after',
      style: const TextStyle(fontSize: 12),
    ),
  );

  Widget _selector({required bool from}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      Text(
        from ? context.l10n.skillVersionFrom : context.l10n.skillVersionTo,
        style: Theme.of(context).textTheme.labelMedium,
      ),
      const SizedBox(height: 5),
      DesktopSelectField<int>(
        key: Key(from ? 'skill-version-from' : 'skill-version-to'),
        value: (from ? _from : _to)!,
        semanticLabel: from
            ? context.l10n.skillVersionFrom
            : context.l10n.skillVersionTo,
        enabled: !_restoring,
        items: _versions.reversed
            .map(
              (SkillVersion v) => DesktopSelectItem<int>(
                value: v.number,
                label: 'v${v.number}',
              ),
            )
            .toList(),
        onChanged: (int value) {
          setState(() {
            if (from) {
              _from = value;
            } else {
              _to = value;
            }
          });
          unawaited(_compare());
        },
      ),
    ],
  );

  Widget _message(String message, {bool retry = false}) => Center(
    child: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(message, textAlign: TextAlign.center),
            if (retry) ...<Widget>[
              const SizedBox(height: 12),
              DesktopActionButton(
                label: context.l10n.skillVersionRetry,
                onPressed: _restoring
                    ? null
                    : _versions.isEmpty
                    ? _load
                    : _compare,
              ),
            ],
          ],
        ),
      ),
    ),
  );

  Widget _fileDiff(SkillFileDiff file) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool dark = colors.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (file.permissionsChanged)
          Text(context.l10n.skillVersionPermissionsChanged),
        if (file.simplified) Text(context.l10n.skillVersionLargeFile),
        if (file.binary || file.directory || file.lines.isEmpty)
          Expanded(
            child: _message(
              file.binary
                  ? context.l10n.skillVersionBinary
                  : file.directory
                  ? context.l10n.skillVersionDirectory
                  : context.l10n.skillVersionEmptyFile,
            ),
          )
        else
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(5),
              ),
              child: SelectionArea(
                child: ListView.builder(
                  key: ValueKey<String>(
                    'skill-version-diff-$_from-$_to-${file.path}',
                  ),
                  itemCount: file.lines.length,
                  itemBuilder: (BuildContext context, int index) {
                    final SkillLineChange line = file.lines[index];
                    final Color? background = switch (line.kind) {
                      SkillLineKind.added =>
                        dark
                            ? const Color(0xFF18372C)
                            : const Color(0xFFECF6EE),
                      SkillLineKind.removed =>
                        dark
                            ? const Color(0xFF402829)
                            : const Color(0xFFFBEFEE),
                      SkillLineKind.context => null,
                    };
                    final String sign = switch (line.kind) {
                      SkillLineKind.added => '+',
                      SkillLineKind.removed => '−',
                      SkillLineKind.context => ' ',
                    };
                    return ColoredBox(
                      color: background ?? Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: DefaultTextStyle(
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            height: 1.5,
                            color: colors.onSurface,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              SelectionContainer.disabled(
                                child: SizedBox(
                                  width: 62,
                                  child: Text(
                                    '${'${line.oldLine ?? ''}'.padLeft(3)} ${'${line.newLine ?? ''}'.padLeft(3)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 18, child: Text(sign)),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      line.displayText.isEmpty
                                          ? ' '
                                          : line.displayText,
                                    ),
                                    if (!line.hasNewline &&
                                        line.kind != SkillLineKind.context)
                                      Text(
                                        '\\ ${context.l10n.skillVersionNoNewline}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
      ],
    );
  }
}
