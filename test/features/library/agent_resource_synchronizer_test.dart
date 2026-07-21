import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/agent_resource_synchronizer.dart';
import 'package:dingdong/features/library/domain/built_in_resources.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
      packageRoot: Directory('${temp.path}/packages'),
      skillRoots: const <Directory>[],
      mcpTargets: <AgentMcpTarget>[
        AgentMcpTarget(codex, AgentMcpConfigKind.codexToml),
        AgentMcpTarget(claude, AgentMcpConfigKind.claudeJson),
        AgentMcpTarget(cursor, AgentMcpConfigKind.cursorJson),
        AgentMcpTarget(gemini, AgentMcpConfigKind.geminiJson),
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
  });
}

final class _OfflineInstaller implements SkillPackageInstaller {
  @override
  Future<SkillPackageInstallResult> install(Uri source) {
    throw StateError('Network installer must not run for a bundled Skill.');
  }
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
