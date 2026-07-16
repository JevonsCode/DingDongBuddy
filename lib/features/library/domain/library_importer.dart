import 'dart:io';
import 'dart:math';

import 'package:dingdong/core/models/resource.dart';
import 'package:path/path.dart' as path;

/// User-selected directory import options.
final class LibraryImportRequest {
  const LibraryImportRequest({
    required this.type,
    required this.path,
    this.group,
    this.tags,
    this.source = 'Library Import',
    this.limit = 30,
  });

  final ResourceType type;
  final String path;
  final String? group;
  final List<String>? tags;
  final String source;
  final int limit;
}

/// Import candidates and auditable scan counts.
final class LibraryImportResult {
  const LibraryImportResult({
    required this.imported,
    required this.skippedCount,
    required this.scannedCount,
  });

  final List<Resource> imported;
  final int skippedCount;
  final int scannedCount;
}

/// Scans a bounded directory using the native DingDong import conventions.
final class LibraryImporter {
  LibraryImporter({String Function()? idGenerator, DateTime Function()? now})
    : _idGenerator = idGenerator ?? _generateUuid,
      _now = now ?? _utcNow;

  static const int maximumItems = 50;
  static const int maximumPromptCharacters = 20000;
  static const int maximumPortableCharacters = 100000;

  final String Function() _idGenerator;
  final DateTime Function() _now;

  Future<LibraryImportResult> scan(
    LibraryImportRequest request, {
    required List<Resource> existing,
  }) async {
    if (!request.type.isLibraryResource) {
      throw const FormatException('Clipboard history cannot be bulk imported.');
    }
    final Directory root = Directory(_expandedPath(request.path));
    if (!await root.exists()) {
      throw FileSystemException('Import path is not a directory', root.path);
    }
    if (request.type == ResourceType.skill &&
        await _firstFile(root, const <String>['SKILL.md', 'skill.md']) !=
            null) {
      final Resource? resource = await _skill(root, request);
      final bool duplicate =
          resource == null ||
          existing
              .where((Resource item) => item.type == request.type)
              .map((Resource item) => _normalizedContent(item.content))
              .contains(_normalizedContent(resource.content));
      return LibraryImportResult(
        imported: duplicate ? const <Resource>[] : <Resource>[resource],
        skippedCount: duplicate ? 1 : 0,
        scannedCount: 1,
      );
    }
    final List<FileSystemEntity> children = await root
        .list(followLinks: false)
        .where(
          (FileSystemEntity child) =>
              !path.basename(child.path).startsWith('.'),
        )
        .toList();
    children.sort(
      (FileSystemEntity left, FileSystemEntity right) => path
          .basename(left.path)
          .toLowerCase()
          .compareTo(path.basename(right.path).toLowerCase()),
    );

    final int limit = request.limit.clamp(1, maximumItems);
    final Set<String> knownContent = existing
        .where((Resource item) => item.type == request.type)
        .map((Resource item) => _normalizedContent(item.content))
        .toSet();
    final List<Resource> imported = <Resource>[];
    int skipped = 0;
    for (final FileSystemEntity child in children) {
      if (imported.length >= limit) {
        skipped += 1;
        continue;
      }
      final Resource? resource = await _makeResource(child, request);
      if (resource == null ||
          !knownContent.add(_normalizedContent(resource.content))) {
        skipped += 1;
        continue;
      }
      imported.add(resource);
    }
    return LibraryImportResult(
      imported: List<Resource>.unmodifiable(imported),
      skippedCount: skipped,
      scannedCount: children.length,
    );
  }

  Future<Resource?> _makeResource(
    FileSystemEntity entity,
    LibraryImportRequest request,
  ) async {
    return switch (request.type) {
      ResourceType.prompt => _prompt(entity, request),
      ResourceType.skill => _skill(entity, request),
      ResourceType.mcp => _mcp(entity, request),
      ResourceType.knowledge => _knowledge(entity, request),
      ResourceType.clipboard => null,
    };
  }

  Future<Resource?> _prompt(
    FileSystemEntity entity,
    LibraryImportRequest request,
  ) async {
    if (entity is! File ||
        !<String>{
          '.md',
          '.markdown',
          '.txt',
        }.contains(path.extension(entity.path).toLowerCase())) {
      return null;
    }
    final String content = await entity.readAsString();
    if (content.trim().isEmpty) {
      return null;
    }
    return _resource(
      request,
      entity,
      content: content.length > maximumPromptCharacters
          ? content.substring(0, maximumPromptCharacters)
          : content,
    );
  }

  Future<Resource?> _skill(
    FileSystemEntity entity,
    LibraryImportRequest request,
  ) async {
    if (entity is! Directory) {
      return null;
    }
    final File? marker = await _firstFile(entity, const <String>[
      'SKILL.md',
      'skill.md',
    ]);
    if (marker == null) {
      return null;
    }
    return _resource(request, entity, content: await marker.readAsString());
  }

  Future<Resource?> _mcp(
    FileSystemEntity entity,
    LibraryImportRequest request,
  ) async {
    if (entity is Directory) {
      final File? marker = await _firstFile(entity, const <String>[
        'package.json',
        'mcp.json',
        'server.json',
      ]);
      if (marker == null) {
        return null;
      }
      return _resource(request, entity, content: await marker.readAsString());
    } else if (entity is File) {
      if (!<String>{
        '.json',
        '.toml',
        '.yaml',
        '.yml',
      }.contains(path.extension(entity.path).toLowerCase())) {
        return null;
      }
    } else {
      return null;
    }
    return _resource(request, entity, content: await entity.readAsString());
  }

  Future<Resource?> _knowledge(
    FileSystemEntity entity,
    LibraryImportRequest request,
  ) async {
    if (entity is File &&
        !<String>{
          '.md',
          '.markdown',
          '.txt',
          '.json',
          '.yaml',
          '.yml',
        }.contains(path.extension(entity.path).toLowerCase())) {
      return null;
    }
    if (entity is! File && entity is! Directory) {
      return null;
    }
    final String content = entity is File
        ? await entity.readAsString()
        : await _knowledgeDirectoryText(entity as Directory);
    if (content.trim().isEmpty) {
      return null;
    }
    return _resource(request, entity, content: content);
  }

  Resource _resource(
    LibraryImportRequest request,
    FileSystemEntity entity, {
    required String content,
  }) {
    final DateTime timestamp = _now().toUtc();
    return Resource(
      id: _idGenerator(),
      type: request.type,
      group: request.group,
      title: path.basenameWithoutExtension(entity.path),
      content: content,
      tags: request.tags ?? <String>['imported', request.type.name],
      source: request.source,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}

Future<File?> _firstFile(Directory directory, List<String> names) async {
  for (final String name in names) {
    final File file = File(path.join(directory.path, name));
    if (await file.exists()) {
      return file;
    }
  }
  return null;
}

Future<String> _knowledgeDirectoryText(Directory directory) async {
  final List<File> files = await directory
      .list(recursive: true, followLinks: false)
      .where((FileSystemEntity entity) => entity is File)
      .cast<File>()
      .where(
        (File file) => <String>{
          '.md',
          '.markdown',
          '.txt',
          '.json',
          '.yaml',
          '.yml',
        }.contains(path.extension(file.path).toLowerCase()),
      )
      .take(30)
      .toList();
  files.sort((File left, File right) => left.path.compareTo(right.path));
  final StringBuffer output = StringBuffer();
  for (final File file in files) {
    final String content = await file.readAsString();
    final String section =
        '## ${path.relative(file.path, from: directory.path)}\n\n$content\n\n';
    if (output.length + section.length >
        LibraryImporter.maximumPortableCharacters) {
      break;
    }
    output.write(section);
  }
  return output.toString().trim();
}

String _expandedPath(String value) {
  final String trimmed = value.trim();
  if (trimmed == '~') {
    return Platform.environment['HOME'] ?? trimmed;
  }
  if (trimmed.startsWith('~/')) {
    return path.join(Platform.environment['HOME'] ?? '~', trimmed.substring(2));
  }
  return path.normalize(path.absolute(trimmed));
}

String _normalizedContent(String content) {
  return content.replaceAll('\r\n', '\n').trim();
}

DateTime _utcNow() => DateTime.now().toUtc();

String _generateUuid() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final String hex = bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
          '${hex.substring(20)}'
      .toUpperCase();
}
