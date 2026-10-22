import 'package:dingdong/features/library/domain/skill_version.dart';
import 'package:dingdong/features/library/domain/skill_version_diff.dart';
import 'package:flutter_test/flutter_test.dart';

SkillSnapshot snapshot(
  String document, {
  Map<String, SkillVersionFile> files = const <String, SkillVersionFile>{},
  List<String> directories = const <String>[],
  String title = 'test',
  String? sourceUrl,
}) => SkillSnapshot(
  title: title,
  document: document,
  sourceUrl: sourceUrl,
  files: files,
  directories: directories,
  hasPackage: files.isNotEmpty,
);

void main() {
  test(
    'document-only Skills compare both arbitrary directions with line numbers',
    () {
      final SkillSnapshot v1 = snapshot('first\nkeep\nlast\n');
      final SkillSnapshot v3 = snapshot('new\nkeep\nlast\nextra');
      final List<SkillLineChange> forward = SkillVersionDiff(
        v1,
        v3,
      ).files.single.lines;
      expect(forward.first.kind, SkillLineKind.removed);
      expect(forward.first.oldLine, 1);
      expect(forward[1].kind, SkillLineKind.added);
      expect(forward[1].newLine, 1);
      expect(forward.last.text, 'extra');
      expect(forward.last.hasNewline, isFalse);
      final List<SkillLineChange> reversed = SkillVersionDiff(
        v3,
        v1,
      ).files.single.lines;
      expect(reversed.first.text, 'new\n');
      expect(reversed.last.kind, SkillLineKind.removed);
      expect(SkillVersionDiff(v1, v1).isEmpty, isTrue);
    },
  );

  test(
    'package files, binary, directories and executable changes are visible',
    () {
      final SkillSnapshot a = snapshot(
        'body',
        files: <String, SkillVersionFile>{
          'removed.txt': SkillVersionFile.text('bye'),
          'run.sh': SkillVersionFile.text('echo hi\n'),
          'image.bin': SkillVersionFile(bytes: <int>[0, 1]),
        },
        directories: <String>['empty'],
      );
      final SkillSnapshot b = snapshot(
        'body',
        files: <String, SkillVersionFile>{
          'added.txt': SkillVersionFile.text('hello'),
          'run.sh': SkillVersionFile(
            bytes: <int>[101, 99, 104, 111, 32, 104, 105, 10],
            executable: true,
          ),
          'image.bin': SkillVersionFile(bytes: <int>[0, 2]),
        },
      );
      final Map<String, SkillFileDiff> diff = <String, SkillFileDiff>{
        for (final SkillFileDiff file in SkillVersionDiff(a, b).files)
          file.path: file,
      };
      expect(diff['removed.txt']!.kind, SkillChangeKind.removed);
      expect(diff['added.txt']!.kind, SkillChangeKind.added);
      expect(diff['image.bin']!.binary, isTrue);
      expect(diff['image.bin']!.lines, isEmpty);
      expect(diff['run.sh']!.permissionsChanged, isTrue);
      expect(diff['run.sh']!.lines.single.kind, SkillLineKind.context);
      expect(diff['empty']!.directory, isTrue);
      expect(diff['empty']!.kind, SkillChangeKind.removed);
    },
  );

  test(
    'empty file addition is distinct from missing file and metadata compares',
    () {
      final SkillVersionDiff diff = SkillVersionDiff(
        snapshot(''),
        snapshot(
          '',
          files: <String, SkillVersionFile>{
            'empty.txt': SkillVersionFile.text(''),
          },
          title: 'renamed',
          sourceUrl: 'https://example.com/skill',
        ),
      );
      expect(diff.files.single.kind, SkillChangeKind.added);
      expect(diff.files.single.lines, isEmpty);
      expect(diff.titleChanged, isTrue);
      expect(diff.sourceChanged, isTrue);
      expect(diff.packageChanged, isTrue);
    },
  );

  test(
    'trailing newline changes and resource document override are retained',
    () {
      final SkillVersionDiff diff = SkillVersionDiff(
        snapshot('same\n'),
        snapshot(
          'same',
          files: <String, SkillVersionFile>{
            'SKILL.md': SkillVersionFile.text('stale package document'),
          },
        ),
      );
      expect(diff.files.single.path, 'SKILL.md');
      expect(
        diff.files.single.lines.map((SkillLineChange line) => line.kind),
        <SkillLineKind>[SkillLineKind.removed, SkillLineKind.added],
      );
      expect(diff.files.single.lines.last.displayText, 'same');
    },
  );

  test('large comparison bounds work and exposes whole-file fallback', () {
    final SkillVersionDiff diff = SkillVersionDiff(
      snapshot(List<String>.filled(600, 'before').join('\n')),
      snapshot(List<String>.filled(600, 'after').join('\n')),
    );
    expect(diff.files.single.simplified, isTrue);
    expect(diff.files.single.lines, hasLength(1200));
  });
}
