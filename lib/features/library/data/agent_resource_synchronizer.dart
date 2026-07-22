import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/library/data/agent_skill_catalog.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resources.dart';
import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:path/path.dart' as path;

enum AgentMcpConfigKind {
  codexToml,
  claudeJson,
  cursorJson,
  geminiJson,
  kiroJson,
}

final class AgentPromptTarget {
  const AgentPromptTarget(
    this.file, {
    this.includeBridgeRoutingInstructions = true,
    this.clientName = 'Agent',
  });

  final File file;
  final bool includeBridgeRoutingInstructions;
  final String clientName;
}

final class AgentMcpTarget {
  const AgentMcpTarget(this.file, this.kind, {this.clientName = 'Agent'});

  final File file;
  final AgentMcpConfigKind kind;
  final String clientName;
}

/// Data-driven native locations for one supported Agent client.
final class AgentClientAdapter {
  const AgentClientAdapter({
    required this.id,
    required this.displayName,
    required this.homeMarker,
    required this.globalSkillPath,
    required this.projectSkillPath,
    required this.mcpPath,
    required this.mcpKind,
    this.promptPath,
    this.includeBridgeRoutingInstructions = true,
  });

  final String id;
  final String displayName;
  final String homeMarker;
  final List<String> globalSkillPath;
  final List<String> projectSkillPath;
  final List<String> mcpPath;
  final AgentMcpConfigKind mcpKind;
  final List<String>? promptPath;
  final bool includeBridgeRoutingInstructions;

  bool isInstalled(String home) =>
      Directory(path.join(home, homeMarker)).existsSync();

  Directory globalSkillDirectory(String home) =>
      Directory(path.joinAll(<String>[home, ...globalSkillPath]));

  String get projectSkillRoot => path.joinAll(projectSkillPath);

  File mcpFile(String home) => File(path.joinAll(<String>[home, ...mcpPath]));

  File? promptFile(String home) => promptPath == null
      ? null
      : File(path.joinAll(<String>[home, ...promptPath!]));
}

const List<AgentClientAdapter> builtInAgentClientAdapters =
    <AgentClientAdapter>[
      AgentClientAdapter(
        id: 'codex',
        displayName: 'Codex',
        homeMarker: '.codex',
        globalSkillPath: <String>['.agents', 'skills'],
        projectSkillPath: <String>['.agents', 'skills'],
        promptPath: <String>['.codex', 'AGENTS.md'],
        mcpPath: <String>['.codex', 'config.toml'],
        mcpKind: AgentMcpConfigKind.codexToml,
      ),
      AgentClientAdapter(
        id: 'claude-code',
        displayName: 'Claude Code',
        homeMarker: '.claude',
        globalSkillPath: <String>['.claude', 'skills'],
        projectSkillPath: <String>['.claude', 'skills'],
        promptPath: <String>['.claude', 'CLAUDE.md'],
        includeBridgeRoutingInstructions: false,
        mcpPath: <String>['.claude.json'],
        mcpKind: AgentMcpConfigKind.claudeJson,
      ),
      AgentClientAdapter(
        id: 'cursor',
        displayName: 'Cursor',
        homeMarker: '.cursor',
        globalSkillPath: <String>['.cursor', 'skills'],
        projectSkillPath: <String>['.cursor', 'skills'],
        mcpPath: <String>['.cursor', 'mcp.json'],
        mcpKind: AgentMcpConfigKind.cursorJson,
      ),
      AgentClientAdapter(
        id: 'gemini',
        displayName: 'Gemini CLI',
        homeMarker: '.gemini',
        globalSkillPath: <String>['.gemini', 'skills'],
        projectSkillPath: <String>['.gemini', 'skills'],
        mcpPath: <String>['.gemini', 'settings.json'],
        mcpKind: AgentMcpConfigKind.geminiJson,
      ),
      AgentClientAdapter(
        id: 'kiro',
        displayName: 'Kiro',
        homeMarker: '.kiro',
        globalSkillPath: <String>['.kiro', 'skills'],
        projectSkillPath: <String>['.kiro', 'skills'],
        mcpPath: <String>['.kiro', 'settings', 'mcp.json'],
        mcpKind: AgentMcpConfigKind.kiroJson,
      ),
    ];

/// Makes DingDong's enabled state concrete in supported Agent clients.
/// Skills are mirrored as complete packages; MCP resources become real client
/// configuration entries. Only DingDong-marked files and entries are removed.
final class AgentResourceSynchronizer {
  AgentResourceSynchronizer({
    required this.packageRoot,
    required this.skillRoots,
    this.projectSkillRoots = const <String>[],
    required this.mcpTargets,
    this.promptTargets = const <AgentPromptTarget>[],
    this.skillClientNames = const <String, String>{},
    this.projectSkillClientNames = const <String, String>{},
    this.externalSkillCatalogs = const <AgentSkillCatalog>[],
    File? managedStateFile,
    SkillPackageInstaller? skillPackageInstaller,
  }) : managedStateFile =
           managedStateFile ??
           File(path.join(packageRoot.parent.path, 'agent-sync-state.json')),
       skillPackageInstaller =
           skillPackageInstaller ?? GitHubSkillPackageInstaller(packageRoot);

  factory AgentResourceSynchronizer.currentUser(
    Directory packageRoot, {
    SkillPackageInstaller? skillPackageInstaller,
    String? homeDirectory,
  }) {
    final String home =
        homeDirectory ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE']!;
    final List<AgentClientAdapter> installed = builtInAgentClientAdapters
        .where((AgentClientAdapter adapter) => adapter.isInstalled(home))
        .toList(growable: false);
    final List<Directory> skills = installed
        .map((AgentClientAdapter adapter) => adapter.globalSkillDirectory(home))
        .toList(growable: false);
    final List<String> projectSkills = installed
        .map((AgentClientAdapter adapter) => adapter.projectSkillRoot)
        .toList(growable: false);
    final List<AgentPromptTarget> prompts = installed
        .map((AgentClientAdapter adapter) {
          final File? file = adapter.promptFile(home);
          return file == null
              ? null
              : AgentPromptTarget(
                  file,
                  includeBridgeRoutingInstructions:
                      adapter.includeBridgeRoutingInstructions,
                  clientName: adapter.displayName,
                );
        })
        .whereType<AgentPromptTarget>()
        .toList(growable: false);
    final List<AgentMcpTarget> mcps = installed
        .map(
          (AgentClientAdapter adapter) => AgentMcpTarget(
            adapter.mcpFile(home),
            adapter.mcpKind,
            clientName: adapter.displayName,
          ),
        )
        .toList(growable: false);
    final List<AgentSkillCatalog> externalSkills = <AgentSkillCatalog>[
      if (installed.any(
        (AgentClientAdapter adapter) => adapter.id == 'claude-code',
      ))
        ClaudeCodePluginSkillCatalog(
          settingsFile: File(path.join(home, '.claude', 'settings.json')),
          installedPluginsFile: File(
            path.join(home, '.claude', 'plugins', 'installed_plugins.json'),
          ),
        ),
    ];
    return AgentResourceSynchronizer(
      packageRoot: packageRoot,
      skillRoots: skills,
      projectSkillRoots: projectSkills,
      promptTargets: prompts,
      mcpTargets: mcps,
      skillClientNames: <String, String>{
        for (final AgentClientAdapter adapter in installed)
          path.normalize(adapter.globalSkillDirectory(home).path):
              adapter.displayName,
      },
      projectSkillClientNames: <String, String>{
        for (final AgentClientAdapter adapter in installed)
          path.normalize(adapter.projectSkillRoot): adapter.displayName,
      },
      externalSkillCatalogs: externalSkills,
      skillPackageInstaller: skillPackageInstaller,
    );
  }

  final Directory packageRoot;
  final List<Directory> skillRoots;
  final List<String> projectSkillRoots;
  final List<AgentPromptTarget> promptTargets;
  final List<AgentMcpTarget> mcpTargets;
  final Map<String, String> skillClientNames;
  final Map<String, String> projectSkillClientNames;
  final List<AgentSkillCatalog> externalSkillCatalogs;
  final File managedStateFile;
  final SkillPackageInstaller skillPackageInstaller;

  Future<List<AppIssue>> sync(List<Resource> resources) async {
    final List<Resource> prompts = resources
        .where(
          (Resource item) => item.enabled && item.type == ResourceType.prompt,
        )
        .toList(growable: false);
    final List<Resource> skills = resources
        .where(
          (Resource item) => item.enabled && item.type == ResourceType.skill,
        )
        .toList(growable: false);
    final List<Resource> mcps = resources
        .where((Resource item) => item.enabled && item.type == ResourceType.mcp)
        .toList(growable: false);
    final List<AppIssue> issues = await inspect(resources);
    final List<AppIssue> blockingIssues = issues
        .where((AppIssue issue) => issue.severity == AppIssueSeverity.error)
        .toList(growable: false);
    if (blockingIssues.isNotEmpty) {
      throw AppIssueException(blockingIssues);
    }
    final Map<String, Set<String>> managed = await _readManagedMcpState();
    final Set<String> previousProjectSkillRoots =
        managed.remove(_managedProjectSkillRootsStateKey) ?? <String>{};
    for (final AgentPromptTarget target in promptTargets) {
      await _syncPrompts(
        target.file,
        prompts,
        includeBridgeRoutingInstructions:
            target.includeBridgeRoutingInstructions,
      );
    }
    final List<Resource> globalSkills = skills
        .where((Resource resource) => resource.skillProjectPaths.isEmpty)
        .toList(growable: false);
    for (final Directory root in skillRoots) {
      await _syncSkills(root, globalSkills);
    }
    final Map<String, List<Resource>> projectSkillsByRoot =
        <String, List<Resource>>{};
    for (final Resource resource in skills.where(
      (Resource item) => item.skillProjectPaths.isNotEmpty,
    )) {
      for (final String projectPath in resource.skillProjectPaths) {
        _validateProjectSkillPath(projectPath);
        for (final String relativeRoot in projectSkillRoots) {
          final String root = path.normalize(
            path.join(projectPath, relativeRoot),
          );
          projectSkillsByRoot
              .putIfAbsent(root, () => <Resource>[])
              .add(resource);
        }
      }
    }
    final Set<String> currentProjectSkillRoots = projectSkillsByRoot.keys
        .toSet();
    final List<String> rootsToSync = <String>{
      ...previousProjectSkillRoots,
      ...currentProjectSkillRoots,
    }.toList()..sort();
    for (final String root in rootsToSync) {
      await _syncSkills(
        Directory(root),
        projectSkillsByRoot[root] ?? const <Resource>[],
      );
    }
    if (currentProjectSkillRoots.isNotEmpty) {
      managed[_managedProjectSkillRootsStateKey] = currentProjectSkillRoots;
    }
    for (final AgentMcpTarget target in mcpTargets) {
      final Set<String> previousNames = managed[target.file.path] ?? <String>{};
      if (mcps.isEmpty && previousNames.isEmpty) {
        continue;
      }
      await switch (target.kind) {
        AgentMcpConfigKind.codexToml => _syncCodex(target.file, mcps),
        AgentMcpConfigKind.claudeJson ||
        AgentMcpConfigKind.cursorJson ||
        AgentMcpConfigKind.geminiJson ||
        AgentMcpConfigKind.kiroJson => _syncJson(
          target.file,
          target.kind,
          mcps,
          previousNames,
        ),
      };
      managed[target.file.path] = mcps.map(_serverName).toSet();
    }
    await _writeManagedMcpState(managed);
    return issues;
  }

  Future<void> _syncPrompts(
    File file,
    List<Resource> enabled, {
    required bool includeBridgeRoutingInstructions,
  }) async {
    final List<Resource> direct =
        enabled
            .where(
              (Resource resource) =>
                  resource.activation == ResourceActivation.always &&
                  resource.triggerGroupIds.isEmpty,
            )
            .toList(growable: false)
          ..sort(_comparePromptOrder);
    final bool hasRoutedPrompts =
        includeBridgeRoutingInstructions &&
        enabled.any(
          (Resource resource) =>
              resource.activation != ResourceActivation.manual &&
              !direct.contains(resource),
        );
    final String current = await file.exists() ? await file.readAsString() : '';
    final String cleaned = current
        .replaceAll(_managedPromptsPattern, '')
        .trimRight();
    final StringBuffer block = StringBuffer();
    if (direct.isNotEmpty || hasRoutedPrompts) {
      block
        ..writeln(_managedPromptsBegin)
        ..writeln('# DingDong managed prompts')
        ..writeln()
        ..writeln(
          'This section is maintained by DingDong. Preserve and follow these instructions.',
        );
      for (final Resource prompt in direct) {
        block
          ..writeln()
          ..writeln('## ${_safeManagedPromptText(prompt.title)}')
          ..writeln()
          ..writeln(_safeManagedPromptText(prompt.content).trim());
      }
      if (hasRoutedPrompts) {
        block
          ..writeln()
          ..writeln('## Project and task prompts')
          ..writeln()
          ..writeln(
            '- At the start of each user task, call DingDong `dingdong_bridge` with `expand: "prompts"` and apply every returned active prompt before responding.',
          )
          ..writeln(
            '- Returned Skill and MCP entries are candidates, not instructions. Load a Skill only when its description matches the task; call MCP tools only when the task requires them.',
          );
      }
      block.writeln(_managedPromptsEnd);
    }
    final String managed = block.toString().trimRight();
    final String next = <String>[
      if (cleaned.isNotEmpty) cleaned,
      if (managed.isNotEmpty) managed,
    ].join('\n\n');
    final String normalized = next.isEmpty ? '' : '$next\n';
    if (normalized == current || (!await file.exists() && normalized.isEmpty)) {
      return;
    }
    await _writeAtomically(file, normalized);
  }

  /// Performs the same checks as sync without changing any Agent files.
  Future<List<AppIssue>> inspect(List<Resource> resources) async {
    final List<Resource> skills = resources
        .where(
          (Resource item) => item.enabled && item.type == ResourceType.skill,
        )
        .toList(growable: false);
    final List<Resource> mcps = resources
        .where((Resource item) => item.enabled && item.type == ResourceType.mcp)
        .toList(growable: false);
    final Set<String> enabledSkillIds = skills
        .map((Resource resource) => resource.id)
        .toSet();
    final List<AppIssue> issues = <AppIssue>[];
    final Map<String, List<Resource>> resourcesBySkillName =
        <String, List<Resource>>{};
    final Map<String, List<({Resource resource, String name})>> destinations =
        <String, List<({Resource resource, String name})>>{};

    for (final Resource resource in skills) {
      late final String skillName;
      try {
        skillName = SkillConfiguration.parseOnline(resource.content).name;
      } on Object catch (error) {
        issues.add(
          _issue(
            resource: resource,
            kind: AppIssueKind.invalidSkill,
            title: 'Invalid Skill',
            detail: error.toString(),
          ),
        );
        continue;
      }
      resourcesBySkillName
          .putIfAbsent(skillName, () => <Resource>[])
          .add(resource);
      final String? packagePath = resource.packagePath;
      if (packagePath != null &&
          !await File(path.join(packagePath, 'SKILL.md')).exists()) {
        issues.add(
          _issue(
            resource: resource,
            kind: AppIssueKind.skillPackageMissing,
            title: 'Skill package is missing',
            detail: 'SKILL.md was not found in $packagePath.',
            targetPath: packagePath,
          ),
        );
      }
      final List<({Directory root, String clientName})> targets =
          <({Directory root, String clientName})>[];
      if (resource.skillProjectPaths.isEmpty) {
        for (final Directory root in skillRoots) {
          targets.add((
            root: root,
            clientName:
                skillClientNames[path.normalize(root.path)] ??
                _clientNameFromPath(root.path),
          ));
        }
      } else {
        for (final String projectPath in resource.skillProjectPaths) {
          if (!_isValidProjectSkillPath(projectPath)) {
            issues.add(
              _issue(
                resource: resource,
                kind: AppIssueKind.invalidProjectPath,
                title: 'Project Skill path is invalid',
                detail:
                    'The project path must be an existing absolute directory.',
                targetPath: projectPath,
              ),
            );
            continue;
          }
          for (final String relativeRoot in projectSkillRoots) {
            targets.add((
              root: Directory(
                path.normalize(path.join(projectPath, relativeRoot)),
              ),
              clientName:
                  projectSkillClientNames[path.normalize(relativeRoot)] ??
                  _clientNameFromPath(relativeRoot),
            ));
          }
        }
      }
      for (final ({Directory root, String clientName}) target in targets) {
        final Directory destination = Directory(
          path.join(target.root.path, skillName),
        );
        final String destinationPath = path.normalize(destination.path);
        destinations
            .putIfAbsent(
              destinationPath,
              () => <({Resource resource, String name})>[],
            )
            .add((resource: resource, name: skillName));
        final FileSystemEntityType destinationType =
            await FileSystemEntity.type(destinationPath, followLinks: false);
        if (destinationType == FileSystemEntityType.notFound) {
          continue;
        }
        final File marker = File(
          path.join(destinationPath, '.dingdong-managed'),
        );
        if (!await marker.exists()) {
          issues.add(
            _issue(
              resource: resource,
              kind: AppIssueKind.skillNameConflict,
              title: 'Skill name conflict',
              detail:
                  'An existing Skill named "$skillName" is managed outside DingDong.',
              clientName: target.clientName,
              targetPath: destinationPath,
            ),
          );
          continue;
        }
        final String managedId = (await marker.readAsString()).trim();
        if (managedId.isNotEmpty &&
            managedId != resource.id &&
            enabledSkillIds.contains(managedId)) {
          issues.add(
            _issue(
              resource: resource,
              kind: AppIssueKind.managedSkillNameConflict,
              title: 'DingDong Skills use the same name',
              detail:
                  'The destination is already managed by another DingDong resource.',
              clientName: target.clientName,
              targetPath: destinationPath,
            ),
          );
        }
      }
    }

    for (final MapEntry<String, List<({Resource resource, String name})>> entry
        in destinations.entries) {
      final Map<String, Resource> distinct = <String, Resource>{
        for (final ({Resource resource, String name}) item in entry.value)
          item.resource.id: item.resource,
      };
      if (distinct.length < 2) {
        continue;
      }
      for (final Resource resource in distinct.values) {
        issues.add(
          _issue(
            resource: resource,
            kind: AppIssueKind.managedSkillNameConflict,
            title: 'DingDong Skills use the same name',
            detail:
                'Multiple enabled DingDong Skills resolve to the same destination.',
            clientName: _clientNameFromPath(entry.key),
            targetPath: entry.key,
          ),
        );
      }
    }

    for (final AgentSkillCatalog catalog in externalSkillCatalogs) {
      final List<ExternalAgentSkill> externalSkills = await catalog.load();
      for (final ExternalAgentSkill external in externalSkills) {
        for (final Resource resource
            in resourcesBySkillName[external.name] ?? const <Resource>[]) {
          issues.add(
            _issue(
              resource: resource,
              kind: AppIssueKind.pluginSkillNameConflict,
              severity: AppIssueSeverity.warning,
              title: 'Agent plugin provides the same Skill',
              detail:
                  '${external.providerName} also provides a Skill named '
                  '"${external.name}".',
              clientName: '${external.clientName} · ${external.providerName}',
              targetPath: external.targetPath,
            ),
          );
        }
      }
    }

    for (final Resource resource in mcps) {
      try {
        final McpConfiguration config = McpConfiguration.parse(
          resource.content,
        );
        if (config.transport == McpTransport.raw) {
          throw const FormatException(
            'Enabled MCP resources must use STDIO or Streamable HTTP.',
          );
        }
      } on Object catch (error) {
        issues.add(
          _issue(
            resource: resource,
            kind: AppIssueKind.invalidMcp,
            title: 'MCP configuration is invalid',
            detail: error.toString(),
          ),
        );
      }
    }
    for (final AgentMcpTarget target in mcpTargets) {
      if (target.kind == AgentMcpConfigKind.codexToml ||
          !await target.file.exists()) {
        continue;
      }
      try {
        final String contents = await target.file.readAsString();
        if (contents.trim().isEmpty) {
          continue;
        }
        final Object? decoded = jsonDecode(contents);
        if (decoded is! Map) {
          throw const FormatException('The file must contain a JSON object.');
        }
        final Object? servers = decoded['mcpServers'];
        if (servers != null && servers is! Map) {
          throw const FormatException('mcpServers must be a JSON object.');
        }
      } on Object catch (error) {
        issues.add(
          AppIssue(
            id: _issueId(
              AppIssueKind.invalidAgentConfig,
              null,
              target.file.path,
            ),
            source: agentResourceSyncIssueSource,
            kind: AppIssueKind.invalidAgentConfig,
            severity: AppIssueSeverity.error,
            title: 'Agent MCP file is invalid',
            detail: error.toString(),
            clientName: target.clientName,
            targetPath: target.file.path,
          ),
        );
      }
    }
    final Map<String, AppIssue> unique = <String, AppIssue>{
      for (final AppIssue issue in issues) issue.id: issue,
    };
    return unique.values.toList(growable: false);
  }

  void _validateProjectSkillPath(String projectPath) {
    if (!_isValidProjectSkillPath(projectPath)) {
      throw FormatException(
        'Project-scoped Skill path must be an existing absolute project directory: $projectPath',
      );
    }
  }

  bool _isValidProjectSkillPath(String projectPath) {
    final String normalized = path.normalize(projectPath);
    return path.isAbsolute(normalized) &&
        !path.equals(normalized, path.dirname(normalized)) &&
        Directory(normalized).existsSync();
  }

  Future<void> _syncSkills(Directory targetRoot, List<Resource> enabled) async {
    if (!await targetRoot.exists()) {
      if (enabled.isEmpty) {
        return;
      }
      await targetRoot.create(recursive: true);
    }
    final Map<String, String> activeNamesById = <String, String>{
      for (final Resource resource in enabled)
        resource.id: _skillName(resource),
    };
    await for (final FileSystemEntity entity in targetRoot.list()) {
      if (entity is! Directory) {
        continue;
      }
      final File marker = File(path.join(entity.path, '.dingdong-managed'));
      if (await marker.exists()) {
        final String managedId = (await marker.readAsString()).trim();
        final String? expectedName = activeNamesById[managedId];
        if (expectedName == null ||
            !path.equals(path.basename(entity.path), expectedName)) {
          await entity.delete(recursive: true);
        }
      }
    }
    for (final Resource resource in enabled) {
      final Directory source = await _skillSource(resource);
      final String name = _skillName(resource);
      final Directory destination = Directory(path.join(targetRoot.path, name));
      final File marker = File(
        path.join(destination.path, '.dingdong-managed'),
      );
      if (await destination.exists() && !await marker.exists()) {
        throw StateError(
          'Skill "$name" already exists in ${targetRoot.path} and is not managed by DingDong.',
        );
      }
      final Directory staging = Directory('${destination.path}.dingdong-tmp');
      final Directory backup = Directory('${destination.path}.dingdong-bak');
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      if (await backup.exists()) {
        await backup.delete(recursive: true);
      }
      await _copyDirectory(source, staging);
      await File(
        path.join(staging.path, '.dingdong-managed'),
      ).writeAsString(resource.id, flush: true);
      final bool hadDestination = await destination.exists();
      try {
        if (hadDestination) {
          await destination.rename(backup.path);
        }
        await staging.rename(destination.path);
        if (await backup.exists()) {
          await backup.delete(recursive: true);
        }
      } on Object {
        if (await staging.exists()) {
          await staging.delete(recursive: true);
        }
        if (hadDestination &&
            await backup.exists() &&
            !await destination.exists()) {
          await backup.rename(destination.path);
        }
        rethrow;
      }
    }
  }

  Future<Directory> _skillSource(Resource resource) async {
    final String? storedPath = resource.packagePath;
    if (storedPath != null) {
      final Directory stored = Directory(storedPath);
      if (await File(path.join(stored.path, 'SKILL.md')).exists()) {
        final String managedRoot = path.canonicalize(packageRoot.path);
        final String sourcePath = path.canonicalize(stored.path);
        if (path.isWithin(managedRoot, sourcePath)) {
          return stored;
        }
        final Directory imported = Directory(
          path.join(packageRoot.path, resource.id),
        );
        final Directory staging = Directory('${imported.path}.dingdong-tmp');
        if (await staging.exists()) {
          await staging.delete(recursive: true);
        }
        await _copyDirectory(stored, staging);
        if (await imported.exists()) {
          await imported.delete(recursive: true);
        }
        await staging.rename(imported.path);
        return imported;
      }
    }
    final String? updateUrl = resource.updateUrl;
    if (updateUrl != null) {
      final Directory installed = Directory(
        path.join(packageRoot.path, _skillName(resource)),
      );
      if (resource.source == builtInDingDongConfigureSkillSource) {
        await installed.create(recursive: true);
        await File(
          path.join(installed.path, 'SKILL.md'),
        ).writeAsString(resource.content, flush: true);
        return installed;
      }
      if (await File(path.join(installed.path, 'SKILL.md')).exists()) {
        return installed;
      }
      final SkillPackageInstallResult result = await skillPackageInstaller
          .install(Uri.parse(updateUrl));
      return Directory(result.directoryPath);
    }
    final Directory generated = Directory(
      path.join(packageRoot.path, resource.id),
    );
    await generated.create(recursive: true);
    await File(
      path.join(generated.path, 'SKILL.md'),
    ).writeAsString(resource.content, flush: true);
    return generated;
  }

  Future<void> _syncJson(
    File file,
    AgentMcpConfigKind kind,
    List<Resource> resources,
    Set<String> previousNames,
  ) async {
    Map<String, Object?> root = <String, Object?>{};
    if (await file.exists() && (await file.readAsString()).trim().isNotEmpty) {
      root = Map<String, Object?>.from(
        jsonDecode(await file.readAsString()) as Map,
      );
    }
    final Map<String, Object?> servers = Map<String, Object?>.from(
      (root['mcpServers'] as Map?) ?? const <String, Object?>{},
    )..removeWhere((String key, Object? _) => previousNames.contains(key));
    for (final Resource resource in resources) {
      servers[_serverName(resource)] = _jsonMcp(
        McpConfiguration.parse(resource.content),
        kind,
      );
    }
    await _writeAtomically(
      file,
      const JsonEncoder.withIndent(
        '  ',
      ).convert(<String, Object?>{...root, 'mcpServers': servers}),
    );
  }

  Future<void> _syncCodex(File file, List<Resource> resources) async {
    final String current = await file.exists() ? await file.readAsString() : '';
    final String cleaned = current
        .replaceAll(
          RegExp(
            r'^# BEGIN DINGDONG MCP .*?^# END DINGDONG MCP\s*\n?',
            multiLine: true,
            dotAll: true,
          ),
          '',
        )
        .trimRight();
    final StringBuffer output = StringBuffer(cleaned);
    for (final Resource resource in resources) {
      final McpConfiguration config = McpConfiguration.parse(resource.content);
      output
        ..writeln(output.isEmpty ? '' : '\n')
        ..writeln('# BEGIN DINGDONG MCP ${resource.id}')
        ..writeln('[mcp_servers.${_serverName(resource)}]');
      if (config.transport == McpTransport.stdio) {
        output.writeln('command = "${_toml(config.command)}"');
        if (config.arguments.isNotEmpty) {
          output.writeln(
            'args = [${config.arguments.map((String value) => '"${_toml(value)}"').join(', ')}]',
          );
        }
        if (config.environment.isNotEmpty) {
          output.writeln(
            'env = { ${config.environment.entries.map((MapEntry<String, String> item) => '${item.key} = "${_toml(item.value)}"').join(', ')} }',
          );
        }
      } else if (config.transport == McpTransport.streamableHttp) {
        output.writeln('url = "${_toml(config.url)}"');
        if (config.tokenEnvironmentVariable.isNotEmpty) {
          output.writeln(
            'bearer_token_env_var = "${_toml(config.tokenEnvironmentVariable)}"',
          );
        }
        if (config.headers.isNotEmpty) {
          output.writeln(
            'http_headers = { ${config.headers.entries.map((MapEntry<String, String> item) => '"${_toml(item.key)}" = "${_toml(item.value)}"').join(', ')} }',
          );
        }
      } else {
        throw FormatException('MCP ${resource.title} must use STDIO or HTTP.');
      }
      output
        ..writeln('enabled = true')
        ..writeln('# END DINGDONG MCP');
    }
    await _writeAtomically(file, '${output.toString().trimRight()}\n');
  }

  Future<Map<String, Set<String>>> _readManagedMcpState() async {
    if (!await managedStateFile.exists()) {
      return <String, Set<String>>{};
    }
    try {
      final Map<String, Object?> decoded = Map<String, Object?>.from(
        jsonDecode(await managedStateFile.readAsString()) as Map,
      );
      return <String, Set<String>>{
        for (final MapEntry<String, Object?> entry in decoded.entries)
          entry.key: (entry.value as List<Object?>? ?? const <Object?>[])
              .map((Object? value) => value as String)
              .toSet(),
      };
    } on Object {
      throw const FormatException('DingDong Agent sync state is invalid.');
    }
  }

  Future<void> _writeManagedMcpState(Map<String, Set<String>> managed) async {
    await _writeAtomically(
      managedStateFile,
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        for (final MapEntry<String, Set<String>> entry in managed.entries)
          entry.key: entry.value.toList(growable: false)..sort(),
      }),
    );
  }
}

/// Adds transactional synchronization without changing callers of ResourceStore.
final class SynchronizedResourceStore implements ResourceStore {
  SynchronizedResourceStore(
    this._delegate,
    this._synchronizer, {
    this.issueCenter,
    this.onChanged,
  });

  final ResourceStore _delegate;
  final AgentResourceSynchronizer _synchronizer;
  final IssueCenterController? issueCenter;
  final void Function()? onChanged;

  @override
  Future<List<Resource>> load() => _delegate.load();

  @override
  Future<void> save(List<Resource> resources) async {
    final List<Resource> previous = await _delegate.load();
    await _delegate.save(resources);
    try {
      final List<AppIssue> issues = await _synchronizer.sync(resources);
      await _cleanupRemovedPackages(previous, resources);
      issueCenter?.replaceSource(agentResourceSyncIssueSource, issues);
    } on Object catch (error, stackTrace) {
      final List<AppIssue> issues = error is AppIssueException
          ? error.issues
          : <AppIssue>[
              AppIssue(
                id: _issueId(AppIssueKind.syncFailed, null, null),
                source: agentResourceSyncIssueSource,
                kind: AppIssueKind.syncFailed,
                severity: AppIssueSeverity.error,
                title: 'Agent resource sync failed',
                detail: error.toString(),
              ),
            ];
      await _delegate.save(previous);
      try {
        await _synchronizer.sync(previous);
      } on Object {
        // Preserve the original save failure; the resource file is rolled back.
      }
      await _cleanupRemovedPackages(resources, previous);
      issueCenter?.replaceSource(agentResourceSyncIssueSource, issues);
      Error.throwWithStackTrace(error, stackTrace);
    }
    onChanged?.call();
  }

  Future<void> _cleanupRemovedPackages(
    List<Resource> previous,
    List<Resource> current,
  ) async {
    final Set<String> active = current
        .map((Resource resource) => resource.packagePath)
        .whereType<String>()
        .map(path.canonicalize)
        .toSet();
    final String managedRoot = path.canonicalize(
      _synchronizer.packageRoot.path,
    );
    for (final String packagePath
        in previous
            .map((Resource resource) => resource.packagePath)
            .whereType<String>()) {
      final String canonical = path.canonicalize(packagePath);
      if (active.contains(canonical) ||
          !path.isWithin(managedRoot, canonical)) {
        continue;
      }
      final Directory directory = Directory(canonical);
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
    final Set<String> currentIds = current
        .map((Resource resource) => resource.id)
        .toSet();
    final Set<String> activeSkillNames = current
        .where((Resource resource) => resource.type == ResourceType.skill)
        .map(_skillName)
        .toSet();
    for (final Resource resource in previous) {
      if (currentIds.contains(resource.id)) {
        continue;
      }
      final Directory generated = Directory(
        path.join(_synchronizer.packageRoot.path, resource.id),
      );
      if (await generated.exists()) {
        await generated.delete(recursive: true);
      }
      if (resource.type == ResourceType.skill &&
          resource.updateUrl != null &&
          resource.packagePath == null &&
          !activeSkillNames.contains(_skillName(resource))) {
        final Directory downloaded = Directory(
          path.join(_synchronizer.packageRoot.path, _skillName(resource)),
        );
        if (await downloaded.exists()) {
          await downloaded.delete(recursive: true);
        }
      }
    }
  }
}

Map<String, Object?> _jsonMcp(
  McpConfiguration config,
  AgentMcpConfigKind kind,
) {
  final Map<String, String> headers = <String, String>{...config.headers};
  if (config.tokenEnvironmentVariable.isNotEmpty &&
      !headers.containsKey('Authorization')) {
    final String variable = config.tokenEnvironmentVariable;
    headers['Authorization'] = switch (kind) {
      AgentMcpConfigKind.claudeJson => 'Bearer \${$variable}',
      AgentMcpConfigKind.cursorJson => 'Bearer \${env:$variable}',
      AgentMcpConfigKind.geminiJson => 'Bearer \$$variable',
      AgentMcpConfigKind.kiroJson => 'Bearer \${$variable}',
      AgentMcpConfigKind.codexToml => throw StateError(
        'Codex MCP configuration is not JSON.',
      ),
    };
  }
  return switch (config.transport) {
    McpTransport.stdio => <String, Object?>{
      if (kind == AgentMcpConfigKind.claudeJson) 'type': 'stdio',
      'command': config.command,
      if (config.arguments.isNotEmpty) 'args': config.arguments,
      if (config.environment.isNotEmpty) 'env': config.environment,
      if (kind == AgentMcpConfigKind.claudeJson) 'alwaysLoad': true,
    },
    McpTransport.streamableHttp => <String, Object?>{
      if (kind == AgentMcpConfigKind.claudeJson) 'type': 'http',
      if (kind == AgentMcpConfigKind.geminiJson)
        'httpUrl': config.url
      else
        'url': config.url,
      if (headers.isNotEmpty) 'headers': headers,
      if (kind == AgentMcpConfigKind.claudeJson) 'alwaysLoad': true,
    },
    McpTransport.raw => throw const FormatException(
      'Enabled MCP resources must use STDIO or HTTP configuration.',
    ),
  };
}

Future<void> _copyDirectory(Directory source, Directory destination) async {
  await destination.create(recursive: true);
  await for (final FileSystemEntity entity in source.list()) {
    final String name = path.basename(entity.path);
    if (name == '.dingdong-managed') {
      continue;
    }
    final String target = path.join(destination.path, name);
    if (entity is Directory) {
      await _copyDirectory(entity, Directory(target));
    } else if (entity is File) {
      await entity.copy(target);
    } else if (entity is Link) {
      throw const FormatException(
        'Skill packages with symbolic links are not supported.',
      );
    }
  }
}

String _serverName(Resource resource) {
  final String slug = normalizeSkillName(resource.title);
  final String suffix = resource.id
      .replaceAll(RegExp('[^A-Za-z0-9]'), '')
      .toLowerCase();
  final int suffixLength = suffix.length < 6 ? suffix.length : 6;
  return 'dingdong-$slug-${suffix.substring(0, suffixLength)}';
}

String _skillName(Resource resource) {
  try {
    return SkillConfiguration.parseOnline(resource.content).name;
  } on Object {
    return normalizeSkillName(resource.title);
  }
}

AppIssue _issue({
  required Resource resource,
  required AppIssueKind kind,
  required String title,
  required String detail,
  AppIssueSeverity severity = AppIssueSeverity.error,
  String? clientName,
  String? targetPath,
}) => AppIssue(
  id: _issueId(kind, resource.id, targetPath),
  source: agentResourceSyncIssueSource,
  kind: kind,
  severity: severity,
  title: title,
  detail: detail,
  resourceId: resource.id,
  resourceTitle: resource.title,
  clientName: clientName,
  targetPath: targetPath,
);

String _issueId(AppIssueKind kind, String? resourceId, String? targetPath) =>
    '${kind.name}:${resourceId ?? '-'}:${targetPath ?? '-'}';

String _clientNameFromPath(String value) {
  final String normalized = value.replaceAll(r'\', '/').toLowerCase();
  if (normalized.contains('/.agents/') || normalized.endsWith('/.agents')) {
    return 'Codex';
  }
  if (normalized.contains('/.claude/') || normalized.endsWith('/.claude')) {
    return 'Claude Code';
  }
  if (normalized.contains('/.cursor/') || normalized.endsWith('/.cursor')) {
    return 'Cursor';
  }
  if (normalized.contains('/.gemini/') || normalized.endsWith('/.gemini')) {
    return 'Gemini CLI';
  }
  if (normalized.contains('/.kiro/') || normalized.endsWith('/.kiro')) {
    return 'Kiro';
  }
  return 'Agent';
}

const String _managedPromptsBegin = '<!-- BEGIN DINGDONG MANAGED PROMPTS -->';
const String _managedPromptsEnd = '<!-- END DINGDONG MANAGED PROMPTS -->';
const String _managedProjectSkillRootsStateKey = r'$dingdongProjectSkillRoots';

final RegExp _managedPromptsPattern = RegExp(
  '${RegExp.escape(_managedPromptsBegin)}.*?${RegExp.escape(_managedPromptsEnd)}\\s*',
  dotAll: true,
);

int _comparePromptOrder(Resource left, Resource right) {
  final int order = (left.sortOrder ?? 1 << 30).compareTo(
    right.sortOrder ?? 1 << 30,
  );
  if (order != 0) {
    return order;
  }
  final int title = left.title.compareTo(right.title);
  return title != 0 ? title : left.id.compareTo(right.id);
}

String _safeManagedPromptText(String value) => value
    .replaceAll(_managedPromptsBegin, '&lt;!-- BEGIN DINGDONG PROMPTS --&gt;')
    .replaceAll(_managedPromptsEnd, '&lt;!-- END DINGDONG PROMPTS --&gt;');

String _toml(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\n', r'\n');

Future<void> _writeAtomically(File file, String content) async {
  await file.parent.create(recursive: true);
  final File temporary = File('${file.path}.dingdong-tmp');
  final File backup = File('${file.path}.dingdong-bak');
  await temporary.writeAsString(content, flush: true);
  final bool hadFile = await file.exists();
  try {
    if (hadFile) {
      if (await backup.exists()) {
        await backup.delete();
      }
      await file.rename(backup.path);
    }
    await temporary.rename(file.path);
    if (await backup.exists()) {
      await backup.delete();
    }
  } on Object {
    if (await temporary.exists()) {
      await temporary.delete();
    }
    if (hadFile && await backup.exists() && !await file.exists()) {
      await backup.rename(file.path);
    }
    rethrow;
  }
}
