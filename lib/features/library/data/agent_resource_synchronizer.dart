import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_adapters/data/codex_completion_hook_gateway.dart';
import 'package:dingdong/features/agent_adapters/domain/agent_adapter.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/library/data/agent_skill_catalog.dart';
import 'package:dingdong/features/library/data/codex_project_hook_inventory.dart';
import 'package:dingdong/features/library/data/native_skill_delivery_coordinator.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/skill_deployment_store.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resources.dart';
import 'package:dingdong/features/library/domain/project_hook_integration.dart';
import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:dingdong/features/library/domain/resource_scope_policy.dart';
import 'package:dingdong/features/library/domain/skill_deployment_plan.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:path/path.dart' as path;

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

typedef AgentAdapterLoader = Future<List<AgentAdapter>> Function();

/// Makes DingDong's enabled state concrete in supported Agent clients.
///
/// Prompts install a stable Bridge bootstrap. Skills use one mutually
/// exclusive delivery plane per Agent: dynamic Bridge loading or a complete
/// receipt-owned native package. MCP resources become real client
/// configuration entries filtered by each target Agent's source. Legacy Skill
/// mirrors are removed only when DingDong marked them.
final class AgentResourceSynchronizer {
  AgentResourceSynchronizer({
    required this.packageRoot,
    required this.skillRoots,
    this.projectSkillRoots = const <String>[],
    required this.mcpTargets,
    this.triggerGroupStore,
    this.promptTargets = const <AgentPromptTarget>[],
    this.skillClientNames = const <String, String>{},
    this.projectSkillClientNames = const <String, String>{},
    this.skillTargets = const <AgentSkillTarget>[],
    this.externalSkillCatalogs = const <AgentSkillCatalog>[],
    this._adapterLoader,
    this._adapterHomeDirectory,
    File? managedStateFile,
    SkillDeploymentStore? deploymentStore,
    CodexProjectHookInventory? projectHookInventory,
    SkillPackageInstaller? skillPackageInstaller,
  }) : managedStateFile =
           managedStateFile ??
           File(path.join(packageRoot.parent.path, 'agent-sync-state.json')),
       skillPackageInstaller =
           skillPackageInstaller ?? GitHubSkillPackageInstaller(packageRoot),
       deploymentStore =
           deploymentStore ??
           SkillDeploymentStore(
             Directory(path.join(packageRoot.parent.path, 'Skill Deployments')),
           ) {
    nativeSkillDelivery = NativeSkillDeliveryCoordinator(
      store: this.deploymentStore,
      hookInventory: projectHookInventory,
    );
  }

  static Future<AgentResourceSynchronizer> currentUser(
    Directory packageRoot, {
    required AgentAdapterLoader loadAdapters,
    SkillPackageInstaller? skillPackageInstaller,
    TriggerGroupStore? triggerGroupStore,
    String? homeDirectory,
    CodexProjectHookInventory? projectHookInventory,
  }) async {
    final String home =
        homeDirectory ??
        Platform.environment['HOME'] ??
        Platform.environment['USERPROFILE']!;
    final AgentResourceSynchronizer synchronizer = AgentResourceSynchronizer(
      packageRoot: packageRoot,
      skillRoots: const <Directory>[],
      mcpTargets: const <AgentMcpTarget>[],
      triggerGroupStore: triggerGroupStore,
      adapterLoader: loadAdapters,
      adapterHomeDirectory: home,
      skillPackageInstaller: skillPackageInstaller,
      projectHookInventory:
          projectHookInventory ??
          CodexAppServerProjectHookInventory(
            connectionFactory: NativeCodexAppServerConnectionFactory(
              homeDirectory: home,
            ),
          ),
    );
    try {
      await synchronizer._reloadAdapterTargets();
    } on FormatException {
      // Keep DingDong and Resource Manager available so the invalid user YAML
      // can remain visible and be repaired. inspect/sync still surface the
      // configuration error and do not apply a partial Adapter catalog.
    }
    return synchronizer;
  }

  final Directory packageRoot;
  List<Directory> skillRoots;
  List<String> projectSkillRoots;
  List<AgentPromptTarget> promptTargets;
  List<AgentMcpTarget> mcpTargets;
  final TriggerGroupStore? triggerGroupStore;
  Map<String, String> skillClientNames;
  Map<String, String> projectSkillClientNames;
  List<AgentSkillTarget> skillTargets;
  List<AgentSkillCatalog> externalSkillCatalogs;
  final File managedStateFile;
  final SkillPackageInstaller skillPackageInstaller;
  final SkillDeploymentStore deploymentStore;
  late final NativeSkillDeliveryCoordinator nativeSkillDelivery;
  final AgentAdapterLoader? _adapterLoader;
  final String? _adapterHomeDirectory;

  Future<List<AppIssue>> sync(List<Resource> resources) async {
    await _reloadAdapterTargets();
    final List<Resource> skills = resources
        .where((Resource item) => item.type == ResourceType.skill)
        .toList(growable: false);
    final List<Resource> mcps = resources
        .where((Resource item) => item.enabled && item.type == ResourceType.mcp)
        .toList(growable: false);
    final Map<String, TriggerGroup> triggerGroupsById =
        await _loadTriggerGroups();
    // Recover durable deployment journals before unrelated validation can
    // reject a later reconciliation plan.
    await nativeSkillDelivery.recoverPending(
      resources: resources,
      targets: skillTargets,
    );
    final List<AppIssue> issues = await _inspect(resources);
    final List<AppIssue> blockingIssues = issues
        .where((AppIssue issue) => issue.severity == AppIssueSeverity.error)
        .toList(growable: false);
    if (blockingIssues.isNotEmpty) {
      throw AppIssueException(blockingIssues);
    }
    await nativeSkillDelivery.reconcile(
      resources: resources,
      targets: skillTargets,
    );
    final Map<String, Set<String>> managed = await _readManagedMcpState();
    _normalizeManagedTargetPaths(managed);
    final Set<String> previousProjectSkillRoots =
        managed.remove(_managedProjectSkillRootsStateKey) ?? <String>{};
    final Set<String> previousGlobalSkillRoots =
        managed.remove(_managedGlobalSkillRootsStateKey) ?? <String>{};
    final Set<String> currentGlobalSkillRoots = skillRoots
        .map((Directory root) => path.normalize(root.path))
        .toSet();
    final List<String> globalRootsToSync = <String>{
      ...previousGlobalSkillRoots,
      ...currentGlobalSkillRoots,
    }.toList()..sort();
    for (final String root in globalRootsToSync) {
      await _syncSkills(Directory(root), const <Resource>[]);
    }

    final Set<String> previousPromptPaths =
        managed.remove(_managedPromptTargetsStateKey) ?? <String>{};
    final Map<String, AgentPromptTarget> currentPrompts =
        <String, AgentPromptTarget>{
          for (final AgentPromptTarget target in promptTargets)
            path.normalize(target.file.path): target,
        };
    final List<String> promptPathsToSync = <String>{
      ...previousPromptPaths,
      ...currentPrompts.keys,
    }.toList()..sort();
    for (final String promptPath in promptPathsToSync) {
      final AgentPromptTarget? target = currentPrompts[promptPath];
      await _syncPrompts(
        target?.file ?? File(promptPath),
        includeBridgeRoutingInstructions:
            target?.includeBridgeRoutingInstructions ?? false,
      );
    }
    if (currentPrompts.isNotEmpty) {
      managed[_managedPromptTargetsStateKey] = currentPrompts.keys.toSet();
    }

    final Set<String> knownProjectSkillRoots = <String>{
      ...previousProjectSkillRoots,
    };
    for (final Resource resource in skills) {
      for (final String projectPath in resource.skillProjectPaths) {
        for (final String relativeRoot in projectSkillRoots) {
          knownProjectSkillRoots.add(
            path.normalize(path.join(projectPath, relativeRoot)),
          );
        }
      }
    }
    final List<String> rootsToSync = knownProjectSkillRoots.toList()..sort();
    for (final String root in rootsToSync) {
      await _syncSkills(Directory(root), const <Resource>[]);
    }

    final Map<String, AgentMcpConfigKind> previousMcpKinds =
        _decodeManagedMcpTargetKinds(
          managed.remove(_managedMcpTargetKindsStateKey) ?? <String>{},
        );
    final Map<String, AgentMcpTarget> currentMcpTargets =
        <String, AgentMcpTarget>{
          for (final AgentMcpTarget target in mcpTargets)
            path.normalize(target.file.path): target,
        };
    final Set<String> previousMcpPaths = managed.keys
        .where((String key) => !_isManagedStateKey(key))
        .toSet();
    final List<String> mcpPathsToSync = <String>{
      ...previousMcpPaths,
      ...previousMcpKinds.keys,
      ...currentMcpTargets.keys,
    }.toList()..sort();
    for (final String mcpPath in mcpPathsToSync) {
      final AgentMcpTarget? target = currentMcpTargets[mcpPath];
      final Set<String> previousNames = managed[mcpPath] ?? <String>{};
      if (target == null) {
        final File oldFile = File(mcpPath);
        if (previousNames.isNotEmpty && await oldFile.exists()) {
          await _syncMcpTarget(
            oldFile,
            previousMcpKinds[mcpPath] ?? _inferMcpKind(oldFile),
            const <Resource>[],
            previousNames,
          );
        }
        managed.remove(mcpPath);
        continue;
      }
      final List<Resource> targetMcps = _mcpResourcesForTarget(
        mcps,
        target,
        triggerGroupsById,
      );
      if (targetMcps.isEmpty && previousNames.isEmpty) {
        managed.remove(mcpPath);
        continue;
      }
      await _syncMcpTarget(target.file, target.kind, targetMcps, previousNames);
      final Set<String> currentNames = targetMcps.map(_serverName).toSet();
      if (currentNames.isEmpty) {
        managed.remove(mcpPath);
      } else {
        managed[mcpPath] = currentNames;
      }
    }
    if (currentMcpTargets.isNotEmpty) {
      managed[_managedMcpTargetKindsStateKey] = _encodeManagedMcpTargetKinds(
        currentMcpTargets,
      );
    }
    await _writeManagedMcpState(managed);
    return issues;
  }

  Future<Map<String, TriggerGroup>> _loadTriggerGroups() async {
    final TriggerGroupStore? store = triggerGroupStore;
    if (store == null) {
      return const <String, TriggerGroup>{};
    }
    return <String, TriggerGroup>{
      for (final TriggerGroup group in await store.load()) group.id: group,
    };
  }

  List<Resource> _mcpResourcesForTarget(
    List<Resource> resources,
    AgentMcpTarget target,
    Map<String, TriggerGroup> triggerGroupsById,
  ) {
    if (triggerGroupStore == null) {
      return resources;
    }
    final TriggerContext context = TriggerContext(source: target.clientName);
    return resources
        .where(
          (Resource resource) =>
              resourceMatchesScope(resource, context, triggerGroupsById),
        )
        .toList(growable: false);
  }

  Future<void> _syncMcpTarget(
    File file,
    AgentMcpConfigKind kind,
    List<Resource> resources,
    Set<String> previousNames,
  ) => switch (kind) {
    AgentMcpConfigKind.codexToml => _syncCodex(file, resources, previousNames),
    AgentMcpConfigKind.claudeJson ||
    AgentMcpConfigKind.cursorJson ||
    AgentMcpConfigKind.geminiJson ||
    AgentMcpConfigKind.kiroJson ||
    AgentMcpConfigKind.mcpServersJson => _syncJson(
      file,
      kind,
      resources,
      previousNames,
    ),
  };

  Future<void> _syncPrompts(
    File file, {
    required bool includeBridgeRoutingInstructions,
  }) async {
    final String current = await file.exists() ? await file.readAsString() : '';
    final String cleaned = current
        .replaceAll(_managedPromptsPattern, '')
        .trimRight();
    final StringBuffer block = StringBuffer();
    if (includeBridgeRoutingInstructions) {
      block
        ..writeln(_managedPromptsBegin)
        ..writeln('# DingDong prompt bridge')
        ..writeln()
        ..writeln(
          'This section is maintained by DingDong. Preserve and follow these instructions.',
        )
        ..writeln()
        ..writeln(
          '- At the start of each user task, call DingDong `dingdong_bridge` with `expand: "prompts"`.',
        )
        ..writeln(
          '- Apply every returned active Prompt in full before responding. The bridge routes global, project, and task-matched Prompts dynamically.',
        )
        ..writeln(
          '- Treat `active.prompts` in each successful bridge response as the authoritative snapshot for that user task. It replaces every Prompt set returned for earlier tasks; any Prompt absent now is inactive and must not be applied.',
        )
        ..writeln(
          '- If the bridge call fails, state that DingDong Prompts and the Skill catalog could not be loaded; do not silently treat any previous Prompt or Skill set as current.',
        )
        ..writeln(
          '- Treat `active.skills` in each successful response as the authoritative Skill catalog for that task and workspace. It contains every valid, enabled, scope-matched Skill, with each entry limited to `id`, `name`, and `description`; a Skill absent from the current catalog is unavailable, disabled, invalid, or out of scope. Load only a Skill returned by the current catalog.',
        )
        ..writeln(
          '- A Skill candidate is not an instruction. Only when its description matches the task, call `dingdong_load_skill` with its id or name and current workspace, then apply the returned full `SKILL.md`. Read only supporting files referenced by that document with `dingdong_read_skill_file`.',
        )
        ..writeln(
          '- Returned MCP entries are tool references, not instructions. Call configured MCP tools only when the task requires them.',
        )
        ..writeln(
          '- When `conversation.visible` is true, keep the successful Bridge `conversation.capsule` until the final user-visible response. For each successful `dingdong_load_skill` call, replace only the capsule item whose `mergeKey` matches the returned `conversation.item`; the merge key is opaque merge-only metadata and must never be displayed. Append `*` only to a Skill item whose returned `confirmedUse` is true; this confirms that DingDong returned the full Skill in this task, not that every instruction was followed. On Codex desktop, include `conversation.line` exactly once as a single Markdown text line and keep `DingDong` as text. Use the exact Prompt, Skill, and MCP symbols already supplied in `conversation.line` and each item\'s `lineToken`; these symbols are user-configurable, so never infer or rebuild them. The capsule palette remains warm orange for Prompt, blue for Skill, and green for MCP. Do not use an image, HTML/XML, inline font, or rendering tool for this footer. Use `conversation.presentations.ansi.line` only on an explicitly ANSI-capable terminal; every other host includes `conversation.fallbackLine` exactly once. Never mark a Skill candidate, Prompt, or MCP, and never display resource content, descriptions, IDs, or merge keys.',
        );
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
    await _reloadAdapterTargets();
    return _inspect(resources);
  }

  Future<List<AppIssue>> _inspect(List<Resource> resources) async {
    final List<Resource> skills = resources
        .where(
          (Resource item) => item.enabled && item.type == ResourceType.skill,
        )
        .toList(growable: false);
    final List<Resource> mcps = resources
        .where((Resource item) => item.enabled && item.type == ResourceType.mcp)
        .toList(growable: false);
    final List<AppIssue> issues = <AppIssue>[];
    final Map<String, List<Resource>> resourcesBySkillName =
        <String, List<Resource>>{};

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
        final FileSystemEntityType destinationType =
            await FileSystemEntity.type(destinationPath, followLinks: false);
        if (destinationType == FileSystemEntityType.notFound) {
          continue;
        }
        final File marker = File(
          path.join(destinationPath, '.dingdong-managed'),
        );
        final File receipt = File(
          path.join(destinationPath, skillDeploymentReceiptFileName),
        );
        if (!await marker.exists() &&
            !await _isOwnedNativeSkillReceipt(receipt, resource.id)) {
          issues.add(
            _issue(
              resource: resource,
              kind: AppIssueKind.skillNameConflict,
              severity: AppIssueSeverity.warning,
              title: 'Skill name conflict',
              detail:
                  'An existing native Skill named "$skillName" is managed outside DingDong and remains available independently of DingDong\'s switch.',
              clientName: target.clientName,
              targetPath: destinationPath,
            ),
          );
        }
      }
    }

    for (final MapEntry<String, List<Resource>> entry
        in resourcesBySkillName.entries) {
      if (entry.value.length < 2) {
        continue;
      }
      for (final Resource resource in entry.value) {
        issues.add(
          _issue(
            resource: resource,
            kind: AppIssueKind.managedSkillNameConflict,
            severity: AppIssueSeverity.warning,
            title: 'DingDong Skills use the same name',
            detail:
                'Loading "${entry.key}" by name is ambiguous; Agents must include the candidate id.',
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

  Future<bool> _isOwnedNativeSkillReceipt(
    File receipt,
    String resourceId,
  ) async {
    if (!await receipt.exists()) {
      return false;
    }
    try {
      final Object? decoded = jsonDecode(await receipt.readAsString());
      if (decoded is! Map) {
        return false;
      }
      final Map<String, Object?> value = Map<String, Object?>.from(decoded);
      return value['schemaVersion'] == 1 &&
          value['managedBy'] == 'DingDong' &&
          value['resourceId'] == resourceId &&
          value['deploymentKey'] is String &&
          value['destinationKey'] is String &&
          value['contentDigest'] is String;
    } on Object {
      return false;
    }
  }

  Future<void> _reloadAdapterTargets() async {
    final AgentAdapterLoader? load = _adapterLoader;
    if (load == null) {
      return;
    }
    final _AgentResourceTargets targets = _targetsForAdapters(
      await load(),
      _adapterHomeDirectory!,
    );
    skillRoots = targets.skillRoots;
    projectSkillRoots = targets.projectSkillRoots;
    promptTargets = targets.promptTargets;
    mcpTargets = targets.mcpTargets;
    skillClientNames = targets.skillClientNames;
    projectSkillClientNames = targets.projectSkillClientNames;
    skillTargets = targets.skillTargets;
    externalSkillCatalogs = targets.externalSkillCatalogs;
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

  Future<void> _syncCodex(
    File file,
    List<Resource> resources,
    Set<String> previousNames,
  ) async {
    final String current = await file.exists() ? await file.readAsString() : '';
    final Set<String> managedServerNames = <String>{
      ...previousNames,
      ...resources.map(_serverName),
    };
    final String cleaned = _removeCodexMcpTables(
      current.replaceAll(_managedMcpBlockPattern, ''),
      managedServerNames,
    ).trimRight();
    _rejectDuplicateTomlTables(cleaned, file.path);
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
    final String next = '${output.toString().trimRight()}\n';
    _rejectDuplicateTomlTables(next, file.path);
    if (next == current) {
      return;
    }
    final String latest = await file.exists() ? await file.readAsString() : '';
    if (latest != current) {
      throw StateError(
        'Codex configuration changed during DingDong MCP synchronization; '
        '${file.path} was not overwritten.',
      );
    }
    await _writeAtomically(file, next);
    if (await file.readAsString() != next) {
      throw StateError(
        'Codex configuration changed immediately after DingDong MCP '
        'synchronization: ${file.path}.',
      );
    }
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

final class _AgentResourceTargets {
  const _AgentResourceTargets({
    required this.skillRoots,
    required this.projectSkillRoots,
    required this.promptTargets,
    required this.mcpTargets,
    required this.skillClientNames,
    required this.projectSkillClientNames,
    required this.skillTargets,
    required this.externalSkillCatalogs,
  });

  final List<Directory> skillRoots;
  final List<String> projectSkillRoots;
  final List<AgentPromptTarget> promptTargets;
  final List<AgentMcpTarget> mcpTargets;
  final Map<String, String> skillClientNames;
  final Map<String, String> projectSkillClientNames;
  final List<AgentSkillTarget> skillTargets;
  final List<AgentSkillCatalog> externalSkillCatalogs;
}

_AgentResourceTargets _targetsForAdapters(
  List<AgentAdapter> adapters,
  String home,
) {
  final List<AgentAdapter> installed = adapters
      .where((AgentAdapter adapter) => adapter.isInstalled(home))
      .toList(growable: false);
  final Map<String, ({AgentMcpConfigKind kind, String client})>
  mcpTargetOwners = <String, ({AgentMcpConfigKind kind, String client})>{};
  final Map<String, ({bool routing, String client})> promptTargetOwners =
      <String, ({bool routing, String client})>{};
  for (final AgentAdapter adapter in installed) {
    if (adapter.resolvedMcpFilePath(home) case final String mcpPath) {
      final String normalized = path.normalize(mcpPath);
      final ({AgentMcpConfigKind kind, String client})? existing =
          mcpTargetOwners[normalized];
      if (existing != null && existing.kind != adapter.mcpKind) {
        throw FormatException(
          'Agent Adapters "${existing.client}" and "${adapter.displayName}" '
          'use conflicting MCP formats for $normalized.',
        );
      }
      mcpTargetOwners[normalized] = (
        kind: adapter.mcpKind!,
        client: adapter.displayName,
      );
    }
    if (adapter.resolvedPromptFilePath(home) case final String promptPath) {
      final String normalized = path.normalize(promptPath);
      final ({bool routing, String client})? existing =
          promptTargetOwners[normalized];
      if (existing != null &&
          existing.routing != adapter.includeBridgeRoutingInstructions) {
        throw FormatException(
          'Agent Adapters "${existing.client}" and "${adapter.displayName}" '
          'use conflicting Prompt routing settings for $normalized.',
        );
      }
      promptTargetOwners[normalized] = (
        routing: adapter.includeBridgeRoutingInstructions,
        client: adapter.displayName,
      );
    }
  }
  final List<Directory> skillRoots = installed
      .map((AgentAdapter adapter) => adapter.resolvedGlobalSkillPath(home))
      .whereType<String>()
      .map(Directory.new)
      .toList(growable: false);
  final List<String> projectSkillRoots = installed
      .where((AgentAdapter adapter) => adapter.projectSkillPath != null)
      .map((AgentAdapter adapter) => adapter.resolvedProjectSkillPath())
      .toList(growable: false);
  final List<AgentPromptTarget> promptTargets = installed
      .map((AgentAdapter adapter) {
        final String? file = adapter.resolvedPromptFilePath(home);
        return file == null
            ? null
            : AgentPromptTarget(
                File(file),
                includeBridgeRoutingInstructions:
                    adapter.includeBridgeRoutingInstructions,
                clientName: adapter.displayName,
              );
      })
      .whereType<AgentPromptTarget>()
      .toList(growable: false);
  final List<AgentMcpTarget> mcpTargets = installed
      .map((AgentAdapter adapter) {
        final String? file = adapter.resolvedMcpFilePath(home);
        return file == null
            ? null
            : AgentMcpTarget(
                File(file),
                adapter.mcpKind!,
                clientName: adapter.displayName,
              );
      })
      .whereType<AgentMcpTarget>()
      .toList(growable: false);
  return _AgentResourceTargets(
    skillRoots: skillRoots,
    projectSkillRoots: projectSkillRoots,
    promptTargets: promptTargets,
    mcpTargets: mcpTargets,
    skillClientNames: <String, String>{
      for (final AgentAdapter adapter in installed)
        if (adapter.resolvedGlobalSkillPath(home) case final String root)
          path.normalize(root): adapter.displayName,
    },
    projectSkillClientNames: <String, String>{
      for (final AgentAdapter adapter in installed)
        if (adapter.projectSkillPath != null)
          path.normalize(adapter.resolvedProjectSkillPath()):
              adapter.displayName,
    },
    skillTargets: installed
        .where(
          (AgentAdapter adapter) =>
              adapter.globalSkillPath != null &&
              adapter.projectSkillPath != null,
        )
        .map(
          (AgentAdapter adapter) => AgentSkillTarget(
            agentId: adapter.id,
            clientName: adapter.displayName,
            globalRoot: Directory(adapter.resolvedGlobalSkillPath(home)!),
            projectRelativeRoot: adapter.resolvedProjectSkillPath(),
          ),
        )
        .toList(growable: false),
    externalSkillCatalogs: <AgentSkillCatalog>[
      if (installed.any((AgentAdapter adapter) => adapter.id == 'claude-code'))
        ClaudeCodePluginSkillCatalog(
          settingsFile: File(path.join(home, '.claude', 'settings.json')),
          installedPluginsFile: File(
            path.join(home, '.claude', 'plugins', 'installed_plugins.json'),
          ),
        ),
    ],
  );
}

/// Adds transactional synchronization without changing callers of ResourceStore.
final class SynchronizedResourceStore
    implements ResourceStore, ResourceUsageStore, ExclusiveResourceStore {
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
  List<Resource>? _lastLoaded;

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final ResourceStore delegate = _delegate;
    if (delegate is ResourceRepository) {
      return delegate.exclusive(action);
    }
    return action();
  }

  @override
  Future<T> exclusiveMutation<T>(Future<T> Function() action) =>
      _exclusive(action);

  @override
  Future<List<Resource>> load() async {
    final List<Resource> resources = await _delegate.load();
    _lastLoaded = List<Resource>.of(resources);
    return resources;
  }

  @override
  Future<void> save(List<Resource> resources) =>
      _exclusive(() => _saveLocked(resources));

  Future<void> _saveLocked(List<Resource> resources) async {
    final List<Resource> previous = await _delegate.load();
    final List<Resource> proposed = _mergeConcurrentResources(
      base: _lastLoaded ?? previous,
      current: previous,
      proposed: resources,
    );
    await _delegate.save(proposed);
    if (_onlyAgentResourceUsageChanged(previous, proposed)) {
      _lastLoaded = List<Resource>.of(proposed);
      onChanged?.call();
      return;
    }
    try {
      final List<AppIssue> issues = await _synchronizer.sync(proposed);
      await _cleanupRemovedPackages(previous, proposed);
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
      _lastLoaded = List<Resource>.of(previous);
      try {
        await _synchronizer.sync(previous);
      } on Object {
        // Preserve the original save failure; the resource file is rolled back.
      }
      await _cleanupRemovedPackages(proposed, previous);
      issueCenter?.replaceSource(agentResourceSyncIssueSource, issues);
      Error.throwWithStackTrace(error, stackTrace);
    }
    _lastLoaded = List<Resource>.of(proposed);
    onChanged?.call();
  }

  @override
  Future<List<Resource>> recordUsage(
    Set<String> resourceIds,
    DateTime usedAt,
  ) => _exclusive(() async {
    final List<Resource> latest = await _delegate.load();
    final List<Resource> updated = latest
        .map(
          (Resource resource) => resourceIds.contains(resource.id)
              ? resource.copyWith(
                  usageCount: resource.usageCount + 1,
                  lastUsedAt: usedAt,
                )
              : resource,
        )
        .toList(growable: false);
    await _delegate.save(updated);
    _lastLoaded = List<Resource>.of(updated);
    onChanged?.call();
    return updated;
  });

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

/// Keeps native Agent MCP files in sync when a trigger group changes without
/// requiring an unrelated resource edit to occur first.
final class SynchronizedTriggerGroupStore implements TriggerGroupStore {
  SynchronizedTriggerGroupStore(
    this._delegate,
    this._resourceStore,
    this._synchronizer, {
    this.issueCenter,
  });

  final TriggerGroupStore _delegate;
  final ResourceStore _resourceStore;
  final AgentResourceSynchronizer _synchronizer;
  final IssueCenterController? issueCenter;

  @override
  Future<List<TriggerGroup>> load() => _delegate.load();

  @override
  Future<void> save(List<TriggerGroup> groups) async {
    final List<TriggerGroup> previous = await _delegate.load();
    await _delegate.save(groups);
    try {
      final List<AppIssue> issues = await _synchronizer.sync(
        await _resourceStore.load(),
      );
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
        await _synchronizer.sync(await _resourceStore.load());
      } on Object {
        // Preserve the original save failure; the trigger-group file is
        // rolled back even if native configuration recovery also fails.
      }
      issueCenter?.replaceSource(agentResourceSyncIssueSource, issues);
      Error.throwWithStackTrace(error, stackTrace);
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
      AgentMcpConfigKind.kiroJson ||
      AgentMcpConfigKind.mcpServersJson => 'Bearer \${$variable}',
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
const String _managedGlobalSkillRootsStateKey = r'$dingdongGlobalSkillRoots';
const String _managedPromptTargetsStateKey = r'$dingdongPromptTargets';
const String _managedMcpTargetKindsStateKey = r'$dingdongMcpTargetKinds';

bool _isManagedStateKey(String value) => const <String>{
  _managedProjectSkillRootsStateKey,
  _managedGlobalSkillRootsStateKey,
  _managedPromptTargetsStateKey,
  _managedMcpTargetKindsStateKey,
}.contains(value);

void _normalizeManagedTargetPaths(Map<String, Set<String>> managed) {
  for (final MapEntry<String, Set<String>> entry in managed.entries.toList(
    growable: false,
  )) {
    if (_isManagedStateKey(entry.key)) {
      continue;
    }
    final String normalized = path.normalize(entry.key);
    if (normalized == entry.key) {
      continue;
    }
    managed.putIfAbsent(normalized, () => <String>{}).addAll(entry.value);
    managed.remove(entry.key);
  }
}

Set<String> _encodeManagedMcpTargetKinds(Map<String, AgentMcpTarget> targets) =>
    targets.entries
        .map(
          (MapEntry<String, AgentMcpTarget> entry) =>
              jsonEncode(<String, String>{
                'path': entry.key,
                'kind': entry.value.kind.configValue,
              }),
        )
        .toSet();

Map<String, AgentMcpConfigKind> _decodeManagedMcpTargetKinds(
  Set<String> encoded,
) {
  try {
    return <String, AgentMcpConfigKind>{
      for (final String value in encoded)
        if (jsonDecode(value) case final Map<String, Object?> item)
          path.normalize(item['path']! as String): AgentMcpConfigKind.parse(
            item['kind'],
            'managed MCP kind',
          ),
    };
  } on Object {
    throw const FormatException('DingDong Agent sync state is invalid.');
  }
}

AgentMcpConfigKind _inferMcpKind(File file) =>
    path.extension(file.path).toLowerCase() == '.toml'
    ? AgentMcpConfigKind.codexToml
    : AgentMcpConfigKind.mcpServersJson;

final RegExp _managedPromptsPattern = RegExp(
  '${RegExp.escape(_managedPromptsBegin)}.*?${RegExp.escape(_managedPromptsEnd)}\\s*',
  dotAll: true,
);

final RegExp _managedMcpBlockPattern = RegExp(
  r'^# BEGIN DINGDONG MCP .*?^# END DINGDONG MCP\s*\n?',
  multiLine: true,
  dotAll: true,
);

String _removeCodexMcpTables(String contents, Set<String> serverNames) {
  if (contents.isEmpty || serverNames.isEmpty) {
    return contents;
  }
  final Set<String> targetTables = serverNames
      .map((String name) => 'mcp_servers.$name')
      .toSet();
  final List<String> kept = <String>[];
  String? removingTable;
  for (final String line in contents.split('\n')) {
    final String? table = _tomlTablePath(line);
    if (table != null) {
      if (targetTables.contains(table)) {
        removingTable = table;
        continue;
      }
      final String? activeRemoval = removingTable;
      if (activeRemoval != null) {
        if (table.startsWith('$activeRemoval.')) {
          continue;
        }
        removingTable = null;
      }
    }
    if (removingTable == null) {
      kept.add(line);
    }
  }
  return kept.join('\n');
}

String? _tomlTablePath(String line) {
  final String trimmed = line.trim();
  if (!trimmed.startsWith('[')) {
    return null;
  }
  final bool arrayTable = trimmed.startsWith('[[');
  final String closing = arrayTable ? ']]' : ']';
  final int openingLength = arrayTable ? 2 : 1;
  final int end = trimmed.indexOf(closing, openingLength);
  if (end < openingLength) {
    return null;
  }
  final String trailing = trimmed.substring(end + closing.length).trimLeft();
  if (trailing.isNotEmpty && !trailing.startsWith('#')) {
    return null;
  }
  final String table = trimmed.substring(openingLength, end).trim();
  return table.isEmpty ? null : table;
}

void _rejectDuplicateTomlTables(String contents, String targetPath) {
  final Set<String> seen = <String>{};
  final Set<String> duplicates = <String>{};
  for (final String line in contents.split('\n')) {
    if (line.trimLeft().startsWith('[[')) {
      continue;
    }
    final String? table = _tomlTablePath(line);
    if (table != null && !seen.add(table)) {
      duplicates.add(table);
    }
  }
  if (duplicates.isEmpty) {
    return;
  }
  final List<String> sorted = duplicates.toList()..sort();
  throw FormatException(
    'Codex configuration contains duplicate TOML tables: '
    '${sorted.join(', ')}. $targetPath was not changed.',
  );
}

List<Resource> _mergeConcurrentResources({
  required List<Resource> base,
  required List<Resource> current,
  required List<Resource> proposed,
}) {
  final Map<String, Resource> baseById = <String, Resource>{
    for (final Resource resource in base) resource.id: resource,
  };
  final Map<String, Resource> currentById = <String, Resource>{
    for (final Resource resource in current) resource.id: resource,
  };
  final Map<String, Resource> proposedById = <String, Resource>{
    for (final Resource resource in proposed) resource.id: resource,
  };
  final List<Resource> merged = <Resource>[];
  for (final Resource candidate in proposed) {
    final Resource? baseline = baseById[candidate.id];
    final Resource? latest = currentById[candidate.id];
    if (baseline == null) {
      if (latest != null && latest != candidate) {
        throw StateError(
          'Resource "${candidate.title}" was created differently in another '
          'window. Reload before saving.',
        );
      }
      merged.add(latest ?? candidate);
      continue;
    }
    if (latest == null) {
      if (!_sameResourceConfiguration(candidate, baseline)) {
        throw StateError(
          'Resource "${candidate.title}" was deleted in another window. '
          'Reload before saving.',
        );
      }
      continue;
    }
    final bool latestChanged = !_sameResourceConfiguration(latest, baseline);
    final bool candidateChanged = !_sameResourceConfiguration(
      candidate,
      baseline,
    );
    if (latestChanged &&
        candidateChanged &&
        !_sameResourceConfiguration(latest, candidate)) {
      throw StateError(
        'Resource "${candidate.title}" changed in another window. Reload '
        'before saving so delivery, scope, and Hook switches are not '
        'overwritten.',
      );
    }
    if (latestChanged && !candidateChanged) {
      merged.add(latest);
    } else {
      merged.add(_mergeUsageMetadata(candidate, latest, baseline));
    }
  }
  for (final Resource baseline in base) {
    if (proposedById.containsKey(baseline.id)) {
      continue;
    }
    final Resource? latest = currentById[baseline.id];
    if (latest != null && !_sameResourceConfiguration(latest, baseline)) {
      throw StateError(
        'Resource "${baseline.title}" changed in another window and cannot '
        'be deleted from a stale view. Reload before saving.',
      );
    }
  }
  for (final Resource latest in current) {
    if (!baseById.containsKey(latest.id) &&
        !proposedById.containsKey(latest.id)) {
      merged.add(latest);
    }
  }
  return merged;
}

bool _sameResourceConfiguration(Resource first, Resource second) {
  final Map<String, Object?> firstJson = first.toJson()
    ..remove('usageCount')
    ..remove('lastUsedAt');
  final Map<String, Object?> secondJson = second.toJson()
    ..remove('usageCount')
    ..remove('lastUsedAt');
  return jsonEncode(firstJson) == jsonEncode(secondJson);
}

Resource _mergeUsageMetadata(
  Resource candidate,
  Resource latest,
  Resource baseline,
) {
  final bool latestChanged =
      latest.usageCount != baseline.usageCount ||
      latest.lastUsedAt != baseline.lastUsedAt;
  final bool candidateChanged =
      candidate.usageCount != baseline.usageCount ||
      candidate.lastUsedAt != baseline.lastUsedAt;
  final int usageCount = latestChanged && candidateChanged
      ? max(latest.usageCount, candidate.usageCount)
      : latestChanged
      ? latest.usageCount
      : candidate.usageCount;
  final DateTime? lastUsedAt = latestChanged && candidateChanged
      ? _laterDate(latest.lastUsedAt, candidate.lastUsedAt)
      : latestChanged
      ? latest.lastUsedAt
      : candidate.lastUsedAt;
  final Map<String, Object?> json = candidate.toJson();
  json['usageCount'] = usageCount;
  if (lastUsedAt != null) {
    json['lastUsedAt'] = lastUsedAt.toIso8601String();
  } else {
    json.remove('lastUsedAt');
  }
  return Resource.fromJson(json);
}

DateTime? _laterDate(DateTime? first, DateTime? second) {
  if (first == null) {
    return second;
  }
  if (second == null) {
    return first;
  }
  return first.isAfter(second) ? first : second;
}

bool _onlyAgentResourceUsageChanged(
  List<Resource> previous,
  List<Resource> current,
) {
  if (previous.length != current.length) {
    return false;
  }
  bool usageChanged = false;
  for (int index = 0; index < previous.length; index += 1) {
    usageChanged =
        usageChanged ||
        previous[index].usageCount != current[index].usageCount ||
        previous[index].lastUsedAt != current[index].lastUsedAt;
    final Map<String, Object?> before = previous[index].toJson()
      ..remove('usageCount')
      ..remove('lastUsedAt');
    final Map<String, Object?> after = current[index].toJson()
      ..remove('usageCount')
      ..remove('lastUsedAt');
    if (jsonEncode(before) != jsonEncode(after)) {
      return false;
    }
  }
  return usageChanged;
}

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
