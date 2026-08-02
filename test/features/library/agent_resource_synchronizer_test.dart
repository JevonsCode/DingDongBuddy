import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_adapters/domain/agent_adapter.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/library/data/agent_resource_synchronizer.dart';
import 'package:dingdong/features/library/data/agent_skill_catalog.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resources.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test(
    'current user discovery includes native Codex and Claude prompts',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-prompt-discovery-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      Directory('${temp.path}/.codex').createSync();
      Directory('${temp.path}/.claude').createSync();
      final String resolvedHome = temp.resolveSymbolicLinksSync();

      final AgentResourceSynchronizer synchronizer =
          await AgentResourceSynchronizer.currentUser(
            Directory('${temp.path}/packages'),
            loadAdapters: () async => <AgentAdapter>[
              AgentAdapter.parse(_codexAdapter),
              AgentAdapter.parse(_claudeAdapter),
            ],
            homeDirectory: temp.path,
          );

      expect(
        synchronizer.promptTargets.map(
          (AgentPromptTarget target) => target.file.path,
        ),
        containsAll(<String>[
          path.join(resolvedHome, '.codex', 'AGENTS.md'),
          path.join(resolvedHome, '.claude', 'CLAUDE.md'),
        ]),
      );
      expect(
        synchronizer.promptTargets
            .singleWhere(
              (AgentPromptTarget target) =>
                  target.file.path ==
                  path.join(resolvedHome, '.codex', 'AGENTS.md'),
            )
            .includeBridgeRoutingInstructions,
        isTrue,
      );
      expect(
        synchronizer.promptTargets
            .singleWhere(
              (AgentPromptTarget target) =>
                  target.file.path ==
                  path.join(resolvedHome, '.claude', 'CLAUDE.md'),
            )
            .includeBridgeRoutingInstructions,
        isTrue,
      );
      expect(synchronizer.externalSkillCatalogs, hasLength(1));
    },
  );

  test('current user discovery includes Kiro native locations', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-kiro-discovery-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    Directory('${temp.path}/.kiro').createSync();
    final String resolvedHome = temp.resolveSymbolicLinksSync();

    final AgentResourceSynchronizer synchronizer =
        await AgentResourceSynchronizer.currentUser(
          Directory('${temp.path}/packages'),
          loadAdapters: () async => <AgentAdapter>[
            AgentAdapter.parse(_kiroAdapter),
          ],
          homeDirectory: temp.path,
        );

    expect(
      synchronizer.skillRoots.map((Directory root) => root.path),
      contains(path.join(resolvedHome, '.kiro', 'skills')),
    );
    expect(
      synchronizer.projectSkillRoots,
      contains(path.join('.kiro', 'skills')),
    );
    expect(
      synchronizer.mcpTargets.single.file.path,
      path.join(resolvedHome, '.kiro', 'settings', 'mcp.json'),
    );
    expect(synchronizer.mcpTargets.single.kind, AgentMcpConfigKind.kiroJson);
  });

  test(
    'invalid Adapter YAML does not prevent startup but still blocks sync',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-invalid-adapter-startup-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final AgentResourceSynchronizer synchronizer =
          await AgentResourceSynchronizer.currentUser(
            Directory('${temp.path}/packages'),
            loadAdapters: () async =>
                throw const FormatException('invalid user Adapter'),
            homeDirectory: temp.path,
          );

      expect(synchronizer.skillRoots, isEmpty);
      expect(
        synchronizer.inspect(const <Resource>[]),
        throwsA(isA<FormatException>()),
      );
      expect(
        synchronizer.sync(const <Resource>[]),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('conflicting shared Adapter targets block synchronization', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-conflicting-adapters-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    Directory('${temp.path}/.first').createSync();
    Directory('${temp.path}/.second').createSync();
    final List<AgentAdapter> adapters = <AgentAdapter>[
      AgentAdapter.parse('''
schemaVersion: 1
id: first
displayName: First
detect:
  directory: ~/.first
mcp:
  file: ~/.shared/mcp.json
  format: mcpServers-json
'''),
      AgentAdapter.parse('''
schemaVersion: 1
id: second
displayName: Second
detect:
  directory: ~/.second
mcp:
  file: ~/.shared/mcp.json
  format: codex-toml
'''),
    ];
    final AgentResourceSynchronizer synchronizer =
        await AgentResourceSynchronizer.currentUser(
          Directory('${temp.path}/packages'),
          loadAdapters: () async => adapters,
          homeDirectory: temp.path,
        );

    expect(
      synchronizer.inspect(const <Resource>[]),
      throwsA(
        isA<FormatException>().having(
          (FormatException error) => error.message,
          'message',
          contains('conflicting MCP formats'),
        ),
      ),
    );
  });

  test(
    'changing an Adapter migrates Prompt and MCP while cleaning legacy Skill mirrors',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-adapter-migration-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      Directory('${temp.path}/.new-agent').createSync();
      final Directory packageRoot = Directory('${temp.path}/packages');
      final File oldPrompt = File('${temp.path}/.new-agent/old/AGENTS.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('Keep the old user instruction.\n');
      final File oldMcp = File('${temp.path}/.new-agent/old/mcp.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '{"theme":"dark","mcpServers":{"personal":{"command":"mine"}}}',
        );
      final Directory oldSkillRoot = Directory(
        '${temp.path}/.new-agent/old/skills',
      );
      File(
        '${oldSkillRoot.path}/user-owned/README.md',
      ).createSync(recursive: true);
      File(
        '${oldSkillRoot.path}/migrated-skill/SKILL.md',
      ).createSync(recursive: true);
      File(
        '${oldSkillRoot.path}/migrated-skill/.dingdong-managed',
      ).writeAsStringSync('MIGRATED-SKILL');
      var adapters = <AgentAdapter>[AgentAdapter.parse(_movableAdapter('old'))];
      final List<Resource> resources = <Resource>[
        _resource(
          id: 'MIGRATED-PROMPT',
          type: ResourceType.prompt,
          content: 'Keep responses concise.',
          activation: ResourceActivation.always,
        ),
        _resource(
          id: 'MIGRATED-SKILL',
          type: ResourceType.skill,
          content:
              '---\nname: migrated-skill\ndescription: Migration test\n---\n',
        ),
        _resource(
          id: 'MIGRATED-MCP',
          type: ResourceType.mcp,
          content: '{"type":"stdio","command":"npx","args":["server"]}',
        ),
      ];
      AgentResourceSynchronizer synchronizer =
          await AgentResourceSynchronizer.currentUser(
            packageRoot,
            loadAdapters: () async => adapters,
            homeDirectory: temp.path,
          );

      await synchronizer.sync(resources);

      expect(
        File('${oldSkillRoot.path}/migrated-skill/SKILL.md').existsSync(),
        isFalse,
      );
      expect(oldPrompt.readAsStringSync(), contains('dingdong_bridge'));
      expect(
        oldPrompt.readAsStringSync(),
        isNot(contains('Keep responses concise.')),
      );
      expect(_onlyServerCount(oldMcp), 2);

      adapters = <AgentAdapter>[AgentAdapter.parse(_movableAdapter('new'))];
      synchronizer = await AgentResourceSynchronizer.currentUser(
        packageRoot,
        loadAdapters: () async => adapters,
        homeDirectory: temp.path,
      );

      await synchronizer.sync(resources);

      expect(
        Directory('${oldSkillRoot.path}/migrated-skill').existsSync(),
        isFalse,
      );
      expect(
        File('${oldSkillRoot.path}/user-owned/README.md').existsSync(),
        isTrue,
      );
      expect(oldPrompt.readAsStringSync(), 'Keep the old user instruction.\n');
      expect(_onlyServerCount(oldMcp), 1);
      expect(
        File(
          '${temp.path}/.new-agent/new/skills/migrated-skill/SKILL.md',
        ).existsSync(),
        isFalse,
      );
      expect(
        File('${temp.path}/.new-agent/new/AGENTS.md').readAsStringSync(),
        contains('dingdong_bridge'),
      );
      expect(
        File('${temp.path}/.new-agent/new/AGENTS.md').readAsStringSync(),
        isNot(contains('Keep responses concise.')),
      );
      expect(_onlyServerCount(File('${temp.path}/.new-agent/new/mcp.json')), 1);
    },
  );

  test('bundled Skill stays dynamic without creating a native mirror', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-sync-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final Directory target = Directory('${temp.path}/agent-skills');
    final Directory cached = Directory(
      '${temp.path}/packages/dingdong-configure',
    )..createSync(recursive: true);
    File('${cached.path}/SKILL.md').writeAsStringSync('stale instructions');
    final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
      packageRoot: Directory('${temp.path}/packages'),
      skillRoots: <Directory>[target],
      mcpTargets: const <AgentMcpTarget>[],
      managedStateFile: File('${temp.path}/state.json'),
      skillPackageInstaller: _OfflineInstaller(),
    );
    const String document =
        '---\nname: dingdong-configure\ndescription: Configure DingDong resources\n---\n\n# Configure';
    final Resource resource = builtInDingDongConfigureSkill(
      document,
      DateTime.utc(2026, 7, 19),
    );

    await synchronizer.sync(<Resource>[resource]);

    expect(
      File('${target.path}/dingdong-configure/SKILL.md').existsSync(),
      isFalse,
    );
    expect(
      File('${cached.path}/SKILL.md').readAsStringSync(),
      'stale instructions',
    );
  });

  test(
    'keeps enabled Skill packages in DingDong and removes legacy mirrors',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-sync-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final Directory package = Directory('${temp.path}/package')..createSync();
      File('${package.path}/SKILL.md').writeAsStringSync(
        '---\nname: reviewer\ndescription: Review code\n---\n',
      );
      Directory('${package.path}/references').createSync();
      File('${package.path}/references/policy.md').writeAsStringSync('policy');
      final Directory target = Directory('${temp.path}/agent-skills');
      final Directory legacy = Directory('${target.path}/reviewer')
        ..createSync(recursive: true);
      File(
        '${legacy.path}/.dingdong-managed',
      ).writeAsStringSync('RESOURCE-0000');
      File('${legacy.path}/SKILL.md').writeAsStringSync('legacy');
      final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
        packageRoot: Directory('${temp.path}/packages'),
        skillRoots: <Directory>[target],
        mcpTargets: const <AgentMcpTarget>[],
        managedStateFile: File('${temp.path}/state.json'),
      );
      final Resource resource = _resource(
        type: ResourceType.skill,
        content: File('${package.path}/SKILL.md').readAsStringSync(),
        packagePath: package.path,
      );

      await synchronizer.sync(<Resource>[resource]);
      expect(
        File('${target.path}/reviewer/references/policy.md').existsSync(),
        isFalse,
      );
      expect(File('${package.path}/references/policy.md').existsSync(), isTrue);

      await synchronizer.sync(<Resource>[resource.copyWith(enabled: false)]);
      expect(Directory('${target.path}/reviewer').existsSync(), isFalse);
    },
  );

  test('Skill edits remain dynamic and leave native roots clean', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-skill-rename-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final Directory codex = Directory('${temp.path}/.agents/skills');
    final Directory claude = Directory('${temp.path}/.claude/skills');
    final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
      packageRoot: Directory('${temp.path}/packages'),
      skillRoots: <Directory>[codex, claude],
      mcpTargets: const <AgentMcpTarget>[],
      managedStateFile: File('${temp.path}/state.json'),
    );
    final Resource original = _resource(
      id: 'RENAMED-SKILL',
      type: ResourceType.skill,
      content:
          '---\nname: old-reviewer\ndescription: Review old code\n---\n\n# Old',
    );
    for (final Directory root in <Directory>[codex, claude]) {
      final Directory legacy = Directory('${root.path}/old-reviewer')
        ..createSync(recursive: true);
      File('${legacy.path}/SKILL.md').writeAsStringSync('# Legacy');
      File(
        '${legacy.path}/.dingdong-managed',
      ).writeAsStringSync('RENAMED-SKILL');
    }

    await synchronizer.sync(<Resource>[original]);
    await synchronizer.sync(<Resource>[
      original.copyWith(
        title: 'new-reviewer',
        content:
            '---\nname: new-reviewer\ndescription: Review new code\n---\n\n# New',
      ),
    ]);

    for (final Directory root in <Directory>[codex, claude]) {
      expect(Directory('${root.path}/old-reviewer').existsSync(), isFalse);
      expect(File('${root.path}/new-reviewer/SKILL.md').existsSync(), isFalse);
    }
  });

  test(
    'enabled Claude plugin Skill duplicates are warnings and do not block sync',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-claude-plugin-skill-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final Directory claude = Directory('${temp.path}/.claude')..createSync();
      final Directory plugin = Directory('${temp.path}/superpowers')
        ..createSync();
      final Directory pluginSkill = Directory(
        '${plugin.path}/skills/verification-before-completion',
      )..createSync(recursive: true);
      File('${pluginSkill.path}/SKILL.md').writeAsStringSync(
        '---\nname: verification-before-completion\n'
        'description: Verify before completion\n---\n',
      );
      File('${claude.path}/settings.json').writeAsStringSync(
        jsonEncode(<String, Object?>{
          'enabledPlugins': <String, Object?>{
            'superpowers@official': true,
            'disabled@official': false,
          },
        }),
      );
      final Directory registry = Directory('${claude.path}/plugins')
        ..createSync();
      File('${registry.path}/installed_plugins.json').writeAsStringSync(
        jsonEncode(<String, Object?>{
          'version': 2,
          'plugins': <String, Object?>{
            'superpowers@official': <Object?>[
              <String, Object?>{'scope': 'user', 'installPath': plugin.path},
            ],
          },
        }),
      );
      final Directory target = Directory('${claude.path}/skills');
      final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
        packageRoot: Directory('${temp.path}/packages'),
        skillRoots: <Directory>[target],
        mcpTargets: const <AgentMcpTarget>[],
        externalSkillCatalogs: <AgentSkillCatalog>[
          ClaudeCodePluginSkillCatalog(
            settingsFile: File('${claude.path}/settings.json'),
            installedPluginsFile: File(
              '${registry.path}/installed_plugins.json',
            ),
          ),
        ],
        managedStateFile: File('${temp.path}/state.json'),
      );
      final Resource resource = _resource(
        id: 'VERIFY-SKILL',
        type: ResourceType.skill,
        content:
            '---\nname: verification-before-completion\n'
            'description: DingDong verification\n---\n\n# DingDong',
      );

      final List<AppIssue> inspected = await synchronizer.inspect(<Resource>[
        resource,
      ]);
      final List<AppIssue> synchronized = await synchronizer.sync(<Resource>[
        resource,
      ]);

      expect(inspected, hasLength(1));
      expect(inspected.single.kind, AppIssueKind.pluginSkillNameConflict);
      expect(inspected.single.severity, AppIssueSeverity.warning);
      expect(inspected.single.clientName, 'Claude Code · superpowers');
      expect(
        inspected.single.targetPath,
        path.normalize(path.join(pluginSkill.path, 'SKILL.md')),
      );
      expect(synchronized.single.id, inspected.single.id);
      expect(
        File(
          '${target.path}/verification-before-completion/SKILL.md',
        ).existsSync(),
        isFalse,
      );
    },
  );

  test('successful sync keeps plugin warnings in the issue center', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-sync-warning-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final InMemoryResourceStore base = InMemoryResourceStore();
    final IssueCenterController issueCenter = IssueCenterController();
    int changeCount = 0;
    final SynchronizedResourceStore store = SynchronizedResourceStore(
      base,
      AgentResourceSynchronizer(
        packageRoot: Directory('${temp.path}/packages'),
        skillRoots: <Directory>[Directory('${temp.path}/skills')],
        mcpTargets: const <AgentMcpTarget>[],
        externalSkillCatalogs: <AgentSkillCatalog>[
          _FakeSkillCatalog(const <ExternalAgentSkill>[
            ExternalAgentSkill(
              name: 'reviewer',
              clientName: 'Claude Code',
              providerName: 'test-plugin',
              targetPath: '/plugins/test-plugin/skills/reviewer/SKILL.md',
            ),
          ]),
        ],
        managedStateFile: File('${temp.path}/state.json'),
      ),
      issueCenter: issueCenter,
      onChanged: () => changeCount += 1,
    );
    final Resource resource = _resource(
      type: ResourceType.skill,
      content: '---\nname: reviewer\ndescription: Review code\n---\n',
    );

    await store.save(<Resource>[resource]);

    expect(await base.load(), hasLength(1));
    expect(issueCenter.issues, hasLength(1));
    expect(
      issueCenter.issues.single.kind,
      AppIssueKind.pluginSkillNameConflict,
    );
    expect(issueCenter.issues.single.severity, AppIssueSeverity.warning);
    expect(changeCount, 1);
  });

  test('warns about an independent native Skill without changing it', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-user-skill-conflict-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final Directory target = Directory('${temp.path}/.agents/skills');
    final Directory existing = Directory('${target.path}/reviewer')
      ..createSync(recursive: true);
    final File existingSkill = File('${existing.path}/SKILL.md')
      ..writeAsStringSync('user owned');
    final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
      packageRoot: Directory('${temp.path}/packages'),
      skillRoots: <Directory>[target],
      skillClientNames: <String, String>{path.normalize(target.path): 'Codex'},
      mcpTargets: const <AgentMcpTarget>[],
      managedStateFile: File('${temp.path}/state.json'),
    );
    final Resource resource = _resource(
      type: ResourceType.skill,
      content: '---\nname: reviewer\ndescription: Review code\n---\n',
    );

    final List<AppIssue> issues = await synchronizer.inspect(<Resource>[
      resource,
    ]);

    expect(issues, hasLength(1));
    expect(issues.single.kind, AppIssueKind.skillNameConflict);
    expect(issues.single.severity, AppIssueSeverity.warning);
    expect(issues.single.clientName, 'Codex');
    expect(issues.single.targetPath, path.normalize(existing.path));
    expect(await synchronizer.sync(<Resource>[resource]), hasLength(1));
    expect(existingSkill.readAsStringSync(), 'user owned');
    expect(File('${existing.path}/.dingdong-managed').existsSync(), isFalse);
  });

  test(
    'reports two DingDong Skills resolving to the same destination',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-managed-skill-conflict-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final Directory target = Directory('${temp.path}/skills');
      final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
        packageRoot: Directory('${temp.path}/packages'),
        skillRoots: <Directory>[target],
        mcpTargets: const <AgentMcpTarget>[],
        managedStateFile: File('${temp.path}/state.json'),
      );
      final Resource first = _resource(
        id: 'FIRST-SKILL',
        type: ResourceType.skill,
        content: '---\nname: reviewer\ndescription: First reviewer\n---\n',
      );
      final Resource second = _resource(
        id: 'SECOND-SKILL',
        type: ResourceType.skill,
        content: '---\nname: reviewer\ndescription: Second reviewer\n---\n',
      );

      final List<AppIssue> issues = await synchronizer.inspect(<Resource>[
        first,
        second,
      ]);

      expect(issues, hasLength(2));
      expect(
        issues.map((AppIssue issue) => issue.kind),
        everyElement(AppIssueKind.managedSkillNameConflict),
      );
      expect(Directory('${target.path}/reviewer').existsSync(), isFalse);
    },
  );

  test(
    'native Skill conflicts publish warnings without rolling back',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-sync-issue-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final Directory target = Directory('${temp.path}/skills');
      Directory('${target.path}/reviewer').createSync(recursive: true);
      final InMemoryResourceStore base = InMemoryResourceStore();
      final IssueCenterController issueCenter = IssueCenterController();
      int changeCount = 0;
      final SynchronizedResourceStore store = SynchronizedResourceStore(
        base,
        AgentResourceSynchronizer(
          packageRoot: Directory('${temp.path}/packages'),
          skillRoots: <Directory>[target],
          mcpTargets: const <AgentMcpTarget>[],
          managedStateFile: File('${temp.path}/state.json'),
        ),
        issueCenter: issueCenter,
        onChanged: () => changeCount += 1,
      );
      final Resource resource = _resource(
        type: ResourceType.skill,
        content: '---\nname: reviewer\ndescription: Review code\n---\n',
      );

      await store.save(<Resource>[resource]);

      expect(await base.load(), hasLength(1));
      expect(issueCenter.issues, hasLength(1));
      expect(issueCenter.issues.single.kind, AppIssueKind.skillNameConflict);
      expect(issueCenter.issues.single.severity, AppIssueSeverity.warning);
      expect(changeCount, 1);
    },
  );

  test(
    'project-scoped dynamic Skills clean global and project legacy copies',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-sync-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final Directory package = Directory('${temp.path}/package')..createSync();
      File('${package.path}/SKILL.md').writeAsStringSync(
        '---\nname: reviewer\ndescription: Review code\n---\n',
      );
      final Directory globalRoot = Directory('${temp.path}/global-skills');
      final Directory project = Directory('${temp.path}/checkout')
        ..createSync();
      for (final Directory legacy in <Directory>[
        Directory('${globalRoot.path}/reviewer'),
        Directory('${project.path}/.agents/skills/reviewer'),
      ]) {
        legacy.createSync(recursive: true);
        File('${legacy.path}/SKILL.md').writeAsStringSync('legacy');
        File(
          '${legacy.path}/.dingdong-managed',
        ).writeAsStringSync('RESOURCE-0000');
      }
      final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
        packageRoot: Directory('${temp.path}/packages'),
        skillRoots: <Directory>[globalRoot],
        projectSkillRoots: const <String>['.agents/skills'],
        mcpTargets: const <AgentMcpTarget>[],
        managedStateFile: File('${temp.path}/state.json'),
      );
      final Resource scoped = _resource(
        type: ResourceType.skill,
        content: File('${package.path}/SKILL.md').readAsStringSync(),
        packagePath: package.path,
        skillProjectPaths: <String>[project.path],
      );

      await synchronizer.sync(<Resource>[scoped]);

      expect(Directory('${globalRoot.path}/reviewer').existsSync(), isFalse);
      expect(
        File('${project.path}/.agents/skills/reviewer/SKILL.md').existsSync(),
        isFalse,
      );

      await synchronizer.sync(<Resource>[scoped.copyWith(enabled: false)]);

      expect(
        Directory('${project.path}/.agents/skills/reviewer').existsSync(),
        isFalse,
      );
    },
  );

  test('stale scope cleanup does not recreate a deleted project', () async {
    final Directory root = await Directory.systemTemp.createTemp(
      'dingdong-project-skill-deleted-',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });
    final Directory project = Directory('${root.path}/project')..createSync();
    final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
      packageRoot: Directory('${root.path}/packages'),
      skillRoots: <Directory>[Directory('${root.path}/global')],
      projectSkillRoots: const <String>['.agents/skills'],
      mcpTargets: const <AgentMcpTarget>[],
      managedStateFile: File('${root.path}/managed.json'),
      skillPackageInstaller: _OfflineInstaller(),
    );
    final Resource resource = _resource(
      id: 'reviewer',
      type: ResourceType.skill,
      content:
          '---\nname: reviewer\ndescription: Review changes\n---\n\n# Review',
      skillProjectPaths: <String>[project.path],
    );
    await synchronizer.sync(<Resource>[resource]);
    await project.delete(recursive: true);

    await synchronizer.sync(<Resource>[resource.copyWith(enabled: false)]);

    expect(await project.exists(), isFalse);
  });

  test(
    'keeps a bridge bootstrap without copying prompt bodies into AGENTS',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-sync-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final File agents = File('${temp.path}/AGENTS.md')
        ..writeAsStringSync('- Keep the existing user instruction.\n');
      final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
        packageRoot: Directory('${temp.path}/packages'),
        skillRoots: const <Directory>[],
        promptTargets: <AgentPromptTarget>[AgentPromptTarget(agents)],
        mcpTargets: const <AgentMcpTarget>[],
        managedStateFile: File('${temp.path}/state.json'),
      );
      final Resource global = _resource(
        type: ResourceType.prompt,
        content: 'Add one star to every complete response.',
        activation: ResourceActivation.always,
      );
      final Resource routed = _resource(
        id: 'ROUTED-0000',
        type: ResourceType.prompt,
        content: 'Only apply inside one project.',
        activation: ResourceActivation.always,
        triggerGroupIds: const <String>['project'],
      );
      final Resource manual = _resource(
        id: 'MANUAL-0000',
        type: ResourceType.prompt,
        content: 'Only load when explicitly requested.',
        activation: ResourceActivation.manual,
      );

      await synchronizer.sync(<Resource>[global, routed, manual]);

      String contents = agents.readAsStringSync();
      expect(contents, startsWith('- Keep the existing user instruction.'));
      expect(contents, contains('dingdong_bridge'));
      expect(contents, contains('every returned active Prompt'));
      expect(contents, contains('authoritative snapshot'));
      expect(contents, contains('replaces every Prompt set'));
      expect(contents, contains('authoritative Skill catalog'));
      expect(contents, contains('every valid, enabled, scope-matched Skill'));
      expect(contents, contains('dingdong_load_skill'));
      expect(contents, contains('dingdong_read_skill_file'));
      expect(contents, contains('Call configured MCP tools only when'));
      expect(
        contents,
        isNot(contains('Add one star to every complete response.')),
      );
      expect(contents, isNot(contains('Only apply inside one project.')));
      expect(contents, isNot(contains('Only load when explicitly requested.')));
      expect(
        RegExp('BEGIN DINGDONG MANAGED PROMPTS').allMatches(contents),
        hasLength(1),
      );

      await synchronizer.sync(<Resource>[
        global.copyWith(content: 'Use the updated global instruction.'),
        routed.copyWith(enabled: false),
        manual,
      ]);
      contents = agents.readAsStringSync();
      expect(contents, contains('dingdong_bridge'));
      expect(contents, isNot(contains('Use the updated global instruction.')));
      expect(contents, isNot(contains('Add one star')));

      await synchronizer.sync(<Resource>[
        global.copyWith(enabled: false),
        routed.copyWith(enabled: false),
        manual,
      ]);
      contents = agents.readAsStringSync();
      expect(contents, startsWith('- Keep the existing user instruction.'));
      expect(contents, contains('dingdong_bridge'));
      expect(
        RegExp('BEGIN DINGDONG MANAGED PROMPTS').allMatches(contents),
        hasLength(1),
      );
    },
  );

  test(
    'prompt targets without bridge routing remove legacy inline prompts',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-claude-prompt-sync-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final File claude = File('${temp.path}/CLAUDE.md')
        ..writeAsStringSync('- Keep the existing Claude instruction.\n');
      final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
        packageRoot: Directory('${temp.path}/packages'),
        skillRoots: const <Directory>[],
        promptTargets: <AgentPromptTarget>[
          AgentPromptTarget(claude, includeBridgeRoutingInstructions: false),
        ],
        mcpTargets: const <AgentMcpTarget>[],
        managedStateFile: File('${temp.path}/state.json'),
      );
      final Resource global = _resource(
        type: ResourceType.prompt,
        content: 'Add one star to every complete response.',
        activation: ResourceActivation.always,
      );
      final Resource routed = _resource(
        id: 'ROUTED-CLAUDE',
        type: ResourceType.prompt,
        content: 'Only apply inside one project.',
        activation: ResourceActivation.always,
        triggerGroupIds: const <String>['project'],
      );

      await synchronizer.sync(<Resource>[global, routed]);

      String contents = claude.readAsStringSync();
      expect(contents, '- Keep the existing Claude instruction.\n');
      expect(contents, isNot(contains('Only apply inside one project.')));
      expect(contents, isNot(contains('dingdong_bridge')));

      await synchronizer.sync(<Resource>[
        global.copyWith(enabled: false),
        routed,
      ]);

      contents = claude.readAsStringSync();
      expect(contents, '- Keep the existing Claude instruction.\n');
    },
  );

  test(
    'preserves unrelated JSON MCP config and removes managed entries',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-sync-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final File config = File('${temp.path}/mcp.json')
        ..writeAsStringSync(
          '{"theme":"dark","mcpServers":{"personal":{"command":"mine"}}}',
        );
      final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
        packageRoot: Directory('${temp.path}/packages'),
        skillRoots: const <Directory>[],
        mcpTargets: <AgentMcpTarget>[
          AgentMcpTarget(config, AgentMcpConfigKind.cursorJson),
        ],
        managedStateFile: File('${temp.path}/state.json'),
      );
      final Resource resource = _resource(
        type: ResourceType.mcp,
        content: '{"type":"stdio","command":"npx","args":["server"]}',
      );

      await synchronizer.sync(<Resource>[resource]);
      Map<String, Object?> json =
          jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
      expect(json['theme'], 'dark');
      expect(
        (json['mcpServers'] as Map<String, Object?>)['personal'],
        isNotNull,
      );
      expect((json['mcpServers'] as Map<String, Object?>).keys, hasLength(2));

      await synchronizer.sync(<Resource>[resource.copyWith(enabled: false)]);
      json = jsonDecode(config.readAsStringSync()) as Map<String, Object?>;
      expect((json['mcpServers'] as Map<String, Object?>).keys, <String>[
        'personal',
      ]);
    },
  );

  test('writes each Agent native HTTP MCP shape', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-sync-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final File codex = File('${temp.path}/codex.toml')
      ..writeAsStringSync('model = "gpt-5"\n');
    final File claude = File('${temp.path}/claude.json');
    final File cursor = File('${temp.path}/cursor.json');
    final File gemini = File('${temp.path}/gemini.json');
    final File kiro = File('${temp.path}/kiro.json');
    final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
      packageRoot: Directory('${temp.path}/packages'),
      skillRoots: const <Directory>[],
      mcpTargets: <AgentMcpTarget>[
        AgentMcpTarget(codex, AgentMcpConfigKind.codexToml),
        AgentMcpTarget(claude, AgentMcpConfigKind.claudeJson),
        AgentMcpTarget(cursor, AgentMcpConfigKind.cursorJson),
        AgentMcpTarget(gemini, AgentMcpConfigKind.geminiJson),
        AgentMcpTarget(kiro, AgentMcpConfigKind.kiroJson),
      ],
      managedStateFile: File('${temp.path}/state.json'),
    );
    final Resource resource = _resource(
      type: ResourceType.mcp,
      content:
          '{"type":"streamable-http","url":"https://example.com/mcp",'
          '"bearerTokenEnvVar":"EXAMPLE_TOKEN"}',
    );

    await synchronizer.sync(<Resource>[resource]);

    expect(
      codex.readAsStringSync(),
      contains('bearer_token_env_var = "EXAMPLE_TOKEN"'),
    );
    expect(codex.readAsStringSync(), contains('model = "gpt-5"'));
    final Map<String, Object?> claudeServer = _onlyServer(claude);
    expect(claudeServer['type'], 'http');
    expect(claudeServer['url'], 'https://example.com/mcp');
    expect(claudeServer['alwaysLoad'], isTrue);
    expect(
      (claudeServer['headers'] as Map<String, Object?>)['Authorization'],
      r'Bearer ${EXAMPLE_TOKEN}',
    );
    final Map<String, Object?> cursorServer = _onlyServer(cursor);
    expect(cursorServer['url'], 'https://example.com/mcp');
    expect(
      (cursorServer['headers'] as Map<String, Object?>)['Authorization'],
      r'Bearer ${env:EXAMPLE_TOKEN}',
    );
    final Map<String, Object?> geminiServer = _onlyServer(gemini);
    expect(geminiServer['httpUrl'], 'https://example.com/mcp');
    expect(geminiServer.containsKey('url'), isFalse);
    expect(
      (geminiServer['headers'] as Map<String, Object?>)['Authorization'],
      r'Bearer $EXAMPLE_TOKEN',
    );
    final Map<String, Object?> kiroServer = _onlyServer(kiro);
    expect(kiroServer['url'], 'https://example.com/mcp');
    expect(
      (kiroServer['headers'] as Map<String, Object?>)['Authorization'],
      r'Bearer ${EXAMPLE_TOKEN}',
    );
  });

  test('source-scoped MCPs sync only to matching Agent targets', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-source-mcp-sync-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final File codex = File('${temp.path}/codex.json');
    final File claude = File('${temp.path}/claude.json');
    final File cursor = File('${temp.path}/cursor.json');
    final DateTime timestamp = DateTime.utc(2026, 7, 17);
    final InMemoryTriggerGroupStore groups = InMemoryTriggerGroupStore([
      TriggerGroup(
        id: 'codex',
        name: 'Codex',
        rules: <TriggerRule>[
          TriggerRule(
            field: TriggerRuleField.source,
            operator: TriggerRuleOperator.equals,
            value: 'Codex',
          ),
        ],
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
      TriggerGroup(
        id: 'cursor',
        name: 'Cursor',
        rules: <TriggerRule>[
          TriggerRule(
            field: TriggerRuleField.source,
            operator: TriggerRuleOperator.equals,
            value: 'Cursor',
          ),
        ],
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    ]);
    final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
      packageRoot: Directory('${temp.path}/packages'),
      skillRoots: const <Directory>[],
      mcpTargets: <AgentMcpTarget>[
        AgentMcpTarget(
          codex,
          AgentMcpConfigKind.mcpServersJson,
          clientName: 'Codex',
        ),
        AgentMcpTarget(
          claude,
          AgentMcpConfigKind.mcpServersJson,
          clientName: 'Claude Code',
        ),
        AgentMcpTarget(
          cursor,
          AgentMcpConfigKind.mcpServersJson,
          clientName: 'Cursor',
        ),
      ],
      triggerGroupStore: groups,
      managedStateFile: File('${temp.path}/state.json'),
    );
    final String content =
        '{"type":"streamable-http","url":"https://example.com/mcp"}';

    await synchronizer.sync(<Resource>[
      _resource(
        id: 'codex-mcp',
        type: ResourceType.mcp,
        content: content,
        triggerGroupIds: const <String>['codex'],
      ),
      _resource(
        id: 'cursor-mcp',
        type: ResourceType.mcp,
        content: content,
        triggerGroupIds: const <String>['cursor'],
      ),
    ]);

    expect(_onlyServerCount(codex), 1);
    expect(claude.existsSync(), isFalse);
    expect(_onlyServerCount(cursor), 1);
  });

  test('trigger-group changes resynchronize source-scoped MCPs', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-source-mcp-group-sync-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final File codex = File('${temp.path}/codex.json');
    final DateTime timestamp = DateTime.utc(2026, 7, 17);
    final InMemoryTriggerGroupStore groups = InMemoryTriggerGroupStore();
    final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
      packageRoot: Directory('${temp.path}/packages'),
      skillRoots: const <Directory>[],
      mcpTargets: <AgentMcpTarget>[
        AgentMcpTarget(
          codex,
          AgentMcpConfigKind.mcpServersJson,
          clientName: 'Codex',
        ),
      ],
      triggerGroupStore: groups,
      managedStateFile: File('${temp.path}/state.json'),
    );
    final ResourceStore resources = InMemoryResourceStore(<Resource>[
      _resource(
        id: 'codex-mcp',
        type: ResourceType.mcp,
        content: '{"type":"streamable-http","url":"https://example.com/mcp"}',
        triggerGroupIds: const <String>['codex'],
      ),
    ]);
    final SynchronizedTriggerGroupStore synchronizedGroups =
        SynchronizedTriggerGroupStore(groups, resources, synchronizer);

    await synchronizedGroups.save(<TriggerGroup>[
      TriggerGroup(
        id: 'codex',
        name: 'Codex',
        rules: <TriggerRule>[
          TriggerRule(
            field: TriggerRuleField.source,
            operator: TriggerRuleOperator.equals,
            value: 'Codex',
          ),
        ],
        createdAt: timestamp,
        updatedAt: timestamp,
      ),
    ]);

    expect(_onlyServerCount(codex), 1);
  });
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
mcp:
  file: ~/.codex/config.toml
  format: codex-toml
prompt:
  file: ~/.codex/AGENTS.md
  includeBridgeRoutingInstructions: true
''';

const String _claudeAdapter = '''
schemaVersion: 1
id: claude-code
displayName: Claude Code
detect:
  directory: ~/.claude
skills:
  global: ~/.claude/skills
  project: .claude/skills
mcp:
  file: ~/.claude.json
  format: claude-json
prompt:
  file: ~/.claude/CLAUDE.md
  includeBridgeRoutingInstructions: true
''';

const String _kiroAdapter = '''
schemaVersion: 1
id: kiro
displayName: Kiro
detect:
  directory: ~/.kiro
skills:
  global: ~/.kiro/skills
  project: .kiro/skills
mcp:
  file: ~/.kiro/settings/mcp.json
  format: kiro-json
''';

final class _OfflineInstaller implements SkillPackageInstaller {
  @override
  Future<SkillPackageInstallResult> install(Uri source) {
    throw StateError('Network installer must not run for a bundled Skill.');
  }
}

final class _FakeSkillCatalog implements AgentSkillCatalog {
  const _FakeSkillCatalog(this.skills);

  final List<ExternalAgentSkill> skills;

  @override
  Future<List<ExternalAgentSkill>> load() async => skills;
}

Map<String, Object?> _onlyServer(File file) {
  final Map<String, Object?> root =
      jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final Map<String, Object?> servers =
      root['mcpServers'] as Map<String, Object?>;
  return servers.values.single as Map<String, Object?>;
}

int _onlyServerCount(File file) {
  final Map<String, Object?> root =
      jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  return (root['mcpServers'] as Map<String, Object?>).length;
}

String _movableAdapter(String target) =>
    '''
schemaVersion: 1
id: new-agent
displayName: New Agent
detect:
  directory: ~/.new-agent
skills:
  global: ~/.new-agent/$target/skills
  project: .new-agent/skills
mcp:
  file: ~/.new-agent/$target/mcp.json
  format: mcpServers-json
prompt:
  file: ~/.new-agent/$target/AGENTS.md
  includeBridgeRoutingInstructions: true
''';

Resource _resource({
  String id = 'ABCDEF12-0000',
  required ResourceType type,
  required String content,
  String? packagePath,
  bool enabled = true,
  ResourceActivation? activation,
  List<String> triggerGroupIds = const <String>[],
  List<String> skillProjectPaths = const <String>[],
}) {
  final DateTime now = DateTime.utc(2026, 7, 17);
  return Resource(
    id: id,
    type: type,
    title: 'reviewer',
    content: content,
    packagePath: packagePath,
    enabled: enabled,
    activation: activation,
    triggerGroupIds: triggerGroupIds,
    skillProjectPaths: skillProjectPaths,
    createdAt: now,
    updatedAt: now,
  );
}
