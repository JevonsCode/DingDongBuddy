import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dingdong/features/library/domain/skill_deployment_plan.dart';
import 'package:path/path.dart' as path;

/// Computes the canonical immutable identity shared by package installation
/// and native deployment verification.
Future<String> computeSkillPackageDigest(Directory root) async {
  final List<FileSystemEntity> entities = await root
      .list(recursive: true, followLinks: false)
      .toList();
  entities.sort(
    (FileSystemEntity left, FileSystemEntity right) => path
        .relative(left.path, from: root.path)
        .compareTo(path.relative(right.path, from: root.path)),
  );
  final StringBuffer manifest = StringBuffer('dingdong-skill-package-v1\n');
  for (final FileSystemEntity entity in entities) {
    final String relative = path
        .relative(entity.path, from: root.path)
        .replaceAll(path.separator, '/');
    if (relative == skillDeploymentReceiptFileName) {
      continue;
    }
    final FileSystemEntityType type = await FileSystemEntity.type(
      entity.path,
      followLinks: false,
    );
    switch (type) {
      case FileSystemEntityType.directory:
        manifest.writeln('D\u0000$relative');
      case FileSystemEntityType.file:
        final File file = File(entity.path);
        final Hash hash = await Sha256().hash(await file.readAsBytes());
        final FileStat stat = await file.stat();
        final bool executable = !Platform.isWindows && stat.mode & 0x49 != 0;
        manifest.writeln(
          'F\u0000$relative\u0000${_hex(hash.bytes)}\u0000${executable ? 1 : 0}',
        );
      case FileSystemEntityType.link:
        throw FileSystemException(
          'Symbolic links are not allowed in a Skill package.',
          entity.path,
        );
      case FileSystemEntityType.notFound:
      case FileSystemEntityType.pipe:
      case FileSystemEntityType.unixDomainSock:
        throw FileSystemException(
          'Unsupported entry in Skill package.',
          entity.path,
        );
    }
  }
  final Hash digest = await Sha256().hash(utf8.encode(manifest.toString()));
  return 'sha256:${_hex(digest.bytes)}';
}

String _hex(List<int> bytes) =>
    bytes.map((int value) => value.toRadixString(16).padLeft(2, '0')).join();
