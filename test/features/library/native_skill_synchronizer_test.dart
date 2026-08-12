import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_adapters/domain/agent_adapter.dart';
import 'package:dingdong/features/library/data/agent_resource_synchronizer.dart';
import 'package:dingdong/features/library/data/native_skill_delivery_coordinator.dart';
import 'package:dingdong/features/library/data/skill_deployment_store.dart';
import 'package:dingdong/features/library/domain/project_hook_integration.dart';
import 'package:dingdong/features/library/domain/skill_deployment_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory temp;
  late Directory packages;
  late Directory package;
  late Directory project;
  late Directory globalRoot;
  late SkillDeploymentStore deploymentStore;
  late AgentResourceSynchronizer synchronizer;
  late DateTime now;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('dingdong-native-sync-');
    packages = Directory(path.join(temp.path, 'packages'))..createSync();
    package = Directory(path.join(packages.path, 'resource-1', 'artifact'))
      ..createSync(recursive: true);
    File(path.join(package.path, 'SKILL.md')).writeAsStringSync(
      '---\nname: impeccable\ndescription: Improve frontend design\n---\n',
    );
    File(path.join(package.path, 'scripts', 'context.mjs'))
      ..createSync(recursive: true)
      ..writeAsStringSync('console.log(import.meta.url);');
    project = Directory(path.join(temp.path, 'project'))..createSync();
    globalRoot = Directory(path.join(temp.path, 'home', '.agents', 'skills'));
    deploymentStore = SkillDeploymentStore(
      Directory(path.join(temp.path, 'deployment-state')),
    );
    synchronizer = AgentResourceSynchronizer(
      packageRoot: packages,
      skillRoots: const <Directory>[],
      projectSkillRoots: const <String>[],
      mcpTargets: const <AgentMcpTarget>[],
      deploymentStore: deploymentStore,
      skillTargets: <AgentSkillTarget>[
        AgentSkillTarget(
          agentId: 'codex',
          clientName: 'Codex',
          globalRoot: globalRoot,
          projectRelativeRoot: path.join('.agents', 'skills'),
        ),
      ],
    );
    now = DateTime.utc(2026, 8, 12);
  });

  tearDown(() => temp.deleteSync(recursive: true));

  Resource skill({
    required SkillDeliveryMode mode,
    bool enabled = true,
    bool hooksEnabled = false,
  }) => Resource(
    id: 'resource-1',
    type: ResourceType.skill,
    title: 'Impeccable',
    content: File(path.join(package.path, 'SKILL.md')).readAsStringSync(),
    packagePath: package.path,
    enabled: enabled,
    strictProjectSkill: mode == SkillDeliveryMode.nativeProject,
    skillProjectPaths: mode == SkillDeliveryMode.nativeProject
        ? <String>[project.path]
        : const <String>[],
    skillDeliveryByAgent: <String, SkillDeliveryMode>{'codex': mode},
    skillHooksEnabledByAgent: <String, bool>{'codex': hooksEnabled},
    createdAt: now,
    updatedAt: now,
  );

  test(
    'nativeProject deploys the complete package and disable removes only it',
    () async {
      final Resource enabled = skill(mode: SkillDeliveryMode.nativeProject);

      await synchronizer.sync(<Resource>[enabled]);

      final Directory destination = Directory(
        path.join(project.path, '.agents', 'skills', 'impeccable'),
      );
      expect(
        File(path.join(destination.path, 'SKILL.md')).existsSync(),
        isTrue,
      );
      expect(
        File(
          path.join(destination.path, 'scripts', 'context.mjs'),
        ).existsSync(),
        isTrue,
      );
      expect(globalRoot.existsSync(), isFalse);

      await synchronizer.sync(<Resource>[enabled.copyWith(enabled: false)]);

      expect(destination.existsSync(), isFalse);
      expect(
        await deploymentStore.queryPresence(
          resourceId: enabled.id,
          agentId: 'codex',
          workspace: path.normalize(project.absolute.path),
        ),
        SkillDeploymentPresence.confirmedAbsent,
      );
    },
  );

  test('nativeUser deploys only to the selected Agent global root', () async {
    await synchronizer.sync(<Resource>[
      skill(mode: SkillDeliveryMode.nativeUser),
    ]);

    expect(
      File(path.join(globalRoot.path, 'impeccable', 'SKILL.md')).existsSync(),
      isTrue,
    );
    expect(
      Directory(
        path.join(project.path, '.agents', 'skills', 'impeccable'),
      ).existsSync(),
      isFalse,
    );
  });

  test(
    'switching nativeUser to nativeProject removes the old plane first',
    () async {
      await synchronizer.sync(<Resource>[
        skill(mode: SkillDeliveryMode.nativeUser),
      ]);

      await synchronizer.sync(<Resource>[
        skill(mode: SkillDeliveryMode.nativeProject),
      ]);

      expect(
        Directory(path.join(globalRoot.path, 'impeccable')).existsSync(),
        isFalse,
      );
      expect(
        File(
          path.join(
            project.path,
            '.agents',
            'skills',
            'impeccable',
            'SKILL.md',
          ),
        ).existsSync(),
        isTrue,
      );
    },
  );

  test('a replacement resource can take over after owned removal', () async {
    final Resource first = skill(mode: SkillDeliveryMode.nativeProject);
    await synchronizer.sync(<Resource>[first]);
    final Resource replacement = Resource(
      id: 'resource-2',
      type: ResourceType.skill,
      title: first.title,
      content: first.content,
      packagePath: first.packagePath,
      enabled: true,
      strictProjectSkill: true,
      skillProjectPaths: first.skillProjectPaths,
      skillDeliveryByAgent: first.skillDeliveryByAgent,
      createdAt: now,
      updatedAt: now,
    );

    await synchronizer.sync(<Resource>[replacement]);

    final SkillDeploymentObservedState observed = await deploymentStore
        .readObserved();
    expect(
      observed.deployments.values
          .where(
            (SkillDeploymentObservation value) =>
                value.status == SkillDeploymentObservationStatus.present,
          )
          .single
          .resourceId,
      'resource-2',
    );
  });

  test('dynamic delivery never writes a native copy', () async {
    await synchronizer.sync(<Resource>[skill(mode: SkillDeliveryMode.dynamic)]);

    expect(globalRoot.existsSync(), isFalse);
    expect(Directory(path.join(project.path, '.agents')).existsSync(), isFalse);
  });

  test('user-native delivery rejects retained project scope', () async {
    final Resource invalid = skill(
      mode: SkillDeliveryMode.nativeUser,
    ).copyWith(triggerGroupIds: const <String>['project']);

    await expectLater(
      synchronizer.sync(<Resource>[invalid]),
      throwsA(isA<StateError>()),
    );
    expect(globalRoot.existsSync(), isFalse);
  });

  test('nativeProject Hook switch is independent and off by default', () async {
    await synchronizer.sync(<Resource>[
      skill(mode: SkillDeliveryMode.nativeProject),
    ]);
    expect(
      File(path.join(project.path, '.codex', 'hooks.json')).existsSync(),
      isFalse,
    );
    SkillDeploymentObservation observation =
        (await deploymentStore.readObserved()).deployments.values.single;
    expect(observation.hookDesiredState, HookDesiredState.disabled);
    expect(observation.hookDisposition, HookReconcileDisposition.absent);
    expect(observation.hookTrustState, HookTrustState.unknown);

    await synchronizer.sync(<Resource>[
      skill(mode: SkillDeliveryMode.nativeProject, hooksEnabled: true),
    ]);
    expect(
      File(path.join(project.path, '.codex', 'hooks.json')).existsSync(),
      isTrue,
    );
    observation =
        (await deploymentStore.readObserved()).deployments.values.single;
    expect(observation.hookDesiredState, HookDesiredState.enabled);
    expect(observation.hookDisposition, HookReconcileDisposition.installed);
    expect(observation.hookTrustState, HookTrustState.pending);
    expect(observation.toJson(), containsPair('hookDesiredState', 'enabled'));
    expect(observation.toJson(), containsPair('hookDisposition', 'installed'));
    expect(observation.toJson(), containsPair('hookTrustState', 'pending'));
    expect(observation.toJson(), isNot(contains('codexHash')));
    expect(observation.toJson(), isNot(contains('trustedHash')));

    await synchronizer.sync(<Resource>[
      skill(mode: SkillDeliveryMode.nativeProject, hooksEnabled: false),
    ]);
    final File hooks = File(path.join(project.path, '.codex', 'hooks.json'));
    expect(
      hooks.existsSync() ? hooks.readAsStringSync() : '',
      isNot(contains('impeccable/scripts/hook.mjs')),
    );
    observation =
        (await deploymentStore.readObserved()).deployments.values.single;
    expect(observation.hookDesiredState, HookDesiredState.disabled);
    expect(observation.hookDisposition, HookReconcileDisposition.removed);
    expect(observation.hookTrustState, HookTrustState.pending);
  });

  test(
    'currentUser injects project Hook inventory into native delivery',
    () async {
      Directory(path.join(temp.path, '.codex')).createSync();
      final _RecordingInventory inventory = _RecordingInventory();
      final AgentResourceSynchronizer currentUser =
          await AgentResourceSynchronizer.currentUser(
            packages,
            loadAdapters: () async => <AgentAdapter>[
              AgentAdapter.parse(_codexAdapter),
            ],
            homeDirectory: temp.path,
            projectHookInventory: inventory,
          );

      await currentUser.sync(<Resource>[
        skill(mode: SkillDeliveryMode.nativeProject, hooksEnabled: true),
      ]);

      expect(inventory.projects, <String>[
        path.normalize(project.absolute.path),
      ]);
    },
  );

  test(
    'external exact Hooks are observed without claiming trust or ownership',
    () async {
      final _ExpectedImpeccableInventory inventory =
          _ExpectedImpeccableInventory(deploymentStore);
      final AgentResourceSynchronizer externalSynchronizer =
          AgentResourceSynchronizer(
            packageRoot: packages,
            skillRoots: const <Directory>[],
            projectSkillRoots: const <String>[],
            mcpTargets: const <AgentMcpTarget>[],
            deploymentStore: deploymentStore,
            projectHookInventory: inventory,
            skillTargets: <AgentSkillTarget>[
              AgentSkillTarget(
                agentId: 'codex',
                clientName: 'Codex',
                globalRoot: globalRoot,
                projectRelativeRoot: path.join('.agents', 'skills'),
              ),
            ],
          );

      await externalSynchronizer.sync(<Resource>[
        skill(mode: SkillDeliveryMode.nativeProject, hooksEnabled: true),
      ]);

      final SkillDeploymentObservation observation =
          (await deploymentStore.readObserved()).deployments.values.single;
      expect(observation.hookDesiredState, HookDesiredState.enabled);
      expect(
        observation.hookDisposition,
        HookReconcileDisposition.externalSatisfied,
      );
      expect(observation.hookTrustState, HookTrustState.unknown);
      expect(
        File(path.join(project.path, '.codex', 'hooks.json')).existsSync(),
        isFalse,
      );
      expect(
        File(
          path.join(project.path, '.codex', '.dingdong-hook-receipts.json'),
        ).existsSync(),
        isFalse,
      );

      await expectLater(
        externalSynchronizer.sync(<Resource>[
          skill(mode: SkillDeliveryMode.nativeProject, hooksEnabled: false),
        ]),
        throwsA(
          isA<StateError>().having(
            (StateError error) => error.message,
            'message',
            contains('/hooks'),
          ),
        ),
      );
      await expectLater(
        externalSynchronizer.sync(<Resource>[
          skill(
            mode: SkillDeliveryMode.nativeProject,
            hooksEnabled: true,
            enabled: false,
          ),
        ]),
        throwsA(isA<StateError>()),
      );
      expect(
        Directory(
          path.join(project.path, '.agents', 'skills', 'impeccable'),
        ).existsSync(),
        isTrue,
      );
      final SkillDeploymentObservation afterRejectedDisable =
          (await deploymentStore.readObserved()).deployments.values.single;
      expect(afterRejectedDisable.hookDesiredState, HookDesiredState.enabled);
      expect(
        afterRejectedDisable.hookDisposition,
        HookReconcileDisposition.externalSatisfied,
      );
    },
  );

  test(
    'Impeccable Hook follows a customized Codex project Skill root',
    () async {
      final AgentResourceSynchronizer customSynchronizer =
          AgentResourceSynchronizer(
            packageRoot: packages,
            skillRoots: const <Directory>[],
            projectSkillRoots: const <String>[],
            mcpTargets: const <AgentMcpTarget>[],
            deploymentStore: deploymentStore,
            skillTargets: <AgentSkillTarget>[
              AgentSkillTarget(
                agentId: 'codex',
                clientName: 'Codex',
                globalRoot: globalRoot,
                projectRelativeRoot: path.join('.codex', 'skills'),
              ),
            ],
          );

      await customSynchronizer.sync(<Resource>[
        skill(mode: SkillDeliveryMode.nativeProject, hooksEnabled: true),
      ]);

      final String hooks = File(
        path.join(project.path, '.codex', 'hooks.json'),
      ).readAsStringSync();
      expect(
        hooks,
        contains('node \\".codex/skills/impeccable/scripts/hook.mjs\\"'),
      );
      expect(hooks, isNot(contains('.agents/skills/impeccable')));
    },
  );

  test(
    'an unmanaged native name collision fails without overwriting it',
    () async {
      final Directory destination = Directory(
        path.join(project.path, '.agents', 'skills', 'impeccable'),
      )..createSync(recursive: true);
      final File external = File(path.join(destination.path, 'SKILL.md'))
        ..writeAsStringSync('external');

      await expectLater(
        synchronizer.sync(<Resource>[
          skill(mode: SkillDeliveryMode.nativeProject),
        ]),
        throwsA(isA<StateError>()),
      );

      expect(external.readAsStringSync(), 'external');
    },
  );

  test(
    'nativeProject rejects a Skill root symlink outside the project',
    () async {
      if (Platform.isWindows) {
        return;
      }
      final Directory externalRoot = Directory(
        path.join(temp.path, 'external-skills'),
      )..createSync();
      final Directory projectAgentRoot = Directory(
        path.join(project.path, '.agents'),
      )..createSync();
      Link(
        path.join(projectAgentRoot.path, 'skills'),
      ).createSync(externalRoot.path);

      await expectLater(
        synchronizer.sync(<Resource>[
          skill(mode: SkillDeliveryMode.nativeProject),
        ]),
        throwsA(isA<StateError>()),
      );

      expect(externalRoot.listSync(), isEmpty);
    },
  );

  test('two resources cannot target the same native destination', () async {
    final Resource first = skill(mode: SkillDeliveryMode.nativeProject);
    final Resource second = Resource(
      id: 'resource-2',
      type: ResourceType.skill,
      title: 'Impeccable fork',
      content: first.content,
      packagePath: first.packagePath,
      enabled: true,
      strictProjectSkill: true,
      skillProjectPaths: first.skillProjectPaths,
      skillDeliveryByAgent: first.skillDeliveryByAgent,
      createdAt: now,
      updatedAt: now,
    );

    await expectLater(
      synchronizer.sync(<Resource>[first, second]),
      throwsA(isA<StateError>()),
    );
    expect(Directory(path.join(project.path, '.agents')).existsSync(), isFalse);
  });

  test(
    'two aliased Agent roots cannot target the same native destination',
    () async {
      if (Platform.isWindows) {
        return;
      }
      final Directory actualRoot = Directory(
        path.join(temp.path, 'aliased-home', 'skills'),
      )..createSync(recursive: true);
      final Link aliasRoot = Link(path.join(temp.path, 'skills-alias'))
        ..createSync(actualRoot.path);
      final AgentResourceSynchronizer aliasedSynchronizer =
          AgentResourceSynchronizer(
            packageRoot: packages,
            skillRoots: const <Directory>[],
            projectSkillRoots: const <String>[],
            mcpTargets: const <AgentMcpTarget>[],
            deploymentStore: deploymentStore,
            skillTargets: <AgentSkillTarget>[
              AgentSkillTarget(
                agentId: 'codex',
                clientName: 'Codex',
                globalRoot: actualRoot,
                projectRelativeRoot: path.join('.agents', 'skills'),
              ),
              AgentSkillTarget(
                agentId: 'claude-code',
                clientName: 'Claude Code',
                globalRoot: Directory(aliasRoot.path),
                projectRelativeRoot: path.join('.claude', 'skills'),
              ),
            ],
          );
      final Resource first = skill(mode: SkillDeliveryMode.nativeUser).copyWith(
        skillDeliveryByAgent: const <String, SkillDeliveryMode>{
          'codex': SkillDeliveryMode.nativeUser,
        },
      );
      final Resource second = Resource(
        id: 'resource-2',
        type: ResourceType.skill,
        title: first.title,
        content: first.content,
        packagePath: first.packagePath,
        enabled: true,
        skillDeliveryByAgent: const <String, SkillDeliveryMode>{
          'claude-code': SkillDeliveryMode.nativeUser,
        },
        createdAt: now,
        updatedAt: now,
      );

      await expectLater(
        aliasedSynchronizer.sync(<Resource>[first, second]),
        throwsA(isA<StateError>()),
      );

      expect(
        Directory(path.join(actualRoot.path, 'impeccable')).existsSync(),
        isFalse,
      );
    },
  );
}

const String _codexAdapter = '''
schemaVersion: 1
id: codex
displayName: Codex
detect:
  directory: ~/.codex
skills:
  global: ~/.codex/skills
  project: .agents/skills
''';

final class _RecordingInventory implements CodexProjectHookInventory {
  final List<String> projects = <String>[];

  @override
  Future<List<CodexEffectiveHook>> list(Directory projectRoot) async {
    projects.add(path.normalize(projectRoot.absolute.path));
    return const <CodexEffectiveHook>[];
  }
}

final class _ExpectedImpeccableInventory implements CodexProjectHookInventory {
  const _ExpectedImpeccableInventory(this.store);

  final SkillDeploymentStore store;

  @override
  Future<List<CodexEffectiveHook>> list(Directory projectRoot) async {
    final SkillDeploymentObservation deployment =
        (await store.readObserved()).deployments.values.single;
    final List<CodexHookDefinition> expected =
        const ImpeccableCodexHookAdapter().definitionsFor(
          HookDeployment(
            deploymentId: deployment.deploymentKey,
            artifactDigest: deployment.contentDigest!,
          ),
        );
    return <CodexEffectiveHook>[
      for (final CodexHookDefinition definition in expected)
        CodexEffectiveHook(
          eventName: definition.event.jsonKey,
          command: _hookCommand(definition.entry),
          sourcePath: path.join(projectRoot.parent.path, 'external-hooks.json'),
        ),
    ];
  }
}

String _hookCommand(Object? value) {
  if (value is Map) {
    if (value['command'] case final String command) {
      return command;
    }
    for (final Object? nested in value.values) {
      final String command = _hookCommand(nested);
      if (command.isNotEmpty) {
        return command;
      }
    }
  }
  if (value is List) {
    for (final Object? nested in value) {
      final String command = _hookCommand(nested);
      if (command.isNotEmpty) {
        return command;
      }
    }
  }
  return '';
}
