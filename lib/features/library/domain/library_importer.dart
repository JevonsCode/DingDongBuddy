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
        .map((Resource item) => _normalizedContent(item.content, item.type))
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
          !knownContent.add(
            _normalizedContent(resource.content, resource.type),
          )) {
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
    if (entity is! Directory ||
        !await _containsMarker(entity, const <String>[
          'SKILL.md',
          'skill.md',
        ])) {
      return null;
    }
    return _resource(request, entity, content: entity.absolute.path);
  }

  Future<Resource?> _mcp(
    FileSystemEntity entity,
    LibraryImportRequest request,
  ) async {
    if (entity is Directory) {
      if (!await _containsMarker(entity, const <String>[
        'package.json',
        'mcp.json',
        'server.json',
      ])) {
        return null;
      }
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
    return _resource(request, entity, content: entity.absolute.path);
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
    return _resource(request, entity, content: entity.absolute.path);
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

Future<bool> _containsMarker(Directory directory, List<String> names) async {
  for (final String name in names) {
    if (await File(path.join(directory.path, name)).exists()) {
      return true;
    }
  }
  return false;
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

String _normalizedContent(String content, ResourceType type) {
  return switch (type) {
    ResourceType.skill || ResourceType.mcp || ResourceType.knowledge =>
      path.normalize(path.absolute(_expandedPath(content))),
    ResourceType.prompt || ResourceType.clipboard => content,
  };
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
