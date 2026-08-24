part of 'agent_resource_synchronizer.dart';

// Merge concurrent Resource Manager edits without losing usage-only updates.
List<Resource> _mergeConcurrentResources({
  required List<Resource> base,
  required List<Resource> current,
  required List<Resource> proposed,
}) {
  final Map<String, Resource> baseById = <String, Resource>{
    for (final Resource resource in base) resource.id: resource,
  };
  final Map<String, Resource> currentById = <String, Resource>{
    for (final Resource resource in current) resource.id: resource,
  };
  final Map<String, Resource> proposedById = <String, Resource>{
    for (final Resource resource in proposed) resource.id: resource,
  };
  final List<Resource> merged = <Resource>[];
  for (final Resource candidate in proposed) {
    final Resource? baseline = baseById[candidate.id];
    final Resource? latest = currentById[candidate.id];
    if (baseline == null) {
      if (latest != null && latest != candidate) {
        throw StateError(
          'Resource "${candidate.title}" was created differently in another '
          'window. Reload before saving.',
        );
      }
      merged.add(latest ?? candidate);
      continue;
    }
    if (latest == null) {
      if (!_sameResourceConfiguration(candidate, baseline)) {
        throw StateError(
          'Resource "${candidate.title}" was deleted in another window. '
          'Reload before saving.',
        );
      }
      continue;
    }
    final bool latestChanged = !_sameResourceConfiguration(latest, baseline);
    final bool candidateChanged = !_sameResourceConfiguration(
      candidate,
      baseline,
    );
    if (latestChanged &&
        candidateChanged &&
        !_sameResourceConfiguration(latest, candidate)) {
      throw StateError(
        'Resource "${candidate.title}" changed in another window. Reload '
        'before saving so delivery, scope, and Hook switches are not '
        'overwritten.',
      );
    }
    if (latestChanged && !candidateChanged) {
      merged.add(latest);
    } else {
      merged.add(_mergeUsageMetadata(candidate, latest, baseline));
    }
  }
  for (final Resource baseline in base) {
    if (proposedById.containsKey(baseline.id)) {
      continue;
    }
    final Resource? latest = currentById[baseline.id];
    if (latest != null && !_sameResourceConfiguration(latest, baseline)) {
      throw StateError(
        'Resource "${baseline.title}" changed in another window and cannot '
        'be deleted from a stale view. Reload before saving.',
      );
    }
  }
  for (final Resource latest in current) {
    if (!baseById.containsKey(latest.id) &&
        !proposedById.containsKey(latest.id)) {
      merged.add(latest);
    }
  }
  return merged;
}

bool _sameResourceConfiguration(Resource first, Resource second) {
  final Map<String, Object?> firstJson = first.toJson()
    ..remove('candidateCount')
    ..remove('lastCandidateAt')
    ..remove('usageCount')
    ..remove('lastUsedAt')
    ..remove('invocationCount')
    ..remove('lastInvokedAt');
  final Map<String, Object?> secondJson = second.toJson()
    ..remove('candidateCount')
    ..remove('lastCandidateAt')
    ..remove('usageCount')
    ..remove('lastUsedAt')
    ..remove('invocationCount')
    ..remove('lastInvokedAt');
  return jsonEncode(firstJson) == jsonEncode(secondJson);
}

Resource _mergeUsageMetadata(
  Resource candidate,
  Resource latest,
  Resource baseline,
) {
  final bool latestCandidateChanged =
      latest.candidateCount != baseline.candidateCount ||
      latest.lastCandidateAt != baseline.lastCandidateAt;
  final bool candidateCandidateChanged =
      candidate.candidateCount != baseline.candidateCount ||
      candidate.lastCandidateAt != baseline.lastCandidateAt;
  final int candidateCount = latestCandidateChanged && candidateCandidateChanged
      ? max(latest.candidateCount, candidate.candidateCount)
      : latestCandidateChanged
      ? latest.candidateCount
      : candidate.candidateCount;
  final DateTime? lastCandidateAt =
      latestCandidateChanged && candidateCandidateChanged
      ? _laterDate(latest.lastCandidateAt, candidate.lastCandidateAt)
      : latestCandidateChanged
      ? latest.lastCandidateAt
      : candidate.lastCandidateAt;
  final bool latestChanged =
      latest.usageCount != baseline.usageCount ||
      latest.lastUsedAt != baseline.lastUsedAt;
  final bool candidateChanged =
      candidate.usageCount != baseline.usageCount ||
      candidate.lastUsedAt != baseline.lastUsedAt;
  final int usageCount = latestChanged && candidateChanged
      ? max(latest.usageCount, candidate.usageCount)
      : latestChanged
      ? latest.usageCount
      : candidate.usageCount;
  final DateTime? lastUsedAt = latestChanged && candidateChanged
      ? _laterDate(latest.lastUsedAt, candidate.lastUsedAt)
      : latestChanged
      ? latest.lastUsedAt
      : candidate.lastUsedAt;
  final bool latestInvocationChanged =
      latest.invocationCount != baseline.invocationCount ||
      latest.lastInvokedAt != baseline.lastInvokedAt;
  final bool candidateInvocationChanged =
      candidate.invocationCount != baseline.invocationCount ||
      candidate.lastInvokedAt != baseline.lastInvokedAt;
  final int invocationCount =
      latestInvocationChanged && candidateInvocationChanged
      ? max(latest.invocationCount, candidate.invocationCount)
      : latestInvocationChanged
      ? latest.invocationCount
      : candidate.invocationCount;
  final DateTime? lastInvokedAt =
      latestInvocationChanged && candidateInvocationChanged
      ? _laterDate(latest.lastInvokedAt, candidate.lastInvokedAt)
      : latestInvocationChanged
      ? latest.lastInvokedAt
      : candidate.lastInvokedAt;
  final Map<String, Object?> json = candidate.toJson();
  json['candidateCount'] = candidateCount;
  if (lastCandidateAt != null) {
    json['lastCandidateAt'] = lastCandidateAt.toIso8601String();
  } else {
    json.remove('lastCandidateAt');
  }
  json['usageCount'] = usageCount;
  if (lastUsedAt != null) {
    json['lastUsedAt'] = lastUsedAt.toIso8601String();
  } else {
    json.remove('lastUsedAt');
  }
  json['invocationCount'] = invocationCount;
  if (lastInvokedAt != null) {
    json['lastInvokedAt'] = lastInvokedAt.toIso8601String();
  } else {
    json.remove('lastInvokedAt');
  }
  return Resource.fromJson(json);
}

DateTime? _laterDate(DateTime? first, DateTime? second) {
  if (first == null) {
    return second;
  }
  if (second == null) {
    return first;
  }
  return first.isAfter(second) ? first : second;
}

bool _onlyAgentResourceUsageChanged(
  List<Resource> previous,
  List<Resource> current,
) {
  if (previous.length != current.length) {
    return false;
  }
  bool usageChanged = false;
  for (int index = 0; index < previous.length; index += 1) {
    usageChanged =
        usageChanged ||
        previous[index].candidateCount != current[index].candidateCount ||
        previous[index].lastCandidateAt != current[index].lastCandidateAt ||
        previous[index].usageCount != current[index].usageCount ||
        previous[index].lastUsedAt != current[index].lastUsedAt ||
        previous[index].invocationCount != current[index].invocationCount ||
        previous[index].lastInvokedAt != current[index].lastInvokedAt;
    final Map<String, Object?> before = previous[index].toJson()
      ..remove('candidateCount')
      ..remove('lastCandidateAt')
      ..remove('usageCount')
      ..remove('lastUsedAt')
      ..remove('invocationCount')
      ..remove('lastInvokedAt');
    final Map<String, Object?> after = current[index].toJson()
      ..remove('candidateCount')
      ..remove('lastCandidateAt')
      ..remove('usageCount')
      ..remove('lastUsedAt')
      ..remove('invocationCount')
      ..remove('lastInvokedAt');
    if (jsonEncode(before) != jsonEncode(after)) {
      return false;
    }
  }
  return usageChanged;
}

String _toml(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\n', r'\n');
