import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:dingdong/features/library/domain/skill_package_digest.dart';
import 'package:path/path.dart' as path;

final class SkillPackageInstallResult {
  const SkillPackageInstallResult({
    required this.skillDocument,
    required this.directoryPath,
    this.packageDigest = '',
    this.createdArtifact = false,
    this.manifest = const <SkillPackageManifestEntry>[],
  });

  final String skillDocument;
  final String directoryPath;
  final String packageDigest;
  final bool createdArtifact;
  final List<SkillPackageManifestEntry> manifest;
}

final class SkillPackageManifestEntry {
  const SkillPackageManifestEntry({
    required this.relativePath,
    required this.executable,
    required this.size,
  });

  final String relativePath;
  final bool executable;
  final int size;
}

abstract interface class SkillPackageInstaller {
  Future<SkillPackageInstallResult> install(Uri source);
}

abstract interface class ResourceKeyedSkillPackageInstaller {
  Future<SkillPackageInstallResult> installForResource(
    Uri source, {
    required String resourceId,
  });

  Future<void> rollback(SkillPackageInstallResult result);
}

/// Parses an HTTPS URL, file URI, or absolute local Skill package path.
///
/// Absolute paths must be recognized before URI parsing because a Windows
/// drive letter (for example, `C:\Skills\reviewer`) otherwise looks like a URI
/// scheme.
Uri? parseSkillPackageSource(String source, {path.Context? pathContext}) {
  final String value = source.trim();
  if (value.isEmpty) {
    return null;
  }
  final path.Context context = pathContext ?? path.context;
  if (context.isAbsolute(value)) {
    return Uri.file(
      context.normalize(value),
      windows: context.style == path.Style.windows,
    );
  }
  return Uri.tryParse(value);
}

/// Returns the stable source identity used to make Skill installation
/// idempotent. Revisions identify artifacts, not separate logical Skills.
Future<String> skillPackageSourceKey(Uri source) async {
  if (source.scheme == 'file') {
    final String sourcePath = source.toFilePath();
    final String directoryPath =
        path.basename(sourcePath).toLowerCase() == 'skill.md'
        ? path.dirname(sourcePath)
        : sourcePath;
    String canonicalPath;
    try {
      canonicalPath = await Directory(directoryPath).resolveSymbolicLinks();
    } on FileSystemException {
      canonicalPath = path.normalize(path.absolute(directoryPath));
    }
    return Uri.file(canonicalPath, windows: Platform.isWindows).toString();
  }
  final _GitHubSkillSource parsed = _GitHubSkillSource.parse(source);
  final List<String> repositorySegments = parsed.cloneUri.pathSegments;
  if (repositorySegments.length != 2) {
    throw const FormatException('Invalid GitHub Skill repository path.');
  }
  final String repository = repositorySegments[1]
      .replaceFirst(RegExp(r'\.git$'), '')
      .toLowerCase();
  return Uri(
    scheme: 'github',
    host: 'github.com',
    pathSegments: <String>[
      repositorySegments[0].toLowerCase(),
      repository,
      ...parsed.directory,
    ],
  ).toString();
}

/// Installs a complete GitHub Skill directory, including scripts, references,
/// assets and other sibling files. Downloads are staged and replaced atomically.
final class GitHubSkillPackageInstaller
    implements SkillPackageInstaller, ResourceKeyedSkillPackageInstaller {
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
  Future<SkillPackageInstallResult> install(Uri source) =>
      _install(source, resourceId: null);

  @override
  Future<SkillPackageInstallResult> installForResource(
    Uri source, {
    required String resourceId,
  }) => _install(source, resourceId: resourceId);

  Future<SkillPackageInstallResult> _install(
    Uri source, {
    required String? resourceId,
  }) async {
    if (source.scheme == 'file') {
      return _installLocal(source, resourceId: resourceId);
    }
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
      SkillConfiguration.parseOnline(document);
      return _commitArtifact(staging, document, resourceId: resourceId);
    } on Object {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<SkillPackageInstallResult> _installLocal(
    Uri source, {
    String? resourceId,
  }) async {
    final String sourcePath = source.toFilePath();
    final FileSystemEntityType sourceType = await FileSystemEntity.type(
      sourcePath,
      followLinks: false,
    );
    final Directory sourceDirectory;
    if (sourceType == FileSystemEntityType.directory) {
      sourceDirectory = Directory(sourcePath);
    } else if (sourceType == FileSystemEntityType.file &&
        path.basename(sourcePath).toLowerCase() == 'skill.md') {
      sourceDirectory = File(sourcePath).parent;
    } else {
      throw const FormatException(
        'Local Skill source must be a directory or SKILL.md file.',
      );
    }
    await root.create(recursive: true);
    final Directory staging = await root.createTemp('.install-');
    try {
      await _copyPackageDirectory(
        sourceDirectory,
        staging,
        excludeGitMetadata: true,
        budget: _DownloadBudget(),
      );
      final File skillFile = File(path.join(staging.path, 'SKILL.md'));
      if (!await skillFile.exists()) {
        throw const FormatException(
          'The selected local directory does not contain SKILL.md.',
        );
      }
      final String document = await skillFile.readAsString();
      SkillConfiguration.parseOnline(document);
      return _commitArtifact(staging, document, resourceId: resourceId);
    } on Object {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<SkillPackageInstallResult> _commitArtifact(
    Directory staging,
    String document, {
    required String? resourceId,
  }) async {
    final _CanonicalSkillPackage package = await _canonicalPackage(staging);
    final String digest = package.digest;
    final String digestDirectoryName = digest.replaceFirst('sha256:', '');
    final String identity = _artifactIdentity(resourceId);
    final Directory parent = Directory(path.join(root.path, identity));
    final Directory destination = Directory(
      path.join(parent.path, digestDirectoryName),
    );
    if (await destination.exists()) {
      final String? existingDigest = await _readPackageDigest(destination);
      if (existingDigest == digest) {
        await staging.delete(recursive: true);
        return SkillPackageInstallResult(
          skillDocument: document,
          directoryPath: destination.path,
          packageDigest: digest,
          manifest: package.manifest,
        );
      }
      await _replaceCorruptedArtifact(
        staging: staging,
        destination: destination,
        expectedDigest: digest,
      );
      return SkillPackageInstallResult(
        skillDocument: document,
        directoryPath: destination.path,
        packageDigest: digest,
        manifest: package.manifest,
      );
    }
    await parent.create(recursive: true);
    try {
      await staging.rename(destination.path);
    } on Object {
      if (await destination.exists()) {
        await staging.delete(recursive: true);
        return SkillPackageInstallResult(
          skillDocument: document,
          directoryPath: destination.path,
          packageDigest: digest,
          manifest: package.manifest,
        );
      }
      rethrow;
    }
    return SkillPackageInstallResult(
      skillDocument: document,
      directoryPath: destination.path,
      packageDigest: digest,
      createdArtifact: true,
      manifest: package.manifest,
    );
  }

  Future<String?> _readPackageDigest(Directory directory) async {
    try {
      return (await _canonicalPackage(directory)).digest;
    } on Object {
      return null;
    }
  }

  Future<void> _replaceCorruptedArtifact({
    required Directory staging,
    required Directory destination,
    required String expectedDigest,
  }) async {
    final Directory reservedBackup = await destination.parent.createTemp(
      '.dingdong-corrupt-',
    );
    final String backupPath = reservedBackup.path;
    await reservedBackup.delete();
    final Directory backup = await destination.rename(backupPath);
    bool activated = false;
    try {
      await staging.rename(destination.path);
      activated = true;
      final String? installedDigest = await _readPackageDigest(destination);
      if (installedDigest != expectedDigest) {
        throw StateError('The repaired Skill artifact failed verification.');
      }
      await backup.delete(recursive: true);
    } on Object {
      if (activated && await destination.exists()) {
        await destination.delete(recursive: true);
      }
      if (await backup.exists() && !await destination.exists()) {
        await backup.rename(destination.path);
      }
      rethrow;
    }
  }

  @override
  Future<void> rollback(SkillPackageInstallResult result) async {
    if (!result.createdArtifact) {
      return;
    }
    final String rootPath = path.canonicalize(root.absolute.path);
    final String artifactPath = path.canonicalize(
      File(result.directoryPath).absolute.path,
    );
    if (!path.isWithin(rootPath, artifactPath) ||
        path.basename(artifactPath) !=
            result.packageDigest.replaceFirst('sha256:', '')) {
      throw StateError('Refusing to roll back an unmanaged Skill artifact.');
    }
    final Directory artifact = Directory(artifactPath);
    if (await artifact.exists()) {
      await artifact.delete(recursive: true);
    }
    final Directory parent = artifact.parent;
    if (path.isWithin(rootPath, parent.path) &&
        await parent.exists() &&
        await parent.list().isEmpty) {
      await parent.delete();
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
        if (kind == 'blob' &&
            directory.isNotEmpty &&
            directory.last.toLowerCase() == 'skill.md') {
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

String _artifactIdentity(String? resourceId) {
  final String? trimmed = resourceId?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return '.staged';
  }
  if (!_safeName(trimmed) ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(trimmed)) {
    throw const FormatException('Resource ID is not safe for Skill storage.');
  }
  return trimmed;
}

final class _CanonicalSkillPackage {
  const _CanonicalSkillPackage({required this.digest, required this.manifest});

  final String digest;
  final List<SkillPackageManifestEntry> manifest;
}

Future<_CanonicalSkillPackage> _canonicalPackage(Directory directory) async {
  final List<File> files = <File>[];
  await for (final FileSystemEntity entity in directory.list(
    recursive: true,
    followLinks: false,
  )) {
    if (entity is Link) {
      throw const FormatException(
        'Skill packages with symbolic links are not supported.',
      );
    }
    if (entity is File) {
      files.add(entity);
    }
  }
  files.sort((File left, File right) {
    final String leftPath = path
        .relative(left.path, from: directory.path)
        .replaceAll(path.separator, '/');
    final String rightPath = path
        .relative(right.path, from: directory.path)
        .replaceAll(path.separator, '/');
    return leftPath.compareTo(rightPath);
  });

  final List<SkillPackageManifestEntry> manifest =
      <SkillPackageManifestEntry>[];
  for (final File file in files) {
    final String relative = path
        .relative(file.path, from: directory.path)
        .replaceAll(path.separator, '/');
    final FileStat stat = await file.stat();
    final int executableBits = Platform.isWindows ? 0 : stat.mode & 0x49;
    manifest.add(
      SkillPackageManifestEntry(
        relativePath: relative,
        executable: executableBits != 0,
        size: stat.size,
      ),
    );
  }
  return _CanonicalSkillPackage(
    digest: await computeSkillPackageDigest(directory),
    manifest: List<SkillPackageManifestEntry>.unmodifiable(manifest),
  );
}

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
    if ((excludeGitMetadata && name == '.git') || name == '.dingdong-managed') {
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
      final int sourceMode = (await entity.stat()).mode;
      await entity.copy(target);
      if (!Platform.isWindows) {
        final int permissions = sourceMode & 0x1ff;
        final ProcessResult chmod = await Process.run('chmod', <String>[
          permissions.toRadixString(8),
          target,
        ]);
        if (chmod.exitCode != 0) {
          throw FileSystemException(
            'Could not preserve Skill file permissions.',
            target,
          );
        }
      }
    } else if (entity is Link) {
      throw const FormatException(
        'Skill packages with symbolic links are not supported.',
      );
    }
  }
}
