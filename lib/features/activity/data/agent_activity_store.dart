import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/activity/domain/agent_activity.dart';

/// Durable Agent completion details plus timestamp-only counting metadata.
final class AgentActivityHistory {
  const AgentActivityHistory({
    this.activities = const <AgentActivity>[],
    this.completionTimes = const <DateTime>[],
  });

  final List<AgentActivity> activities;
  final List<DateTime> completionTimes;
}

abstract interface class AgentActivityStore {
  AgentActivityHistory load();

  void save(AgentActivityHistory history);

  void clear();
}

final class FileAgentActivityStore implements AgentActivityStore {
  FileAgentActivityStore(this.file);

  final File file;

  @override
  AgentActivityHistory load() {
    if (!file.existsSync()) {
      return const AgentActivityHistory();
    }
    try {
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?> ||
          decoded['version'] != 1 ||
          decoded['activities'] is! List<Object?>) {
        return const AgentActivityHistory();
      }
      final List<AgentActivity> activities = (decoded['activities']! as List)
          .map(
            (Object? value) => AgentActivity.fromJson(
              Map<String, Object?>.from(value! as Map),
            ),
          )
          .toList(growable: false);
      final List<DateTime> completionTimes = decoded['completionTimes'] is List
          ? (decoded['completionTimes']! as List)
                .whereType<String>()
                .map((String value) => DateTime.parse(value).toUtc())
                .toList(growable: false)
          : activities
                .map((AgentActivity item) => item.completedAt.toUtc())
                .toList(growable: false);
      return AgentActivityHistory(
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
        'version': 1,
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
    if (file.existsSync()) {
      file.deleteSync();
    }
  }
}

final class InMemoryAgentActivityStore implements AgentActivityStore {
  InMemoryAgentActivityStore([this.history = const AgentActivityHistory()]);

  AgentActivityHistory history;

  @override
  AgentActivityHistory load() => history;

  @override
  void save(AgentActivityHistory history) {
    this.history = AgentActivityHistory(
      activities: List<AgentActivity>.unmodifiable(history.activities),
      completionTimes: List<DateTime>.unmodifiable(history.completionTimes),
    );
  }

  @override
  void clear() {
    history = const AgentActivityHistory();
  }
}
