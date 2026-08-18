import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_api/data/agent_source_identity.dart';
import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:path/path.dart' as path;

final class ConversationTokenUsageRequest {
  const ConversationTokenUsageRequest({
    required this.source,
    this.conversationId,
    this.workspacePath,
    this.transcriptPath,
  });

  final String source;
  final String? conversationId;
  final String? workspacePath;
  final String? transcriptPath;
}

typedef ConversationTokenUsageLoader =
    Future<ConversationTokenUsage?> Function(
      ConversationTokenUsageRequest request,
    );

/// Reads only exact usage fields from locally persisted Agent sessions.
///
/// Unsupported Agents, malformed files, and missing sessions intentionally
/// return null. This boundary never estimates tokens from text length.
final class LocalConversationTokenUsageResolver {
  LocalConversationTokenUsageResolver({
    Directory? homeDirectory,
    Directory? codexSessionsDirectory,
    Directory? codexArchivedSessionsDirectory,
    Directory? claudeProjectsDirectory,
    Directory? piSessionsDirectory,
  }) : _codexSessionsDirectory =
           codexSessionsDirectory ??
           Directory(
             path.join(
               homeDirectory?.path ?? _homeDirectoryPath(),
               '.codex',
               'sessions',
             ),
           ),
       _codexArchivedSessionsDirectory =
           codexArchivedSessionsDirectory ??
           Directory(
             path.join(
               homeDirectory?.path ?? _homeDirectoryPath(),
               '.codex',
               'archived_sessions',
             ),
           ),
       _claudeProjectsDirectory =
           claudeProjectsDirectory ??
           Directory(
             path.join(
               homeDirectory?.path ?? _homeDirectoryPath(),
               '.claude',
               'projects',
             ),
           ),
       _piSessionsDirectory =
           piSessionsDirectory ??
           Directory(
             path.join(
               homeDirectory?.path ?? _homeDirectoryPath(),
               '.pi',
               'agent',
               'sessions',
             ),
           );

  final Directory _codexSessionsDirectory;
  final Directory _codexArchivedSessionsDirectory;
  final Directory _claudeProjectsDirectory;
  final Directory _piSessionsDirectory;

  Future<ConversationTokenUsage?> resolve(
    ConversationTokenUsageRequest request,
  ) async {
    try {
      return switch (resolveAgentAdapterId(request.source)) {
        'codex' => await _readCodex(request),
        'claude-code' => await _readClaudeCode(request),
        'pi' => await _readPi(request),
        _ => null,
      };
    } on Object {
      return null;
    }
  }

  Future<ConversationTokenUsage?> _readCodex(
    ConversationTokenUsageRequest request,
  ) async {
    final String? conversationId = _safeConversationId(request.conversationId);
    if (conversationId == null) {
      return null;
    }
    final File? transcript = await _newestMatchingFile(<Directory>[
      _codexSessionsDirectory,
      _codexArchivedSessionsDirectory,
    ], conversationId);
    if (transcript == null) {
      return null;
    }

    ConversationTokenUsage? latest;
    await for (final String line in _lines(transcript)) {
      if (!line.contains('"token_count"')) {
        continue;
      }
      final Map<String, Object?>? json = _decodeObject(line);
      final Map<String, Object?>? payload = _object(json?['payload']);
      if (payload?['type'] != 'token_count') {
        continue;
      }
      final Map<String, Object?>? info = _object(payload?['info']);
      final Map<String, Object?>? total = _object(info?['total_token_usage']);
      final int? totalTokens = _tokenInt(total?['total_tokens']);
      if (totalTokens == null || totalTokens <= 0) {
        continue;
      }
      latest = ConversationTokenUsage(
        source: ConversationTokenUsageSource.codex,
        totalTokens: totalTokens,
        inputTokens: _tokenInt(total?['input_tokens']) ?? 0,
        outputTokens: _tokenInt(total?['output_tokens']) ?? 0,
        cachedInputTokens: _tokenInt(total?['cached_input_tokens']) ?? 0,
        cacheWriteInputTokens:
            _tokenInt(total?['cache_write_input_tokens']) ?? 0,
        reasoningOutputTokens:
            _tokenInt(total?['reasoning_output_tokens']) ?? 0,
      );
    }
    return latest;
  }

  Future<ConversationTokenUsage?> _readClaudeCode(
    ConversationTokenUsageRequest request,
  ) async {
    final File? transcript = await _resolveTranscript(
      root: _claudeProjectsDirectory,
      transcriptPath: request.transcriptPath,
      conversationId: request.conversationId,
    );
    if (transcript == null) {
      return null;
    }
    final List<File> transcripts = <File>[transcript];
    final Directory subagentRoot = Directory(
      path.join(
        path.dirname(transcript.path),
        path.basenameWithoutExtension(transcript.path),
        'subagents',
      ),
    );
    if (await subagentRoot.exists()) {
      await for (final FileSystemEntity entity in subagentRoot.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && path.extension(entity.path) == '.jsonl') {
          transcripts.add(entity);
        }
      }
    }

    final Set<String> seenResponses = <String>{};
    int input = 0;
    int output = 0;
    int cacheRead = 0;
    int cacheWrite = 0;
    int fallbackIdentity = 0;
    for (final File file in transcripts) {
      await for (final String line in _lines(file)) {
        if (!line.contains('"usage"')) {
          continue;
        }
        final Map<String, Object?>? json = _decodeObject(line);
        if (json?['type'] != 'assistant') {
          continue;
        }
        final Map<String, Object?>? message = _object(json?['message']);
        final Map<String, Object?>? usage = _object(message?['usage']);
        if (usage == null) {
          continue;
        }
        final String identity =
            _nonEmptyText(json?['requestId']) ??
            _nonEmptyText(message?['id']) ??
            _nonEmptyText(json?['uuid']) ??
            '${file.path}#${fallbackIdentity++}';
        if (!seenResponses.add(identity)) {
          continue;
        }
        input += _tokenInt(usage['input_tokens']) ?? 0;
        output += _tokenInt(usage['output_tokens']) ?? 0;
        cacheRead += _tokenInt(usage['cache_read_input_tokens']) ?? 0;
        cacheWrite += _tokenInt(usage['cache_creation_input_tokens']) ?? 0;
      }
    }
    final int total = input + output + cacheRead + cacheWrite;
    return total <= 0
        ? null
        : ConversationTokenUsage(
            source: ConversationTokenUsageSource.claudeCode,
            totalTokens: total,
            inputTokens: input,
            outputTokens: output,
            cachedInputTokens: cacheRead,
            cacheWriteInputTokens: cacheWrite,
          );
  }

  Future<ConversationTokenUsage?> _readPi(
    ConversationTokenUsageRequest request,
  ) async {
    final File? transcript = await _resolveTranscript(
      root: _piSessionsDirectory,
      transcriptPath: request.transcriptPath,
      conversationId: request.conversationId,
    );
    if (transcript == null) {
      return null;
    }

    int input = 0;
    int output = 0;
    int cacheRead = 0;
    int cacheWrite = 0;
    int reasoning = 0;
    await for (final String line in _lines(transcript)) {
      if (!line.contains('"usage"')) {
        continue;
      }
      final Map<String, Object?>? json = _decodeObject(line);
      final String type = json?['type'] as String? ?? '';
      Map<String, Object?>? usage;
      if (type == 'message') {
        final Map<String, Object?>? message = _object(json?['message']);
        final String role = message?['role'] as String? ?? '';
        if (role == 'assistant' || role == 'toolResult') {
          usage = _object(message?['usage']);
        }
      } else if (type == 'branch_summary' || type == 'compaction') {
        usage = _object(json?['usage']);
      }
      if (usage == null) {
        continue;
      }
      input += _tokenInt(usage['input']) ?? 0;
      output += _tokenInt(usage['output']) ?? 0;
      cacheRead += _tokenInt(usage['cacheRead']) ?? 0;
      cacheWrite += _tokenInt(usage['cacheWrite']) ?? 0;
      reasoning += _tokenInt(usage['reasoning']) ?? 0;
    }
    final int total = input + output + cacheRead + cacheWrite;
    return total <= 0
        ? null
        : ConversationTokenUsage(
            source: ConversationTokenUsageSource.pi,
            totalTokens: total,
            inputTokens: input,
            outputTokens: output,
            cachedInputTokens: cacheRead,
            cacheWriteInputTokens: cacheWrite,
            reasoningOutputTokens: reasoning,
          );
  }

  Future<File?> _resolveTranscript({
    required Directory root,
    required String? transcriptPath,
    required String? conversationId,
  }) async {
    final String? directPath = _nonEmptyText(transcriptPath);
    if (directPath != null) {
      final File direct = File(directPath).absolute;
      final String normalizedRoot = path.normalize(root.absolute.path);
      final String normalizedFile = path.normalize(direct.path);
      if ((path.equals(normalizedRoot, normalizedFile) ||
              path.isWithin(normalizedRoot, normalizedFile)) &&
          await FileSystemEntity.type(normalizedFile, followLinks: false) ==
              FileSystemEntityType.file) {
        return direct;
      }
    }
    final String? safeId = _safeConversationId(conversationId);
    return safeId == null
        ? null
        : _newestMatchingFile(<Directory>[root], safeId);
  }

  Future<File?> _newestMatchingFile(
    Iterable<Directory> roots,
    String conversationId,
  ) async {
    File? newest;
    DateTime? newestModified;
    for (final Directory root in roots) {
      if (!await root.exists()) {
        continue;
      }
      await for (final FileSystemEntity entity in root.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File ||
            path.extension(entity.path) != '.jsonl' ||
            !path.basename(entity.path).contains(conversationId)) {
          continue;
        }
        final DateTime modified = (await entity.stat()).modified;
        if (newestModified == null || modified.isAfter(newestModified)) {
          newest = entity;
          newestModified = modified;
        }
      }
    }
    return newest;
  }
}

Stream<String> _lines(File file) =>
    file.openRead().transform(utf8.decoder).transform(const LineSplitter());

Map<String, Object?>? _decodeObject(String value) {
  try {
    return _object(jsonDecode(value));
  } on Object {
    return null;
  }
}

Map<String, Object?>? _object(Object? value) {
  if (value is! Map<Object?, Object?>) {
    return null;
  }
  return <String, Object?>{
    for (final MapEntry<Object?, Object?> entry in value.entries)
      if (entry.key is String) entry.key! as String: entry.value,
  };
}

int? _tokenInt(Object? value) {
  if (value is int && value >= 0) {
    return value;
  }
  if (value is num && value.isFinite && value >= 0 && value == value.round()) {
    return value.toInt();
  }
  return null;
}

String? _safeConversationId(String? value) {
  final String? normalized = _nonEmptyText(value);
  if (normalized == null ||
      normalized.length > 160 ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(normalized) ||
      normalized.contains('..')) {
    return null;
  }
  return normalized;
}

String? _nonEmptyText(Object? value) {
  if (value is! String) {
    return null;
  }
  final String normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

String _homeDirectoryPath() =>
    Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';
