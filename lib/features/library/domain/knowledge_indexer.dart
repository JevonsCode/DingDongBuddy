import 'dart:io';

import 'package:path/path.dart' as path;

/// Bounded metadata and preview for one local knowledge file.
final class KnowledgeIndexEntry {
  const KnowledgeIndexEntry({
    required this.path,
    required this.name,
    required this.relativePath,
    required this.byteCount,
    required this.summary,
    this.modifiedAt,
  });

  final String path;
  final String name;
  final String relativePath;
  final int byteCount;
  final DateTime? modifiedAt;
  final String summary;

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'name': name,
    'relativePath': relativePath,
    'byteCount': byteCount,
    'summary': summary,
    if (modifiedAt != null) 'modifiedAt': modifiedAt!.toUtc().toIso8601String(),
  };
}

/// Recursive knowledge index response with explicit truncation information.
final class KnowledgeIndexResult {
  const KnowledgeIndexResult({
    required this.root,
    required this.files,
    required this.scannedCount,
    required this.skippedCount,
    required this.truncated,
  });

  final String root;
  final List<KnowledgeIndexEntry> files;
  final int scannedCount;
  final int skippedCount;
  final bool truncated;
}

/// Indexes text-oriented knowledge without loading an unbounded directory.
final class KnowledgeIndexer {
  static const int defaultMaxFiles = 40;
  static const int maximumSummaryCharacters = 300;

  Future<KnowledgeIndexResult> index(
    String rootPath, {
    int maxFiles = defaultMaxFiles,
  }) async {
    final Directory root = Directory(_expand(rootPath));
    if (!await root.exists()) {
      throw FileSystemException('Knowledge root is not a directory', root.path);
    }
    final int limit = maxFiles.clamp(1, defaultMaxFiles);
    final List<KnowledgeIndexEntry> entries = <KnowledgeIndexEntry>[];
    int scanned = 0;
    int skipped = 0;
    bool truncated = false;
    await for (final FileSystemEntity entity in root.list(
      recursive: true,
      followLinks: false,
    )) {
      final String relative = path.relative(entity.path, from: root.path);
      if (relative
          .split(path.separator)
          .any((String part) => part.startsWith('.'))) {
        continue;
      }
      if (entity is! File) {
        continue;
      }
      if (!_extensions.contains(path.extension(entity.path).toLowerCase())) {
        skipped += 1;
        continue;
      }
      if (entries.length >= limit) {
        truncated = true;
        break;
      }
      scanned += 1;
      final FileStat stat = await entity.stat();
      final String content = await _safeRead(entity);
      entries.add(
        KnowledgeIndexEntry(
          path: entity.absolute.path,
          name: path.basename(entity.path),
          relativePath: relative,
          byteCount: stat.size,
          modifiedAt: stat.modified,
          summary: _summary(content),
        ),
      );
    }
    entries.sort(
      (KnowledgeIndexEntry left, KnowledgeIndexEntry right) =>
          left.relativePath.compareTo(right.relativePath),
    );
    return KnowledgeIndexResult(
      root: root.absolute.path,
      files: List<KnowledgeIndexEntry>.unmodifiable(entries),
      scannedCount: scanned,
      skippedCount: skipped,
      truncated: truncated,
    );
  }
}

const Set<String> _extensions = <String>{
  '.md',
  '.markdown',
  '.txt',
  '.json',
  '.yaml',
  '.yml',
  '.toml',
  '.swift',
  '.js',
  '.ts',
  '.tsx',
  '.jsx',
  '.py',
  '.rb',
  '.go',
  '.rs',
  '.java',
  '.kt',
  '.sh',
  '.zsh',
  '.sql',
  '.html',
  '.css',
  '.dart',
};

Future<String> _safeRead(File file) async {
  try {
    return await file.readAsString();
  } on Object {
    return '';
  }
}

String _summary(String content) {
  final String collapsed = content
      .split(RegExp(r'[\r\n]+'))
      .map((String line) => line.trim())
      .where((String line) => line.isNotEmpty)
      .join(' ');
  return collapsed.length <= KnowledgeIndexer.maximumSummaryCharacters
      ? collapsed
      : '${collapsed.substring(0, KnowledgeIndexer.maximumSummaryCharacters)}...';
}

String _expand(String value) {
  final String trimmed = value.trim();
  if (trimmed == '~') {
    return Platform.environment['HOME'] ?? trimmed;
  }
  if (trimmed.startsWith('~/')) {
    return path.join(Platform.environment['HOME'] ?? '~', trimmed.substring(2));
  }
  return path.normalize(path.absolute(trimmed));
}
