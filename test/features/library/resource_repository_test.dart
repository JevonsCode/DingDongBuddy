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
