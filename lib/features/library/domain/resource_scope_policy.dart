import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:path/path.dart' as path;

/// Resolves and validates the canonical project roots for a strict Skill.
///
/// Strict Skills intentionally accept only exact, existing, non-root local
/// project paths. The persisted canonical roots are a fail-closed guard in
/// addition to the mutable trigger-group definitions.
List<String> resolveStrictSkillProjectPaths(
  Iterable<String> triggerGroupIds,
  Map<String, TriggerGroup> triggerGroupsById,
) {
  final List<String> ids = triggerGroupIds.toSet().toList(growable: false);
  if (ids.isEmpty) {
    throw const FormatException(
      'strict project Skill scope requires an exact absolute projectPath rule',
    );
  }
  final List<String> unknownIds = ids
      .where((String id) => !triggerGroupsById.containsKey(id))
      .toList(growable: false);
  if (unknownIds.isNotEmpty) {
    throw FormatException(
      'strict project Skill scope references unknown trigger groups: '
      '${unknownIds.join(', ')}',
    );
  }
  final List<TriggerRule> rules = ids
      .expand((String id) => triggerGroupsById[id]!.rules)
      .toList(growable: false);
  if (rules.isEmpty ||
      rules.any(
        (TriggerRule rule) =>
            rule.field != TriggerRuleField.projectPath ||
            rule.operator != TriggerRuleOperator.equals,
      )) {
    throw const FormatException(
      'strict project Skill scope accepts only exact absolute projectPath rules',
    );
  }
  final List<String> resolved =
      rules
          .map((TriggerRule rule) => _canonicalExistingProjectPath(rule.value))
          .toSet()
          .toList(growable: false)
        ..sort();
  return resolved;
}

/// Applies ordinary trigger groups and the additional strict-Skill guard.
bool resourceMatchesScope(
  Resource resource,
  TriggerContext context,
  Map<String, TriggerGroup> triggerGroupsById,
) {
  if (resource.type == ResourceType.skill && resource.strictProjectSkill) {
    if (resource.triggerGroupIds.isEmpty ||
        resource.skillProjectPaths.isEmpty ||
        resource.triggerGroupIds.any(
          (String id) => !triggerGroupsById.containsKey(id),
        )) {
      return false;
    }
    try {
      final List<String> currentProjectPaths = resolveStrictSkillProjectPaths(
        resource.triggerGroupIds,
        triggerGroupsById,
      );
      final Set<String> persistedProjectPaths = resource.skillProjectPaths
          .toSet();
      if (currentProjectPaths.length != persistedProjectPaths.length ||
          currentProjectPaths.any(
            (String projectPath) =>
                !persistedProjectPaths.contains(projectPath),
          )) {
        return false;
      }
    } on FormatException {
      return false;
    }
    final bool currentGroupMatches = resource.triggerGroupIds.any(
      (String id) => triggerGroupsById[id]!.matches(context),
    );
    if (!currentGroupMatches) {
      return false;
    }
    return resource.skillProjectPaths.any(
      (String projectPath) => TriggerRule(
        field: TriggerRuleField.projectPath,
        operator: TriggerRuleOperator.equals,
        value: projectPath,
      ).matches(context),
    );
  }
  if (resource.triggerGroupIds.isEmpty) {
    return true;
  }
  return resource.triggerGroupIds.any(
    (String id) => triggerGroupsById[id]?.matches(context) ?? false,
  );
}

/// Decides whether a resource must exist in one Agent's native configuration.
///
/// Project-path and repository rules are evaluated later at the Bridge with a
/// concrete task context. They therefore cannot be used to exclude an MCP
/// from the user-level client configuration: doing so would make the server
/// unavailable exactly when that later runtime rule matches. Source-only
/// groups remain useful for routing an MCP to selected Agent clients.
bool resourceCanSyncToAgentSource(
  Resource resource,
  String source,
  Map<String, TriggerGroup> triggerGroupsById,
) {
  if (resource.triggerGroupIds.isEmpty) {
    return true;
  }
  final TriggerContext context = TriggerContext(source: source);
  for (final String id in resource.triggerGroupIds) {
    final TriggerGroup? group = triggerGroupsById[id];
    if (group == null || group.rules.isEmpty) {
      continue;
    }
    if (group.rules.any(
      (TriggerRule rule) => rule.field != TriggerRuleField.source,
    )) {
      return true;
    }
    if (group.matches(context)) {
      return true;
    }
  }
  return false;
}

String _canonicalExistingProjectPath(String value) {
  final String normalized = path.normalize(value.trim());
  final Directory directory = Directory(normalized);
  if (!path.isAbsolute(normalized) ||
      path.equals(normalized, path.dirname(normalized)) ||
      !directory.existsSync()) {
    throw FormatException(
      'strict project Skill scope requires an exact absolute projectPath '
      'that exists: $value',
    );
  }
  try {
    final String resolved = directory.resolveSymbolicLinksSync();
    if (path.equals(resolved, path.dirname(resolved))) {
      throw FormatException(
        'strict project Skill scope cannot use a filesystem root: $value',
      );
    }
    return resolved;
  } on FileSystemException {
    throw FormatException(
      'strict project Skill scope could not resolve projectPath: $value',
    );
  }
}
