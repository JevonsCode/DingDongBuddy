import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as path;
import 'package:sqlite3/sqlite3.dart';

import '../domain/token_usage_models.dart';
import 'token_usage_store.dart';
import 'token_usage_transcript_parser.dart';

/// Device-local, restart-safe token history. Reads supported Agent JSONL files
/// directly, including archived Codex sessions and Claude subagent directories.
/// Files and events are identified by SHA-256 hashes in the separate usage DB.
final class LocalTokenUsageRepository {
  LocalTokenUsageRepository({
    required this.databasePath,
    Directory? homeDirectory,
    Map<String, String>? environment,
    Directory? codexSessionsDirectory,
    Directory? codexArchivedSessionsDirectory,
    Directory? claudeProjectsDirectory,
    Directory? piSessionsDirectory,
    DateTime Function()? clock,
    DateTime Function(DateTime)? toLocal,
  }) : _clock = clock ?? DateTime.now,
       // Keep the injectable public name while storing it privately.
       // ignore: prefer_initializing_formals
       _toLocal = toLocal,
       _roots = <ConversationTokenUsageSource, List<Directory>>{
         ConversationTokenUsageSource.codex: [
           codexSessionsDirectory ??
               _defaultRoot(homeDirectory, environment, 'CODEX_HOME', [
                 '.codex',
               ], 'sessions'),
           codexArchivedSessionsDirectory ??
               _defaultRoot(homeDirectory, environment, 'CODEX_HOME', [
                 '.codex',
               ], 'archived_sessions'),
         ],
         ConversationTokenUsageSource.claudeCode: [
           claudeProjectsDirectory ??
               _defaultRoot(homeDirectory, environment, 'CLAUDE_CONFIG_DIR', [
                 '.claude',
               ], 'projects'),
         ],
         ConversationTokenUsageSource.pi: [
           piSessionsDirectory ??
               _defaultRoot(homeDirectory, environment, 'PI_CODING_AGENT_DIR', [
                 '.pi',
                 'agent',
               ], 'sessions'),
         ],
       };

  final String databasePath;
  final DateTime Function() _clock;
  final DateTime Function(DateTime)? _toLocal;
  final Map<ConversationTokenUsageSource, List<Directory>> _roots;
  TokenUsageStore? _store;
  Future<TokenUsageStore?>? _opening;
  Future<TokenUsageRefreshReport>? _refreshing;
  bool _closed = false;
  bool _cancelRequested = false;
  List<String> _warnings = const <String>[];

  Future<TokenUsageStore?> _ensureStore() async {
    if (_closed) {
      _warnings = const ['repository_closed'];
      return null;
    }
    if (_store != null) return _store;
    if (_opening != null) return _opening;
    final future = _openStore();
    _opening = future;
    try {
      return await future;
    } finally {
      _opening = null;
    }
  }

  Future<TokenUsageStore?> _openStore() async {
    Database? database;
    try {
      if (databasePath != ':memory:') {
        await File(databasePath).parent.create(recursive: true);
      }
      if (_closed) return null;
      database = sqlite3.open(databasePath);
      final store = TokenUsageStore(database, toLocal: _toLocal);
      _store = store;
      return store;
    } on Object {
      database?.close();
      _warnings = const ['storage_unavailable'];
      return null;
    }
  }

  /// Concurrent refresh calls on one repository share the same operation.
  /// Separate processes/connections are safe through WAL, short transactions,
  /// canonical event keys and atomic file checkpoints.
  Future<TokenUsageRefreshReport> refresh() {
    if (_closed) {
      return Future.value(
        const TokenUsageRefreshReport(
          storageAvailable: false,
          cancelled: true,
          warnings: ['repository_closed'],
        ),
      );
    }
    if (_refreshing != null) return _refreshing!;
    _cancelRequested = false;
    final future = _refresh();
    _refreshing = future;
    return future.whenComplete(() {
      _refreshing = null;
    });
  }

  /// Stops after the current bounded batch. Its event changes and byte offset
  /// commit together, so the next refresh resumes without double counting.
  void cancelRefresh() => _cancelRequested = true;

  Future<TokenUsageRefreshReport> _refresh() async {
    final store = await _ensureStore();
    if (store == null) {
      return TokenUsageRefreshReport(
        storageAvailable: false,
        cancelled: _cancelRequested,
        warnings: _warnings,
      );
    }
    var files = 0;
    final progress = _RefreshProgress();
    final coverage = <TokenUsageSourceCoverage>[];
    final warnings = <String>{};
    try {
      for (final entry in _roots.entries) {
        var rootExists = false;
        var unreadable = false;
        var sourceFiles = 0;
        var malformed = 0;
        var undated = 0;
        var pending = 0;
        for (final root in entry.value) {
          if (_cancelRequested) break;
          try {
            if (!await root.exists()) {
              if (await FileSystemEntity.type(root.path, followLinks: false) !=
                  FileSystemEntityType.notFound) {
                unreadable = true;
              }
              continue;
            }
            rootExists = true;
            await for (final entity in root.list(
              recursive: true,
              followLinks: false,
            )) {
              if (_cancelRequested) break;
              if (entity is! File ||
                  path.extension(entity.path).toLowerCase() != '.jsonl') {
                continue;
              }
              try {
                final result = await _importFile(
                  store,
                  entity,
                  entry.key,
                  progress,
                );
                files++;
                sourceFiles++;
                malformed += result.malformed;
                undated += result.undated;
                if (result.pending) pending++;
              } on FileSystemException {
                unreadable = true;
              }
            }
          } on FileSystemException {
            unreadable = true;
          }
        }
        coverage.add(
          TokenUsageSourceCoverage(
            source: entry.key,
            availability: unreadable
                ? TokenUsageAvailability.unreadable
                : rootExists
                ? TokenUsageAvailability.available
                : TokenUsageAvailability.missing,
            filesScanned: sourceFiles,
            malformedRows: malformed,
            undatedRows: undated,
            pendingFiles: pending,
          ),
        );
        if (unreadable) warnings.add('source_unreadable');
        if (malformed > 0) warnings.add('malformed_usage_rows');
        if (undated > 0) warnings.add('missing_event_dates');
        if (pending > 0) warnings.add('pending_transcript_tail');
        if (_cancelRequested) break;
      }
      if (!_cancelRequested) store.recordCoverage(coverage, _clock());
    } on Object {
      // Preserve previously committed rows and offsets. Source diagnostics
      // deliberately contain no exception text, transcript paths or content.
      warnings.add('refresh_interrupted');
    }
    if (_cancelRequested) warnings.add('refresh_cancelled');
    _warnings = List.unmodifiable(warnings);
    return TokenUsageRefreshReport(
      filesScanned: files,
      importedEvents: progress.imported,
      skippedRows: progress.skipped,
      cancelled: _cancelRequested,
      warnings: _warnings,
    );
  }

  Future<_FileImportResult> _importFile(
    TokenUsageStore store,
    File file,
    ConversationTokenUsageSource source,
    _RefreshProgress progress,
  ) async {
    final size = await file.length();
    final canonicalPath = path.normalize(file.absolute.path);
    final pathHash = await tokenUsageHash(
      Platform.isWindows ? canonicalPath.toLowerCase() : canonicalPath,
    );
    var checkpoint = store.checkpoint(pathHash);
    if (checkpoint != null &&
        !await _checkpointMatches(file, size, checkpoint)) {
      checkpoint = null;
    }
    final start = checkpoint?.offset ?? 0;
    final fallbackSession = await tokenUsageHash(
      '${source.apiValue}:file:${path.basenameWithoutExtension(file.path)}',
    );
    final parser = TokenUsageTranscriptParser(
      source: source,
      sessionHash: checkpoint?.sessionHash ?? fallbackSession,
      lastCounterHash: checkpoint?.lastCounterHash,
    );
    final priorMalformed = checkpoint?.malformedRows ?? 0;
    final priorUndated = checkpoint?.undatedRows ?? 0;
    var offset = start;
    var batchRows = 0;
    var committedSkipped = 0;
    final batch = <TokenUsageImportEvent>[];
    Future<void> flush() async {
      if (batchRows == 0) return;
      final headLength = math.min(offset, 4096);
      final next = TokenUsageFileCheckpoint(
        offset: offset,
        headLength: headLength,
        headHash: await _rangeHash(file, 0, headLength),
        tailHash: await _rangeHash(file, math.max(0, offset - 256), offset),
        sessionHash: parser.sessionHash,
        malformedRows: priorMalformed + parser.malformedRows,
        undatedRows: priorUndated + parser.undatedRows,
        lastCounterHash: parser.lastCounterHash,
      );
      final imported = store.importBatch(
        events: batch,
        pathHash: pathHash,
        source: source,
        checkpoint: next,
      );
      // Account at the commit boundary: a later batch or file read can fail
      // without undoing these persisted events and diagnostics.
      final skipped = parser.malformedRows + parser.undatedRows;
      progress.imported += imported;
      progress.skipped += skipped - committedSkipped;
      committedSkipped = skipped;
      batch.clear();
      batchRows = 0;
      // Yield explicitly even when a batch contains only non-usage rows.
      await Future<void>.delayed(Duration.zero);
    }

    await for (final line in _completeLines(file, start, size)) {
      if (_cancelRequested) break;
      offset = line.endOffset;
      batchRows++;
      if (line.text == null) {
        parser.malformedRows++;
      } else if (line.text!.trim().isNotEmpty) {
        final event = await parser.parse(line.text!);
        if (event != null) batch.add(event);
      }
      if (batchRows >= 128) await flush();
    }
    await flush();
    return _FileImportResult(
      malformed: priorMalformed + parser.malformedRows,
      undated: priorUndated + parser.undatedRows,
      pending: offset < size,
    );
  }

  Future<bool> _checkpointMatches(
    File file,
    int size,
    TokenUsageFileCheckpoint checkpoint,
  ) async {
    if (checkpoint.offset > size || checkpoint.headLength > size) return false;
    return checkpoint.headHash ==
            await _rangeHash(file, 0, checkpoint.headLength) &&
        checkpoint.tailHash ==
            await _rangeHash(
              file,
              math.max(0, checkpoint.offset - 256),
              checkpoint.offset,
            );
  }

  static Future<String> _rangeHash(File file, int start, int end) async {
    final handle = await file.open();
    try {
      await handle.setPosition(start);
      return tokenUsageBytesHash(await handle.read(end - start));
    } finally {
      await handle.close();
    }
  }

  /// Reads bytes rather than decoded chunks so checkpoints always land on UTF-8
  /// and JSONL boundaries. A trailing partial JSON object stays uncommitted;
  /// a complete final object without a newline can import safely. Oversized
  /// rows are discarded at a fixed 1 MiB bound, then the next row still imports.
  static Stream<_TranscriptLine> _completeLines(
    File file,
    int start,
    int end,
  ) async* {
    const maximumLineBytes = 1024 * 1024;
    var bytes = <int>[];
    var position = start;
    var oversized = false;
    await for (final chunk in file.openRead(start, end)) {
      for (final byte in chunk) {
        position++;
        if (byte == 10) {
          String? text;
          if (!oversized) {
            if (bytes.isNotEmpty && bytes.last == 13) bytes.removeLast();
            try {
              text = utf8.decode(bytes);
            } on FormatException {
              text = null;
            }
          }
          yield _TranscriptLine(position, text);
          bytes = <int>[];
          oversized = false;
        } else if (!oversized) {
          if (bytes.length >= maximumLineBytes) {
            bytes.clear();
            oversized = true;
          } else {
            bytes.add(byte);
          }
        }
      }
    }
    if (bytes.isNotEmpty && !oversized) {
      try {
        final text = utf8.decode(bytes);
        if (jsonDecode(text) is Map) yield _TranscriptLine(position, text);
      } on FormatException {
        // Wait for a later append to complete the UTF-8 or JSON object.
      }
    }
  }

  Future<TokenUsageSnapshot> readSnapshot({
    DateTime? from,
    DateTime? through,
    ConversationTokenUsageSource? source,
  }) async {
    final store = await _ensureStore();
    if (store == null) {
      return TokenUsageSnapshot(storageAvailable: false, warnings: _warnings);
    }
    try {
      final snapshot = store.snapshot(
        from: from,
        through: through,
        source: source,
      );
      final warnings = <String>{..._warnings, ...snapshot.warnings};
      for (final coverage in snapshot.coverage) {
        if (coverage.malformedRows > 0) warnings.add('malformed_usage_rows');
        if (coverage.undatedRows > 0) warnings.add('missing_event_dates');
        if (coverage.pendingFiles > 0) warnings.add('pending_transcript_tail');
        if (coverage.availability == TokenUsageAvailability.unreadable) {
          warnings.add('source_unreadable');
        }
      }
      return TokenUsageSnapshot(
        days: snapshot.days,
        coverage: snapshot.coverage,
        refreshedAt: snapshot.refreshedAt,
        warnings: List.unmodifiable(warnings),
      );
    } on Object {
      return const TokenUsageSnapshot(
        storageAvailable: false,
        warnings: ['storage_unavailable'],
      );
    }
  }

  Future<void> close() async {
    _closed = true;
    _cancelRequested = true;
    await _refreshing;
    await _opening;
    _store?.database.close();
    _store = null;
  }

  /// Explicit roots win; an injected home isolates tests from the host's Agent
  /// environment. Otherwise supported Agent configuration variables are used.
  static Directory _defaultRoot(
    Directory? home,
    Map<String, String>? environment,
    String variable,
    List<String> fallback,
    String child,
  ) {
    final values = environment ?? Platform.environment;
    final custom = home == null ? values[variable]?.trim() : null;
    if (custom != null && custom.isNotEmpty) {
      return Directory(path.join(custom, child));
    }
    return Directory(
      path.joinAll([
        home?.path ??
            values['USERPROFILE'] ??
            values['HOME'] ??
            Directory.current.path,
        ...fallback,
        child,
      ]),
    );
  }
}

final class _TranscriptLine {
  const _TranscriptLine(this.endOffset, this.text);
  final int endOffset;
  final String? text;
}

final class _FileImportResult {
  const _FileImportResult({
    required this.malformed,
    required this.undated,
    required this.pending,
  });
  final int malformed;
  final int undated;
  final bool pending;
}

final class _RefreshProgress {
  int imported = 0;
  int skipped = 0;
}
