import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/library/data/skill_deployment_reconciler.dart';
import 'package:dingdong/features/library/data/skill_deployment_store.dart';
import 'package:dingdong/features/library/domain/skill_deployment_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory workspace;
  late Directory source;
  late Directory destination;
  late SkillDeploymentStore store;
  late SkillDeploymentReconciler reconciler;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync(
      'dingdong-skill-deployment-',
    );
    source = Directory(path.join(workspace.path, 'source'))..createSync();
    destination = Directory(
      path.join(workspace.path, 'codex', 'skills', 'reviewer'),
    );
    store = SkillDeploymentStore(Directory(path.join(workspace.path, 'state')));
    reconciler = SkillDeploymentReconciler(store: store);
  });

  tearDown(() {
    if (workspace.existsSync()) {
      workspace.deleteSync(recursive: true);
    }
  });

  test(
    'an install plan materializes and records the observed deployment',
    () async {
      File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Reviewer');
      final SkillDeploymentPlan plan = SkillDeploymentPlan.install(
        resourceId: 'resource-1',
        agentId: 'codex',
        workspace: 'user',
        sourceDirectory: source,
        destinationDirectory: destination,
      );

      final SkillDeploymentResult result = await reconciler.reconcile(plan);

      expect(result.outcome, SkillDeploymentOutcome.installed);
      expect(
        File(path.join(destination.path, 'SKILL.md')).readAsStringSync(),
        '# Reviewer',
      );
      final SkillDeploymentObservedState observed = await store.readObserved();
      final SkillDeploymentObservation? observation =
          observed.deployments[plan.deploymentKey];
      expect(observation, isNotNull);
      expect(observation?.destinationKey, plan.destinationKey);
      expect(
        observation?.destinationPath,
        path.normalize(destination.absolute.path),
      );
      expect(observation?.resourceId, 'resource-1');
      expect(observation?.agentId, 'codex');
      expect(observation?.workspace, 'user');
      expect(observation?.contentDigest, startsWith('sha256:'));

      final Map<String, Object?> document =
          jsonDecode(store.observedFile.readAsStringSync())
              as Map<String, Object?>;
      expect(document['schemaVersion'], 1);
      expect(document['deployments'], isA<List<Object?>>());
      final Map<String, Object?> journal =
          jsonDecode(store.journalFile.readAsStringSync())
              as Map<String, Object?>;
      expect(journal['schemaVersion'], 1);
      expect(journal['operations'], isEmpty);

      final Map<String, Object?> receipt =
          jsonDecode(
                File(
                  path.join(destination.path, skillDeploymentReceiptFileName),
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(receipt['managedBy'], 'DingDong');
      expect(receipt['resourceId'], 'resource-1');
      expect(receipt['deploymentKey'], plan.deploymentKey);
    },
  );

  test('copies the complete package and preserves executable files', () async {
    File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Reviewer');
    File(path.join(source.path, 'references', 'rules.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync('Keep this reference');
    final File script = File(path.join(source.path, 'scripts', 'check.sh'))
      ..createSync(recursive: true)
      ..writeAsStringSync('#!/bin/sh\nexit 0\n');
    if (!Platform.isWindows) {
      final ProcessResult chmod = await Process.run('chmod', <String>[
        '755',
        script.path,
      ]);
      expect(chmod.exitCode, 0);
    }
    final SkillDeploymentPlan plan = SkillDeploymentPlan.install(
      resourceId: 'resource-1',
      agentId: 'codex',
      workspace: 'user',
      sourceDirectory: source,
      destinationDirectory: destination,
    );

    await reconciler.reconcile(plan);

    expect(
      File(
        path.join(destination.path, 'references', 'rules.md'),
      ).readAsStringSync(),
      'Keep this reference',
    );
    final File installedScript = File(
      path.join(destination.path, 'scripts', 'check.sh'),
    );
    expect(installedScript.readAsStringSync(), '#!/bin/sh\nexit 0\n');
    if (!Platform.isWindows) {
      expect(installedScript.statSync().mode & 0x49, isNonZero);
    }
  });

  test(
    'a healthy store with no matching deployment confirms absence',
    () async {
      expect(
        await store.queryPresence(
          resourceId: 'resource-1',
          agentId: 'codex',
          workspace: 'user',
        ),
        SkillDeploymentPresence.confirmedAbsent,
      );
    },
  );

  test('reconciling the same owned package is a file-system no-op', () async {
    final File sourceSkill = File(path.join(source.path, 'SKILL.md'))
      ..writeAsStringSync('# Reviewer');
    final SkillDeploymentPlan plan = SkillDeploymentPlan.install(
      resourceId: 'resource-1',
      agentId: 'codex',
      workspace: 'user',
      sourceDirectory: source,
      destinationDirectory: destination,
    );
    await reconciler.reconcile(plan);
    final File installed = File(path.join(destination.path, 'SKILL.md'));
    final File receipt = File(
      path.join(destination.path, skillDeploymentReceiptFileName),
    );
    final DateTime sentinel = DateTime.fromMillisecondsSinceEpoch(1000000000);
    for (final File file in <File>[
      installed,
      receipt,
      store.observedFile,
      store.journalFile,
    ]) {
      file.setLastModifiedSync(sentinel);
    }
    sourceSkill.setLastModifiedSync(sentinel);

    final SkillDeploymentResult result = await reconciler.reconcile(plan);

    expect(result.outcome, SkillDeploymentOutcome.unchanged);
    for (final File file in <File>[
      installed,
      receipt,
      store.observedFile,
      store.journalFile,
    ]) {
      expect(file.lastModifiedSync(), sentinel);
    }
  });

  test(
    'owned destination drift fails closed without replacing files',
    () async {
      File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Version 1');
      File(path.join(source.path, 'assets', 'current.txt'))
        ..createSync(recursive: true)
        ..writeAsStringSync('current');
      final SkillDeploymentPlan plan = SkillDeploymentPlan.install(
        resourceId: 'resource-1',
        agentId: 'codex',
        workspace: 'user',
        sourceDirectory: source,
        destinationDirectory: destination,
      );
      await reconciler.reconcile(plan);
      File(
        path.join(destination.path, 'SKILL.md'),
      ).writeAsStringSync('tampered');
      File(path.join(destination.path, 'stale.txt')).writeAsStringSync('stale');

      final SkillDeploymentResult result = await reconciler.reconcile(plan);

      expect(result.outcome, SkillDeploymentOutcome.ownershipConflict);
      expect(
        File(path.join(destination.path, 'SKILL.md')).readAsStringSync(),
        'tampered',
      );
      expect(
        File(path.join(destination.path, 'stale.txt')).existsSync(),
        isTrue,
      );
      expect(
        (await store.readObserved()).deployments[plan.deploymentKey]?.status,
        SkillDeploymentObservationStatus.ownershipConflict,
      );
      expect(
        destination.parent.listSync().map(
          (FileSystemEntity entity) => path.basename(entity.path),
        ),
        isNot(
          contains(matches(RegExp(r'dingdong-(staging|backup|quarantine)-'))),
        ),
      );
    },
  );

  test(
    'recognizes a legacy marker without automatically taking ownership',
    () async {
      File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# New');
      destination.createSync(recursive: true);
      File(
        path.join(destination.path, 'SKILL.md'),
      ).writeAsStringSync('# Legacy');
      File(
        path.join(destination.path, legacySkillDeploymentMarkerFileName),
      ).writeAsStringSync('resource-1');
      final SkillDeploymentPlan plan = SkillDeploymentPlan.install(
        resourceId: 'resource-1',
        agentId: 'codex',
        workspace: 'user',
        sourceDirectory: source,
        destinationDirectory: destination,
      );

      final SkillDeploymentResult result = await reconciler.reconcile(plan);

      expect(result.outcome, SkillDeploymentOutcome.legacyOwnershipRequired);
      expect(
        File(path.join(destination.path, 'SKILL.md')).readAsStringSync(),
        '# Legacy',
      );
      expect(
        File(
          path.join(destination.path, skillDeploymentReceiptFileName),
        ).existsSync(),
        isFalse,
      );
      expect(
        await store.queryPresence(
          resourceId: 'resource-1',
          agentId: 'codex',
          workspace: 'user',
        ),
        SkillDeploymentPresence.possiblyPresent,
      );
    },
  );

  test('removes only a receipt-owned deployment through quarantine', () async {
    File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Reviewer');
    final SkillDeploymentPlan install = SkillDeploymentPlan.install(
      resourceId: 'resource-1',
      agentId: 'codex',
      workspace: 'user',
      sourceDirectory: source,
      destinationDirectory: destination,
    );
    await reconciler.reconcile(install);
    final SkillDeploymentPlan remove = SkillDeploymentPlan.remove(
      resourceId: 'resource-1',
      agentId: 'codex',
      workspace: 'user',
      destinationDirectory: destination,
    );

    final SkillDeploymentResult result = await reconciler.reconcile(remove);

    expect(result.outcome, SkillDeploymentOutcome.removed);
    expect(destination.existsSync(), isFalse);
    expect(
      await store.queryPresence(
        resourceId: 'resource-1',
        agentId: 'codex',
        workspace: 'user',
      ),
      SkillDeploymentPresence.confirmedAbsent,
    );
    expect((await store.readJournal()).operations, isEmpty);
    expect(
      destination.parent.listSync().map(
        (FileSystemEntity entity) => path.basename(entity.path),
      ),
      isNot(contains(matches(RegExp(r'dingdong-quarantine-')))),
    );
  });

  test(
    'refuses to remove an owned package after local content drift',
    () async {
      File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Reviewer');
      File(path.join(source.path, 'scripts', 'run.sh'))
        ..createSync(recursive: true)
        ..writeAsStringSync('original\n');
      final SkillDeploymentPlan install = SkillDeploymentPlan.install(
        resourceId: 'skill-1',
        agentId: 'codex',
        workspace: 'user',
        sourceDirectory: source,
        destinationDirectory: destination,
      );
      await reconciler.reconcile(install);
      final File drifted = File(
        path.join(destination.path, 'scripts', 'run.sh'),
      );
      drifted.writeAsStringSync('user change\n');

      final SkillDeploymentResult result = await reconciler.reconcile(
        SkillDeploymentPlan.remove(
          resourceId: 'skill-1',
          agentId: 'codex',
          workspace: 'user',
          destinationDirectory: destination,
        ),
      );

      expect(result.outcome, SkillDeploymentOutcome.ownershipConflict);
      expect(drifted.readAsStringSync(), 'user change\n');
    },
  );

  test('recovers an owned backup left by an interrupted replacement', () async {
    File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Reviewer');
    final SkillDeploymentPlan plan = SkillDeploymentPlan.install(
      resourceId: 'resource-1',
      agentId: 'codex',
      workspace: 'user',
      sourceDirectory: source,
      destinationDirectory: destination,
    );
    await reconciler.reconcile(plan);
    final SkillDeploymentObservation before =
        (await store.readObserved()).deployments[plan.deploymentKey]!;
    final Directory backup = Directory(
      path.join(destination.parent.path, '.reviewer.dingdong-backup-recovery'),
    );
    final Directory staging = Directory(
      path.join(destination.parent.path, '.reviewer.dingdong-staging-recovery'),
    )..createSync();
    File(path.join(staging.path, 'partial')).writeAsStringSync('partial');
    destination.renameSync(backup.path);
    await store.writeOperation(
      SkillDeploymentOperation(
        operationId: 'recovery',
        deploymentKey: plan.deploymentKey,
        destinationKey: plan.destinationKey,
        resourceId: plan.resourceId,
        agentId: plan.agentId,
        workspace: plan.workspace,
        destinationPath: plan.destinationPath,
        desiredState: SkillDeploymentDesiredState.present,
        phase: SkillDeploymentOperationPhase.destinationBackedUp,
        contentDigest: before.contentDigest,
        stagingPath: staging.path,
        backupPath: backup.path,
      ),
    );

    final SkillDeploymentResult result = await reconciler.reconcile(plan);

    expect(result.outcome, SkillDeploymentOutcome.recovered);
    expect(
      File(path.join(destination.path, 'SKILL.md')).readAsStringSync(),
      '# Reviewer',
    );
    expect(backup.existsSync(), isFalse);
    expect(staging.existsSync(), isFalse);
    expect((await store.readJournal()).operations, isEmpty);
  });

  test(
    'recovery refuses a tampered installed destination before deleting its backup',
    () async {
      File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Version 1');
      final SkillDeploymentPlan plan = SkillDeploymentPlan.install(
        resourceId: 'resource-1',
        agentId: 'codex',
        workspace: 'user',
        sourceDirectory: source,
        destinationDirectory: destination,
      );
      await reconciler.reconcile(plan);
      final SkillDeploymentObservation before =
          (await store.readObserved()).deployments[plan.deploymentKey]!;
      final Directory backup = Directory(
        path.join(destination.parent.path, '.reviewer.dingdong-backup-tamper'),
      );
      _copyDirectory(destination, backup);
      File(
        path.join(destination.path, 'SKILL.md'),
      ).writeAsStringSync('# Tampered after crash');
      await store.writeOperation(
        SkillDeploymentOperation(
          operationId: 'tamper',
          deploymentKey: plan.deploymentKey,
          destinationKey: plan.destinationKey,
          resourceId: plan.resourceId,
          agentId: plan.agentId,
          workspace: plan.workspace,
          destinationPath: plan.destinationPath,
          desiredState: SkillDeploymentDesiredState.present,
          phase: SkillDeploymentOperationPhase.destinationInstalled,
          contentDigest: before.contentDigest,
          backupPath: backup.path,
        ),
      );

      await expectLater(
        reconciler.recoverOperations(<SkillDeploymentPlan>[plan]),
        throwsA(isA<StateError>()),
      );

      expect(backup.existsSync(), isTrue);
      expect(
        File(path.join(backup.path, 'SKILL.md')).readAsStringSync(),
        '# Version 1',
      );
      expect((await store.readJournal()).operations, isNotEmpty);
    },
  );

  test(
    'backed-up recovery refuses a tampered installed destination before deleting its backup',
    () async {
      File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Version 1');
      final SkillDeploymentPlan plan = SkillDeploymentPlan.install(
        resourceId: 'resource-1',
        agentId: 'codex',
        workspace: 'user',
        sourceDirectory: source,
        destinationDirectory: destination,
      );
      await reconciler.reconcile(plan);
      final SkillDeploymentObservation before =
          (await store.readObserved()).deployments[plan.deploymentKey]!;
      final Directory backup = Directory(
        path.join(
          destination.parent.path,
          '.reviewer.dingdong-backup-backed-up-tamper',
        ),
      );
      _copyDirectory(destination, backup);
      File(
        path.join(destination.path, 'SKILL.md'),
      ).writeAsStringSync('# Tampered before phase journal advanced');
      await store.writeOperation(
        SkillDeploymentOperation(
          operationId: 'backed-up-tamper',
          deploymentKey: plan.deploymentKey,
          destinationKey: plan.destinationKey,
          resourceId: plan.resourceId,
          agentId: plan.agentId,
          workspace: plan.workspace,
          destinationPath: plan.destinationPath,
          desiredState: SkillDeploymentDesiredState.present,
          phase: SkillDeploymentOperationPhase.destinationBackedUp,
          contentDigest: before.contentDigest,
          backupPath: backup.path,
        ),
      );

      await expectLater(
        reconciler.recoverOperations(<SkillDeploymentPlan>[plan]),
        throwsA(isA<StateError>()),
      );

      expect(backup.existsSync(), isTrue);
      expect((await store.readJournal()).operations, isNotEmpty);
    },
  );

  test(
    'recovery refuses a tampered quarantined deployment before recording absence',
    () async {
      File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Reviewer');
      final SkillDeploymentPlan install = SkillDeploymentPlan.install(
        resourceId: 'resource-1',
        agentId: 'codex',
        workspace: 'user',
        sourceDirectory: source,
        destinationDirectory: destination,
      );
      await reconciler.reconcile(install);
      final SkillDeploymentObservation before =
          (await store.readObserved()).deployments[install.deploymentKey]!;
      final Directory quarantine = Directory(
        path.join(
          destination.parent.path,
          '.reviewer.dingdong-quarantine-tamper',
        ),
      );
      destination.renameSync(quarantine.path);
      File(
        path.join(quarantine.path, 'SKILL.md'),
      ).writeAsStringSync('# Tampered in quarantine');
      await store.writeOperation(
        SkillDeploymentOperation(
          operationId: 'quarantine-tamper',
          deploymentKey: install.deploymentKey,
          destinationKey: install.destinationKey,
          resourceId: install.resourceId,
          agentId: install.agentId,
          workspace: install.workspace,
          destinationPath: install.destinationPath,
          desiredState: SkillDeploymentDesiredState.absent,
          phase: SkillDeploymentOperationPhase.destinationQuarantined,
          contentDigest: before.contentDigest,
          quarantinePath: quarantine.path,
        ),
      );
      final SkillDeploymentPlan remove = SkillDeploymentPlan.remove(
        resourceId: install.resourceId,
        agentId: install.agentId,
        workspace: install.workspace,
        destinationDirectory: destination,
      );

      await expectLater(
        reconciler.recoverOperations(<SkillDeploymentPlan>[remove]),
        throwsA(isA<StateError>()),
      );

      expect(quarantine.existsSync(), isTrue);
      expect(
        (await store.readObserved()).deployments[install.deploymentKey]?.status,
        SkillDeploymentObservationStatus.present,
      );
      expect((await store.readJournal()).operations, isNotEmpty);
    },
  );

  test(
    'observed removal recovery refuses a tampered quarantine before deleting it',
    () async {
      File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Reviewer');
      final SkillDeploymentPlan install = SkillDeploymentPlan.install(
        resourceId: 'resource-1',
        agentId: 'codex',
        workspace: 'user',
        sourceDirectory: source,
        destinationDirectory: destination,
      );
      await reconciler.reconcile(install);
      final SkillDeploymentObservation before =
          (await store.readObserved()).deployments[install.deploymentKey]!;
      final Directory quarantine = Directory(
        path.join(
          destination.parent.path,
          '.reviewer.dingdong-quarantine-observed-tamper',
        ),
      );
      destination.renameSync(quarantine.path);
      File(
        path.join(quarantine.path, 'SKILL.md'),
      ).writeAsStringSync('# Tampered after absence was observed');
      await store.writeOperation(
        SkillDeploymentOperation(
          operationId: 'observed-tamper',
          deploymentKey: install.deploymentKey,
          destinationKey: install.destinationKey,
          resourceId: install.resourceId,
          agentId: install.agentId,
          workspace: install.workspace,
          destinationPath: install.destinationPath,
          desiredState: SkillDeploymentDesiredState.absent,
          phase: SkillDeploymentOperationPhase.observed,
          contentDigest: before.contentDigest,
          quarantinePath: quarantine.path,
        ),
      );
      final SkillDeploymentPlan remove = SkillDeploymentPlan.remove(
        resourceId: install.resourceId,
        agentId: install.agentId,
        workspace: install.workspace,
        destinationDirectory: destination,
      );

      await expectLater(
        reconciler.recoverOperations(<SkillDeploymentPlan>[remove]),
        throwsA(isA<StateError>()),
      );

      expect(quarantine.existsSync(), isTrue);
      expect((await store.readJournal()).operations, isNotEmpty);
    },
  );

  test(
    'observed removal recovery finishes the journal before a new install',
    () async {
      File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Reviewer');
      final SkillDeploymentPlan install = SkillDeploymentPlan.install(
        resourceId: 'resource-1',
        agentId: 'codex',
        workspace: 'user',
        sourceDirectory: source,
        destinationDirectory: destination,
      );
      await reconciler.reconcile(install);
      final SkillDeploymentObservation before =
          (await store.readObserved()).deployments[install.deploymentKey]!;
      final Directory quarantine = Directory(
        path.join(
          destination.parent.path,
          '.reviewer.dingdong-quarantine-observed-reinstall',
        ),
      );
      destination.renameSync(quarantine.path);
      await store.upsertObservation(
        SkillDeploymentObservation(
          deploymentKey: before.deploymentKey,
          destinationKey: before.destinationKey,
          resourceId: before.resourceId,
          agentId: before.agentId,
          workspace: before.workspace,
          destinationPath: before.destinationPath,
          status: SkillDeploymentObservationStatus.absent,
        ),
      );
      await store.writeOperation(
        SkillDeploymentOperation(
          operationId: 'observed-reinstall',
          deploymentKey: install.deploymentKey,
          destinationKey: install.destinationKey,
          resourceId: install.resourceId,
          agentId: install.agentId,
          workspace: install.workspace,
          destinationPath: install.destinationPath,
          desiredState: SkillDeploymentDesiredState.absent,
          phase: SkillDeploymentOperationPhase.observed,
          contentDigest: before.contentDigest,
          quarantinePath: quarantine.path,
        ),
      );

      await reconciler.recoverOperations(<SkillDeploymentPlan>[install]);

      expect(destination.existsSync(), isFalse);
      expect(quarantine.existsSync(), isFalse);
      expect((await store.readJournal()).operations, isEmpty);
      expect(
        (await store.readObserved()).deployments[install.deploymentKey]?.status,
        SkillDeploymentObservationStatus.absent,
      );

      final SkillDeploymentResult installed = await reconciler.reconcile(
        install,
      );

      expect(installed.outcome, SkillDeploymentOutcome.installed);
      expect(destination.existsSync(), isTrue);
      expect(
        (await store.readObserved()).deployments[install.deploymentKey]?.status,
        SkillDeploymentObservationStatus.present,
      );
    },
  );

  test(
    'recovery tolerates desired state changing from present to absent',
    () async {
      File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Reviewer');
      final SkillDeploymentPlan install = SkillDeploymentPlan.install(
        resourceId: 'resource-1',
        agentId: 'codex',
        workspace: 'user',
        sourceDirectory: source,
        destinationDirectory: destination,
      );
      await reconciler.reconcile(install);
      final SkillDeploymentObservation before =
          (await store.readObserved()).deployments[install.deploymentKey]!;
      final Directory backup = Directory(
        path.join(destination.parent.path, '.reviewer.dingdong-backup-switch'),
      );
      final Directory staging = Directory(
        path.join(destination.parent.path, '.reviewer.dingdong-staging-switch'),
      )..createSync();
      destination.renameSync(backup.path);
      await store.writeOperation(
        SkillDeploymentOperation(
          operationId: 'switch',
          deploymentKey: install.deploymentKey,
          destinationKey: install.destinationKey,
          resourceId: install.resourceId,
          agentId: install.agentId,
          workspace: install.workspace,
          destinationPath: install.destinationPath,
          desiredState: SkillDeploymentDesiredState.present,
          phase: SkillDeploymentOperationPhase.destinationBackedUp,
          contentDigest: before.contentDigest,
          stagingPath: staging.path,
          backupPath: backup.path,
        ),
      );
      final SkillDeploymentPlan remove = SkillDeploymentPlan.remove(
        resourceId: install.resourceId,
        agentId: install.agentId,
        workspace: install.workspace,
        destinationDirectory: destination,
      );

      await reconciler.recoverOperations(<SkillDeploymentPlan>[remove]);
      final SkillDeploymentResult removed = await reconciler.reconcile(remove);

      expect(removed.outcome, SkillDeploymentOutcome.removed);
      expect(destination.existsSync(), isFalse);
      expect(backup.existsSync(), isFalse);
      expect((await store.readJournal()).operations, isEmpty);
    },
  );

  test(
    'state reads restore the last backup after an interrupted atomic write',
    () async {
      File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Reviewer');
      final SkillDeploymentPlan plan = SkillDeploymentPlan.install(
        resourceId: 'resource-1',
        agentId: 'codex',
        workspace: 'user',
        sourceDirectory: source,
        destinationDirectory: destination,
      );
      await reconciler.reconcile(plan);
      final File backup = File('${store.observedFile.path}.crash.bak');
      store.observedFile.renameSync(backup.path);

      final SkillDeploymentPresence presence = await store.queryPresence(
        resourceId: 'resource-1',
        agentId: 'codex',
        workspace: 'user',
      );

      expect(presence, SkillDeploymentPresence.possiblyPresent);
      expect(store.observedFile.existsSync(), isTrue);
    },
  );

  test(
    'an initialized store with missing state files cannot confirm absence',
    () async {
      File(path.join(source.path, 'SKILL.md')).writeAsStringSync('# Reviewer');
      final SkillDeploymentPlan plan = SkillDeploymentPlan.install(
        resourceId: 'resource-1',
        agentId: 'codex',
        workspace: 'user',
        sourceDirectory: source,
        destinationDirectory: destination,
      );
      await reconciler.reconcile(plan);
      final Map<String, Object?> metadata =
          jsonDecode(store.metadataFile.readAsStringSync())
              as Map<String, Object?>;
      expect(metadata['schemaVersion'], SkillDeploymentStore.schemaVersion);
      expect(metadata['generation'], isA<String>());
      store.observedFile.deleteSync();
      store.journalFile.deleteSync();

      expect(
        await store.queryPresence(
          resourceId: plan.resourceId,
          agentId: plan.agentId,
          workspace: plan.workspace,
        ),
        SkillDeploymentPresence.possiblyPresent,
      );
    },
  );

  test('two store instances preserve concurrent journal updates', () async {
    final SkillDeploymentStore second = SkillDeploymentStore(store.root);
    SkillDeploymentOperation operation(String id) => SkillDeploymentOperation(
      operationId: id,
      deploymentKey: 'deployment-$id',
      destinationKey: 'destination-$id',
      resourceId: 'resource-$id',
      agentId: 'codex',
      workspace: 'user',
      destinationPath: path.join(workspace.path, id),
      desiredState: SkillDeploymentDesiredState.present,
      phase: SkillDeploymentOperationPhase.staging,
    );

    await Future.wait(<Future<void>>[
      store.writeOperation(operation('one')),
      second.writeOperation(operation('two')),
    ]);

    expect((await store.readJournal()).operations.keys.toSet(), <String>{
      'deployment-one',
      'deployment-two',
    });
  });

  test('destination identity resolves an existing symlinked ancestor', () {
    if (Platform.isWindows) {
      return;
    }
    final Directory actualRoot = Directory(
      path.join(workspace.path, 'actual', 'skills'),
    )..createSync(recursive: true);
    final Link aliasRoot = Link(path.join(workspace.path, 'alias-skills'))
      ..createSync(actualRoot.path);
    final SkillDeploymentPlan direct = SkillDeploymentPlan.install(
      resourceId: 'resource-1',
      agentId: 'codex',
      workspace: 'user',
      sourceDirectory: source,
      destinationDirectory: Directory(path.join(actualRoot.path, 'reviewer')),
    );
    final SkillDeploymentPlan alias = SkillDeploymentPlan.install(
      resourceId: 'resource-2',
      agentId: 'codex',
      workspace: 'user',
      sourceDirectory: source,
      destinationDirectory: Directory(path.join(aliasRoot.path, 'reviewer')),
    );

    expect(alias.destinationKey, direct.destinationKey);
  });
}

void _copyDirectory(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final FileSystemEntity entity in source.listSync(recursive: true)) {
    final String relative = path.relative(entity.path, from: source.path);
    final String target = path.join(destination.path, relative);
    if (entity is Directory) {
      Directory(target).createSync(recursive: true);
    } else if (entity is File) {
      File(target).parent.createSync(recursive: true);
      entity.copySync(target);
    }
  }
}
