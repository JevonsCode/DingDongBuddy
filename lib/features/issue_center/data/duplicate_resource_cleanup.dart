import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/files/safe_managed_file.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/domain/issue_cleanup.dart';
import 'package:dingdong/features/library/data/agent_resource_synchronizer.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:path/path.dart' as path;

/// Deletes only a freshly verified duplicate. Agent/plugin Skill files remain
/// under their original owner's control; their DingDong copy can be removed.
final class DuplicateResourceCleanup {
  const DuplicateResourceCleanup({
    required this.resourceStore,
    required this.synchronizer,
    required this.backupDirectory,
  });

  final ResourceStore resourceStore;
  final AgentResourceSynchronizer synchronizer;
  final Directory backupDirectory;

  Future<IssueCleanupResult> resolve(
    AppIssue issue, {
    required bool backup,
    required IssueCleanupChoice choice,
  }) async {
    if (!issue.isDuplicateResource) {
      throw StateError(
        'This issue cannot be resolved by deleting a duplicate.',
      );
    }
    final ResourceStore store = resourceStore;
    if (store is ExclusiveResourceStore) {
      return (store as ExclusiveResourceStore).exclusiveMutation(
        () => _resolveLocked(issue, backup: backup, choice: choice),
      );
    }
    throw StateError('Resource cleanup requires a serialized resource store.');
  }

  Future<IssueCleanupResult> _resolveLocked(
    AppIssue issue, {
    required bool backup,
    required IssueCleanupChoice choice,
  }) async {
    final List<Resource> resources = await resourceStore.load();
    final List<AppIssue> current = await synchronizer.inspect(resources);
    if (!current.any(
      (AppIssue value) =>
          value.id == issue.id &&
          value.kind == issue.kind &&
          value.resourceId == issue.resourceId &&
          value.targetPath == issue.targetPath &&
          value.duplicateEntryName == issue.duplicateEntryName,
    )) {
      throw StateError('The duplicate changed. Check the issues again.');
    }
    Directory? saved;
    if (choice == IssueCleanupChoice.externalMcp) {
      await synchronizer.removeDuplicateMcp(
        issue,
        resources,
        beforeRemove: backup
            ? (ManagedFileSnapshot snapshot) async {
                saved = await _newBackup();
                await _writePrivate(
                  saved!,
                  'agent-config.json',
                  snapshot.contents,
                );
                await _writePrivate(
                  saved!,
                  'restore.txt',
                  'Original Agent configuration: ${issue.targetPath}\n'
                      'Removed MCP entry: ${issue.duplicateEntryName}\n'
                      'Restore only the named mcpServers entry from agent-config.json to the original file.\n'
                      'This local backup may contain credentials.\n',
                );
              }
            : null,
      );
    } else {
      final Resource resource = resources.singleWhere(
        (Resource resource) => resource.id == issue.resourceId,
      );
      // Synchronized removal also checks generated package directories by id.
      // Refuse malformed ids before that cleanup can resolve outside its root.
      _managedPackagePath(resource.id);
      if (backup) saved = await _backupResource(resource);
      await resourceStore.save(
        resources
            .where((Resource resource) => resource.id != issue.resourceId)
            .toList(growable: false),
      );
    }
    return IssueCleanupResult(backupPath: saved?.path);
  }

  Future<Directory> _newBackup() async {
    await backupDirectory.create(recursive: true);
    if (await FileSystemEntity.type(backupDirectory.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw FileSystemException(
        'Backup location must be a non-symlink directory',
        backupDirectory.path,
      );
    }
    final Directory folder = await backupDirectory.createTemp('duplicate-');
    await _privateMode(folder.path, '700');
    return folder;
  }

  Future<Directory> _backupResource(Resource resource) async {
    final Directory folder = await _newBackup();
    final Map<String, Object?> values = resource.toJson();
    String? originalPackage;
    if (resource.type == ResourceType.skill) {
      final List<String> candidates = <String>[
        if (resource.packagePath != null) resource.packagePath!,
        _managedPackagePath(resource.id),
        _managedPackagePath(
          SkillConfiguration.parseOnline(resource.content).name,
        ),
      ];
      for (final String candidate in candidates) {
        final FileSystemEntityType type = await FileSystemEntity.type(
          candidate,
          followLinks: false,
        );
        if (type == FileSystemEntityType.notFound) continue;
        if (type != FileSystemEntityType.directory) {
          throw FileSystemException(
            'Skill backup requires a non-symlink package',
            candidate,
          );
        }
        originalPackage = candidate;
        final Directory package = Directory(
          path.join(folder.path, 'skill-package'),
        );
        await _copyPackage(Directory(candidate), package);
        // The saved resource can be restored directly with its backed-up package.
        values['packagePath'] = package.path;
        break;
      }
      if (resource.packagePath != null && originalPackage == null) {
        throw FileSystemException(
          'Skill package is missing; cleanup was cancelled',
          resource.packagePath,
        );
      }
    }
    await _writePrivate(
      folder,
      'resource.json',
      '${const JsonEncoder.withIndent('  ').convert(values)}\n',
    );
    // The regular Import JSON flow resolves updateURL before importing. A
    // recovery snapshot must work offline and retain the saved package instead.
    final Map<String, Object?> localSnapshot = Map<String, Object?>.of(values)
      ..remove('updateURL');
    await _writePrivate(
      folder,
      'restore-bundle.json',
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'service': 'DingDongBuddy',
        'schemaVersion': 2,
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'items': <Object?>[localSnapshot],
      })}\n',
    );
    await _writePrivate(
      folder,
      'restore.txt',
      'Deleted DingDong resource: ${resource.title}\n'
          'Resource id: ${resource.id}\n'
          '${originalPackage == null ? '' : 'Original Skill package: $originalPackage\n'}'
          'To restore, use Import JSON in DingDong Resource Manager and select restore-bundle.json. Keep this backup folder in place: the imported Skill uses its complete skill-package directory.\n'
          'If you move this folder, update packagePath in restore-bundle.json before importing. Existing identical resources are skipped by Import JSON.\n'
          'The import bundle restores the saved local content without fetching online updates. The original updateURL, if any, is preserved in resource.json and can be re-added in the resource editor.\n'
          'This local backup may contain credentials.\n',
    );
    return folder;
  }

  String _managedPackagePath(String name) {
    final String root = path.normalize(synchronizer.packageRoot.absolute.path);
    final String candidate = path.normalize(path.join(root, name));
    if (name.contains('/') ||
        name.contains(r'\') ||
        !path.isWithin(root, candidate)) {
      throw const FormatException(
        'Resource package name must stay within the DingDong package directory.',
      );
    }
    return candidate;
  }

  Future<void> _copyPackage(Directory source, Directory destination) async {
    await destination.create();
    await _privateMode(destination.path, '700');
    await for (final FileSystemEntity entity in source.list(
      followLinks: false,
    )) {
      final String name = path.basename(entity.path);
      if (entity is Directory) {
        await _copyPackage(
          entity,
          Directory(path.join(destination.path, name)),
        );
      } else if (entity is File) {
        final File copy = await entity.copy(path.join(destination.path, name));
        // Preserve executable bits for recovery, while keeping the backup private.
        await _privateMode(
          copy.path,
          ((await entity.stat()).mode & 0x1C0).toRadixString(8),
        );
      } else {
        throw FileSystemException(
          'Skill backups cannot contain symbolic links',
          entity.path,
        );
      }
    }
  }

  Future<void> _writePrivate(Directory folder, String name, String contents) =>
      SafeManagedFile(
        File(path.join(folder.path, name)),
        newFileMode: 0x180,
      ).update((_) => contents).then((_) {});

  Future<void> _privateMode(String target, String mode) async {
    if (Platform.isWindows) return; // Local app-data inherits the user's ACL.
    final ProcessResult result = await Process.run('chmod', <String>[
      mode,
      target,
    ]);
    if (result.exitCode != 0) {
      throw FileSystemException('Could not protect local backup', target);
    }
  }
}
