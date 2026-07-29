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
}
