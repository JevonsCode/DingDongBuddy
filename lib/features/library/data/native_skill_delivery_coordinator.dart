import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/skill_deployment_reconciler.dart';
import 'package:dingdong/features/library/data/skill_deployment_store.dart';
import 'package:dingdong/features/library/domain/project_hook_integration.dart';
import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:dingdong/features/library/domain/skill_deployment_plan.dart';
import 'package:path/path.dart' as path;

/// One provider-specific pair of native Skill discovery roots.
final class AgentSkillTarget {
  const AgentSkillTarget({
    required this.agentId,
    required this.clientName,
    required this.globalRoot,
    required this.projectRelativeRoot,
  });

  final String agentId;
  final String clientName;
  final Directory globalRoot;
  final String projectRelativeRoot;
}

/// Turns Resource desired state into receipt-owned native Skill deployments.
///
/// Dynamic delivery remains outside this coordinator. Native deployment and
/// project Hook configuration are reconciled independently so their switches
/// cannot accidentally enable each other.
final class NativeSkillDeliveryCoordinator {
  NativeSkillDeliveryCoordinator({
    required this.store,
    this.hookInventory,
    SkillDeploymentReconciler? reconciler,
  }) : reconciler = reconciler ?? SkillDeploymentReconciler(store: store);

  final SkillDeploymentStore store;
  final CodexProjectHookInventory? hookInventory;
  final SkillDeploymentReconciler reconciler;

  Future<void> recoverPending({
    required List<Resource> resources,
    required List<AgentSkillTarget> targets,
  }) => store.exclusive(() async {
    final Map<String, Resource> resourcesById = <String, Resource>{
      for (final Resource resource in resources)
        if (resource.type == ResourceType.skill) resource.id: resource,
    };
    final Set<String> availableAgents = targets
        .map((AgentSkillTarget value) => value.agentId)
        .toSet();
    final SkillDeploymentJournal journal = await store.readJournal();
    final List<SkillDeploymentPlan> plans = journal.operations.values
        .map((SkillDeploymentOperation operation) {
          final Resource? resource = resourcesById[operation.resourceId];
          final SkillDeliveryMode mode =
              resource?.skillDeliveryForAgent(operation.agentId) ??
              SkillDeliveryMode.dynamic;
          final bool desiredPresent =
              resource != null &&
              resource.enabled &&
              availableAgents.contains(operation.agentId) &&
              ((mode == SkillDeliveryMode.nativeUser &&
                      operation.workspace == 'user') ||
                  (mode == SkillDeliveryMode.nativeProject &&
                      resource.skillProjectPaths
                          .map(
                            (String value) =>
                                path.normalize(path.absolute(value)),
                          )
                          .contains(operation.workspace)));
          if (desiredPresent) {
            return SkillDeploymentPlan.install(
              resourceId: operation.resourceId,
              agentId: operation.agentId,
              workspace: operation.workspace,
              sourceDirectory: Directory(
                resource.packagePath ?? operation.destinationPath,
              ),
              expectedPackageDigest: _expectedDigest(resource),
              destinationDirectory: Directory(operation.destinationPath),
            );
          }
          return SkillDeploymentPlan.remove(
            resourceId: operation.resourceId,
            agentId: operation.agentId,
            workspace: operation.workspace,
            destinationDirectory: Directory(operation.destinationPath),
          );
        })
        .toList(growable: false);
    await reconciler.recoverOperations(plans);
  });

  Future<void> reconcile({
    required List<Resource> resources,
    required List<AgentSkillTarget> targets,
  }) => store.exclusive(
    () => _reconcileLocked(resources: resources, targets: targets),
  );

  Future<void> _reconcileLocked({
    required List<Resource> resources,
    required List<AgentSkillTarget> targets,
  }) async {
    final Map<String, Resource> resourcesById = <String, Resource>{
      for (final Resource resource in resources)
        if (resource.type == ResourceType.skill) resource.id: resource,
    };
    final List<_DesiredDeployment> desired = _desiredDeployments(
      resourcesById.values,
      targets,
    );
    _rejectDestinationCollisions(desired);

    final Map<String, _DesiredDeployment> desiredByKey =
        <String, _DesiredDeployment>{
          for (final _DesiredDeployment value in desired)
            value.plan.deploymentKey: value,
        };
    final SkillDeploymentObservedState observed = await store.readObserved();
    final SkillDeploymentJournal journal = await store.readJournal();
    final Map<String, SkillDeploymentPlan> recoveryPlans =
        <String, SkillDeploymentPlan>{
          for (final _DesiredDeployment value in desired)
            value.plan.deploymentKey: value.plan,
        };

    for (final SkillDeploymentObservation value
        in observed.deployments.values) {
      if (desiredByKey.containsKey(value.deploymentKey) ||
          _retainWhileAdapterUnavailable(value, resourcesById, targets)) {
        continue;
      }
      recoveryPlans[value.deploymentKey] = _removePlan(value);
    }
    for (final SkillDeploymentOperation value in journal.operations.values) {
      if (recoveryPlans.containsKey(value.deploymentKey)) {
        continue;
      }
      recoveryPlans[value.deploymentKey] = SkillDeploymentPlan.remove(
        resourceId: value.resourceId,
        agentId: value.agentId,
        workspace: value.workspace,
        destinationDirectory: Directory(value.destinationPath),
      );
    }
    await reconciler.recoverOperations(recoveryPlans.values);

    final SkillDeploymentObservedState recoveredObserved = await store
        .readObserved();
    final List<SkillDeploymentObservation> obsolete = recoveredObserved
        .deployments
        .values
        .where(
          (SkillDeploymentObservation value) =>
              !desiredByKey.containsKey(value.deploymentKey) &&
              !_retainWhileAdapterUnavailable(value, resourcesById, targets),
        )
        .toList(growable: false);

    // Remove obsolete Hook entries before their script tree disappears.
    for (final SkillDeploymentObservation value in obsolete) {
      await _reconcileImpeccableHook(value, enabled: false);
    }

    // Remove the old delivery plane before installing its replacement. A
    // synchronized ResourceStore restores the previous desired state if the
    // replacement fails, while this order guarantees no transient duplicate.
    for (final SkillDeploymentObservation value in obsolete) {
      final SkillDeploymentResult result = await reconciler.reconcile(
        _removePlan(value),
      );
      if (result.outcome != SkillDeploymentOutcome.removed &&
          result.outcome != SkillDeploymentOutcome.absent &&
          result.outcome != SkillDeploymentOutcome.recovered) {
        throw StateError(
          'Refusing to remove an unverified native Skill at '
          '${value.destinationPath}: ${result.outcome.name}.',
        );
      }
    }

    // Resource desired state is persisted before this call, so Bridge already
    // withholds these Skills while native copies are staged and verified.
    for (final _DesiredDeployment value in desired) {
      final SkillDeploymentResult result = await reconciler.reconcile(
        value.plan,
      );
      _requireUsableResult(result, value);
      final SkillDeploymentObservation? installed =
          (await store.readObserved()).deployments[value.plan.deploymentKey];
      if (installed == null || installed.contentDigest == null) {
        throw StateError(
          'Native Skill deployment was not durably observed at '
          '${value.plan.destinationPath}.',
        );
      }
      if (value.hooksEnabled && value.skillName != 'impeccable') {
        throw StateError(
          'Project Hook integration is not available for '
          'Skill "${value.skillName}".',
        );
      }
      if (value.plan.agentId == 'codex' &&
          value.plan.workspace != 'user' &&
          value.skillName == 'impeccable') {
        await _reconcileImpeccableHook(installed, enabled: value.hooksEnabled);
      } else if (value.hooksEnabled) {
        throw StateError(
          'Hooks require a Codex project-native Skill deployment.',
        );
      }
    }
  }

  List<_DesiredDeployment> _desiredDeployments(
    Iterable<Resource> resources,
    List<AgentSkillTarget> targets,
  ) {
    final Map<String, AgentSkillTarget> targetsByAgent =
        <String, AgentSkillTarget>{
          for (final AgentSkillTarget target in targets) target.agentId: target,
        };
    final List<_DesiredDeployment> desired = <_DesiredDeployment>[];
    for (final Resource resource in resources) {
      if (!resource.enabled) {
        continue;
      }
      final bool hasUserNative = resource.skillDeliveryByAgent.values.any(
        (SkillDeliveryMode mode) => mode == SkillDeliveryMode.nativeUser,
      );
      final bool hasProjectNative = resource.skillDeliveryByAgent.values.any(
        (SkillDeliveryMode mode) => mode == SkillDeliveryMode.nativeProject,
      );
      if (hasUserNative && hasProjectNative) {
        throw StateError(
          'One Skill cannot mix user-native and project-native delivery '
          'across Agents.',
        );
      }
      if (hasUserNative &&
          (resource.triggerGroupIds.isNotEmpty ||
              resource.strictProjectSkill ||
              resource.skillProjectPaths.isNotEmpty)) {
        throw StateError(
          'User-native Skills are global and cannot retain project scope.',
        );
      }
      final String skillName = SkillConfiguration.parseOnline(
        resource.content,
      ).name;
      for (final MapEntry<String, SkillDeliveryMode> delivery
          in resource.skillDeliveryByAgent.entries) {
        if (delivery.value == SkillDeliveryMode.dynamic) {
          continue;
        }
        final AgentSkillTarget? target = targetsByAgent[delivery.key];
        if (target == null) {
          // Desired native delivery remains fail-closed at Bridge. A missing
          // Adapter is readiness state, not permission to fall back dynamic.
          continue;
        }
        if (delivery.value == SkillDeliveryMode.nativeUser) {
          if (resource.skillHooksEnabledForAgent(delivery.key)) {
            throw StateError('User-native Skills cannot enable project Hooks.');
          }
          desired.add(
            _DesiredDeployment(
              resource: resource,
              skillName: skillName,
              hooksEnabled: false,
              plan: SkillDeploymentPlan.install(
                resourceId: resource.id,
                agentId: delivery.key,
                workspace: 'user',
                sourceDirectory: _source(resource),
                expectedPackageDigest: _expectedDigest(resource),
                destinationDirectory: _safeDestination(
                  target.globalRoot,
                  skillName,
                ),
              ),
            ),
          );
          continue;
        }
        if (!resource.strictProjectSkill ||
            resource.skillProjectPaths.isEmpty) {
          throw StateError(
            'Project-native Skills require at least one exact project scope.',
          );
        }
        final bool hooksEnabled = resource.skillHooksEnabledForAgent(
          delivery.key,
        );
        if (hooksEnabled &&
            (delivery.key != 'codex' || skillName != 'impeccable')) {
          throw StateError(
            'Managed Hooks require Impeccable with Codex project-native '
            'delivery.',
          );
        }
        for (final String projectPath in resource.skillProjectPaths) {
          final Directory project = Directory(
            path.normalize(path.absolute(projectPath)),
          );
          if (!project.existsSync() ||
              path.equals(project.path, path.dirname(project.path))) {
            throw StateError(
              'Project-native Skill path is not an existing project: '
              '${project.path}.',
            );
          }
          final Directory root = Directory(
            path.join(project.path, target.projectRelativeRoot),
          );
          desired.add(
            _DesiredDeployment(
              resource: resource,
              skillName: skillName,
              hooksEnabled: hooksEnabled,
              plan: SkillDeploymentPlan.install(
                resourceId: resource.id,
                agentId: delivery.key,
                workspace: path.normalize(project.absolute.path),
                sourceDirectory: _source(resource),
                expectedPackageDigest: _expectedDigest(resource),
                destinationDirectory: _safeDestination(
                  root,
                  skillName,
                  containmentRoot: project,
                ),
              ),
            ),
          );
        }
      }
    }
    return desired;
  }

  bool _retainWhileAdapterUnavailable(
    SkillDeploymentObservation observation,
    Map<String, Resource> resourcesById,
    List<AgentSkillTarget> targets,
  ) {
    final Resource? resource = resourcesById[observation.resourceId];
    if (resource == null || !resource.enabled) {
      return false;
    }
    final SkillDeliveryMode mode = resource.skillDeliveryForAgent(
      observation.agentId,
    );
    if (mode == SkillDeliveryMode.dynamic) {
      return false;
    }
    final bool adapterAvailable = targets.any(
      (AgentSkillTarget target) => target.agentId == observation.agentId,
    );
    if (adapterAvailable) {
      return false;
    }
    return mode == SkillDeliveryMode.nativeUser
        ? observation.workspace == 'user'
        : resource.skillProjectPaths
              .map((String value) => path.normalize(path.absolute(value)))
              .contains(observation.workspace);
  }

  Future<HookReconcileResult?> _reconcileImpeccableHook(
    SkillDeploymentObservation deployment, {
    required bool enabled,
  }) async {
    if (deployment.agentId != 'codex' || deployment.workspace == 'user') {
      return null;
    }
    if (path.basename(deployment.destinationPath) != 'impeccable') {
      return null;
    }
    final HookDesiredState desiredState = enabled
        ? HookDesiredState.enabled
        : HookDesiredState.disabled;
    final HookReconcileResult result =
        await CodexProjectHookIntegration(
          projectRoot: Directory(deployment.workspace),
          inventory: hookInventory,
        ).reconcile(
          desiredState: desiredState,
          deployment: HookDeployment(
            deploymentId: deployment.deploymentKey,
            artifactDigest: deployment.contentDigest ?? 'unknown',
            skillRelativePath: _relativeSkillPath(deployment),
          ),
          adapter: const ImpeccableCodexHookAdapter(),
        );
    if (!enabled &&
        result.disposition == HookReconcileDisposition.externalSatisfied) {
      throw StateError(
        'The Impeccable Hook is still supplied by an external Codex source. '
        'Review and disable that source with Codex /hooks before turning off '
        'this Hook or removing its Skill deployment.',
      );
    }
    await store.upsertObservation(
      deployment.withHookReconcile(desiredState: desiredState, result: result),
    );
    return result;
  }

  String _relativeSkillPath(SkillDeploymentObservation deployment) {
    final String relative = path
        .relative(deployment.destinationPath, from: deployment.workspace)
        .replaceAll(path.separator, '/');
    if (relative.isEmpty ||
        relative == '.' ||
        path.posix.isAbsolute(relative) ||
        relative == '..' ||
        relative.startsWith('../')) {
      throw StateError(
        'Codex project Skill destination must remain inside its workspace.',
      );
    }
    return relative;
  }
}

final class _DesiredDeployment {
  const _DesiredDeployment({
    required this.resource,
    required this.skillName,
    required this.hooksEnabled,
    required this.plan,
  });

  final Resource resource;
  final String skillName;
  final bool hooksEnabled;
  final SkillDeploymentPlan plan;
}

Directory _source(Resource resource) {
  final String? packagePath = resource.packagePath;
  if (packagePath == null || packagePath.trim().isEmpty) {
    throw StateError(
      'Native Skill "${resource.title}" requires a complete managed package.',
    );
  }
  return Directory(packagePath);
}

String? _expectedDigest(Resource resource) {
  final String? digest = resource.skillPackageDigest;
  return digest != null && digest.startsWith('sha256:') ? digest : null;
}

Directory _safeDestination(
  Directory root,
  String skillName, {
  Directory? containmentRoot,
}) {
  final String rootPath = path.normalize(path.absolute(root.path));
  final String destination = path.normalize(path.join(rootPath, skillName));
  if (!path.isWithin(rootPath, destination)) {
    throw StateError('Native Skill destination escapes its Adapter root.');
  }
  if (containmentRoot != null) {
    final String canonicalContainment = canonicalSkillDeploymentPath(
      containmentRoot.path,
    );
    final String canonicalDestination = canonicalSkillDeploymentPath(
      destination,
    );
    if (!path.isWithin(canonicalContainment, canonicalDestination)) {
      throw StateError(
        'Project-native Skill destination escapes its project workspace.',
      );
    }
  }
  return Directory(destination);
}

SkillDeploymentPlan _removePlan(SkillDeploymentObservation value) =>
    SkillDeploymentPlan.remove(
      resourceId: value.resourceId,
      agentId: value.agentId,
      workspace: value.workspace,
      destinationDirectory: Directory(value.destinationPath),
    );

void _rejectDestinationCollisions(List<_DesiredDeployment> desired) {
  final Map<String, List<_DesiredDeployment>> byDestination =
      <String, List<_DesiredDeployment>>{};
  for (final _DesiredDeployment value in desired) {
    byDestination
        .putIfAbsent(value.plan.destinationKey, () => <_DesiredDeployment>[])
        .add(value);
  }
  for (final MapEntry<String, List<_DesiredDeployment>> entry
      in byDestination.entries) {
    if (entry.value.length > 1) {
      throw StateError(
        'Multiple DingDong Skills target ${entry.key}: '
        '${entry.value.map((_DesiredDeployment value) => value.resource.id).join(', ')}.',
      );
    }
  }
}

void _requireUsableResult(
  SkillDeploymentResult result,
  _DesiredDeployment desired,
) {
  if (result.outcome == SkillDeploymentOutcome.installed ||
      result.outcome == SkillDeploymentOutcome.updated ||
      result.outcome == SkillDeploymentOutcome.unchanged ||
      result.outcome == SkillDeploymentOutcome.recovered) {
    return;
  }
  throw StateError(
    'Native Skill "${desired.skillName}" could not be deployed to '
    '${desired.plan.destinationPath}: ${result.outcome.name}.',
  );
}
