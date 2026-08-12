import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('parses a Windows drive path before treating it as a URI', () {
    final path.Context windows = path.Context(style: path.Style.windows);

    final Uri? source = parseSkillPackageSource(
      r'C:\Users\tester\Skills\reviewer\SKILL.md',
      pathContext: windows,
    );

    expect(source?.scheme, 'file');
    expect(
      source?.toFilePath(windows: true),
      r'C:\Users\tester\Skills\reviewer\SKILL.md',
    );
  });

  test('canonical source key folds GitHub URL forms and revisions', () async {
    final String tree = await skillPackageSourceKey(
      Uri.parse('https://github.com/Acme/Skills/tree/main/skills/reviewer'),
    );
    final String blob = await skillPackageSourceKey(
      Uri.parse(
        'https://github.com/acme/skills/blob/v2/skills/reviewer/SKILL.md',
      ),
    );
    final String raw = await skillPackageSourceKey(
      Uri.parse(
        'https://raw.githubusercontent.com/acme/skills/commit/skills/reviewer/SKILL.md',
      ),
    );

    expect(blob, tree);
    expect(raw, tree);
    expect(tree, 'github://github.com/acme/skills/skills/reviewer');
  });

  test(
    'canonical source key resolves a local Skill to its directory',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-skill-source-key-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final File skill = File(path.join(temp.path, 'SKILL.md'))
        ..writeAsStringSync('---\nname: probe\ndescription: Probe\n---\n');

      expect(
        await skillPackageSourceKey(skill.uri),
        await skillPackageSourceKey(temp.uri),
      );
    },
  );

  test('installs the complete GitHub Skill directory', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'dingdong-skill-package-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final Uri source = Uri.parse(
      'https://github.com/acme/skills/tree/main/skills/reviewer',
    );
    final Uri api = Uri.parse(
      'https://api.github.com/repos/acme/skills/contents/skills/reviewer?ref=main',
    );
    final Uri scriptsApi = Uri.parse(
      'https://api.github.com/repos/acme/skills/contents/skills/reviewer/scripts?ref=main',
    );
    final Map<Uri, List<int>> responses = <Uri, List<int>>{
      api: utf8.encode(
        jsonEncode(<Object?>[
          <String, Object?>{
            'name': 'SKILL.md',
            'type': 'file',
            'download_url': 'https://raw.githubusercontent.com/skill.md',
          },
          <String, Object?>{
            'name': 'scripts',
            'type': 'dir',
            'url': scriptsApi.toString(),
          },
        ]),
      ),
      scriptsApi: utf8.encode(
        jsonEncode(<Object?>[
          <String, Object?>{
            'name': 'check.py',
            'type': 'file',
            'download_url': 'https://raw.githubusercontent.com/check.py',
          },
        ]),
      ),
      Uri.parse('https://raw.githubusercontent.com/skill.md'): utf8.encode(
        '---\nname: reviewer\ndescription: Review changes\n---\n\n# Review',
      ),
      Uri.parse('https://raw.githubusercontent.com/check.py'): utf8.encode(
        'print("ok")',
      ),
    };
    final GitHubSkillPackageInstaller installer = GitHubSkillPackageInstaller(
      root,
      loader: (Uri uri) async => Uint8List.fromList(responses[uri]!),
      preferGit: false,
    );

    final SkillPackageInstallResult result = await installer.install(source);

    expect(result.skillDocument, contains('name: reviewer'));
    expect(
      File(
        path.join(result.directoryPath, 'scripts', 'check.py'),
      ).readAsStringSync(),
      'print("ok")',
    );
  });

  test('accepts a GitHub blob URL that resolves to a Skill directory', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'dingdong-skill-package-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final Uri source = Uri.parse(
      'https://github.com/mattpocock/skills/blob/main/skills/productivity/grilling',
    );
    final Uri api = Uri.parse(
      'https://api.github.com/repos/mattpocock/skills/contents/skills/productivity/grilling?ref=main',
    );
    final Map<Uri, List<int>> responses = <Uri, List<int>>{
      api: utf8.encode(
        jsonEncode(<Object?>[
          <String, Object?>{
            'name': 'SKILL.md',
            'type': 'file',
            'download_url':
                'https://raw.githubusercontent.com/mattpocock/skills/main/skills/productivity/grilling/SKILL.md',
          },
        ]),
      ),
      Uri.parse(
        'https://raw.githubusercontent.com/mattpocock/skills/main/skills/productivity/grilling/SKILL.md',
      ): utf8.encode(
        '---\nname: grilling\ndescription: Stress-test decisions\n---\n\n# Grilling',
      ),
    };
    final List<Uri> requested = <Uri>[];
    final GitHubSkillPackageInstaller installer = GitHubSkillPackageInstaller(
      root,
      loader: (Uri uri) async {
        requested.add(uri);
        return Uint8List.fromList(responses[uri]!);
      },
      preferGit: false,
    );

    final SkillPackageInstallResult result = await installer.install(source);

    expect(result.skillDocument, contains('name: grilling'));
    expect(requested.first, api);
  });

  test(
    'imports a complete local Skill directory into managed storage',
    () async {
      final Directory root = Directory.systemTemp.createTempSync(
        'dingdong-skill-package-',
      );
      final Directory source = Directory.systemTemp.createTempSync(
        'dingdong-local-skill-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      addTearDown(() => source.deleteSync(recursive: true));
      File(path.join(source.path, 'SKILL.md'))
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '---\nname: reviewer\ndescription: Review changes\n---\n\n# Review',
        );
      File(path.join(source.path, 'scripts', 'check.py'))
        ..createSync(recursive: true)
        ..writeAsStringSync('print("ok")');
      final GitHubSkillPackageInstaller installer = GitHubSkillPackageInstaller(
        root,
      );

      final SkillPackageInstallResult result = await installer.install(
        source.uri,
      );

      expect(
        result.directoryPath,
        path.join(
          root.path,
          '.staged',
          result.packageDigest.replaceFirst('sha256:', ''),
        ),
      );
      expect(
        File(
          path.join(result.directoryPath, 'scripts', 'check.py'),
        ).readAsStringSync(),
        'print("ok")',
      );
    },
  );

  test('stores a package by resource identity and canonical digest', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'dingdong-skill-package-',
    );
    final Directory source = Directory.systemTemp.createTempSync(
      'dingdong-local-skill-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    addTearDown(() => source.deleteSync(recursive: true));
    File(path.join(source.path, 'SKILL.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '---\nname: reviewer\ndescription: Review changes\n---\n\n# Review',
      );
    File(path.join(source.path, 'scripts', 'check.sh'))
      ..createSync(recursive: true)
      ..writeAsStringSync('#!/bin/sh\necho ok\n')
      ..setLastModifiedSync(DateTime.utc(2026, 1, 1));
    if (!Platform.isWindows) {
      await Process.run('chmod', <String>[
        '755',
        path.join(source.path, 'scripts', 'check.sh'),
      ]);
    }
    final GitHubSkillPackageInstaller installer = GitHubSkillPackageInstaller(
      root,
    );

    final SkillPackageInstallResult result = await installer.installForResource(
      source.uri,
      resourceId: 'resource-123',
    );

    expect(result.packageDigest, matches(RegExp(r'^sha256:[0-9a-f]{64}$')));
    expect(
      result.directoryPath,
      path.join(
        root.path,
        'resource-123',
        result.packageDigest.replaceFirst('sha256:', ''),
      ),
    );
    expect(result.createdArtifact, isTrue);
    expect(
      result.manifest
          .map(
            (SkillPackageManifestEntry entry) => <Object?>[
              entry.relativePath,
              entry.executable,
              entry.size,
            ],
          )
          .toList(),
      <List<Object?>>[
        <Object?>['SKILL.md', false, 60],
        <Object?>['scripts/check.sh', !Platform.isWindows, 18],
      ],
    );
    expect(
      FileStat.statSync(
            path.join(result.directoryPath, 'scripts', 'check.sh'),
          ).mode &
          0x49,
      Platform.isWindows ? anything : 0x49,
    );
  });

  test('reinstalling the same resource and digest is idempotent', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'dingdong-skill-package-',
    );
    final Directory source = Directory.systemTemp.createTempSync(
      'dingdong-local-skill-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    addTearDown(() => source.deleteSync(recursive: true));
    File(path.join(source.path, 'SKILL.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '---\nname: reviewer\ndescription: Review changes\n---\n\n# Review',
      );
    final GitHubSkillPackageInstaller installer = GitHubSkillPackageInstaller(
      root,
    );

    final SkillPackageInstallResult first = await installer.installForResource(
      source.uri,
      resourceId: 'resource-123',
    );
    final SkillPackageInstallResult second = await installer.installForResource(
      source.uri,
      resourceId: 'resource-123',
    );

    expect(second.directoryPath, first.directoryPath);
    expect(second.packageDigest, first.packageDigest);
    expect(first.createdArtifact, isTrue);
    expect(second.createdArtifact, isFalse);
  });

  test('reinstall repairs a corrupted immutable artifact', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'dingdong-skill-package-',
    );
    final Directory source = Directory.systemTemp.createTempSync(
      'dingdong-local-skill-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    addTearDown(() => source.deleteSync(recursive: true));
    File(path.join(source.path, 'SKILL.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '---\nname: reviewer\ndescription: Review changes\n---\n\n# Review',
      );
    File(path.join(source.path, 'scripts', 'check.sh'))
      ..createSync(recursive: true)
      ..writeAsStringSync('echo original\n');
    final GitHubSkillPackageInstaller installer = GitHubSkillPackageInstaller(
      root,
    );
    final SkillPackageInstallResult first = await installer.installForResource(
      source.uri,
      resourceId: 'resource-123',
    );
    final File installedScript = File(
      path.join(first.directoryPath, 'scripts', 'check.sh'),
    )..writeAsStringSync('echo corrupted\n');

    final SkillPackageInstallResult repaired = await installer
        .installForResource(source.uri, resourceId: 'resource-123');

    expect(repaired.directoryPath, first.directoryPath);
    expect(repaired.packageDigest, first.packageDigest);
    expect(repaired.createdArtifact, isFalse);
    expect(installedScript.readAsStringSync(), 'echo original\n');
  });

  test(
    'canonical digest changes for content or executable-bit changes only',
    () async {
      final Directory root = Directory.systemTemp.createTempSync(
        'dingdong-skill-package-',
      );
      final Directory source = Directory.systemTemp.createTempSync(
        'dingdong-local-skill-',
      );
      addTearDown(() => root.deleteSync(recursive: true));
      addTearDown(() => source.deleteSync(recursive: true));
      final File skill = File(path.join(source.path, 'SKILL.md'))
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '---\nname: reviewer\ndescription: Review changes\n---\n\n# Review',
        );
      final File script = File(path.join(source.path, 'scripts', 'check.sh'))
        ..createSync(recursive: true)
        ..writeAsStringSync('echo ok\n');
      final GitHubSkillPackageInstaller installer = GitHubSkillPackageInstaller(
        root,
      );

      final SkillPackageInstallResult first = await installer
          .installForResource(source.uri, resourceId: 'resource-a');
      skill.setLastModifiedSync(DateTime.utc(2030));
      script.setLastModifiedSync(DateTime.utc(2030));
      final SkillPackageInstallResult timestampOnly = await installer
          .installForResource(source.uri, resourceId: 'resource-b');
      expect(timestampOnly.packageDigest, first.packageDigest);

      script.writeAsStringSync('echo changed\n');
      final SkillPackageInstallResult contentChanged = await installer
          .installForResource(source.uri, resourceId: 'resource-c');
      expect(contentChanged.packageDigest, isNot(first.packageDigest));

      if (!Platform.isWindows) {
        script.writeAsStringSync('echo ok\n');
        await Process.run('chmod', <String>['755', script.path]);
        final SkillPackageInstallResult modeChanged = await installer
            .installForResource(source.uri, resourceId: 'resource-d');
        expect(modeChanged.packageDigest, isNot(first.packageDigest));
      }
    },
  );

  test('rollback removes only an artifact created by this install', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'dingdong-skill-package-',
    );
    final Directory source = Directory.systemTemp.createTempSync(
      'dingdong-local-skill-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    addTearDown(() => source.deleteSync(recursive: true));
    File(path.join(source.path, 'SKILL.md'))
      ..createSync(recursive: true)
      ..writeAsStringSync(
        '---\nname: reviewer\ndescription: Review changes\n---\n\n# Review',
      );
    final GitHubSkillPackageInstaller installer = GitHubSkillPackageInstaller(
      root,
    );
    final SkillPackageInstallResult created = await installer
        .installForResource(source.uri, resourceId: 'resource-123');
    final SkillPackageInstallResult reused = await installer.installForResource(
      source.uri,
      resourceId: 'resource-123',
    );

    await installer.rollback(reused);
    expect(Directory(created.directoryPath).existsSync(), isTrue);

    await installer.rollback(created);
    expect(Directory(created.directoryPath).existsSync(), isFalse);
  });
}
