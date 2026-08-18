import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/files/safe_managed_file.dart';
import 'package:dingdong/core/serialization/strict_json.dart';
import 'package:dingdong/features/agent_adapters/domain/agent_adapter.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

enum AgentAdapterOrigin { builtIn, customized, custom }

final class AgentAdapterEntry {
  const AgentAdapterEntry({
    required this.key,
    required this.id,
    required this.displayName,
    required this.document,
    required this.origin,
    required this.installed,
    this.adapter,
    this.builtInDocument,
    this.userFile,
    this.error,
  });

  final String key;
  final String id;
  final String displayName;
  final String document;
  final AgentAdapterOrigin origin;
  final bool installed;
  final AgentAdapter? adapter;
  final String? builtInDocument;
  final File? userFile;
  final String? error;

  bool get isValid => adapter != null && error == null;
  bool get hasBuiltIn => builtInDocument != null;
  bool get isCustomized => origin == AgentAdapterOrigin.customized;
}

final class AgentAdapterRevision {
  const AgentAdapterRevision({
    required this.recordedAt,
    required this.document,
  });

  factory AgentAdapterRevision.fromJson(Map<String, Object?> json) {
    return AgentAdapterRevision(
      recordedAt: DateTime.parse(json['recordedAt']! as String).toUtc(),
      document: json['document']! as String,
    );
  }

  final DateTime recordedAt;
  final String document;

  Map<String, Object?> toJson() => <String, Object?>{
    'recordedAt': recordedAt.toUtc().toIso8601String(),
    'document': document,
  };
}

final class AgentAdapterCatalog {
  const AgentAdapterCatalog(this.entries);

  final List<AgentAdapterEntry> entries;

  List<AgentAdapter> requireEffectiveAdapters() {
    final List<AgentAdapterEntry> invalid = entries
        .where((AgentAdapterEntry entry) => !entry.isValid)
        .toList(growable: false);
    if (invalid.isNotEmpty) {
      throw FormatException(
        'Agent Adapter configuration is invalid: '
        '${invalid.map((AgentAdapterEntry entry) => '${entry.id}: ${entry.error}').join('; ')}',
      );
    }
    return entries
        .map((AgentAdapterEntry entry) => entry.adapter!)
        .toList(growable: false);
  }
}

typedef BuiltInAgentAdapterLoader = Future<Map<String, String>> Function();

/// Loads bundled defaults plus user YAML overrides and retains three snapshots.
final class AgentAdapterRepository {
  AgentAdapterRepository({
    required this.userDirectory,
    required this.historyDirectory,
    required this.homeDirectory,
    required this.loadBuiltIns,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Directory userDirectory;
  final Directory historyDirectory;
  final String homeDirectory;
  final BuiltInAgentAdapterLoader loadBuiltIns;
  final DateTime Function() _now;

  Future<AgentAdapterCatalog> load() async {
    await userDirectory.create(recursive: true);
    await historyDirectory.create(recursive: true);
    final Map<String, String> builtInDocuments = await loadBuiltIns();
    final Map<String, AgentAdapter> builtIns = <String, AgentAdapter>{};
    for (final MapEntry<String, String> entry in builtInDocuments.entries) {
      final AgentAdapter adapter = AgentAdapter.parse(entry.value);
      adapter.validateForHomeDirectory(homeDirectory);
      if (entry.key != adapter.id) {
        throw StateError(
          'Bundled Agent Adapter key ${entry.key} does not match '
          '${adapter.id}.',
        );
      }
      builtIns[adapter.id] = adapter;
    }

    final List<File> userFiles = await userDirectory
        .list()
        .where((FileSystemEntity entity) => entity is File)
        .cast<File>()
        .where(
          (File file) => const <String>{
            '.yaml',
            '.yml',
          }.contains(path.extension(file.path)),
        )
        .toList();
    userFiles.sort((File left, File right) => left.path.compareTo(right.path));

    final Map<String, List<_UserDocument>> usersById =
        <String, List<_UserDocument>>{};
    for (final File file in userFiles) {
      final String document = await file.readAsString();
      AgentAdapter? adapter;
      String? error;
      try {
        adapter = AgentAdapter.parse(document);
        adapter.validateForHomeDirectory(homeDirectory);
      } on Object catch (caught) {
        error = caught.toString();
      }
      final String id =
          adapter?.id ?? path.basenameWithoutExtension(file.path).trim();
      usersById
          .putIfAbsent(id, () => <_UserDocument>[])
          .add(
            _UserDocument(
              id: id,
              document: document,
              file: file,
              adapter: adapter,
              error: error,
            ),
          );
    }

    final List<AgentAdapterEntry> entries = <AgentAdapterEntry>[];
    final Set<String> allIds = <String>{...builtIns.keys, ...usersById.keys};
    final List<String> sortedIds = allIds.toList()..sort();
    for (final String id in sortedIds) {
      final AgentAdapter? builtIn = builtIns[id];
      final String? builtInDocument = builtInDocuments[id];
      final List<_UserDocument> userDocuments =
          usersById[id] ?? const <_UserDocument>[];
      if (userDocuments.isEmpty) {
        final AgentAdapter adapter = builtIn!;
        final AgentAdapterEntry entry = AgentAdapterEntry(
          key: 'builtin:$id',
          id: id,
          displayName: adapter.displayName,
          document: builtInDocument!,
          origin: AgentAdapterOrigin.builtIn,
          installed: adapter.isInstalled(homeDirectory),
          adapter: adapter,
          builtInDocument: builtInDocument,
        );
        await _snapshot(entry);
        entries.add(entry);
        continue;
      }
      for (final _UserDocument user in userDocuments) {
        final bool duplicate = userDocuments.length > 1;
        final String? error = duplicate
            ? 'More than one user Adapter declares the id "$id".'
            : user.error;
        final AgentAdapter? adapter = error == null ? user.adapter : null;
        final AgentAdapterEntry entry = AgentAdapterEntry(
          key: user.file.path,
          id: id,
          displayName: adapter?.displayName ?? builtIn?.displayName ?? id,
          document: user.document,
          origin: builtIn == null
              ? AgentAdapterOrigin.custom
              : AgentAdapterOrigin.customized,
          installed: adapter?.isInstalled(homeDirectory) ?? false,
          adapter: adapter,
          builtInDocument: builtInDocument,
          userFile: user.file,
          error: error,
        );
        await _snapshot(entry);
        entries.add(entry);
      }
    }
    return AgentAdapterCatalog(List<AgentAdapterEntry>.unmodifiable(entries));
  }

  Future<List<AgentAdapter>> loadEffectiveAdapters() async =>
      (await load()).requireEffectiveAdapters();

  Future<List<AgentAdapterRevision>> historyFor(AgentAdapterEntry entry) async {
    final List<AgentAdapterRevision> chronological = await _readHistory(
      entry.id,
    );
    return chronological.reversed.toList(growable: false);
  }

  Future<void> save(String document, {AgentAdapterEntry? existing}) async {
    final AgentAdapter adapter = AgentAdapter.parse(document);
    adapter.validateForHomeDirectory(homeDirectory);
    if (existing != null && adapter.id != existing.id) {
      throw FormatException(
        'Changing an existing Agent Adapter id is not supported. '
        'Create a new Adapter instead.',
      );
    }
    await userDirectory.create(recursive: true);
    final File destination =
        existing?.userFile ??
        File(path.join(userDirectory.path, '${adapter.id}.yaml'));
    if (existing == null && await destination.exists()) {
      throw FormatException(
        'A user Agent Adapter named "${adapter.id}" already exists.',
      );
    }
    final String normalized = _normalizedDocument(document);
    try {
      await SafeManagedFile(destination).update(
        (ManagedFileSnapshot snapshot) {
          if (existing == null) {
            if (snapshot.exists) {
              throw FormatException(
                'A user Agent Adapter named "${adapter.id}" already exists.',
              );
            }
          } else {
            _requireExpectedSnapshot(existing, snapshot);
          }
          return normalized;
        },
        validate: (String value) {
          final AgentAdapter parsed = AgentAdapter.parse(value);
          parsed.validateForHomeDirectory(homeDirectory);
        },
      );
    } on ManagedFileConflictException {
      throw StateError(
        'The Agent Adapter changed outside DingDong. Refresh before saving.',
      );
    }
    await _recordRevision(adapter.id, normalized);
  }

  Future<void> resetToBuiltIn(AgentAdapterEntry entry) async {
    if (!entry.hasBuiltIn || entry.userFile == null) {
      throw StateError(
        'This Agent Adapter has no built-in version to restore.',
      );
    }
    final SafeManagedFile managed = SafeManagedFile(entry.userFile!);
    final ManagedFileSnapshot snapshot = await managed.snapshot();
    _requireExpectedSnapshot(entry, snapshot);
    try {
      await managed.deleteIfUnchanged(snapshot);
    } on ManagedFileConflictException {
      throw StateError(
        'The Agent Adapter changed outside DingDong. Refresh before saving.',
      );
    }
    await _recordRevision(entry.id, entry.builtInDocument!);
  }

  Future<void> deleteCustom(AgentAdapterEntry entry) async {
    if (entry.hasBuiltIn || entry.userFile == null) {
      throw StateError('Only custom Agent Adapters can be deleted.');
    }
    final SafeManagedFile managed = SafeManagedFile(entry.userFile!);
    final ManagedFileSnapshot snapshot = await managed.snapshot();
    _requireExpectedSnapshot(entry, snapshot);
    try {
      await managed.deleteIfUnchanged(snapshot);
    } on ManagedFileConflictException {
      throw StateError(
        'The Agent Adapter changed outside DingDong. Refresh before saving.',
      );
    }
  }

  Stream<void> watch() async* {
    await userDirectory.create(recursive: true);
    yield* userDirectory
        .watch(
          events:
              FileSystemEvent.create |
              FileSystemEvent.modify |
              FileSystemEvent.delete |
              FileSystemEvent.move,
        )
        .where(
          (FileSystemEvent event) =>
              _isYamlPath(event.path) ||
              (event is FileSystemMoveEvent &&
                  event.destination != null &&
                  _isYamlPath(event.destination!)),
        )
        .map((FileSystemEvent _) {});
  }

  void _requireExpectedSnapshot(
    AgentAdapterEntry existing,
    ManagedFileSnapshot snapshot,
  ) {
    if (existing.userFile == null) {
      if (snapshot.exists) {
        throw StateError(
          'The Agent Adapter was created outside DingDong. Refresh before saving.',
        );
      }
      return;
    }
    if (!snapshot.exists) {
      throw StateError(
        'The Agent Adapter was removed outside DingDong. Refresh before saving.',
      );
    }
    final String current = _normalizedDocument(snapshot.contents);
    if (current != _normalizedDocument(existing.document)) {
      throw StateError(
        'The Agent Adapter changed outside DingDong. Refresh before saving.',
      );
    }
  }

  Future<void> _snapshot(AgentAdapterEntry entry) async {
    final List<AgentAdapterRevision> revisions = await _readHistory(entry.id);
    if (revisions.isEmpty &&
        entry.builtInDocument != null &&
        entry.document != entry.builtInDocument) {
      await _recordRevision(entry.id, entry.builtInDocument!);
    }
    await _recordRevision(entry.id, entry.document);
  }

  Future<List<AgentAdapterRevision>> _readHistory(String id) async {
    final File file = _historyFile(id);
    final ManagedFileSnapshot snapshot = await SafeManagedFile(file).snapshot();
    if (!snapshot.exists) {
      return <AgentAdapterRevision>[];
    }
    return _decodeHistory(id, snapshot.contents);
  }

  Future<void> _recordRevision(String id, String document) async {
    final String normalized = _normalizedDocument(document);
    await SafeManagedFile(_historyFile(id)).update((
      ManagedFileSnapshot snapshot,
    ) {
      final List<AgentAdapterRevision> revisions = snapshot.exists
          ? _decodeHistory(id, snapshot.contents)
          : <AgentAdapterRevision>[];
      if (revisions.isNotEmpty && revisions.last.document == normalized) {
        return null;
      }
      revisions.add(
        AgentAdapterRevision(recordedAt: _now().toUtc(), document: normalized),
      );
      while (revisions.length > 3) {
        revisions.removeAt(0);
      }
      final String encoded = const JsonEncoder.withIndent('  ')
          .convert(<String, Object?>{
            'schemaVersion': 1,
            'revisions': revisions
                .map((AgentAdapterRevision revision) => revision.toJson())
                .toList(growable: false),
          });
      return '$encoded\n';
    }, validate: (String value) => _decodeHistory(id, value));
  }

  List<AgentAdapterRevision> _decodeHistory(String id, String contents) {
    try {
      final Map<String, Object?> json = Map<String, Object?>.from(
        decodeStrictJson(contents) as Map,
      );
      if (json['schemaVersion'] != 1) {
        throw const FormatException();
      }
      return (json['revisions'] as List<Object?>? ?? const <Object?>[])
          .map(
            (Object? value) => AgentAdapterRevision.fromJson(
              Map<String, Object?>.from(value! as Map),
            ),
          )
          .toList();
    } on Object {
      throw FormatException('Agent Adapter history for "$id" is invalid.');
    }
  }

  File _historyFile(String id) {
    final String safe = base64Url.encode(utf8.encode(id)).replaceAll('=', '');
    return File(path.join(historyDirectory.path, '$safe.json'));
  }
}

final class _UserDocument {
  const _UserDocument({
    required this.id,
    required this.document,
    required this.file,
    required this.adapter,
    required this.error,
  });

  final String id;
  final String document;
  final File file;
  final AgentAdapter? adapter;
  final String? error;
}

String _normalizedDocument(String value) =>
    '${value.replaceAll('\r\n', '\n').trimRight()}\n';

bool _isYamlPath(String value) =>
    const <String>{'.yaml', '.yml'}.contains(path.extension(value));

const List<String> builtInAgentAdapterIds = <String>[
  'codex',
  'claude-code',
  'cursor',
  'gemini',
  'grok-build',
  'kiro',
  'pi',
];

Future<Map<String, String>> loadBundledAgentAdapterDocuments() async {
  return <String, String>{
    for (final String id in builtInAgentAdapterIds)
      id: await rootBundle.loadString('Assets/Agent Adapters/$id.yaml'),
  };
}
