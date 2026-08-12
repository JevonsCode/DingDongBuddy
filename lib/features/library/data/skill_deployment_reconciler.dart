import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/library/data/skill_deployment_store.dart';
import 'package:dingdong/features/library/domain/skill_deployment_plan.dart';
import 'package:dingdong/features/library/domain/skill_package_digest.dart';
import 'package:path/path.dart' as path;

final class SkillDeploymentReconciler {
  SkillDeploymentReconciler({required this.store});

  final SkillDeploymentStore store;

  Future<SkillDeploymentResult> reconcile(SkillDeploymentPlan plan) =>
      store.exclusive(() => _reconcileLocked(plan));

  Future<SkillDeploymentResult> _reconcileLocked(
    SkillDeploymentPlan plan,
  ) async {
    final bool recovered = (await recoverOperations(<SkillDeploymentPlan>[
      plan,
    ])).isNotEmpty;
    final SkillDeploymentResult result;
    if (plan.desiredState == SkillDeploymentDesiredState.absent) {
      result = await _remove(plan);
    } else {
      result = await _reconcilePresent(plan);
    }
    if (recovered &&
        (result.outcome == SkillDeploymentOutcome.unchanged ||
            result.outcome == SkillDeploymentOutcome.absent)) {
      return _result(plan, SkillDeploymentOutcome.recovered);
    }
    return result;
  }

  Future<List<SkillDeploymentResult>> recoverOperations(
    Iterable<SkillDeploymentPlan> plans,
  ) => store.exclusive(() => _recoverOperationsLocked(plans));

  Future<List<SkillDeploymentResult>> _recoverOperationsLocked(
    Iterable<SkillDeploymentPlan> plans,
  ) async {
    final Map<String, SkillDeploymentPlan> plansByKey =
        <String, SkillDeploymentPlan>{
          for (final SkillDeploymentPlan plan in plans)
            plan.deploymentKey: plan,
        };
    final SkillDeploymentJournal journal = await store.readJournal();
    final List<SkillDeploymentResult> recovered = <SkillDeploymentResult>[];
    for (final SkillDeploymentOperation operation
        in journal.operations.values.toList()) {
      final SkillDeploymentPlan? plan = plansByKey[operation.deploymentKey];
      if (plan == null) {
        continue;
      }
      _validateRecoveryIdentity(operation, plan);
      await _recoverOperation(operation, plan);
      recovered.add(_result(plan, SkillDeploymentOutcome.recovered));
    }
    return recovered;
  }

  Future<SkillDeploymentResult> _reconcilePresent(
    SkillDeploymentPlan plan,
  ) async {
    final Directory source = plan.sourceDirectory!;
    if (!await source.exists()) {
      throw FileSystemException(
        'Skill source directory does not exist.',
        source.path,
      );
    }
    if (!await File(path.join(source.path, 'SKILL.md')).exists()) {
      throw const FormatException('Skill package does not contain SKILL.md.');
    }
    final String sourceDigest = await computeSkillPackageDigest(source);
    if (plan.expectedPackageDigest case final String expected
        when expected != sourceDigest) {
      throw FormatException(
        'Skill package digest mismatch: expected $expected, got $sourceDigest.',
      );
    }
    final Directory destination = Directory(plan.destinationPath);
    if (await destination.exists()) {
      final _ReceiptInspection inspection = await _inspectReceipt(
        destination,
        plan,
      );
      if (inspection.ownership == _DestinationOwnership.legacy) {
        await _recordObservation(
          plan,
          status: SkillDeploymentObservationStatus.legacyOwnershipRequired,
        );
        return _result(plan, SkillDeploymentOutcome.legacyOwnershipRequired);
      }
      if (inspection.ownership != _DestinationOwnership.owned) {
        await _recordObservation(
          plan,
          status: SkillDeploymentObservationStatus.ownershipConflict,
        );
        return _result(plan, SkillDeploymentOutcome.ownershipConflict);
      }
      final String installedDigest = await computeSkillPackageDigest(
        destination,
      );
      if (inspection.contentDigest != installedDigest) {
        await _recordObservation(
          plan,
          status: SkillDeploymentObservationStatus.ownershipConflict,
          contentDigest: installedDigest,
        );
        return _result(plan, SkillDeploymentOutcome.ownershipConflict);
      }
      if (inspection.contentDigest == sourceDigest &&
          installedDigest == sourceDigest) {
        final SkillDeploymentObservedState observed = await store
            .readObserved();
        final SkillDeploymentObservation? current =
            observed.deployments[plan.deploymentKey];
        if (!_isCurrentObservation(current, plan, sourceDigest)) {
          await _recordObservation(
            plan,
            status: SkillDeploymentObservationStatus.present,
            contentDigest: sourceDigest,
          );
        }
        return _result(plan, SkillDeploymentOutcome.unchanged);
      }
    }
    return _deploy(
      plan,
      source,
      sourceDigest,
      replacing: await destination.exists(),
    );
  }

  Future<SkillDeploymentResult> _deploy(
    SkillDeploymentPlan plan,
    Directory source,
    String sourceDigest, {
    required bool replacing,
  }) async {
    final Directory destination = Directory(plan.destinationPath);
    await destination.parent.create(recursive: true);
    final Directory staging = await destination.parent.createTemp(
      '.${path.basename(destination.path)}.dingdong-staging-',
    );
    final Directory? backup = replacing
        ? await _vacantSibling(destination, 'backup')
        : null;
    SkillDeploymentOperation operation = SkillDeploymentOperation(
      operationId: path.basename(staging.path),
      deploymentKey: plan.deploymentKey,
      destinationKey: plan.destinationKey,
      resourceId: plan.resourceId,
      agentId: plan.agentId,
      workspace: plan.workspace,
      destinationPath: plan.destinationPath,
      desiredState: plan.desiredState,
      phase: SkillDeploymentOperationPhase.staging,
      contentDigest: sourceDigest,
      stagingPath: staging.path,
      backupPath: backup?.path,
    );
    await store.writeOperation(operation);
    try {
      await _copyPackage(source, staging);
      final String stagingDigest = await computeSkillPackageDigest(staging);
      if (stagingDigest != sourceDigest) {
        throw const FileSystemException(
          'Staged Skill package failed digest verification.',
        );
      }
      await _writeReceipt(staging, plan, sourceDigest);
      operation = operation.copyWith(
        phase: SkillDeploymentOperationPhase.staged,
      );
      await store.writeOperation(operation);
      if (replacing) {
        await destination.rename(backup!.path);
        operation = operation.copyWith(
          phase: SkillDeploymentOperationPhase.destinationBackedUp,
        );
        await store.writeOperation(operation);
      }
      await staging.rename(destination.path);
      operation = operation.copyWith(
        phase: SkillDeploymentOperationPhase.destinationInstalled,
      );
      await store.writeOperation(operation);
      await _recordObservation(
        plan,
        status: SkillDeploymentObservationStatus.present,
        contentDigest: sourceDigest,
      );
      operation = operation.copyWith(
        phase: SkillDeploymentOperationPhase.observed,
      );
      await store.writeOperation(operation);
      if (backup != null && await backup.exists()) {
        await backup.delete(recursive: true);
      }
      await store.removeOperation(plan.deploymentKey);
      return _result(
        plan,
        replacing
            ? SkillDeploymentOutcome.updated
            : SkillDeploymentOutcome.installed,
      );
    } on Object {
      final bool destinationExists = await destination.exists();
      final bool backupExists = backup != null && await backup.exists();
      if (!destinationExists && backupExists) {
        await backup.rename(destination.path);
        if (await staging.exists()) {
          await staging.delete(recursive: true);
        }
        await store.removeOperation(plan.deploymentKey);
      } else if (await staging.exists() && (!replacing || destinationExists)) {
        await staging.delete(recursive: true);
        await store.removeOperation(plan.deploymentKey);
      }
      rethrow;
    }
  }

  Future<void> _recoverOperation(
    SkillDeploymentOperation operation,
    SkillDeploymentPlan plan,
  ) async {
    final Directory destination = Directory(plan.destinationPath);
    final Directory? staging = _recoveryArtifact(
      operation.stagingPath,
      destination,
      'staging',
    );
    final Directory? backup = _recoveryArtifact(
      operation.backupPath,
      destination,
      'backup',
    );
    final Directory? quarantine = _recoveryArtifact(
      operation.quarantinePath,
      destination,
      'quarantine',
    );
    switch (operation.phase) {
      case SkillDeploymentOperationPhase.staging:
      case SkillDeploymentOperationPhase.staged:
        if (operation.desiredState == SkillDeploymentDesiredState.present &&
            staging != null &&
            await staging.exists()) {
          await staging.delete(recursive: true);
        }
        await store.removeOperation(plan.deploymentKey);
        return;
      case SkillDeploymentOperationPhase.destinationBackedUp:
        if (!await destination.exists() &&
            backup != null &&
            await backup.exists()) {
          await _requireOwned(backup, plan);
          await backup.rename(destination.path);
          if (staging != null && await staging.exists()) {
            await staging.delete(recursive: true);
          }
          await store.removeOperation(plan.deploymentKey);
          return;
        }
        if (await destination.exists()) {
          final _ReceiptInspection installed = await _inspectReceipt(
            destination,
            plan,
          );
          if (installed.ownership == _DestinationOwnership.owned &&
              installed.contentDigest == operation.contentDigest &&
              await _matchesOperationDigest(destination, operation)) {
            await _recordObservation(
              plan,
              status: SkillDeploymentObservationStatus.present,
              contentDigest: operation.contentDigest,
            );
            await _deleteOwnedIfPresent(backup, plan);
            await store.removeOperation(plan.deploymentKey);
            return;
          }
        }
        throw StateError('Cannot safely recover a backed-up Skill deployment.');
      case SkillDeploymentOperationPhase.destinationInstalled:
        if (!await destination.exists()) {
          if (backup == null || !await backup.exists()) {
            throw StateError(
              'Cannot recover a missing installed Skill deployment.',
            );
          }
          await _requireOwned(backup, plan);
          await backup.rename(destination.path);
          await store.removeOperation(plan.deploymentKey);
          return;
        }
        final _ReceiptInspection installed = await _inspectReceipt(
          destination,
          plan,
        );
        if (installed.ownership != _DestinationOwnership.owned ||
            installed.contentDigest != operation.contentDigest ||
            !await _matchesOperationDigest(destination, operation)) {
          throw StateError(
            'Cannot safely recover the installed Skill deployment.',
          );
        }
        await _recordObservation(
          plan,
          status: SkillDeploymentObservationStatus.present,
          contentDigest: operation.contentDigest,
        );
        await _deleteOwnedIfPresent(backup, plan);
        await store.removeOperation(plan.deploymentKey);
        return;
      case SkillDeploymentOperationPhase.destinationQuarantined:
        if (quarantine != null && await quarantine.exists()) {
          await _requireOwned(quarantine, plan);
          await _requireOperationDigest(quarantine, operation);
          if (operation.desiredState == SkillDeploymentDesiredState.absent) {
            await _recordObservation(
              plan,
              status: SkillDeploymentObservationStatus.absent,
            );
            await quarantine.delete(recursive: true);
          } else if (!await destination.exists()) {
            await quarantine.rename(destination.path);
          } else {
            throw StateError(
              'Cannot restore a quarantined Skill over an existing destination.',
            );
          }
          await store.removeOperation(plan.deploymentKey);
          return;
        }
        if (operation.desiredState == SkillDeploymentDesiredState.absent &&
            !await destination.exists()) {
          await _recordObservation(
            plan,
            status: SkillDeploymentObservationStatus.absent,
          );
          await store.removeOperation(plan.deploymentKey);
          return;
        }
        throw StateError(
          'Cannot safely recover a quarantined Skill deployment.',
        );
      case SkillDeploymentOperationPhase.observed:
        if (operation.desiredState == SkillDeploymentDesiredState.present) {
          await _requireOwned(destination, plan);
          await _requireOperationDigest(destination, operation);
          await _deleteOwnedIfPresent(backup, plan);
        } else {
          if (quarantine != null && await quarantine.exists()) {
            await _requireOwned(quarantine, plan);
            await _requireOperationDigest(quarantine, operation);
            await quarantine.delete(recursive: true);
          }
        }
        if (staging != null && await staging.exists()) {
          await staging.delete(recursive: true);
        }
        await store.removeOperation(plan.deploymentKey);
        return;
    }
  }

  Future<bool> _matchesOperationDigest(
    Directory directory,
    SkillDeploymentOperation operation,
  ) async {
    final String? expected = operation.contentDigest;
    return expected != null &&
        await computeSkillPackageDigest(directory) == expected;
  }

  Future<void> _requireOperationDigest(
    Directory directory,
    SkillDeploymentOperation operation,
  ) async {
    if (!await _matchesOperationDigest(directory, operation)) {
      throw StateError(
        'Skill recovery artifact failed content digest validation.',
      );
    }
  }

  Future<SkillDeploymentResult> _remove(SkillDeploymentPlan plan) async {
    final Directory destination = Directory(plan.destinationPath);
    if (!await destination.exists()) {
      await _recordObservation(
        plan,
        status: SkillDeploymentObservationStatus.absent,
      );
      return _result(plan, SkillDeploymentOutcome.absent);
    }
    final _ReceiptInspection inspection = await _inspectReceipt(
      destination,
      plan,
    );
    if (inspection.ownership == _DestinationOwnership.legacy) {
      await _recordObservation(
        plan,
        status: SkillDeploymentObservationStatus.legacyOwnershipRequired,
      );
      return _result(plan, SkillDeploymentOutcome.legacyOwnershipRequired);
    }
    if (inspection.ownership != _DestinationOwnership.owned) {
      await _recordObservation(
        plan,
        status: SkillDeploymentObservationStatus.ownershipConflict,
      );
      return _result(plan, SkillDeploymentOutcome.ownershipConflict);
    }
    final String currentDigest = await computeSkillPackageDigest(destination);
    if (inspection.contentDigest != currentDigest) {
      await _recordObservation(
        plan,
        status: SkillDeploymentObservationStatus.ownershipConflict,
        contentDigest: currentDigest,
      );
      return _result(plan, SkillDeploymentOutcome.ownershipConflict);
    }
    final Directory quarantine = await _vacantSibling(
      destination,
      'quarantine',
    );
    SkillDeploymentOperation operation = SkillDeploymentOperation(
      operationId: path.basename(quarantine.path),
      deploymentKey: plan.deploymentKey,
      destinationKey: plan.destinationKey,
      resourceId: plan.resourceId,
      agentId: plan.agentId,
      workspace: plan.workspace,
      destinationPath: plan.destinationPath,
      desiredState: plan.desiredState,
      phase: SkillDeploymentOperationPhase.staging,
      contentDigest: inspection.contentDigest,
      quarantinePath: quarantine.path,
    );
    await store.writeOperation(operation);
    try {
      await destination.rename(quarantine.path);
      operation = operation.copyWith(
        phase: SkillDeploymentOperationPhase.destinationQuarantined,
      );
      await store.writeOperation(operation);
      await _recordObservation(
        plan,
        status: SkillDeploymentObservationStatus.absent,
      );
      operation = operation.copyWith(
        phase: SkillDeploymentOperationPhase.observed,
      );
      await store.writeOperation(operation);
      await quarantine.delete(recursive: true);
      await store.removeOperation(plan.deploymentKey);
      return _result(plan, SkillDeploymentOutcome.removed);
    } on Object {
      if (!await destination.exists() && await quarantine.exists()) {
        await quarantine.rename(destination.path);
        await store.removeOperation(plan.deploymentKey);
      }
      rethrow;
    }
  }

  Future<void> _recordObservation(
    SkillDeploymentPlan plan, {
    required SkillDeploymentObservationStatus status,
    String? contentDigest,
  }) async {
    final SkillDeploymentObservation? current =
        (await store.readObserved()).deployments[plan.deploymentKey];
    await store.upsertObservation(
      SkillDeploymentObservation(
        deploymentKey: plan.deploymentKey,
        destinationKey: plan.destinationKey,
        resourceId: plan.resourceId,
        agentId: plan.agentId,
        workspace: plan.workspace,
        destinationPath: plan.destinationPath,
        status: status,
        contentDigest: contentDigest,
        hookDesiredState: current?.hookDesiredState,
        hookDisposition: current?.hookDisposition,
        hookTrustState: current?.hookTrustState,
      ),
    );
  }
}

enum _DestinationOwnership { owned, legacy, unmanaged }

final class _ReceiptInspection {
  const _ReceiptInspection(this.ownership, {this.contentDigest});

  final _DestinationOwnership ownership;
  final String? contentDigest;
}

void _validateRecoveryIdentity(
  SkillDeploymentOperation operation,
  SkillDeploymentPlan plan,
) {
  if (operation.destinationKey != plan.destinationKey ||
      operation.resourceId != plan.resourceId ||
      operation.agentId != plan.agentId ||
      operation.workspace != plan.workspace ||
      path.normalize(path.absolute(operation.destinationPath)) !=
          plan.destinationPath) {
    throw const FormatException(
      'Skill deployment journal does not match the current desired plan.',
    );
  }
}

Directory? _recoveryArtifact(
  String? artifactPath,
  Directory destination,
  String purpose,
) {
  if (artifactPath == null) {
    return null;
  }
  final String normalized = path.normalize(path.absolute(artifactPath));
  final String expectedParent = path.normalize(
    destination.parent.absolute.path,
  );
  final String expectedPrefix =
      '.${path.basename(destination.path)}.dingdong-$purpose-';
  if (path.dirname(normalized) != expectedParent ||
      !path.basename(normalized).startsWith(expectedPrefix)) {
    throw const FormatException(
      'Skill deployment journal contains an unsafe recovery path.',
    );
  }
  return Directory(normalized);
}

Future<void> _requireOwned(
  Directory directory,
  SkillDeploymentPlan plan,
) async {
  if (!await directory.exists()) {
    throw FileSystemException(
      'Owned Skill recovery artifact does not exist.',
      directory.path,
    );
  }
  final _ReceiptInspection inspection = await _inspectReceipt(directory, plan);
  if (inspection.ownership != _DestinationOwnership.owned) {
    throw FileSystemException(
      'Skill recovery artifact failed ownership validation.',
      directory.path,
    );
  }
}

Future<void> _deleteOwnedIfPresent(
  Directory? directory,
  SkillDeploymentPlan plan,
) async {
  if (directory == null || !await directory.exists()) {
    return;
  }
  await _requireOwned(directory, plan);
  await directory.delete(recursive: true);
}

Future<_ReceiptInspection> _inspectReceipt(
  Directory destination,
  SkillDeploymentPlan plan,
) async {
  final File receipt = File(
    path.join(destination.path, skillDeploymentReceiptFileName),
  );
  if (!await receipt.exists()) {
    final bool hasLegacyMarker = await File(
      path.join(destination.path, legacySkillDeploymentMarkerFileName),
    ).exists();
    return _ReceiptInspection(
      hasLegacyMarker
          ? _DestinationOwnership.legacy
          : _DestinationOwnership.unmanaged,
    );
  }
  try {
    final Object? decoded = jsonDecode(await receipt.readAsString());
    if (decoded is! Map) {
      return const _ReceiptInspection(_DestinationOwnership.unmanaged);
    }
    final Map<String, Object?> value = Map<String, Object?>.from(decoded);
    final bool isOwned =
        value['schemaVersion'] == 1 &&
        value['managedBy'] == 'DingDong' &&
        value['resourceId'] == plan.resourceId &&
        value['agentId'] == plan.agentId &&
        value['workspace'] == plan.workspace &&
        value['deploymentKey'] == plan.deploymentKey &&
        value['destinationKey'] == plan.destinationKey &&
        value['contentDigest'] is String;
    return _ReceiptInspection(
      isOwned ? _DestinationOwnership.owned : _DestinationOwnership.unmanaged,
      contentDigest: isOwned ? value['contentDigest']! as String : null,
    );
  } on FormatException {
    return const _ReceiptInspection(_DestinationOwnership.unmanaged);
  } on FileSystemException {
    return const _ReceiptInspection(_DestinationOwnership.unmanaged);
  }
}

bool _isCurrentObservation(
  SkillDeploymentObservation? observation,
  SkillDeploymentPlan plan,
  String contentDigest,
) {
  return observation?.destinationKey == plan.destinationKey &&
      observation?.resourceId == plan.resourceId &&
      observation?.agentId == plan.agentId &&
      observation?.workspace == plan.workspace &&
      observation?.destinationPath == plan.destinationPath &&
      observation?.status == SkillDeploymentObservationStatus.present &&
      observation?.contentDigest == contentDigest;
}

SkillDeploymentResult _result(
  SkillDeploymentPlan plan,
  SkillDeploymentOutcome outcome,
) {
  return SkillDeploymentResult(
    outcome: outcome,
    deploymentKey: plan.deploymentKey,
    destinationKey: plan.destinationKey,
  );
}

Future<Directory> _vacantSibling(Directory destination, String purpose) async {
  final Directory placeholder = await destination.parent.createTemp(
    '.${path.basename(destination.path)}.dingdong-$purpose-',
  );
  await placeholder.delete();
  return placeholder;
}

Future<void> _copyPackage(Directory source, Directory destination) async {
  final List<FileSystemEntity> entities = await source
      .list(recursive: true, followLinks: false)
      .toList();
  entities.sort(
    (FileSystemEntity left, FileSystemEntity right) => path
        .relative(left.path, from: source.path)
        .compareTo(path.relative(right.path, from: source.path)),
  );
  for (final FileSystemEntity entity in entities) {
    final String relative = path.relative(entity.path, from: source.path);
    if (relative == skillDeploymentReceiptFileName) {
      throw const FormatException(
        'Skill package contains a reserved ownership receipt.',
      );
    }
    final String targetPath = path.join(destination.path, relative);
    final FileSystemEntityType type = await FileSystemEntity.type(
      entity.path,
      followLinks: false,
    );
    switch (type) {
      case FileSystemEntityType.directory:
        await Directory(targetPath).create(recursive: true);
      case FileSystemEntityType.file:
        await File(targetPath).parent.create(recursive: true);
        final File copied = await File(entity.path).copy(targetPath);
        await _preservePosixMode(File(entity.path), copied);
      case FileSystemEntityType.link:
        throw FileSystemException(
          'Symbolic links are not allowed in a Skill package.',
          entity.path,
        );
      case FileSystemEntityType.notFound:
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        throw FileSystemException(
          'Unsupported entry in Skill package.',
          entity.path,
        );
    }
  }
}

Future<void> _preservePosixMode(File source, File destination) async {
  if (Platform.isWindows) {
    return;
  }
  final int mode = (await source.stat()).mode & 0x1ff;
  final ProcessResult result = await Process.run('chmod', <String>[
    mode.toRadixString(8),
    destination.path,
  ]);
  if (result.exitCode != 0) {
    throw FileSystemException(
      'Could not preserve Skill package file mode.',
      destination.path,
    );
  }
}

Future<void> _writeReceipt(
  Directory destination,
  SkillDeploymentPlan plan,
  String contentDigest,
) async {
  final File receipt = File(
    path.join(destination.path, skillDeploymentReceiptFileName),
  );
  await receipt.writeAsString(
    '${jsonEncode(<String, Object?>{'schemaVersion': 1, 'managedBy': 'DingDong', 'resourceId': plan.resourceId, 'agentId': plan.agentId, 'workspace': plan.workspace, 'deploymentKey': plan.deploymentKey, 'destinationKey': plan.destinationKey, 'contentDigest': contentDigest})}\n',
    flush: true,
  );
}
