import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/claude_conversation_status_line.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/managed_mcp_identity.dart';
import 'package:path/path.dart' as path;

/// Records managed MCP use from a finished Claude Code turn.
///
/// Claude Code is not asked to report MCP calls through
/// `dingdong_confirm_mcp_use`, which cost one extra model round trip per call
/// and was rarely followed. Its Stop hook already passes the transcript path,
/// so the `tool_use` records of the latest user turn are the evidence.
final class ClaudeMcpUseRecorder {
  ClaudeMcpUseRecorder({Directory? claudeProjectsDirectory})
    : _claudeProjectsDirectory =
          claudeProjectsDirectory ??
          Directory(path.join(_homeDirectoryPath(), '.claude', 'projects'));

  final Directory _claudeProjectsDirectory;

  /// Tool call ids already counted, so a repeated Stop for the same turn does
  /// not count the same call twice.
  final LinkedHashSet<String> _recordedCallIds = LinkedHashSet<String>();

  static const int _maximumRememberedCallIds = 4096;

  /// Returns the ids of the MCP resources whose invocation was recorded.
  Future<Set<String>> record({
    required String transcriptPath,
    required ResourceStore store,
    required DateTime invokedAt,
  }) async {
    final File? transcript = await _transcript(transcriptPath);
    if (transcript == null) {
      return const <String>{};
    }
    final Map<String, String> calls = await _latestTurnCalls(transcript);
    calls.removeWhere((String id, String _) => _recordedCallIds.contains(id));
    if (calls.isEmpty) {
      return const <String>{};
    }
    final Set<String> servers = calls.values.toSet();
    final List<Resource> resources = await store.load();
    final Set<String> ids = resources
        .where(
          (Resource resource) =>
              resource.type == ResourceType.mcp &&
              resource.enabled &&
              servers.contains(
                managedMcpServerName(title: resource.title, id: resource.id),
              ),
        )
        .map((Resource resource) => resource.id)
        .toSet();
    _remember(calls.keys);
    if (ids.isEmpty) {
      return const <String>{};
    }
    if (store is ResourceInvocationStore) {
      await (store as ResourceInvocationStore).recordInvocation(ids, invokedAt);
    } else {
      await store.save(
        resources
            .map(
              (Resource resource) => ids.contains(resource.id)
                  ? resource.copyWith(
                      invocationCount: resource.invocationCount + 1,
                      lastInvokedAt: invokedAt,
                    )
                  : resource,
            )
            .toList(growable: false),
      );
    }
    return ids;
  }

  Future<File?> _transcript(String transcriptPath) async {
    final String trimmed = transcriptPath.trim();
    if (trimmed.isEmpty || path.extension(trimmed) != '.jsonl') {
      return null;
    }
    final String root = path.normalize(_claudeProjectsDirectory.absolute.path);
    final String file = path.normalize(File(trimmed).absolute.path);
    if (!path.isWithin(root, file) ||
        await FileSystemEntity.type(file, followLinks: false) !=
            FileSystemEntityType.file) {
      return null;
    }
    return File(file);
  }

  void _remember(Iterable<String> ids) {
    _recordedCallIds.addAll(ids);
    while (_recordedCallIds.length > _maximumRememberedCallIds) {
      _recordedCallIds.remove(_recordedCallIds.first);
    }
  }
}

/// Managed MCP tool calls since the latest real user message, by call id.
Future<Map<String, String>> _latestTurnCalls(File transcript) async {
  final Map<String, String> calls = <String, String>{};
  await for (final String line
      in transcript
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
    // Only user turns and managed tool calls matter; skip decoding the rest.
    if (!line.contains('"user"') && !line.contains('mcp__dingdong')) {
      continue;
    }
    final Map<String, Object?>? row;
    try {
      final Object? decoded = jsonDecode(line);
      row = decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      continue;
    }
    final Object? message = row?['message'];
    final Object? content = message is Map<String, Object?>
        ? message['content']
        : null;
    if (row?['type'] == 'user' &&
        row?['isMeta'] != true &&
        (content is String ||
            content is List &&
                content.any(
                  (Object? block) => block is Map && block['type'] == 'text',
                ))) {
      calls.clear();
      continue;
    }
    if (row?['type'] != 'assistant' || content is! List) {
      continue;
    }
    for (final Object? block in content) {
      if (block is! Map || block['type'] != 'tool_use') {
        continue;
      }
      final Object? id = block['id'];
      final Object? name = block['name'];
      final String? server = name is String
          ? claudeManagedMcpServer(name)
          : null;
      if (id is String && server != null) {
        calls[id] = server;
      }
    }
  }
  return calls;
}

String _homeDirectoryPath() =>
    Platform.environment['HOME'] ??
    Platform.environment['USERPROFILE'] ??
    Directory.current.path;
