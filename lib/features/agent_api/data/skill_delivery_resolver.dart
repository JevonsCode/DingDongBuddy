import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:dingdong/features/library/domain/skill_deployment_plan.dart';
import 'package:path/path.dart' as path;

typedef SkillDeploymentPresenceQuery =
    Future<SkillDeploymentPresence> Function({
      required String resourceId,
      required String agentId,
      required String workspace,
    });

enum SkillSuppressionReason {
  nativeDelivery,
  unknownAgentWithNativeRoute,
  nativePresenceUncertain,
}

final class SkillDeliverySuppression {
  const SkillDeliverySuppression({
    required this.resourceId,
    required this.reason,
  });

  final String resourceId;
  final SkillSuppressionReason reason;

  Map<String, Object?> toJson() => <String, Object?>{
    'resourceId': resourceId,
    'reason': reason.name,
  };
}

final class DynamicSkillCandidate {
  const DynamicSkillCandidate({
    required this.resource,
    required this.configuration,
    required this.artifactFingerprint,
    this.deduplicatedResourceIds = const <String>[],
  });

  final Resource resource;
  final SkillConfiguration configuration;
  final String artifactFingerprint;
  final List<String> deduplicatedResourceIds;
}

final class SkillDeliveryConflict {
  const SkillDeliveryConflict({required this.name, required this.resourceIds});

  final String name;
  final List<String> resourceIds;

  Map<String, Object?> toJson() => <String, Object?>{
    'name': name,
    'candidateIds': resourceIds,
    'reason': 'different-artifacts-share-one-skill-name',
  };
}

final class SkillDeliveryResolution {
  const SkillDeliveryResolution({
    required this.candidates,
    required this.conflicts,
    required this.suppressed,
  });

  final List<DynamicSkillCandidate> candidates;
  final List<SkillDeliveryConflict> conflicts;
  final List<SkillDeliverySuppression> suppressed;
}

/// Resolves the one allowed Skill delivery plane for a concrete Agent task.
///
/// This is deliberately shared by catalog and full-load paths. An id-based
/// load must not bypass native/dynamic arbitration or a duplicate-name
/// conflict detected while building the catalog.
Future<SkillDeliveryResolution> resolveSkillDelivery({
  required Iterable<Resource> resources,
  String? agentId,
  required String workspacePath,
  SkillDeploymentPresenceQuery? queryPresence,
}) async {
  final String? normalizedAgentId = _trimmedOrNull(agentId);
  final List<DynamicSkillCandidate> eligible = <DynamicSkillCandidate>[];
  final List<SkillDeliverySuppression> suppressed =
      <SkillDeliverySuppression>[];
  for (final Resource resource in resources) {
    if (resource.type != ResourceType.skill) {
      continue;
    }
    SkillConfiguration configuration;
    try {
      configuration = SkillConfiguration.parseOnline(resource.content);
    } on FormatException {
      continue;
    }

    if (normalizedAgentId == null) {
      final bool hasNativeRoute = resource.skillDeliveryByAgent.values.any(
        (SkillDeliveryMode mode) => mode != SkillDeliveryMode.dynamic,
      );
      if (hasNativeRoute) {
        suppressed.add(
          SkillDeliverySuppression(
            resourceId: resource.id,
            reason: SkillSuppressionReason.unknownAgentWithNativeRoute,
          ),
        );
        continue;
      }
    } else {
      final SkillDeliveryMode mode = resource.skillDeliveryForAgent(
        normalizedAgentId,
      );
      if (mode != SkillDeliveryMode.dynamic) {
        suppressed.add(
          SkillDeliverySuppression(
            resourceId: resource.id,
            reason: SkillSuppressionReason.nativeDelivery,
          ),
        );
        continue;
      }
      if (queryPresence != null &&
          await _nativeCopyMightRemain(
            queryPresence: queryPresence,
            resourceId: resource.id,
            agentId: normalizedAgentId,
            workspacePath: workspacePath,
          )) {
        suppressed.add(
          SkillDeliverySuppression(
            resourceId: resource.id,
            reason: SkillSuppressionReason.nativePresenceUncertain,
          ),
        );
        continue;
      }
    }

    eligible.add(
      DynamicSkillCandidate(
        resource: resource,
        configuration: configuration,
        artifactFingerprint:
            resource.skillPackageDigest ??
            'document:${await _documentDigest(resource.content)}',
      ),
    );
  }

  final Map<String, List<DynamicSkillCandidate>> byName =
      <String, List<DynamicSkillCandidate>>{};
  for (final DynamicSkillCandidate candidate in eligible) {
    byName
        .putIfAbsent(
          candidate.configuration.name,
          () => <DynamicSkillCandidate>[],
        )
        .add(candidate);
  }
  final List<DynamicSkillCandidate> winners = <DynamicSkillCandidate>[];
  final List<SkillDeliveryConflict> conflicts = <SkillDeliveryConflict>[];
  final List<String> names = byName.keys.toList()..sort();
  for (final String name in names) {
    final List<DynamicSkillCandidate> candidates = byName[name]!
      ..sort(
        (DynamicSkillCandidate left, DynamicSkillCandidate right) =>
            left.resource.id.compareTo(right.resource.id),
      );
    final Set<String> fingerprints = candidates
        .map((DynamicSkillCandidate value) => value.artifactFingerprint)
        .toSet();
    if (fingerprints.length > 1) {
      conflicts.add(
        SkillDeliveryConflict(
          name: name,
          resourceIds: List<String>.unmodifiable(
            candidates.map((DynamicSkillCandidate value) => value.resource.id),
          ),
        ),
      );
      continue;
    }
    final DynamicSkillCandidate winner = candidates.first;
    winners.add(
      DynamicSkillCandidate(
        resource: winner.resource,
        configuration: winner.configuration,
        artifactFingerprint: winner.artifactFingerprint,
        deduplicatedResourceIds: List<String>.unmodifiable(
          candidates
              .skip(1)
              .map((DynamicSkillCandidate value) => value.resource.id),
        ),
      ),
    );
  }
  return SkillDeliveryResolution(
    candidates: List<DynamicSkillCandidate>.unmodifiable(winners),
    conflicts: List<SkillDeliveryConflict>.unmodifiable(conflicts),
    suppressed: List<SkillDeliverySuppression>.unmodifiable(suppressed),
  );
}

Future<String> _documentDigest(String document) async {
  final Hash digest = await Sha256().hash(utf8.encode(document));
  return digest.bytes
      .map((int value) => value.toRadixString(16).padLeft(2, '0'))
      .join();
}

Future<bool> _nativeCopyMightRemain({
  required SkillDeploymentPresenceQuery queryPresence,
  required String resourceId,
  required String agentId,
  required String workspacePath,
}) async {
  final Set<String> workspaces = <String>{'user'};
  final String workspace = workspacePath.trim();
  if (workspace.isNotEmpty) {
    workspaces.add(path.normalize(path.absolute(workspace)));
  }
  try {
    for (final String value in workspaces) {
      final SkillDeploymentPresence presence = await queryPresence(
        resourceId: resourceId,
        agentId: agentId,
        workspace: value,
      );
      if (presence != SkillDeploymentPresence.confirmedAbsent) {
        return true;
      }
    }
    return false;
  } on Object {
    return true;
  }
}

String? _trimmedOrNull(String? value) {
  final String trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
