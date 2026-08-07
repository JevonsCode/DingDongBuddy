import 'dart:convert';
import 'dart:io';

/// The two user-facing ways a library bundle can enter DingDong.
enum LibraryImportSourceKind { file, link }

/// One durable record of a resource-library import attempt.
final class LibraryImportHistoryEntry {
  const LibraryImportHistoryEntry({
    required this.source,
    required this.kind,
    required this.importedCount,
    required this.duplicateIds,
    required this.conflictIds,
    required this.onlineTitles,
    required this.createdAt,
  });

  factory LibraryImportHistoryEntry.fromJson(Map<String, Object?> json) {
    return LibraryImportHistoryEntry(
      source: json['source'] as String? ?? '',
      kind: LibraryImportSourceKind.values.firstWhere(
        (LibraryImportSourceKind value) => value.name == json['kind'],
        orElse: () => LibraryImportSourceKind.file,
      ),
      importedCount: json['importedCount'] as int? ?? 0,
      duplicateIds: _stringList(json['duplicateIds']),
      conflictIds: _stringList(json['conflictIds']),
      onlineTitles: _stringList(json['onlineTitles']),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
    );
  }

  final String source;
  final LibraryImportSourceKind kind;
  final int importedCount;
  final List<String> duplicateIds;
  final List<String> conflictIds;
  final List<String> onlineTitles;
  final DateTime createdAt;

  int get skippedCount => duplicateIds.length + conflictIds.length;

  Map<String, Object?> toJson() => <String, Object?>{
    'source': source,
    'kind': kind.name,
    'importedCount': importedCount,
    'duplicateIds': duplicateIds,
    'conflictIds': conflictIds,
    'onlineTitles': onlineTitles,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

abstract interface class LibraryImportHistoryStore {
  Future<List<LibraryImportHistoryEntry>> load();

  Future<void> record(LibraryImportHistoryEntry entry);
}

/// Small in-memory implementation used by tests and lightweight windows.
final class InMemoryLibraryImportHistoryStore
    implements LibraryImportHistoryStore {
  InMemoryLibraryImportHistoryStore([
    List<LibraryImportHistoryEntry> entries =
        const <LibraryImportHistoryEntry>[],
  ]) : _entries = List<LibraryImportHistoryEntry>.of(entries);

  static const int maximumEntries = 50;
  final List<LibraryImportHistoryEntry> _entries;

  @override
  Future<List<LibraryImportHistoryEntry>> load() async =>
      List<LibraryImportHistoryEntry>.unmodifiable(_entries);

  @override
  Future<void> record(LibraryImportHistoryEntry entry) async {
    _entries
      ..removeWhere(
        (LibraryImportHistoryEntry value) =>
            value.source == entry.source && value.createdAt == entry.createdAt,
      )
      ..insert(0, entry);
    if (_entries.length > maximumEntries) {
      _entries.removeRange(maximumEntries, _entries.length);
    }
  }
}

/// File-backed history kept beside the resource library JSON.
final class FileLibraryImportHistoryStore implements LibraryImportHistoryStore {
  FileLibraryImportHistoryStore(this.file);

  static const int maximumEntries = 50;
  final File file;

  @override
  Future<List<LibraryImportHistoryEntry>> load() async {
    if (!await file.exists()) {
      return const <LibraryImportHistoryEntry>[];
    }
    final String contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return const <LibraryImportHistoryEntry>[];
    }
    final Object? decoded = jsonDecode(contents);
    if (decoded is! List<Object?>) {
      throw const FormatException('Import history must be a JSON list.');
    }
    return List<LibraryImportHistoryEntry>.unmodifiable(
      decoded.whereType<Map<String, Object?>>().map(
        LibraryImportHistoryEntry.fromJson,
      ),
    );
  }

  @override
  Future<void> record(LibraryImportHistoryEntry entry) async {
    final List<LibraryImportHistoryEntry> existing =
        List<LibraryImportHistoryEntry>.of(await load());
    existing
      ..removeWhere(
        (LibraryImportHistoryEntry value) =>
            value.source == entry.source && value.createdAt == entry.createdAt,
      )
      ..insert(0, entry);
    if (existing.length > maximumEntries) {
      existing.removeRange(maximumEntries, existing.length);
    }
    await file.parent.create(recursive: true);
    final File temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        existing
            .map((LibraryImportHistoryEntry value) => value.toJson())
            .toList(growable: false),
      ),
      flush: true,
    );
    final File backup = File('${file.path}.bak');
    if (await backup.exists()) {
      await backup.delete();
    }
    var movedExisting = false;
    try {
      if (await file.exists()) {
        await file.rename(backup.path);
        movedExisting = true;
      }
      await temporary.rename(file.path);
      if (movedExisting && await backup.exists()) {
        await backup.delete();
      }
    } on Object {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      if (movedExisting && !await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      rethrow;
    }
  }
}

List<String> _stringList(Object? value) {
  if (value is! List<Object?>) {
    return const <String>[];
  }
  return value.whereType<String>().toList(growable: false);
}
