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

      await repository.save(resources);
      expect((await repository.load()).single, resource);
    },
  );
}
