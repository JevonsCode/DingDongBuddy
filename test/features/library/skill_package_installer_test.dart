import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
      File('${result.directoryPath}/scripts/check.py').readAsStringSync(),
      'print("ok")',
    );
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
      File('${source.path}/SKILL.md')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '---\nname: reviewer\ndescription: Review changes\n---\n\n# Review',
        );
      File('${source.path}/scripts/check.py')
        ..createSync(recursive: true)
        ..writeAsStringSync('print("ok")');
      final GitHubSkillPackageInstaller installer = GitHubSkillPackageInstaller(
        root,
      );

      final SkillPackageInstallResult result = await installer.install(
        source.uri,
      );

      expect(result.directoryPath, '${root.path}/reviewer');
      expect(
        File('${result.directoryPath}/scripts/check.py').readAsStringSync(),
        'print("ok")',
      );
    },
  );
}
