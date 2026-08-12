import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/utils/uuid.dart';
import 'package:dingdong/features/library/domain/project_hook_integration.dart';
import 'package:dingdong/features/library/domain/skill_deployment_plan.dart';
import 'package:path/path.dart' as path;

enum SkillDeploymentObservationStatus {
  present,
  absent,
  legacyOwnershipRequired,
  ownershipConflict,
}

enum SkillDeploymentOperationPhase {
  staging,
  staged,
  destinationBackedUp,
  destinationInstalled,
  destinationQuarantined,
  observed,
}

final class SkillDeploymentObservation {
  const SkillDeploymentObservation({
    required this.deploymentKey,
    required this.destinationKey,
    required this.resourceId,
    required this.agentId,
    required this.workspace,
    required this.destinationPath,
    required this.status,
    this.contentDigest,
    this.hookDesiredState,
    this.hookDisposition,
    this.hookTrustState,
  });

  factory SkillDeploymentObservation.fromJson(Map<String, Object?> json) {
    return SkillDeploymentObservation(
      deploymentKey: json['deploymentKey']! as String,
      destinationKey: json['destinationKey']! as String,
      resourceId: json['resourceId']! as String,
      agentId: json['agentId']! as String,
      workspace: json['workspace']! as String,
      destinationPath: json['destinationPath']! as String,
      status: SkillDeploymentObservationStatus.values.byName(
        json['status']! as String,
      ),
      contentDigest: json['contentDigest'] as String?,
      hookDesiredState: _hookDesiredState(json['hookDesiredState']),
      hookDisposition: _hookDisposition(json['hookDisposition']),
      hookTrustState: _hookTrustState(json['hookTrustState']),
    );
  }

  final String deploymentKey;
  final String destinationKey;
  final String resourceId;
  final String agentId;
  final String workspace;
  final String destinationPath;
  final SkillDeploymentObservationStatus status;
  final String? contentDigest;
  final HookDesiredState? hookDesiredState;
  final HookReconcileDisposition? hookDisposition;
  final HookTrustState? hookTrustState;

  SkillDeploymentObservation withHookReconcile({
    required HookDesiredState desiredState,
    required HookReconcileResult result,
  }) => SkillDeploymentObservation(
    deploymentKey: deploymentKey,
    destinationKey: destinationKey,
    resourceId: resourceId,
    agentId: agentId,
    workspace: workspace,
    destinationPath: destinationPath,
    status: status,
    contentDigest: contentDigest,
    hookDesiredState: desiredState,
    hookDisposition: result.disposition,
    hookTrustState: result.trustState,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'deploymentKey': deploymentKey,
    'destinationKey': destinationKey,
    'resourceId': resourceId,
    'agentId': agentId,
    'workspace': workspace,
    'destinationPath': destinationPath,
    'status': status.name,
    if (contentDigest != null) 'contentDigest': contentDigest,
    if (hookDesiredState != null) 'hookDesiredState': hookDesiredState!.name,
    if (hookDisposition != null) 'hookDisposition': hookDisposition!.name,
    if (hookTrustState != null) 'hookTrustState': hookTrustState!.name,
  };
}

HookDesiredState? _hookDesiredState(Object? value) =>
    _optionalEnum(value, HookDesiredState.values, 'Hook desired state');

HookReconcileDisposition? _hookDisposition(Object? value) => _optionalEnum(
  value,
  HookReconcileDisposition.values,
  'Hook reconcile disposition',
);

HookTrustState? _hookTrustState(Object? value) =>
    _optionalEnum(value, HookTrustState.values, 'Hook trust state');

T? _optionalEnum<T extends Enum>(Object? value, List<T> values, String label) {
  if (value == null) {
    return null;
  }
  if (value is! String) {
    throw FormatException('$label is invalid.');
  }
  for (final T candidate in values) {
    if (candidate.name == value) {
      return candidate;
    }
  }
  throw FormatException('$label is invalid.');
}

final class SkillDeploymentObservedState {
  SkillDeploymentObservedState(Iterable<SkillDeploymentObservation> values)
    : deployments = <String, SkillDeploymentObservation>{
        for (final SkillDeploymentObservation value in values)
          value.deploymentKey: value,
      };

  factory SkillDeploymentObservedState.empty() =>
      SkillDeploymentObservedState(<SkillDeploymentObservation>[]);

  final Map<String, SkillDeploymentObservation> deployments;
}

final class SkillDeploymentOperation {
  const SkillDeploymentOperation({
    required this.operationId,
    required this.deploymentKey,
    required this.destinationKey,
    required this.resourceId,
    required this.agentId,
    required this.workspace,
    required this.destinationPath,
    required this.desiredState,
    required this.phase,
    this.contentDigest,
    this.stagingPath,
    this.backupPath,
    this.quarantinePath,
  });

  factory SkillDeploymentOperation.fromJson(Map<String, Object?> json) {
    return SkillDeploymentOperation(
      operationId: json['operationId']! as String,
      deploymentKey: json['deploymentKey']! as String,
      destinationKey: json['destinationKey']! as String,
      resourceId: json['resourceId']! as String,
      agentId: json['agentId']! as String,
      workspace: json['workspace']! as String,
      destinationPath: json['destinationPath']! as String,
      desiredState: SkillDeploymentDesiredState.values.byName(
        json['desiredState']! as String,
      ),
      phase: SkillDeploymentOperationPhase.values.byName(
        json['phase']! as String,
      ),
      contentDigest: json['contentDigest'] as String?,
      stagingPath: json['stagingPath'] as String?,
      backupPath: json['backupPath'] as String?,
      quarantinePath: json['quarantinePath'] as String?,
    );
  }

  final String operationId;
  final String deploymentKey;
  final String destinationKey;
  final String resourceId;
  final String agentId;
  final String workspace;
  final String destinationPath;
  final SkillDeploymentDesiredState desiredState;
  final SkillDeploymentOperationPhase phase;
  final String? contentDigest;
  final String? stagingPath;
  final String? backupPath;
  final String? quarantinePath;

  SkillDeploymentOperation copyWith({
    SkillDeploymentOperationPhase? phase,
    String? stagingPath,
    String? backupPath,
    String? quarantinePath,
  }) {
    return SkillDeploymentOperation(
      operationId: operationId,
      deploymentKey: deploymentKey,
      destinationKey: destinationKey,
      resourceId: resourceId,
      agentId: agentId,
      workspace: workspace,
      destinationPath: destinationPath,
      desiredState: desiredState,
      phase: phase ?? this.phase,
      contentDigest: contentDigest,
      stagingPath: stagingPath ?? this.stagingPath,
      backupPath: backupPath ?? this.backupPath,
      quarantinePath: quarantinePath ?? this.quarantinePath,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'operationId': operationId,
    'deploymentKey': deploymentKey,
    'destinationKey': destinationKey,
    'resourceId': resourceId,
    'agentId': agentId,
    'workspace': workspace,
    'destinationPath': destinationPath,
    'desiredState': desiredState.name,
    'phase': phase.name,
    if (contentDigest != null) 'contentDigest': contentDigest,
    if (stagingPath != null) 'stagingPath': stagingPath,
    if (backupPath != null) 'backupPath': backupPath,
    if (quarantinePath != null) 'quarantinePath': quarantinePath,
  };
}

final class SkillDeploymentJournal {
  SkillDeploymentJournal(Iterable<SkillDeploymentOperation> values)
    : operations = <String, SkillDeploymentOperation>{
        for (final SkillDeploymentOperation value in values)
          value.deploymentKey: value,
      };

  factory SkillDeploymentJournal.empty() =>
      SkillDeploymentJournal(<SkillDeploymentOperation>[]);

  final Map<String, SkillDeploymentOperation> operations;
}

final class SkillDeploymentStore {
  SkillDeploymentStore(this.root)
    : observedFile = File(path.join(root.path, 'observed.json')),
      journalFile = File(path.join(root.path, 'operations.json')),
      metadataFile = File(path.join(root.path, 'state.json'));

  static const int schemaVersion = 1;
  static final Object _lockZoneKey = Object();
  static final Map<String, Future<void>> _mutationBarriers =
      <String, Future<void>>{};

  final Directory root;
  final File observedFile;
  final File journalFile;
  final File metadataFile;

  Future<T> exclusive<T>(Future<T> Function() action) async {
    final String key = path.normalize(root.absolute.path);
    final Set<String> held =
        Zone.current[_lockZoneKey] as Set<String>? ?? const <String>{};
    if (held.contains(key)) {
      return action();
    }
    final Future<void> previous =
        _mutationBarriers[key] ?? Future<void>.value();
    final Completer<void> gate = Completer<void>();
    _mutationBarriers[key] = gate.future;
    await previous;
    await root.create(recursive: true);
    final RandomAccessFile lock = await File(
      path.join(root.path, '.deployment.lock'),
    ).open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
      return await runZoned(
        action,
        zoneValues: <Object, Object>{
          _lockZoneKey: <String>{...held, key},
        },
      );
    } finally {
      try {
        await lock.unlock();
      } finally {
        await lock.close();
        gate.complete();
        if (identical(_mutationBarriers[key], gate.future)) {
          unawaited(_mutationBarriers.remove(key));
        }
      }
    }
  }

  Future<SkillDeploymentObservedState> readObserved() =>
      exclusive(_readObservedUnlocked);

  Future<SkillDeploymentObservedState> _readObservedUnlocked() async {
    await _restoreMissingStateFile(observedFile);
    if (!await observedFile.exists()) {
      return SkillDeploymentObservedState.empty();
    }
    final Map<String, Object?> document = await _readDocument(observedFile);
    final Object? values = document['deployments'];
    if (values is! List<Object?>) {
      throw const FormatException('Invalid Skill deployment observations.');
    }
    return SkillDeploymentObservedState(
      values.map((Object? value) {
        if (value is! Map) {
          throw const FormatException('Invalid Skill deployment observation.');
        }
        return SkillDeploymentObservation.fromJson(
          Map<String, Object?>.from(value),
        );
      }),
    );
  }

  Future<SkillDeploymentJournal> readJournal() =>
      exclusive(_readJournalUnlocked);

  Future<SkillDeploymentJournal> _readJournalUnlocked() async {
    await _restoreMissingStateFile(journalFile);
    if (!await journalFile.exists()) {
      return SkillDeploymentJournal.empty();
    }
    final Map<String, Object?> document = await _readDocument(journalFile);
    final Object? values = document['operations'];
    if (values is! List<Object?>) {
      throw const FormatException('Invalid Skill deployment journal.');
    }
    return SkillDeploymentJournal(
      values.map((Object? value) {
        if (value is! Map) {
          throw const FormatException('Invalid Skill deployment operation.');
        }
        return SkillDeploymentOperation.fromJson(
          Map<String, Object?>.from(value),
        );
      }),
    );
  }

  Future<void> upsertObservation(SkillDeploymentObservation observation) async {
    await exclusive(() async {
      final SkillDeploymentObservedState state = await _readObservedUnlocked();
      state.deployments[observation.deploymentKey] = observation;
      await _writeJson(observedFile, <String, Object?>{
        'schemaVersion': schemaVersion,
        'deployments': state.deployments.values
            .map((SkillDeploymentObservation value) => value.toJson())
            .toList(),
      });
    });
  }

  Future<void> writeOperation(SkillDeploymentOperation operation) async {
    await exclusive(() async {
      final SkillDeploymentJournal journal = await _readJournalUnlocked();
      journal.operations[operation.deploymentKey] = operation;
      await _writeJournal(journal);
    });
  }

  Future<void> removeOperation(String deploymentKey) async {
    await exclusive(() async {
      final SkillDeploymentJournal journal = await _readJournalUnlocked();
      journal.operations.remove(deploymentKey);
      await _writeJournal(journal);
    });
  }

  Future<SkillDeploymentPresence> queryPresence({
    required String resourceId,
    required String agentId,
    required String workspace,
  }) async {
    return exclusive(() async {
      try {
        final bool initialized = await metadataFile.exists();
        final bool observedStateAvailable =
            await observedFile.exists() ||
            await _hasRecoverableBackup(observedFile);
        final bool journalStateAvailable =
            await journalFile.exists() ||
            await _hasRecoverableBackup(journalFile);
        if (initialized &&
            (!observedStateAvailable || !journalStateAvailable)) {
          return SkillDeploymentPresence.possiblyPresent;
        }
        final SkillDeploymentJournal journal = await _readJournalUnlocked();
        if (journal.operations.values.any(
          (SkillDeploymentOperation value) =>
              value.resourceId == resourceId &&
              value.agentId == agentId &&
              value.workspace == workspace,
        )) {
          return SkillDeploymentPresence.possiblyPresent;
        }
        final SkillDeploymentObservedState state =
            await _readObservedUnlocked();
        final List<SkillDeploymentObservation> matching = state
            .deployments
            .values
            .where(
              (SkillDeploymentObservation value) =>
                  value.resourceId == resourceId &&
                  value.agentId == agentId &&
                  value.workspace == workspace,
            )
            .toList();
        if (matching.every(
          (SkillDeploymentObservation value) =>
              value.status == SkillDeploymentObservationStatus.absent,
        )) {
          return SkillDeploymentPresence.confirmedAbsent;
        }
      } on FileSystemException {
        return SkillDeploymentPresence.possiblyPresent;
      } on FormatException {
        return SkillDeploymentPresence.possiblyPresent;
      }
      return SkillDeploymentPresence.possiblyPresent;
    });
  }

  Future<Map<String, Object?>> _readDocument(File file) async {
    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw const FormatException('Invalid Skill deployment state.');
    }
    final Map<String, Object?> document = Map<String, Object?>.from(decoded);
    if (document['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported Skill deployment state schema.');
    }
    return document;
  }

  Future<void> _restoreMissingStateFile(File target) async {
    if (await target.exists() || !await target.parent.exists()) {
      return;
    }
    final String prefix = '${path.basename(target.path)}.';
    final List<File> backups = await target.parent
        .list(followLinks: false)
        .where(
          (FileSystemEntity entity) =>
              entity is File &&
              path.basename(entity.path).startsWith(prefix) &&
              entity.path.endsWith('.bak'),
        )
        .cast<File>()
        .toList();
    if (backups.isEmpty) {
      return;
    }
    backups.sort(
      (File left, File right) =>
          right.lastModifiedSync().compareTo(left.lastModifiedSync()),
    );
    await backups.first.rename(target.path);
  }

  Future<bool> _hasRecoverableBackup(File target) async {
    if (!await target.parent.exists()) {
      return false;
    }
    final String prefix = '${path.basename(target.path)}.';
    return target.parent
        .list(followLinks: false)
        .any(
          (FileSystemEntity entity) =>
              entity is File &&
              path.basename(entity.path).startsWith(prefix) &&
              entity.path.endsWith('.bak'),
        );
  }

  Future<void> _writeJournal(SkillDeploymentJournal journal) async {
    await _writeJson(journalFile, <String, Object?>{
      'schemaVersion': schemaVersion,
      'operations': journal.operations.values
          .map((SkillDeploymentOperation value) => value.toJson())
          .toList(),
    });
  }

  Future<void> _writeJson(File target, Map<String, Object?> value) async {
    await root.create(recursive: true);
    if (!await metadataFile.exists()) {
      await metadataFile.writeAsString(
        '${jsonEncode(<String, Object?>{'schemaVersion': schemaVersion, 'generation': generateUuid().toLowerCase()})}\n',
        flush: true,
      );
    }
    final String operationId = generateUuid().toLowerCase();
    final File staging = File('${target.path}.$operationId.tmp');
    final File backup = File('${target.path}.$operationId.bak');
    await staging.writeAsString('${jsonEncode(value)}\n', flush: true);
    if (await target.exists()) {
      await target.rename(backup.path);
    }
    try {
      await staging.rename(target.path);
      if (await backup.exists()) {
        await backup.delete();
      }
    } on Object {
      if (!await target.exists() && await backup.exists()) {
        await backup.rename(target.path);
      }
      if (await staging.exists()) {
        await staging.delete();
      }
      rethrow;
    }
  }
}
