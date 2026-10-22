import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_adapters/domain/agent_adapter.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/library/data/agent_resource_synchronizer.dart';
import 'package:dingdong/features/library/data/native_skill_delivery_coordinator.dart';
import 'package:dingdong/features/library/data/resource_file_service.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/skill_version_history.dart';
import 'package:dingdong/features/library/domain/skill_version.dart';
import 'package:flutter_test/flutter_test.dart';

const String _document =
    '---\nname: example\ndescription: Example Skill\n---\nFirst version\n';

void main() {
  late Directory temp;
  late ResourceRepository repository;
  late SkillVersionHistory history;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('dingdong-version-store-');
    repository = ResourceRepository(
      ResourceFileService(File('${temp.path}/resources.json')),
    );
    history = SkillVersionHistory(Directory('${temp.path}/Skill History'));
  });
  tearDown(() => temp.deleteSync(recursive: true));
  SynchronizedResourceStore store({SkillVersionHistory? overrideHistory}) =>
      SynchronizedResourceStore(
        repository,
        AgentResourceSynchronizer(
          packageRoot: Directory('${temp.path}/packages'),
          skillRoots: const [],
          mcpTargets: const [],
        ),
        skillVersionHistory: overrideHistory ?? history,
      );

  test(
    'existing Skill baseline, manual edit, metadata-only edit and restart',
    () async {
      final Resource resource = _skill();
      await repository.save([resource]);
      final SynchronizedResourceStore active = store();
      await active.load();
      expect(
        (await active.loadSkillVersions('skill')).single.source,
        SkillVersionSource.initial,
      );
      final Resource changed = resource.copyWith(
        content: '${_document}Edited\n',
      );
      await active.save([changed]);
      await active.save([
        changed.copyWith(note: 'my note', usageCount: 4, enabled: false),
      ]);
      expect(await store().loadSkillVersions('skill'), hasLength(2));
      expect((await store().load()).single.note, 'my note');
      expect(await store().loadSkillVersions('skill'), hasLength(2));
    },
  );

  test(
    'new Skill is tracked only after successful save and invalid sync rolls back',
    () async {
      final SynchronizedResourceStore active = store();
      await active.save([_skill()]);
      final Resource invalid = _skill().copyWith(content: 'not a valid Skill');
      await expectLater(
        active.save([invalid]),
        throwsA(isA<AppIssueException>()),
      );
      expect((await repository.load()).single.content, _document);
      expect(await active.loadSkillVersions('skill'), hasLength(1));
    },
  );

  test(
    'failed manifest commit rolls back persisted resource and history',
    () async {
      final Resource resource = _skill();
      await repository.save([resource]);
      await store().load();
      final SynchronizedResourceStore failing = store(
        overrideHistory: SkillVersionHistory(
          history.root!,
          beforeManifestWrite: (_) async =>
              throw const FileSystemException('injected history write failure'),
        ),
      );
      await failing.load();
      await expectLater(
        failing.save([resource.copyWith(content: '${_document}Changed\n')]),
        throwsA(isA<FileSystemException>()),
      );
      expect((await repository.load()).single.content, _document);
      expect(await history.versions('skill'), hasLength(1));
    },
  );

  test(
    'nested memory-store mutation remains reentrant for HTTP and Agent writes',
    () async {
      final SynchronizedResourceStore active = SynchronizedResourceStore(
        InMemoryResourceStore([_skill()]),
        AgentResourceSynchronizer(
          packageRoot: Directory('${temp.path}/packages'),
          skillRoots: const [],
          mcpTargets: const [],
        ),
      );
      await active
          .exclusiveMutation(() async {
            final List<Resource> resources = await active.load();
            await active.save([
              resources.single.copyWith(content: '${_document}Nested'),
            ]);
          })
          .timeout(const Duration(seconds: 3));
      expect(await active.loadSkillVersions('skill'), hasLength(2));
    },
  );

  test(
    'document-only history restores while retaining enabled native delivery',
    () async {
      final Resource original = _skill();
      await repository.save([original]);
      final Directory nativeRoot = Directory('${temp.path}/native');
      final SynchronizedResourceStore active = SynchronizedResourceStore(
        repository,
        AgentResourceSynchronizer(
          packageRoot: Directory('${temp.path}/packages'),
          skillRoots: const [],
          mcpTargets: const [],
          skillTargets: [
            AgentSkillTarget(
              agentId: 'codex',
              clientName: 'Codex',
              globalRoot: nativeRoot,
              projectRelativeRoot: '.agents/skills',
            ),
          ],
        ),
        skillVersionHistory: history,
      );
      await active.load();
      final Directory package = Directory('${temp.path}/packages/current')
        ..createSync(recursive: true);
      File('${package.path}/SKILL.md').writeAsStringSync('${_document}Current');
      await active.save([
        original.copyWith(
          content: '${_document}Current',
          packagePath: package.path,
          skillDeliveryByAgent: {'codex': SkillDeliveryMode.nativeUser},
        ),
      ]);
      await active.restoreSkillVersion('skill', 1);
      final Resource restored = (await repository.load()).single;
      expect(restored.enabled, isTrue);
      expect(restored.skillDeliveryByAgent, {
        'codex': SkillDeliveryMode.nativeUser,
      });
      expect(
        File('${nativeRoot.path}/example/SKILL.md').readAsStringSync(),
        _document,
      );
      expect(restored.skillPackageDigest, startsWith('sha256:'));
      final SkillVersion latest = (await active.loadSkillVersions(
        'skill',
      )).last;
      expect(
        (await active.loadSkillSnapshot(latest.snapshotId)).hasPackage,
        isTrue,
      );
    },
  );

  test('manifest failure rolls back actual Agent MCP configuration', () async {
    final Resource skill = _skill();
    final Resource mcp = Resource(
      id: 'mcp',
      type: ResourceType.mcp,
      title: 'Server',
      content: '{"type":"stdio","command":"old-command"}',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final File agentConfig = File('${temp.path}/agent.json')
      ..writeAsStringSync('{}');
    AgentResourceSynchronizer synchronizer() => AgentResourceSynchronizer(
      packageRoot: Directory('${temp.path}/packages'),
      skillRoots: const [],
      mcpTargets: [
        AgentMcpTarget(agentConfig, AgentMcpConfigKind.mcpServersJson),
      ],
    );
    final SynchronizedResourceStore good = SynchronizedResourceStore(
      repository,
      synchronizer(),
      skillVersionHistory: history,
    );
    await good.save([skill, mcp]);
    final String originalConfig = agentConfig.readAsStringSync();
    final SynchronizedResourceStore failing = SynchronizedResourceStore(
      repository,
      synchronizer(),
      skillVersionHistory: SkillVersionHistory(
        history.root!,
        beforeManifestWrite: (_) async =>
            throw const FileSystemException('manifest unavailable'),
      ),
    );
    await failing.load();
    await expectLater(
      failing.save([
        skill.copyWith(content: '${_document}Changed'),
        mcp.copyWith(content: '{"type":"stdio","command":"new-command"}'),
      ]),
      throwsA(isA<FileSystemException>()),
    );
    expect(agentConfig.readAsStringSync(), originalConfig);
    expect((await repository.load()).last.content, mcp.content);
    expect(await history.versions(skill.id), hasLength(1));
  });

  test('failed package restore preserves current artifact and history', () async {
    final Directory package = Directory('${temp.path}/packages/original')
      ..createSync(recursive: true);
    File('${package.path}/SKILL.md').writeAsStringSync(_document);
    File('${package.path}/payload').writeAsStringSync('old payload');
    final Resource original = _skill(packagePath: package.path);
    await repository.save([original]);
    final SynchronizedResourceStore active = store();
    await active.load();
    final Directory currentPackage = Directory('${temp.path}/packages/current')
      ..createSync(recursive: true);
    File(
      '${currentPackage.path}/SKILL.md',
    ).writeAsStringSync('${_document}New');
    File('${currentPackage.path}/payload').writeAsStringSync('current payload');
    await active.save([
      original.copyWith(
        content: '${_document}New',
        packagePath: currentPackage.path,
      ),
    ]);
    final SynchronizedResourceStore failing = store(
      overrideHistory: SkillVersionHistory(
        history.root!,
        beforeManifestWrite: (_) async =>
            throw const FileSystemException('manifest unavailable'),
      ),
    );
    await expectLater(
      failing.restoreSkillVersion('skill', 1),
      throwsA(isA<FileSystemException>()),
    );
    expect((await repository.load()).single.packagePath, currentPackage.path);
    expect(
      File('${currentPackage.path}/payload').readAsStringSync(),
      'current payload',
    );
    expect(await history.versions('skill'), hasLength(2));
    final String originalSnapshotId = (await history.versions(
      'skill',
    )).first.snapshotId;
    final Directory restoredParent = Directory(
      '${temp.path}/packages/${history.resourceKey('skill:$originalSnapshotId')}',
    );
    expect(
      !restoredParent.existsSync() || restoredParent.listSync().isEmpty,
      isTrue,
    );
  });

  test('deleting before first load retains initial history', () async {
    await repository.save([_skill()]);
    await store().save([]);
    final SkillVersion version = (await history.versions('skill')).single;
    expect(version.source, SkillVersionSource.initial);
    expect((await history.snapshot(version.snapshotId)).document, _document);
  });

  test(
    'restores packages larger than the online import file-count budget',
    () async {
      final Directory package = Directory('${temp.path}/large-package')
        ..createSync();
      File('${package.path}/SKILL.md').writeAsStringSync(_document);
      for (int i = 0; i < 601; i++) {
        File('${package.path}/file-$i.txt').writeAsStringSync('payload $i');
      }
      final Resource original = _skill(packagePath: package.path);
      await repository.save([original]);
      final SynchronizedResourceStore active = store();
      await active.load();
      await active.save([
        original.copyWith(content: '${_document}New', packagePath: ''),
      ]);
      await active.restoreSkillVersion('skill', 1);
      final Resource restored = (await repository.load()).single;
      expect(
        Directory(restored.packagePath!).listSync().whereType<File>(),
        hasLength(602),
      );
      expect(
        File('${restored.packagePath}/file-600.txt').readAsStringSync(),
        'payload 600',
      );
      expect((await active.loadSkillVersions('skill')).last.restoredFrom, 1);
    },
  );

  test(
    'receipt-only snapshot differences restore exact bytes despite equal native digests',
    () async {
      Directory createPackage(String name, String receipt) {
        final Directory package = Directory('${temp.path}/$name')..createSync();
        File('${package.path}/SKILL.md').writeAsStringSync(_document);
        File(
          '${package.path}/.dingdong-skill-deployment.json',
        ).writeAsStringSync(receipt);
        return package;
      }

      final Directory firstPackage = createPackage(
        'first-package',
        '{"revision":1}',
      );
      final Directory secondPackage = createPackage(
        'second-package',
        '{"revision":2}',
      );
      final Resource original = _skill(packagePath: firstPackage.path);
      await repository.save([original]);
      final SynchronizedResourceStore active = store();
      await active.load();
      await active.save([original.copyWith(packagePath: secondPackage.path)]);
      final List<SkillVersion> sourceVersions = await active.loadSkillVersions(
        'skill',
      );
      expect(
        sourceVersions.first.snapshotId,
        isNot(sourceVersions.last.snapshotId),
      );
      await active.restoreSkillVersion('skill', 1);
      final Resource restoredFirst = (await repository.load()).single;
      expect(
        File(
          '${restoredFirst.packagePath}/.dingdong-skill-deployment.json',
        ).readAsStringSync(),
        '{"revision":1}',
      );
      await active.restoreSkillVersion('skill', 2);
      final Resource restoredSecond = (await repository.load()).single;
      expect(
        restoredSecond.skillPackageDigest,
        restoredFirst.skillPackageDigest,
      );
      expect(restoredSecond.packagePath, isNot(restoredFirst.packagePath));
      expect(
        File(
          '${restoredSecond.packagePath}/.dingdong-skill-deployment.json',
        ).readAsStringSync(),
        '{"revision":2}',
      );
      expect(
        (await active.loadSkillVersions('skill')).last.snapshotId,
        sourceVersions[1].snapshotId,
      );
    },
  );

  test('stale concurrent save conflicts without adding history', () async {
    await repository.save([_skill()]);
    final SynchronizedResourceStore first = store();
    final SynchronizedResourceStore second = store();
    final Resource original = (await first.load()).single;
    await second.load();
    await first.save([original.copyWith(content: '${_document}First edit\n')]);
    await expectLater(
      second.save([original.copyWith(content: '${_document}Second edit\n')]),
      throwsStateError,
    );
    expect(await history.versions('skill'), hasLength(2));
  });

  test(
    'complete package restores after cleanup and preserves current Agent metadata',
    () async {
      final Directory package = Directory('${temp.path}/packages/old/artifact')
        ..createSync(recursive: true);
      File('${package.path}/SKILL.md').writeAsStringSync(_document);
      File('${package.path}/image.bin').writeAsBytesSync([0, 128, 255]);
      File(
        '${package.path}/.dingdong-managed',
      ).writeAsStringSync('original marker');
      Directory('${package.path}/.git').createSync();
      File(
        '${package.path}/.git/config',
      ).writeAsStringSync('original git metadata');
      Directory('${package.path}/nested').createSync();
      File(
        '${package.path}/nested/.dingdong-managed',
      ).writeAsStringSync('nested marker');
      Directory('${package.path}/empty/nested').createSync(recursive: true);
      final Resource original = _skill(
        packagePath: package.path,
        updateUrl: 'https://example.com/old',
      );
      await repository.save([original]);
      final SynchronizedResourceStore active = store();
      await active.load();
      final Resource current = original.copyWith(
        title: 'New title',
        content: '${_document}Second\n',
        packagePath: '',
        updateUrl: 'https://example.com/new',
        enabled: false,
        note: 'keep note',
        usageCount: 9,
        skillHooksEnabledByAgent: {'codex': false},
        skillDeliveryByAgent: {'codex': SkillDeliveryMode.nativeUser},
      );
      await active.saveWithSkillVersionSource([
        current,
      ], source: SkillVersionSource.online);
      expect(package.existsSync(), isFalse);
      await active.restoreSkillVersion('skill', 1);
      final Resource restored = (await repository.load()).single;
      expect(restored.title, original.title);
      expect(restored.content, _document);
      expect(restored.updateUrl, original.updateUrl);
      expect(restored.enabled, isFalse);
      expect(restored.note, 'keep note');
      expect(restored.usageCount, 9);
      expect(restored.skillHooksEnabledByAgent, {'codex': false});
      expect(restored.skillDeliveryByAgent, current.skillDeliveryByAgent);
      expect(restored.skillPackageDigest, startsWith('sha256:'));
      expect(
        File('${restored.packagePath}/.dingdong-managed').readAsStringSync(),
        'original marker',
      );
      expect(
        File('${restored.packagePath}/.git/config').readAsStringSync(),
        'original git metadata',
      );
      expect(
        File(
          '${restored.packagePath}/nested/.dingdong-managed',
        ).readAsStringSync(),
        'nested marker',
      );
      expect(File('${restored.packagePath}/image.bin').readAsBytesSync(), [
        0,
        128,
        255,
      ]);
      expect(
        Directory('${restored.packagePath}/empty/nested').existsSync(),
        isTrue,
      );
      final List<SkillVersion> versions = await active.loadSkillVersions(
        'skill',
      );
      expect(versions, hasLength(3));
      expect(versions.last.source, SkillVersionSource.restored);
      expect(versions.last.restoredFrom, 1);
      await active.restoreSkillVersion('skill', 3);
      expect(await active.loadSkillVersions('skill'), hasLength(4));
      await active.save([]);
      expect(await history.versions('skill'), hasLength(4));
    },
  );

  test(
    'document-only restore clears newer source and package using a fresh baseline',
    () async {
      final Resource resource = _skill();
      await repository.save([resource]);
      final SynchronizedResourceStore stale = store();
      await stale.load();
      final SynchronizedResourceStore fresh = store();
      await fresh.load();
      await fresh.save([
        resource.copyWith(
          title: 'New',
          content: '${_document}New\n',
          updateUrl: 'https://example.com/new',
          note: 'latest note',
        ),
      ]);
      await stale.restoreSkillVersion('skill', 1);
      final Resource restored = (await repository.load()).single;
      expect(restored.title, resource.title);
      expect(restored.note, 'latest note');
      expect(restored.updateUrl, isNull);
      expect(restored.packagePath, isNull);
      expect(restored.skillPackageDigest, isNull);
    },
  );
}

Resource _skill({String? packagePath, String? updateUrl}) => Resource(
  id: 'skill',
  type: ResourceType.skill,
  title: 'Original',
  content: _document,
  packagePath: packagePath,
  updateUrl: updateUrl,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
