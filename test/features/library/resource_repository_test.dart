import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_file_service.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'loads legacy resources and preserves every public field when saved',
    () async {
      final Directory directory = await Directory.systemTemp.createTemp(
        'dingdong-resource-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final File file = File('${directory.path}/resource-library.json');
      await File('test/fixtures/resource-library-legacy.json').copy(file.path);
      final ResourceRepository repository = ResourceRepository(
        ResourceFileService(file),
      );

      final List<Resource> resources = await repository.load();
      final Resource resource = resources.single;
      expect(resource.title, 'Release note writer');
      expect(resource.enabled, isTrue);
      expect(resource.activation, ResourceActivation.always);

      final Resource scoped = resource.copyWith(
        skillProjectPaths: <String>[directory.path],
        strictProjectSkill: true,
      );
      await repository.save(<Resource>[scoped]);
      expect((await repository.load()).single, scoped);
    },
  );

  test('legacy project paths migrate to an explicit strict Skill flag', () {
    final Resource resource = Resource.fromJson(<String, Object?>{
      'id': 'reviewer',
      'type': 'skill',
      'group': 'Skills',
      'title': 'Reviewer',
      'content': 'Review code',
      'skillProjectPaths': <String>['/work/project'],
      'createdAt': '2026-07-29T00:00:00.000Z',
      'updatedAt': '2026-07-29T00:00:00.000Z',
    });

    expect(resource.strictProjectSkill, isTrue);
    expect(resource.toJson()['strictProjectSkill'], isTrue);
  });

  test(
    'legacy Skills default every Agent to dynamic delivery with hooks off',
    () {
      final Resource resource = Resource.fromJson(<String, Object?>{
        'id': 'reviewer',
        'type': 'skill',
        'group': 'Skills',
        'title': 'Reviewer',
        'content': 'Review code',
        'createdAt': '2026-07-29T00:00:00.000Z',
        'updatedAt': '2026-07-29T00:00:00.000Z',
      });

      expect(
        resource.skillDeliveryForAgent('codex'),
        SkillDeliveryMode.dynamic,
      );
      expect(resource.skillHooksEnabledForAgent('codex'), isFalse);
      expect(resource.skillDeliveryByAgent, isEmpty);
      expect(resource.skillHooksEnabledByAgent, isEmpty);
    },
  );

  test('persists one delivery and hook switch per Agent', () {
    final DateTime now = DateTime.utc(2026, 8, 12);
    final Resource resource = Resource(
      id: 'reviewer',
      type: ResourceType.skill,
      title: 'Reviewer',
      content: 'Review code',
      skillDeliveryByAgent: const <String, SkillDeliveryMode>{
        ' claude-code ': SkillDeliveryMode.nativeProject,
        'codex': SkillDeliveryMode.nativeUser,
      },
      skillHooksEnabledByAgent: const <String, bool>{
        ' codex ': true,
        'claude-code': false,
      },
      skillPackageDigest: ' ABCDEF ',
      createdAt: now,
      updatedAt: now,
    );

    expect(resource.skillDeliveryByAgent.keys, <String>[
      'claude-code',
      'codex',
    ]);
    expect(
      resource.skillDeliveryForAgent('claude-code'),
      SkillDeliveryMode.nativeProject,
    );
    expect(resource.skillHooksEnabledForAgent('codex'), isTrue);
    expect(resource.skillPackageDigest, 'ABCDEF');

    final Map<String, Object?> json = resource.toJson();
    expect(json['skillDeliveryByAgent'], <String, String>{
      'claude-code': 'nativeProject',
      'codex': 'nativeUser',
    });
    expect(json['skillHooksEnabledByAgent'], <String, bool>{
      'claude-code': false,
      'codex': true,
    });
    expect(Resource.fromJson(json), resource);
    expect(resource.toApiJson()['skillPackageDigest'], 'ABCDEF');
    expect(resource.toSummaryApiJson()['skillPackageDigest'], 'ABCDEF');
  });

  test('two file-backed repositories serialize concurrent updates', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-resource-concurrency-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/resource-library.json');
    final ResourceRepository first = ResourceRepository(
      ResourceFileService(file),
    );
    final ResourceRepository second = ResourceRepository(
      ResourceFileService(file),
    );
    final DateTime now = DateTime.utc(2026, 8, 12);
    final Resource original = Resource(
      id: 'reviewer',
      type: ResourceType.skill,
      title: 'Reviewer',
      content: 'Review code',
      createdAt: now,
      updatedAt: now,
    );
    await first.save(<Resource>[original]);

    final List<List<Resource>> seen = await Future.wait<List<Resource>>(
      <Future<List<Resource>>>[
        first.exclusive(() async {
          final List<Resource> latest = await first.load();
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await first.save(<Resource>[
            latest.single.copyWith(
              skillDeliveryByAgent: const <String, SkillDeliveryMode>{
                'codex': SkillDeliveryMode.nativeUser,
              },
            ),
          ]);
          return first.load();
        }),
        second.exclusive(() async {
          final List<Resource> latest = await second.load();
          return latest;
        }),
      ],
    );

    expect(
      seen.last.single.skillDeliveryForAgent('codex'),
      SkillDeliveryMode.nativeUser,
    );
    expect(jsonDecode(await file.readAsString()), isA<List<Object?>>());
  });

  test('copyWith can replace and clear the package digest', () {
    final DateTime now = DateTime.utc(2026, 8, 12);
    final Resource resource = Resource(
      id: 'reviewer',
      type: ResourceType.skill,
      title: 'Reviewer',
      content: 'Review code',
      skillPackageDigest: 'old',
      createdAt: now,
      updatedAt: now,
    );

    expect(
      resource.copyWith(skillPackageDigest: 'new').skillPackageDigest,
      'new',
    );
    expect(
      resource.copyWith(skillPackageDigest: null).skillPackageDigest,
      isNull,
    );
  });

  test('agent session names are persisted and limited to seven characters', () {
    final DateTime now = DateTime.utc(2026, 8, 6);
    final Resource resource = Resource(
      id: 'session-name',
      type: ResourceType.prompt,
      title: 'Long title fallback',
      content: 'Prompt body',
      agentSessionName: '一二三四五六七八',
      createdAt: now,
      updatedAt: now,
    );

    expect(resource.agentSessionName, '一二三四五六七');
    expect(resource.toJson()['agentSessionName'], '一二三四五六七');
    expect(Resource.fromJson(resource.toJson()).agentSessionName, '一二三四五六七');
  });

  test('conversation visibility is persisted and can be turned back on', () {
    final DateTime now = DateTime.utc(2026, 8, 6);
    final Resource hidden = Resource(
      id: 'hidden-resource',
      type: ResourceType.skill,
      title: 'Hidden skill',
      content: '---\nname: hidden\ndescription: Hidden\n---\n\nUse it.',
      hideInAgentConversation: true,
      createdAt: now,
      updatedAt: now,
    );

    expect(hidden.toJson()['hideInAgentConversation'], isTrue);
    expect(Resource.fromJson(hidden.toJson()).hideInAgentConversation, isTrue);
    expect(
      hidden.copyWith(hideInAgentConversation: false).hideInAgentConversation,
      isFalse,
    );
  });
}
