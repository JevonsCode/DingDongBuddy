import 'dart:typed_data';

import 'package:dingdong/features/library/domain/skill_version.dart';

enum SkillChangeKind { added, removed, modified }

enum SkillLineKind { context, added, removed }

final class SkillLineChange {
  const SkillLineChange(this.kind, this.text, this.oldLine, this.newLine);

  final SkillLineKind kind;
  final String text;
  final int? oldLine;
  final int? newLine;

  bool get hasNewline => text.endsWith('\n');
  String get displayText => hasNewline
      ? text.substring(0, text.length - 1).replaceFirst(RegExp(r'\r$'), '')
      : text;
}

final class SkillFileDiff {
  const SkillFileDiff({
    required this.path,
    required this.kind,
    this.lines = const <SkillLineChange>[],
    this.binary = false,
    this.directory = false,
    this.oldExecutable = false,
    this.newExecutable = false,
    this.simplified = false,
  });

  final String path;
  final SkillChangeKind kind;
  final List<SkillLineChange> lines;
  final bool binary;
  final bool directory;
  final bool oldExecutable;
  final bool newExecutable;
  final bool simplified;
  bool get permissionsChanged => oldExecutable != newExecutable;
}

/// Deterministic local comparison. Either endpoint may be older or newer.
final class SkillVersionDiff {
  SkillVersionDiff(this.before, this.after)
    : files = _compareFiles(before, after);

  final SkillSnapshot before;
  final SkillSnapshot after;
  final List<SkillFileDiff> files;
  bool get titleChanged => before.title != after.title;
  bool get sourceChanged => before.sourceUrl != after.sourceUrl;
  bool get packageChanged => before.hasPackage != after.hasPackage;
  bool get isEmpty =>
      files.isEmpty && !titleChanged && !sourceChanged && !packageChanged;
}

List<SkillFileDiff> _compareFiles(SkillSnapshot before, SkillSnapshot after) {
  Map<String, SkillVersionFile> effectiveFiles(SkillSnapshot snapshot) =>
      <String, SkillVersionFile>{
        ...snapshot.files,
        'SKILL.md': SkillVersionFile(
          bytes: SkillVersionFile.text(snapshot.document).bytes,
          executable: snapshot.files['SKILL.md']?.executable ?? false,
        ),
      };
  final Map<String, SkillVersionFile> oldFiles = effectiveFiles(before);
  final Map<String, SkillVersionFile> newFiles = effectiveFiles(after);
  final List<String> paths = <String>{
    ...oldFiles.keys,
    ...newFiles.keys,
    ...before.directories,
    ...after.directories,
  }.toList()..sort();
  final List<SkillFileDiff> changes = <SkillFileDiff>[];
  for (final String path in paths) {
    final SkillVersionFile? oldFile = oldFiles[path];
    final SkillVersionFile? newFile = newFiles[path];
    final bool oldDirectory = before.directories.contains(path);
    final bool newDirectory = after.directories.contains(path);
    if (oldFile == null && newFile == null) {
      if (oldDirectory != newDirectory) {
        changes.add(
          SkillFileDiff(
            path: path,
            kind: newDirectory
                ? SkillChangeKind.added
                : SkillChangeKind.removed,
            directory: true,
          ),
        );
      }
      continue;
    }
    if (oldFile != null &&
        newFile != null &&
        oldFile.executable == newFile.executable &&
        _sameBytes(oldFile.bytes, newFile.bytes) &&
        oldDirectory == newDirectory) {
      continue;
    }
    final String? oldText = oldFile?.text;
    final String? newText = newFile?.text;
    final bool binary =
        (oldFile != null && oldText == null) ||
        (newFile != null && newText == null);
    final List<String> oldLines = _splitLines(oldText ?? '');
    final List<String> newLines = _splitLines(newText ?? '');
    final bool simplified = oldLines.length * newLines.length > 250000;
    changes.add(
      SkillFileDiff(
        path: path,
        kind: oldFile == null && !oldDirectory
            ? SkillChangeKind.added
            : newFile == null && !newDirectory
            ? SkillChangeKind.removed
            : SkillChangeKind.modified,
        binary: binary,
        oldExecutable: oldFile?.executable ?? false,
        newExecutable: newFile?.executable ?? false,
        simplified: !binary && simplified,
        lines: binary
            ? const <SkillLineChange>[]
            : _compareLines(oldLines, newLines, simplified: simplified),
      ),
    );
  }
  return List<SkillFileDiff>.unmodifiable(changes);
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<String> _splitLines(String text) {
  if (text.isEmpty) return const <String>[];
  final List<String> parts = text.split('\n');
  return <String>[
    for (var i = 0; i < parts.length - 1; i++) '${parts[i]}\n',
    if (parts.last.isNotEmpty) parts.last,
  ];
}

List<SkillLineChange> _compareLines(
  List<String> oldLines,
  List<String> newLines, {
  required bool simplified,
}) {
  final List<SkillLineChange> result = <SkillLineChange>[];
  if (simplified) {
    // Bound memory and CPU for large generated text. The UI labels this mode.
    return <SkillLineChange>[
      for (var i = 0; i < oldLines.length; i++)
        SkillLineChange(SkillLineKind.removed, oldLines[i], i + 1, null),
      for (var i = 0; i < newLines.length; i++)
        SkillLineChange(SkillLineKind.added, newLines[i], null, i + 1),
    ];
  }
  final List<Uint32List> lengths = List<Uint32List>.generate(
    oldLines.length + 1,
    (_) => Uint32List(newLines.length + 1),
  );
  for (var i = oldLines.length - 1; i >= 0; i--) {
    for (var j = newLines.length - 1; j >= 0; j--) {
      lengths[i][j] = oldLines[i] == newLines[j]
          ? lengths[i + 1][j + 1] + 1
          : lengths[i + 1][j] >= lengths[i][j + 1]
          ? lengths[i + 1][j]
          : lengths[i][j + 1];
    }
  }
  var i = 0;
  var j = 0;
  while (i < oldLines.length || j < newLines.length) {
    if (i < oldLines.length &&
        j < newLines.length &&
        oldLines[i] == newLines[j]) {
      result.add(
        SkillLineChange(SkillLineKind.context, oldLines[i], i + 1, j + 1),
      );
      i++;
      j++;
    } else if (i < oldLines.length &&
        (j == newLines.length || lengths[i + 1][j] >= lengths[i][j + 1])) {
      result.add(
        SkillLineChange(SkillLineKind.removed, oldLines[i], i + 1, null),
      );
      i++;
    } else {
      result.add(
        SkillLineChange(SkillLineKind.added, newLines[j], null, j + 1),
      );
      j++;
    }
  }
  return result;
}
