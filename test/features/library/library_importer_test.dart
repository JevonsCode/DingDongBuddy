import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/domain/library_importer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('dingdong-import-test');
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test(
    'prompt import reads supported text files and skips duplicates',
    () async {
      await File('${root.path}/review.md').writeAsString('Review carefully');
      await File('${root.path}/ignore.png').writeAsBytes(<int>[1, 2, 3]);
      final DateTime now = DateTime.utc(2026, 7, 12);

      final result =
          await LibraryImporter(
            idGenerator: () => 'prompt-1',
            now: () => now,
          ).scan(
            LibraryImportRequest(type: ResourceType.prompt, path: root.path),
            existing: <Resource>[
              Resource(
                id: 'existing',
                type: ResourceType.prompt,
                title: 'Existing',
                content: 'Other content',
                createdAt: now,
                updatedAt: now,
              ),
            ],
          );

      expect(result.scannedCount, 2);
      expect(result.skippedCount, 1);
      expect(result.imported.single.title, 'review');
      expect(result.imported.single.content, 'Review carefully');
    },
  );

  test('skill import recognizes directories containing SKILL.md', () async {
    final Directory skill = Directory('${root.path}/release-skill');
    await skill.create();
    await File('${skill.path}/SKILL.md').writeAsString('# Release');

    final result = await LibraryImporter(idGenerator: () => 'skill-1').scan(
      LibraryImportRequest(type: ResourceType.skill, path: root.path),
      existing: const <Resource>[],
    );

    expect(result.imported.single.type, ResourceType.skill);
    expect(
      path.equals(result.imported.single.content, skill.absolute.path),
      isTrue,
    );
  });
}
