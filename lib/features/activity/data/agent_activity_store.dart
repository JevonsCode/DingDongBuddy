import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:path/path.dart' as path;

/// Claude Desktop indexes local Code sessions separately from CLI transcripts.
Directory? claudeDesktopSessionDirectoryForCurrentPlatform() {
  final String? home = Platform.environment['HOME'];
  final String? appData = Platform.environment['APPDATA'];
  final String? base = switch (Platform.operatingSystem) {
    'macos' when home != null => path.join(
      home,
      'Library',
      'Application Support',
    ),
    'windows' => appData,
    'linux' when home != null =>
      Platform.environment['XDG_CONFIG_HOME'] ?? path.join(home, '.config'),
    _ => null,
  };
  return base == null
      ? null
      : Directory(path.join(base, 'Claude', 'claude-code-sessions'));
}

/// Durable Agent completion details plus timestamp-only counting metadata.
final class AgentActivityHistory {
  const AgentActivityHistory({
    this.activities = const <AgentActivity>[],
    this.recentPageSize = 21,
    this.completionTimes = const <DateTime>[],
    this.latestSequence = 0,
    this.lastViewedSequence,
  });

  final int recentPageSize;
  final List<AgentActivity> activities;
  final List<DateTime> completionTimes;
  final int latestSequence;
  final int? lastViewedSequence;
}

abstract interface class AgentActivityStore {
  AgentActivityHistory load();

  void save(AgentActivityHistory history);

  void clear();
}

final class FileAgentActivityStore implements AgentActivityStore {
  FileAgentActivityStore(this.file, {this.claudeDesktopSessionDirectory});

  final File file;
  final Directory? claudeDesktopSessionDirectory;

  @override
  AgentActivityHistory load() {
    try {
      String? contents;
      // The host flushes .tmp before moving the current file to .bak. An
      // auxiliary engine can observe that short rename gap. If .tmp has
      // already moved into place by the time it is opened, retry current.
      for (final candidate in [file, File('${file.path}.tmp'), file]) {
        try {
          contents = candidate.readAsStringSync();
          break;
        } on FileSystemException {
          continue;
        }
      }
      if (contents == null) return const AgentActivityHistory();
      final Object? decoded = jsonDecode(contents);
      if (decoded is! Map<String, Object?> ||
          (decoded['version'] != 1 && decoded['version'] != 2) ||
          decoded['activities'] is! List<Object?>) {
        return const AgentActivityHistory();
      }
      final List<AgentActivity> loadedActivities =
          (decoded['activities']! as List)
              .map(
                (Object? value) => AgentActivity.fromJson(
                  Map<String, Object?>.from(value! as Map),
                ),
              )
              .toList(growable: false);
      final List<AgentActivity> activities = _restoreClaudeDesktopTargets(
        loadedActivities,
        claudeDesktopSessionDirectory,
      );
      final List<DateTime> completionTimes = decoded['completionTimes'] is List
          ? (decoded['completionTimes']! as List)
                .whereType<String>()
                .map((String value) => DateTime.parse(value).toUtc())
                .toList(growable: false)
          : activities
                .map((AgentActivity item) => item.completedAt.toUtc())
                .toList(growable: false);
      return AgentActivityHistory(
        latestSequence:
            decoded['latestSequence'] is int &&
                (decoded['latestSequence']! as int) >= 0
            ? decoded['latestSequence']! as int
            : 0,
        lastViewedSequence:
            decoded['lastViewedSequence'] is int &&
                (decoded['lastViewedSequence']! as int) >= 0
            ? decoded['lastViewedSequence']! as int
            : null,
        recentPageSize: decoded['recentPageSize'] is int
            ? (decoded['recentPageSize'] as int).clamp(1, 500)
            : 21,
        activities: List<AgentActivity>.unmodifiable(activities),
        completionTimes: List<DateTime>.unmodifiable(completionTimes),
      );
    } on Object {
      return const AgentActivityHistory();
    }
  }

  @override
  void save(AgentActivityHistory history) {
    file.parent.createSync(recursive: true);
    final File temporary = File('${file.path}.tmp');
    final File backup = File('${file.path}.bak');
    temporary.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 2,
        'latestSequence': history.latestSequence,
        if (history.lastViewedSequence != null)
          'lastViewedSequence': history.lastViewedSequence,
        'recentPageSize': history.recentPageSize,
        'activities': history.activities
            .map((AgentActivity item) => item.toJson())
            .toList(growable: false),
        'completionTimes': history.completionTimes
            .map((DateTime value) => value.toUtc().toIso8601String())
            .toList(growable: false),
      }),
      flush: true,
    );
    final bool hadOriginal = file.existsSync();
    try {
      if (backup.existsSync()) {
        backup.deleteSync();
      }
      if (hadOriginal) {
        file.renameSync(backup.path);
      }
      temporary.renameSync(file.path);
      if (backup.existsSync()) {
        backup.deleteSync();
      }
    } on Object {
      if (!file.existsSync() && backup.existsSync()) {
        backup.renameSync(file.path);
      }
      if (temporary.existsSync()) {
        temporary.deleteSync();
      }
      rethrow;
    }
  }

  @override
  void clear() {
    for (final File candidate in <File>[
      file,
      File('${file.path}.tmp'),
      File('${file.path}.bak'),
    ]) {
      if (candidate.existsSync()) {
        candidate.deleteSync();
      }
    }
  }
}

List<AgentActivity> _restoreClaudeDesktopTargets(
  List<AgentActivity> activities,
  Directory? directory,
) {
  if (directory == null ||
      !activities.any(
        (item) =>
            item.conversationTarget?.client == AgentClient.claudeCode ||
            item.conversationTarget?.client == AgentClient.claudeDesktop,
      )) {
    return activities;
  }
  final Map<String, ({String id, bool archived})> sessions = {};
  final Set<String> ambiguous = {};
  var scannedFiles = 0;
  var scannedBytes = 0;
  try {
    // Desktop stores records at account/organization/local_<id>.json. Do not
    // follow links or recursively scan unrelated user files.
    for (final account
        in directory.listSync(followLinks: false).whereType<Directory>()) {
      for (final organization
          in account.listSync(followLinks: false).whereType<Directory>()) {
        for (final file
            in organization.listSync(followLinks: false).whereType<File>()) {
          final String name = path.basename(file.path);
          if (!name.startsWith('local_') || !name.endsWith('.json')) continue;
          try {
            final int size = file.lengthSync();
            scannedFiles += 1;
            scannedBytes += size;
            // Incomplete scans cannot establish an unambiguous mapping.
            if (size > 2 * 1024 * 1024 ||
                scannedFiles > 2000 ||
                scannedBytes > 64 * 1024 * 1024) {
              return activities;
            }
            final Object? decoded = jsonDecode(file.readAsStringSync());
            if (decoded is! Map) return activities;
            final String id = decoded['sessionId'] is String
                ? decoded['sessionId'] as String
                : '';
            final String cliId = decoded['cliSessionId'] is String
                ? decoded['cliSessionId'] as String
                : '';
            if (name != '$id.json' ||
                !RegExp(r'^local_[A-Za-z0-9-]{1,64}$').hasMatch(id) ||
                cliId.isEmpty) {
              return activities;
            }
            // A CLI transcript imported into Desktop is not evidence that a
            // historical notification originated there.
            if (id == 'local_$cliId') {
              sessions.remove(cliId);
              ambiguous.add(cliId);
              continue;
            }
            if (sessions.containsKey(cliId) && sessions[cliId]!.id != id) {
              sessions.remove(cliId);
              ambiguous.add(cliId);
            } else if (!ambiguous.contains(cliId)) {
              sessions[cliId] = (
                id: id,
                archived: decoded['isArchived'] == true,
              );
            }
          } on Object {
            // A damaged or concurrently written session makes the index
            // incomplete; keep every existing source unchanged.
            return activities;
          }
        }
      }
    }
  } on Object {
    return activities;
  }
  return activities
      .map((item) {
        final target = item.conversationTarget;
        final session = sessions[target?.conversationId];
        if (target == null || session == null) return item;
        final bool legacy =
            target.client == AgentClient.claudeCode &&
            item.source.trim().toLowerCase() == 'claude code';
        if (!legacy && target.client != AgentClient.claudeDesktop) return item;
        if (!legacy &&
            target.hostSessionId != null &&
            target.hostSessionId != session.id) {
          return item;
        }
        final targetJson = target.toJson()
          ..['client'] = 'claude-desktop'
          ..remove('hostSessionId');
        if (!session.archived) targetJson['hostSessionId'] = session.id;
        return AgentActivity.fromJson({
          ...item.toJson(),
          'source': 'Claude Desktop',
          'conversationTarget': targetJson,
        });
      })
      .toList(growable: false);
}

final class InMemoryAgentActivityStore implements AgentActivityStore {
  InMemoryAgentActivityStore([this.history = const AgentActivityHistory()]);

  AgentActivityHistory history;

  @override
  AgentActivityHistory load() => history;

  @override
  void save(AgentActivityHistory history) {
    this.history = AgentActivityHistory(
      latestSequence: history.latestSequence,
      lastViewedSequence: history.lastViewedSequence,
      recentPageSize: history.recentPageSize,
      activities: List<AgentActivity>.unmodifiable(history.activities),
      completionTimes: List<DateTime>.unmodifiable(history.completionTimes),
    );
  }

  @override
  void clear() {
    history = const AgentActivityHistory();
  }
}
