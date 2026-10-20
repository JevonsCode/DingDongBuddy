import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_adapters/domain/agent_adapter.dart';
import 'package:dingdong/features/issue_center/data/duplicate_resource_cleanup.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/domain/issue_cleanup.dart';
import 'package:dingdong/features/library/data/agent_resource_synchronizer.dart';
import 'package:dingdong/features/library/data/agent_skill_catalog.dart';
import 'package:dingdong/features/library/data/resource_file_service.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory temp;
  late File target;
  late AgentResourceSynchronizer synchronizer;
  late ResourceRepository baseStore;
  late SynchronizedResourceStore store;
  late DuplicateResourceCleanup cleanup;
  late Resource mcp;

  setUp(() async {
    temp = Directory.systemTemp.createTempSync('dingdong-duplicate-cleanup-');
    target = File(path.join(temp.path, 'cursor.json'))
      ..writeAsStringSync(
        jsonEncode(<String, Object?>{
          'editor': <String, Object?>{'keep': true},
          'mcpServers': <String, Object?>{
            'Figma': <String, Object?>{'url': 'https://example.com/mcp/'},
            'Figma-2': <String, Object?>{'url': 'https://example.com/mcp'},
            'other': <String, Object?>{'command': 'other'},
          },
        }),
      );
    synchronizer = AgentResourceSynchronizer(
      packageRoot: Directory(path.join(temp.path, 'packages')),
      skillRoots: const <Directory>[],
      mcpTargets: <AgentMcpTarget>[
        AgentMcpTarget(
          target,
          AgentMcpConfigKind.cursorJson,
          clientName: 'Cursor',
        ),
      ],
    );
    baseStore = ResourceRepository(
      ResourceFileService(File(path.join(temp.path, 'resources.json'))),
    );
    mcp = _resource(
      'figma',
      ResourceType.mcp,
      '{"type":"streamable-http","url":"https://example.com/mcp"}',
    );
    await baseStore.save(<Resource>[mcp]);
    store = SynchronizedResourceStore(baseStore, synchronizer);
    cleanup = DuplicateResourceCleanup(
      resourceStore: store,
      synchronizer: synchronizer,
      backupDirectory: Directory(path.join(temp.path, 'backups')),
    );
  });
  tearDown(() => temp.deleteSync(recursive: true));

  Future<AppIssue> duplicate([String name = 'Figma']) async =>
      (await synchronizer.inspect(
        await baseStore.load(),
      )).singleWhere((AppIssue issue) => issue.duplicateEntryName == name);

  test('keeps separate actionable issues for each duplicate entry', () async {
    final List<AppIssue> issues = await synchronizer.inspect(<Resource>[mcp]);
    expect(issues, hasLength(2));
    expect(issues.map((AppIssue issue) => issue.id).toSet(), hasLength(2));
    expect(
      AppIssue.fromJson(issues.first.toJson()).duplicateEntryName,
      'Figma',
    );
  });

  test(
    'removes only selected external entry and saves private exact backup',
    () async {
      final String before = target.readAsStringSync();
      final IssueCleanupResult result = await cleanup.resolve(
        await duplicate(),
        backup: true,
        choice: IssueCleanupChoice.externalMcp,
      );
      final Map<String, Object?> current =
          jsonDecode(target.readAsStringSync()) as Map<String, Object?>;
      expect(current['editor'], <String, Object?>{'keep': true});
      expect((current['mcpServers'] as Map).keys, <String>['Figma-2', 'other']);
      expect(await baseStore.load(), <Resource>[mcp]);
      final Directory backup = Directory(result.backupPath!);
      expect(
        File(path.join(backup.path, 'agent-config.json')).readAsStringSync(),
        before,
      );
      if (!Platform.isWindows) {
        expect(backup.statSync().mode & 0x1FF, 0x1C0);
        expect(
          File(path.join(backup.path, 'agent-config.json')).statSync().mode &
              0x1FF,
          0x180,
        );
      }
    },
  );

  test('does not create backups when unchecked', () async {
    final IssueCleanupResult result = await cleanup.resolve(
      await duplicate(),
      backup: false,
      choice: IssueCleanupChoice.externalMcp,
    );
    expect(result.backupPath, isNull);
    expect(Directory(path.join(temp.path, 'backups')).existsSync(), isFalse);
  });

  test('rechecks changed endpoint and refuses stale issue', () async {
    final AppIssue issue = await duplicate();
    final Map<String, Object?> current =
        jsonDecode(target.readAsStringSync()) as Map<String, Object?>;
    (current['mcpServers'] as Map)['Figma'] = <String, Object?>{
      'url': 'https://different.example/mcp',
    };
    target.writeAsStringSync(jsonEncode(current));
    final String before = target.readAsStringSync();
    await expectLater(
      cleanup.resolve(
        issue,
        backup: true,
        choice: IssueCleanupChoice.externalMcp,
      ),
      throwsStateError,
    );
    expect(target.readAsStringSync(), before);
    expect(Directory(path.join(temp.path, 'backups')).existsSync(), isFalse);
  });

  test('rejects a target that is no longer configured', () async {
    final AppIssue issue = await duplicate();
    synchronizer.mcpTargets = const <AgentMcpTarget>[];
    await expectLater(
      cleanup.resolve(
        issue,
        backup: false,
        choice: IssueCleanupChoice.externalMcp,
      ),
      throwsStateError,
    );
    expect(target.readAsStringSync(), contains('Figma'));
  });

  test('invalid JSON keys block cleanup without changing the file', () async {
    final AppIssue issue = await duplicate();
    const String ambiguous =
        '{"mcpServers":{"Figma":{"url":"https://example.com/mcp"},"Figma":{"url":"https://example.com/mcp"}}}';
    target.writeAsStringSync(ambiguous);
    await expectLater(
      cleanup.resolve(
        issue,
        backup: true,
        choice: IssueCleanupChoice.externalMcp,
      ),
      throwsFormatException,
    );
    expect(target.readAsStringSync(), ambiguous);
    expect(Directory(path.join(temp.path, 'backups')).existsSync(), isFalse);
  });

  test(
    'backup failure cancels cleanup and preserves resource and Agent config',
    () async {
      final AppIssue issue = await duplicate();
      final String before = target.readAsStringSync();
      File(path.join(temp.path, 'backups')).writeAsStringSync('blocked');
      await expectLater(
        cleanup.resolve(
          issue,
          backup: true,
          choice: IssueCleanupChoice.externalMcp,
        ),
        throwsA(isA<FileSystemException>()),
      );
      expect(target.readAsStringSync(), before);
      expect(await baseStore.load(), <Resource>[mcp]);
    },
  );

  test(
    'can keep external MCP copies and remove DingDong copy instead',
    () async {
      final AppIssue issue = await duplicate();
      await cleanup.resolve(
        issue,
        backup: false,
        choice: IssueCleanupChoice.dingDongResource,
      );
      expect(await baseStore.load(), isEmpty);
      expect(
        (jsonDecode(target.readAsStringSync()) as Map)['mcpServers'],
        contains('Figma'),
      );
    },
  );

  test(
    'backups preserve a complete Skill before managed package deletion',
    () async {
      final Directory package = Directory(
        path.join(synchronizer.packageRoot.path, 'reviewer'),
      )..createSync(recursive: true);
      File(path.join(package.path, 'SKILL.md')).writeAsStringSync(
        '---\nname: reviewer\ndescription: Review\n---\nReview',
      );
      Directory(path.join(package.path, 'scripts')).createSync();
      File(
        path.join(package.path, 'scripts', 'review.txt'),
      ).writeAsStringSync('complete package');
      final Resource skill = _resource(
        'reviewer',
        ResourceType.skill,
        '---\nname: reviewer\ndescription: Review\n---\nReview',
        packagePath: package.path,
      );
      final Resource other = _resource(
        'reviewer-other',
        ResourceType.skill,
        skill.content,
      );
      await baseStore.save(<Resource>[skill, other]);
      final AppIssue issue =
          (await synchronizer.inspect(<Resource>[skill, other])).firstWhere(
            (AppIssue issue) =>
                issue.resourceId == skill.id &&
                issue.kind == AppIssueKind.managedSkillNameConflict,
          );
      final IssueCleanupResult result = await cleanup.resolve(
        issue,
        backup: true,
        choice: IssueCleanupChoice.dingDongResource,
      );
      expect(
        (await baseStore.load()).map((Resource resource) => resource.id),
        <String>[other.id],
      );
      expect(package.existsSync(), isFalse);
      expect(
        File(
          path.join(
            result.backupPath!,
            'skill-package',
            'scripts',
            'review.txt',
          ),
        ).readAsStringSync(),
        'complete package',
      );
      final Map<String, Object?> saved =
          jsonDecode(
                File(
                  path.join(result.backupPath!, 'resource.json'),
                ).readAsStringSync(),
              )
              as Map<String, Object?>;
      expect(Resource.fromJson(saved).id, skill.id);
      final Resource restored = LibraryBundle.decode(
        File(
          path.join(result.backupPath!, 'restore-bundle.json'),
        ).readAsStringSync(),
        existing: const <Resource>[],
      ).imported.single;
      expect(
        restored.packagePath,
        path.join(result.backupPath!, 'skill-package'),
      );
      expect(
        File(
          path.join(restored.packagePath!, 'scripts', 'review.txt'),
        ).readAsStringSync(),
        'complete package',
      );
      expect(
        File(path.join(result.backupPath!, 'restore.txt')).readAsStringSync(),
        contains(package.path),
      );
    },
  );

  test('plugin Skill cleanup deletes only the DingDong resource', () async {
    final File pluginSkill = File(path.join(temp.path, 'plugin', 'SKILL.md'));
    pluginSkill.parent.createSync();
    pluginSkill.writeAsStringSync('owned by plugin');
    synchronizer.externalSkillCatalogs = <AgentSkillCatalog>[
      _PluginCatalog(pluginSkill.path),
    ];
    final Resource skill = _resource(
      'reviewer',
      ResourceType.skill,
      '---\nname: reviewer\ndescription: Review\n---\nReview',
    );
    await baseStore.save(<Resource>[skill]);
    final AppIssue issue = (await synchronizer.inspect(<Resource>[
      skill,
    ])).single;
    expect(issue.kind, AppIssueKind.pluginSkillNameConflict);
    await cleanup.resolve(
      issue,
      backup: false,
      choice: IssueCleanupChoice.dingDongResource,
    );
    expect(await baseStore.load(), isEmpty);
    expect(pluginSkill.readAsStringSync(), 'owned by plugin');
  });

  test(
    'deleting one duplicate preserves a shared package used by the survivor',
    () async {
      final Directory package = Directory(
        path.join(synchronizer.packageRoot.path, 'reviewer'),
      )..createSync(recursive: true);
      const String content =
          '---\nname: reviewer\ndescription: Review\n---\nReview';
      File(path.join(package.path, 'SKILL.md')).writeAsStringSync(content);
      final Resource removed = _resource(
        'reviewer',
        ResourceType.skill,
        content,
        packagePath: package.path,
      );
      final Resource retained = _resource(
        'reviewer-other',
        ResourceType.skill,
        content,
        packagePath: package.path,
      );
      await baseStore.save(<Resource>[removed, retained]);
      final AppIssue issue = (await synchronizer.inspect(<Resource>[
        removed,
        retained,
      ])).firstWhere((AppIssue issue) => issue.resourceId == removed.id);
      await cleanup.resolve(
        issue,
        backup: false,
        choice: IssueCleanupChoice.dingDongResource,
      );
      expect(
        (await baseStore.load()).map((Resource resource) => resource.id),
        <String>[retained.id],
      );
      expect(
        File(path.join(package.path, 'SKILL.md')).readAsStringSync(),
        content,
      );
      expect(await synchronizer.inspect(await baseStore.load()), isEmpty);
    },
  );

  test(
    'malformed managed id cannot resolve a removal outside package root',
    () async {
      final Resource unsafe = _resource(
        '../outside',
        ResourceType.skill,
        '---\nname: reviewer\ndescription: Review\n---\nReview',
      );
      final Resource other = _resource(
        'other',
        ResourceType.skill,
        unsafe.content,
      );
      await baseStore.save(<Resource>[unsafe, other]);
      final File unrelated = File(path.join(temp.path, 'outside', 'SKILL.md'));
      unrelated.parent.createSync();
      unrelated.writeAsStringSync('preserve');
      final AppIssue issue = (await synchronizer.inspect(<Resource>[
        unsafe,
        other,
      ])).firstWhere((AppIssue issue) => issue.resourceId == unsafe.id);
      await expectLater(
        cleanup.resolve(
          issue,
          backup: false,
          choice: IssueCleanupChoice.dingDongResource,
        ),
        throwsFormatException,
      );
      expect(unrelated.readAsStringSync(), 'preserve');
      expect(await baseStore.load(), hasLength(2));
    },
  );
}

final class _PluginCatalog implements AgentSkillCatalog {
  const _PluginCatalog(this.file);
  final String file;

  @override
  Future<List<ExternalAgentSkill>> load() async => <ExternalAgentSkill>[
    ExternalAgentSkill(
      name: 'reviewer',
      clientName: 'Claude Code',
      providerName: 'Reviews',
      targetPath: file,
    ),
  ];
}

Resource _resource(
  String id,
  ResourceType type,
  String content, {
  String? packagePath,
}) => Resource(
  id: id,
  type: type,
  title: id,
  content: content,
  packagePath: packagePath,
  createdAt: DateTime.utc(2026, 10, 21),
  updatedAt: DateTime.utc(2026, 10, 21),
);
