import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/library/data/agent_resource_synchronizer.dart';
import 'package:dingdong/features/library/data/agent_skill_catalog.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resources.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('current user discovery includes native Codex and Claude prompts', () {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-prompt-discovery-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    Directory('${temp.path}/.codex').createSync();
    Directory('${temp.path}/.claude').createSync();

    final AgentResourceSynchronizer synchronizer =
        AgentResourceSynchronizer.currentUser(
          Directory('${temp.path}/packages'),
          homeDirectory: temp.path,
        );

    expect(
      synchronizer.promptTargets.map(
        (AgentPromptTarget target) => target.file.path,
      ),
      containsAll(<String>[
        path.join(temp.path, '.codex', 'AGENTS.md'),
        path.join(temp.path, '.claude', 'CLAUDE.md'),
      ]),
    );
    expect(
      synchronizer.promptTargets
          .singleWhere(
            (AgentPromptTarget target) =>
                target.file.path == path.join(temp.path, '.codex', 'AGENTS.md'),
          )
          .includeBridgeRoutingInstructions,
      isTrue,
    );
    expect(
      synchronizer.promptTargets
          .singleWhere(
            (AgentPromptTarget target) =>
                target.file.path ==
                path.join(temp.path, '.claude', 'CLAUDE.md'),
          )
          .includeBridgeRoutingInstructions,
      isFalse,
    );
    expect(synchronizer.externalSkillCatalogs, hasLength(1));
  });

  test('current user discovery includes Kiro native locations', () {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-kiro-discovery-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    Directory('${temp.path}/.kiro').createSync();

    final AgentResourceSynchronizer synchronizer =
        AgentResourceSynchronizer.currentUser(
          Directory('${temp.path}/packages'),
          homeDirectory: temp.path,
        );

    expect(
      synchronizer.skillRoots.map((Directory root) => root.path),
      contains(path.join(temp.path, '.kiro', 'skills')),
    );
    expect(
      synchronizer.projectSkillRoots,
      contains(path.join('.kiro', 'skills')),
    );
    expect(
      synchronizer.mcpTargets.single.file.path,
      path.join(temp.path, '.kiro', 'settings', 'mcp.json'),
    );
    expect(synchronizer.mcpTargets.single.kind, AgentMcpConfigKind.kiroJson);
  });

  test('bundled online Skill syncs offline from embedded content', () async {
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
      File('${target.path}/dingdong-configure/SKILL.md').readAsStringSync(),
      document,
    );
    expect(File('${cached.path}/SKILL.md').readAsStringSync(), document);
  });

  test(
    'mirrors enabled Skill packages and removes them when disabled',
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
        isTrue,
      );

      await synchronizer.sync(<Resource>[resource.copyWith(enabled: false)]);
      expect(Directory('${target.path}/reviewer').existsSync(), isFalse);
    },
  );

  test('Skill edits replace every mirror and remove the previous name', () async {
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
      final File mirrored = File('${root.path}/new-reviewer/SKILL.md');
      expect(mirrored.existsSync(), isTrue);
      expect(mirrored.readAsStringSync(), contains('# New'));
      expect(
        File('${root.path}/new-reviewer/.dingdong-managed').readAsStringSync(),
        'RENAMED-SKILL',
      );
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
        isTrue,
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
  });

  test('reports a user-owned Skill collision without changing it', () async {
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
    expect(issues.single.clientName, 'Codex');
    expect(issues.single.targetPath, path.normalize(existing.path));
    await expectLater(
      synchronizer.sync(<Resource>[resource]),
      throwsA(isA<AppIssueException>()),
    );
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

  test('transaction rollback publishes a structured issue', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-sync-issue-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final Directory target = Directory('${temp.path}/skills');
    Directory('${target.path}/reviewer').createSync(recursive: true);
    final InMemoryResourceStore base = InMemoryResourceStore();
    final IssueCenterController issueCenter = IssueCenterController();
    final SynchronizedResourceStore store = SynchronizedResourceStore(
      base,
      AgentResourceSynchronizer(
        packageRoot: Directory('${temp.path}/packages'),
        skillRoots: <Directory>[target],
        mcpTargets: const <AgentMcpTarget>[],
        managedStateFile: File('${temp.path}/state.json'),
      ),
      issueCenter: issueCenter,
    );
    final Resource resource = _resource(
      type: ResourceType.skill,
      content: '---\nname: reviewer\ndescription: Review code\n---\n',
    );

    await expectLater(
      store.save(<Resource>[resource]),
      throwsA(isA<AppIssueException>()),
    );

    expect(await base.load(), isEmpty);
    expect(issueCenter.issues, hasLength(1));
    expect(issueCenter.issues.single.kind, AppIssueKind.skillNameConflict);
  });

  test(
    'project-scoped Skills avoid global roots and clean stale project copies',
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
        isTrue,
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
    'manages global always-on prompts without replacing user instructions',
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
      expect(contents, contains('Add one star to every complete response.'));
      expect(contents, contains('dingdong_bridge'));
      expect(contents, contains('Skill and MCP entries are candidates'));
      expect(contents, contains('call MCP tools only when'));
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
      expect(contents, contains('Use the updated global instruction.'));
      expect(contents, isNot(contains('Add one star')));
      expect(contents, isNot(contains('dingdong_bridge')));

      await synchronizer.sync(<Resource>[
        global.copyWith(enabled: false),
        routed.copyWith(enabled: false),
        manual,
      ]);
      expect(
        agents.readAsStringSync(),
        '- Keep the existing user instruction.\n',
      );
    },
  );

  test(
    'Claude prompt target mirrors only global always-on instructions',
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
      expect(contents, startsWith('- Keep the existing Claude instruction.'));
      expect(contents, contains('Add one star to every complete response.'));
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
}

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
