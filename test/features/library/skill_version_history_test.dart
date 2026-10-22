import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/skill_version_history.dart';
import 'package:dingdong/features/library/domain/skill_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temp;
  late SkillVersionHistory history;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('dingdong-version-history-');
    history = SkillVersionHistory(Directory('${temp.path}/history'));
  });
  tearDown(() => temp.deleteSync(recursive: true));

  test(
    'baseline, changes, no-op and restart keep immutable deduplicated snapshots',
    () async {
      final Resource first = _skill();
      await (await history.prepare([], [
        first,
      ], source: SkillVersionSource.initial)).commit();
      final Resource second = first.copyWith(content: 'second');
      await (await history.prepare([first], [second])).commit();
      await (await history.prepare(
        [second],
        [second.copyWith(note: 'note', usageCount: 5)],
      )).commit();
      history = SkillVersionHistory(history.root!);
      await (await history.prepare([second], [first])).commit();
      final List<SkillVersion> entries = await history.versions(first.id);
      expect(entries.map((SkillVersion version) => version.number), [1, 2, 3]);
      expect(entries.map((SkillVersion version) => version.source), [
        SkillVersionSource.initial,
        SkillVersionSource.manual,
        SkillVersionSource.manual,
      ]);
      expect(entries.first.snapshotId, entries.last.snapshotId);
      expect(
        Directory('${history.root!.path}/snapshots')
            .listSync()
            .whereType<File>()
            .where((File file) => file.path.endsWith('.json')),
        hasLength(2),
      );
    },
  );

  test(
    'failed multi-resource manifest commit restores every previous manifest',
    () async {
      final List<Resource> old = [_skill(), _skill(id: 'two')];
      await (await history.prepare(
        [],
        old,
        source: SkillVersionSource.initial,
      )).commit();
      final SkillVersionHistory failing = SkillVersionHistory(
        history.root!,
        beforeManifestWrite: (String id) async {
          if (id == 'two') {
            throw const FileSystemException('injected manifest failure');
          }
        },
      );
      final SkillHistoryTransaction transaction = await failing.prepare(
        old,
        old
            .map((Resource resource) => resource.copyWith(content: 'new'))
            .toList(),
      );
      await expectLater(
        transaction.commit(),
        throwsA(isA<FileSystemException>()),
      );
      expect(await history.versions('one'), hasLength(1));
      expect(await history.versions('two'), hasLength(1));
    },
  );

  test('binary bytes and empty directories survive materialization', () async {
    final Directory package = Directory('${temp.path}/package')..createSync();
    Directory('${package.path}/empty/nested').createSync(recursive: true);
    File('${package.path}/asset.bin').writeAsBytesSync([0, 255, 128, 1]);
    File('${package.path}/SKILL.md').writeAsStringSync('outdated');
    final SkillSnapshot captured = await history.capture(
      _skill(packagePath: package.path),
    );
    expect(captured.files['SKILL.md']!.text, 'first');
    final Directory restored = await history.materialize(captured);
    expect(File('${restored.path}/asset.bin').readAsBytesSync(), [
      0,
      255,
      128,
      1,
    ]);
    expect(Directory('${restored.path}/empty/nested').existsSync(), isTrue);
  });

  test(
    'unsafe identifiers, hash corruption, and valid-hash traversal fail closed',
    () async {
      await expectLater(history.versions(''), throwsFormatException);
      final Resource resource = _skill();
      await (await history.prepare([], [resource])).commit();
      final String id = (await history.versions(resource.id)).single.snapshotId;
      File('${history.root!.path}/snapshots/$id.json').writeAsStringSync('{}');
      await expectLater(history.snapshot(id), throwsFormatException);
      expect(await history.versions(resource.id), hasLength(1));
      final SkillSnapshot unsafe = SkillSnapshot(
        title: 'unsafe',
        document: '',
        sourceUrl: null,
        files: {'../escape': SkillVersionFile.text('bad')},
        hasPackage: true,
      );
      final String contents = jsonEncode(unsafe.toJson());
      final String unsafeId = sha256.convert(utf8.encode(contents)).toString();
      File(
        '${history.root!.path}/snapshots/$unsafeId.json',
      ).writeAsStringSync(contents);
      await expectLater(history.snapshot(unsafeId), throwsFormatException);
      expect(File('${temp.path}/escape').existsSync(), isFalse);
    },
  );

  test(
    'in-place package edits are online and document edits remain manual',
    () async {
      final Directory package = Directory('${temp.path}/package')..createSync();
      final File script = File('${package.path}/script.txt')
        ..writeAsStringSync('old');
      final Resource resource = _skill(packagePath: package.path);
      await (await history.prepare([], [
        resource,
      ], source: SkillVersionSource.initial)).commit();
      script.writeAsStringSync('new');
      await (await history.prepare([resource], [resource])).commit();
      final Resource manual = resource.copyWith(content: 'edited document');
      await (await history.prepare([resource], [manual])).commit();
      expect(
        (await history.versions(
          resource.id,
        )).map((SkillVersion entry) => entry.source),
        [
          SkillVersionSource.initial,
          SkillVersionSource.online,
          SkillVersionSource.manual,
        ],
      );
    },
  );

  test(
    'resource IDs remain data even for Unicode, traversal text, and long values',
    () async {
      for (final String id in <String>[
        '技能/../first',
        List<String>.filled(400, 'a').join(),
      ]) {
        final Resource resource = _skill(id: id);
        await (await history.prepare([], [resource])).commit();
        expect(await history.versions(id), hasLength(1));
      }
      expect(
        Directory('${history.root!.path}/manifests')
            .listSync()
            .whereType<File>()
            .where((File file) => file.path.endsWith('.json')),
        hasLength(2),
      );
    },
  );

  test(
    'executable bits and symlink rejection on POSIX',
    () async {
      final Directory package = Directory('${temp.path}/package')..createSync();
      final File script = File('${package.path}/run.sh')
        ..writeAsStringSync('#!/bin/sh\n');
      await Process.run('chmod', ['755', script.path]);
      final SkillSnapshot value = await history.capture(
        _skill(packagePath: package.path),
      );
      final Directory restored = await history.materialize(value);
      expect(
        (await File('${restored.path}/run.sh').stat()).mode & 0x49,
        isNot(0),
      );
      Link('${package.path}/link').createSync(script.path);
      await expectLater(
        history.capture(_skill(packagePath: package.path)),
        throwsA(isA<FileSystemException>()),
      );
    },
    skip: Platform.isWindows
        ? 'POSIX mode and symlinks require a POSIX host.'
        : false,
  );
}

Resource _skill({String id = 'one', String? packagePath}) => Resource(
  id: id,
  type: ResourceType.skill,
  title: 'Skill',
  content: 'first',
  packagePath: packagePath,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);
