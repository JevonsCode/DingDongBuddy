import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:path/path.dart' as path;

final class SkillPackageInstallResult {
  const SkillPackageInstallResult({
    required this.skillDocument,
    required this.directoryPath,
  });

  final String skillDocument;
  final String directoryPath;
}

abstract interface class SkillPackageInstaller {
  Future<SkillPackageInstallResult> install(Uri source);
}

/// Installs a complete GitHub Skill directory, including scripts, references,
/// assets and other sibling files. Downloads are staged and replaced atomically.
final class GitHubSkillPackageInstaller implements SkillPackageInstaller {
  GitHubSkillPackageInstaller(
    this.root, {
    HttpClient? client,
    this.loader,
    this.preferGit = true,
  }) : _client = client ?? HttpClient();

  final Directory root;
  final HttpClient _client;
  final Future<Uint8List> Function(Uri uri)? loader;
  final bool preferGit;

  @override
  Future<SkillPackageInstallResult> install(Uri source) async {
    final _GitHubSkillSource parsed = _GitHubSkillSource.parse(source);
    await root.create(recursive: true);
    final Directory staging = await root.createTemp('.install-');
    try {
      final bool cloned = preferGit && loader == null
          ? await _cloneDirectory(parsed, staging)
          : false;
      if (!cloned) {
        await _clearDirectory(staging);
        final _DownloadBudget budget = _DownloadBudget();
        await _downloadDirectory(parsed.contentsApiUri, staging, budget);
      }
      final File skillFile = File(path.join(staging.path, 'SKILL.md'));
      if (!await skillFile.exists()) {
        throw const FormatException(
          'The selected GitHub directory does not contain SKILL.md.',
        );
      }
      final String document = await skillFile.readAsString();
      final SkillConfiguration skill = SkillConfiguration.parseOnline(document);
      final Directory destination = Directory(path.join(root.path, skill.name));
      final Directory backup = Directory('${destination.path}.bak');
      if (await backup.exists()) {
        await backup.delete(recursive: true);
      }
      if (await destination.exists()) {
        await destination.rename(backup.path);
      }
      try {
        await staging.rename(destination.path);
        if (await backup.exists()) {
          await backup.delete(recursive: true);
        }
      } on Object {
        if (!await destination.exists() && await backup.exists()) {
          await backup.rename(destination.path);
        }
        rethrow;
      }
      return SkillPackageInstallResult(
        skillDocument: document,
        directoryPath: destination.path,
      );
    } on Object {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<bool> _cloneDirectory(
    _GitHubSkillSource source,
    Directory destination,
  ) async {
    final Directory workspace = await root.createTemp('.git-');
    final Directory repository = Directory(path.join(workspace.path, 'repo'));
    try {
      final List<String> arguments = <String>[
        'clone',
        '--depth',
        '1',
        '--filter=blob:none',
        '--single-branch',
        '--no-checkout',
        if (source.revision != null) ...<String>['--branch', source.revision!],
        source.cloneUri.toString(),
        repository.path,
      ];
      final ProcessResult result = await Process.run(
        'git',
        arguments,
        environment: <String, String>{
          ...Platform.environment,
          'GIT_TERMINAL_PROMPT': '0',
        },
      ).timeout(const Duration(seconds: 60));
      if (result.exitCode != 0) {
        return false;
      }
      if (source.directory.isNotEmpty) {
        final ProcessResult sparse = await _runGit(<String>[
          '-C',
          repository.path,
          'sparse-checkout',
          'set',
          '--',
          source.directory.join('/'),
        ]);
        if (sparse.exitCode != 0) {
          return false;
        }
      }
      final ProcessResult checkout = await _runGit(<String>[
        '-C',
        repository.path,
        'checkout',
      ]);
      if (checkout.exitCode != 0) {
        return false;
      }
      final Directory selected = source.directory.isEmpty
          ? repository
          : Directory(
              path.joinAll(<String>[repository.path, ...source.directory]),
            );
      if (!await selected.exists()) {
        return false;
      }
      await _copyPackageDirectory(
        selected,
        destination,
        excludeGitMetadata: source.directory.isEmpty,
        budget: _DownloadBudget(),
      );
      return true;
    } on Object {
      return false;
    } finally {
      if (await workspace.exists()) {
        await workspace.delete(recursive: true);
      }
    }
  }

  Future<ProcessResult> _runGit(List<String> arguments) {
    return Process.run(
      'git',
      arguments,
      environment: <String, String>{
        ...Platform.environment,
        'GIT_TERMINAL_PROMPT': '0',
      },
    ).timeout(const Duration(seconds: 60));
  }

  Future<void> _downloadDirectory(
    Uri apiUri,
    Directory destination,
    _DownloadBudget budget,
  ) async {
    final Object? decoded = jsonDecode(utf8.decode(await _get(apiUri, budget)));
    if (decoded is! List<Object?>) {
      throw const FormatException('GitHub did not return a Skill directory.');
    }
    for (final Object? value in decoded) {
      final Map<String, Object?> item = Map<String, Object?>.from(
        value! as Map,
      );
      final String name = (item['name'] as String? ?? '').trim();
      if (!_safeName(name)) {
        throw const FormatException('Skill package contains an unsafe path.');
      }
      final String type = item['type'] as String? ?? '';
      if (type == 'dir') {
        final Directory child = Directory(path.join(destination.path, name));
        await child.create(recursive: true);
        await _downloadDirectory(
          Uri.parse(item['url']! as String),
          child,
          budget,
        );
      } else if (type == 'file') {
        final String? downloadUrl = item['download_url'] as String?;
        if (downloadUrl == null || downloadUrl.isEmpty) {
          throw const FormatException('GitHub file has no download URL.');
        }
        final Uint8List bytes = await _get(Uri.parse(downloadUrl), budget);
        await File(
          path.join(destination.path, name),
        ).writeAsBytes(bytes, flush: true);
      } else {
        throw FormatException(
          'Skill package contains unsupported GitHub entry "$name" ($type).',
        );
      }
    }
  }

  Future<Uint8List> _get(Uri uri, _DownloadBudget budget) async {
    if (uri.scheme != 'https') {
      throw const FormatException('Skill downloads must use HTTPS.');
    }
    final Future<Uint8List> Function(Uri uri)? byteLoader = loader;
    if (byteLoader != null) {
      final Uint8List bytes = await byteLoader(uri);
      budget
        ..add(bytes.length)
        ..addFile();
      return bytes;
    }
    final HttpClientRequest request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'DingDong Skill Installer',
    );
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/vnd.github+json',
    );
    final HttpClientResponse response = await request.close().timeout(
      const Duration(seconds: 15),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      await response.drain<void>();
      throw HttpException(
        'GitHub returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    final BytesBuilder bytes = BytesBuilder(copy: false);
    await for (final List<int> chunk in response.timeout(
      const Duration(seconds: 15),
    )) {
      bytes.add(chunk);
      budget.add(chunk.length);
    }
    budget.addFile();
    return bytes.takeBytes();
  }
}

final class _GitHubSkillSource {
  const _GitHubSkillSource({
    required this.contentsApiUri,
    required this.cloneUri,
    required this.revision,
    required this.directory,
  });

  factory _GitHubSkillSource.parse(Uri source) {
    final List<String> parts = source.pathSegments;
    late String owner;
    late String repository;
    String? revision;
    late List<String> directory;
    if (source.host.toLowerCase() == 'github.com' && parts.length >= 2) {
      owner = parts[0];
      repository = parts[1].replaceFirst(RegExp(r'\.git$'), '');
      if (parts.length == 2) {
        directory = <String>[];
      } else {
        if (parts.length < 4) {
          throw const FormatException(
            'Use a GitHub Skill repository, folder, or SKILL.md link.',
          );
        }
        final String kind = parts[2];
        if (kind != 'tree' && kind != 'blob') {
          throw const FormatException(
            'Use a GitHub Skill repository, folder, or SKILL.md link.',
          );
        }
        revision = parts[3];
        directory = parts.skip(4).toList(growable: true);
        if (kind == 'blob') {
          if (directory.isEmpty || directory.last.toLowerCase() != 'skill.md') {
            throw const FormatException('GitHub file must be SKILL.md.');
          }
          directory.removeLast();
        }
      }
    } else if (source.host.toLowerCase() == 'raw.githubusercontent.com' &&
        parts.length >= 4 &&
        parts.last.toLowerCase() == 'skill.md') {
      owner = parts[0];
      repository = parts[1];
      revision = parts[2];
      directory = parts.sublist(3, parts.length - 1);
    } else {
      throw const FormatException(
        'Online Skills must use a GitHub folder or SKILL.md link.',
      );
    }
    final String contentsPath = directory.isEmpty
        ? '/repos/$owner/$repository/contents'
        : '/repos/$owner/$repository/contents/${directory.join('/')}';
    return _GitHubSkillSource(
      contentsApiUri: Uri.https(
        'api.github.com',
        contentsPath,
        revision == null ? null : <String, String>{'ref': revision},
      ),
      cloneUri: Uri.https('github.com', '/$owner/$repository.git'),
      revision: revision,
      directory: List<String>.unmodifiable(directory),
    );
  }

  final Uri contentsApiUri;
  final Uri cloneUri;
  final String? revision;
  final List<String> directory;
}

final class _DownloadBudget {
  int bytes = 0;
  int files = 0;

  void add(int count) {
    bytes += count;
    if (bytes > 25 * 1024 * 1024) {
      throw const FormatException('Skill package exceeds 25 MB.');
    }
  }

  void addFile() {
    files += 1;
    if (files > 600) {
      throw const FormatException('Skill package contains too many files.');
    }
  }
}

bool _safeName(String value) =>
    value.isNotEmpty &&
    value != '.' &&
    value != '..' &&
    !value.contains('/') &&
    !value.contains(r'\');

Future<void> _clearDirectory(Directory directory) async {
  await for (final FileSystemEntity entity in directory.list()) {
    await entity.delete(recursive: true);
  }
}

Future<void> _copyPackageDirectory(
  Directory source,
  Directory destination, {
  bool excludeGitMetadata = false,
  _DownloadBudget? budget,
}) async {
  await destination.create(recursive: true);
  await for (final FileSystemEntity entity in source.list(followLinks: false)) {
    final String name = path.basename(entity.path);
    if (excludeGitMetadata && name == '.git') {
      continue;
    }
    final String target = path.join(destination.path, name);
    if (entity is Directory) {
      await _copyPackageDirectory(entity, Directory(target), budget: budget);
    } else if (entity is File) {
      final int length = await entity.length();
      budget
        ?..add(length)
        ..addFile();
      await entity.copy(target);
    } else if (entity is Link) {
      throw const FormatException(
        'Skill packages with symbolic links are not supported.',
      );
    }
  }
}
