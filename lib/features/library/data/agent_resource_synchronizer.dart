import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dingdong/core/files/safe_managed_file.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/serialization/strict_json.dart';
import 'package:dingdong/features/agent_adapters/data/codex_completion_hook_gateway.dart';
import 'package:dingdong/features/agent_adapters/domain/agent_adapter.dart';
import 'package:dingdong/features/agent_api/data/agent_installer_edits.dart'
    as installer_edits;
import 'package:dingdong/features/agent_api/domain/agent_bridge_guidance.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/library/data/agent_skill_catalog.dart';
import 'package:dingdong/features/library/data/codex_project_hook_inventory.dart';
import 'package:dingdong/features/library/data/native_skill_delivery_coordinator.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/skill_deployment_store.dart';
import 'package:dingdong/features/library/data/skill_version_history.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resources.dart';
import 'package:dingdong/features/library/domain/managed_mcp_identity.dart';
import 'package:dingdong/features/library/domain/project_hook_integration.dart';
import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:dingdong/features/library/domain/resource_scope_policy.dart';
import 'package:dingdong/features/library/domain/skill_deployment_plan.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:dingdong/features/library/domain/skill_version.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:path/path.dart' as path;

// The synchronizer owns orchestration; target discovery, persistence codecs,
// and conflict merging live in focused private parts of the same library.
part 'agent_resource_concurrent_merge.dart';
part 'agent_resource_duplicate_cleanup.dart';
part 'agent_resource_serialization.dart';
part 'agent_resource_targets.dart';
part 'synchronized_resource_store.dart';

final class AgentPromptTarget {
  const AgentPromptTarget(
    this.file, {
    this.includeBridgeRoutingInstructions = true,
    this.clientName = 'Agent',
    this.mcpFile,
    this.mcpKind,
  });

  final File file;
  final bool includeBridgeRoutingInstructions;
  final String clientName;

  /// The same client's MCP configuration. When known, the Bridge bootstrap is
  /// written only while that configuration declares a `dingdong` server, so
  /// the client is never told to call a tool it does not have.
  final File? mcpFile;
  final AgentMcpConfigKind? mcpKind;
}

final class AgentMcpTarget {
  const AgentMcpTarget(
    this.file,
    this.kind, {
    this.clientName = 'Agent',
    this.additionalClientNames = const <String>[],
  });

  final File file;
  final AgentMcpConfigKind kind;
  final String clientName;
  final List<String> additionalClientNames;
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

  /// In [sandbox] mode, resources stay local to DingDong's own data directory.
  /// Agent discovery and recovery of earlier live-target state are excluded.
  static Future<AgentResourceSynchronizer> currentUser(
    Directory packageRoot, {
    required AgentAdapterLoader loadAdapters,
    SkillPackageInstaller? skillPackageInstaller,
    TriggerGroupStore? triggerGroupStore,
    String? homeDirectory,
    CodexProjectHookInventory? projectHookInventory,
    bool sandbox = false,
  }) async {
    if (sandbox) {
      final Directory stateRoot = Directory(
        path.join(packageRoot.parent.path, 'Agent Sync Sandbox'),
      );
      return AgentResourceSynchronizer(
        packageRoot: packageRoot,
        skillRoots: const <Directory>[],
        mcpTargets: const <AgentMcpTarget>[],
        triggerGroupStore: triggerGroupStore,
        managedStateFile: File(
          path.join(stateRoot.path, 'agent-sync-state.json'),
        ),
        deploymentStore: SkillDeploymentStore(
          Directory(path.join(stateRoot.path, 'Skill Deployments')),
        ),
        skillPackageInstaller: skillPackageInstaller,
      );
    }
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

  Future<List<AppIssue>> sync(List<Resource> resources) =>
      SafeManagedFile(managedStateFile).exclusive(() => _syncLocked(resources));

  Future<List<AppIssue>> _syncLocked(List<Resource> resources) async {
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
            target != null &&
            target.includeBridgeRoutingInstructions &&
            await _declaresDingDongServer(target),
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
      final Set<String> currentNames = targetMcps
          .map(
            (Resource resource) =>
                managedMcpServerName(title: resource.title, id: resource.id),
          )
          .toSet();
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
    return resources
        .where(
          (Resource resource) =>
              (triggerGroupStore == null ||
                  _mcpSourcePermissions(
                    resource,
                    target,
                    triggerGroupsById,
                  ).every((bool allowed) => allowed)) &&
              _mcpSupportedForTarget(resource, target),
        )
        .toList(growable: false);
  }

  List<bool> _mcpSourcePermissions(
    Resource resource,
    AgentMcpTarget target,
    Map<String, TriggerGroup> triggerGroupsById,
  ) => <String>[target.clientName, ...target.additionalClientNames]
      .map(
        (source) =>
            resourceCanSyncToAgentSource(resource, source, triggerGroupsById),
      )
      .toList(growable: false);

  bool _mcpSupportedForTarget(Resource resource, AgentMcpTarget target) {
    if (target.kind != AgentMcpConfigKind.antigravityJson) return true;
    try {
      final config = McpConfiguration.parse(resource.content);
      return config.tokenEnvironmentVariable.isEmpty ||
          config.headers.containsKey('Authorization');
    } on Object {
      // Invalid resources are reported separately by _inspect.
      return true;
    }
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
    AgentMcpConfigKind.openCodeJson ||
    AgentMcpConfigKind.antigravityJson ||
    AgentMcpConfigKind.copilotJson ||
    AgentMcpConfigKind.mcpServersJson => _syncJson(
      file,
      kind,
      resources,
      previousNames,
    ),
  };

  // The Bridge bootstrap tells a client to call `dingdong_bridge` on every task,
  // so it is written only for clients whose MCP configuration declares the
  // DingDong server. A detected but unconnected client gets no instruction to
  // call a tool it does not have; connecting it adds the block on next sync.
  Future<bool> _declaresDingDongServer(AgentPromptTarget target) async {
    final File? file = target.mcpFile;
    final AgentMcpConfigKind? kind = target.mcpKind;
    if (file == null || kind == null) return true;
    final String contents;
    try {
      if (!await file.exists()) return false;
      contents = await file.readAsString();
    } on FileSystemException {
      return false;
    }
    if (kind == AgentMcpConfigKind.codexToml) {
      return RegExp(
        r'^\s*\[mcp_servers\.(?:dingdong|"dingdong")\]\s*$',
        multiLine: true,
      ).hasMatch(contents);
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(contents);
    } on FormatException {
      return false;
    }
    if (decoded is! Map) return false;
    bool declares(Object? servers) =>
        servers is Map && servers.containsKey('dingdong');
    if (declares(decoded[_mcpServersKey(kind)])) return true;
    // Claude Code also keeps local-scope servers under each project.
    final Object? projects = decoded['projects'];
    return kind == AgentMcpConfigKind.claudeJson &&
        projects is Map &&
        projects.values.any(
          (Object? project) =>
              project is Map && declares(project['mcpServers']),
        );
  }

  Future<void> _syncPrompts(
    File file, {
    required bool includeBridgeRoutingInstructions,
  }) => SafeManagedFile(file).update((ManagedFileSnapshot snapshot) {
    String? next = snapshot.exists ? snapshot.contents : null;
    // Collapse earlier duplicate managed blocks using the installer's codec.
    while (true) {
      final cleaned = installer_edits.MarkdownBlock.remove(
        next,
        _managedPromptsBegin,
        _managedPromptsEnd,
      );
      if (cleaned == next) break;
      next = cleaned;
    }
    if (includeBridgeRoutingInstructions) {
      next = installer_edits.MarkdownBlock.set(
        next,
        _managedPromptsBegin,
        _managedPromptsEnd,
        dingDongAgentBridgeGuidance.trim(),
      );
    }
    return next;
  });

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
    final Map<String, TriggerGroup> triggerGroupsById =
        await _loadTriggerGroups();
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
      for (final Resource resource in mcps) {
        final List<bool> permissions = triggerGroupStore == null
            ? <bool>[true]
            : _mcpSourcePermissions(resource, target, triggerGroupsById);
        if (permissions.any((allowed) => allowed) &&
            !permissions.every((allowed) => allowed)) {
          issues.add(
            _issue(
              resource: resource,
              kind: AppIssueKind.sharedMcpScopeConflict,
              severity: AppIssueSeverity.warning,
              title: 'MCP scope cannot be isolated in a shared configuration',
              detail:
                  'This MCP was not written because the shared configuration is read by clients outside its source scope.',
              clientName: target.clientName,
              targetPath: target.file.path,
            ),
          );
        } else if (permissions.every((allowed) => allowed) &&
            !_mcpSupportedForTarget(resource, target)) {
          issues.add(
            _issue(
              resource: resource,
              kind: AppIssueKind.unsupportedMcpAuthentication,
              severity: AppIssueSeverity.warning,
              title: 'MCP authentication is not supported by this client',
              detail:
                  'Antigravity does not support this environment-variable bearer token configuration.',
              clientName: target.clientName,
              targetPath: target.file.path,
            ),
          );
        }
      }
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
        final String serversKey = _mcpServersKey(target.kind);
        final Object? servers = decoded[serversKey];
        if (servers != null && servers is! Map) {
          throw FormatException('$serversKey must be a JSON object.');
        }
        if (servers is Map) {
          issues.addAll(
            _duplicateMcpIssues(
              target,
              servers,
              _mcpResourcesForTarget(mcps, target, triggerGroupsById),
            ),
          );
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

  /// Warns when a user-managed server in an Agent's JSON file points at the
  /// same endpoint as a DingDong-managed MCP. Both copies load their tools on
  /// every request, so an unnoticed duplicate silently doubles the cost.
  Iterable<AppIssue> _duplicateMcpIssues(
    AgentMcpTarget target,
    Map<Object?, Object?> servers,
    List<Resource> mcps,
  ) sync* {
    final Map<String, Resource> managedByEndpoint = <String, Resource>{};
    final Set<String> managedNames = <String>{};
    for (final Resource resource in mcps) {
      managedNames.add(
        managedMcpServerName(title: resource.title, id: resource.id),
      );
      try {
        final String? endpoint = _mcpEndpointKey(
          McpConfiguration.parse(resource.content),
        );
        if (endpoint != null) managedByEndpoint[endpoint] = resource;
      } on Object {
        // Invalid managed MCPs are reported separately.
      }
    }
    if (managedByEndpoint.isEmpty) return;
    for (final MapEntry<Object?, Object?> entry in servers.entries) {
      final Object? name = entry.key;
      final Object? value = entry.value;
      if (name is! String || managedNames.contains(name) || value is! Map) {
        continue;
      }
      final Object? url =
          value['url'] ?? value['httpUrl'] ?? value['serverUrl'];
      final Object? command = value['command'];
      final Object? args = value['args'];
      final String? endpoint = url is String
          ? _normalizedMcpUrl(url)
          : command is String && command.trim().isNotEmpty
          ? _commandEndpointKey(
              command,
              args is List ? args.whereType<String>().toList() : <String>[],
            )
          : command is List &&
                command.isNotEmpty &&
                command.every((v) => v is String) &&
                (command.first as String).trim().isNotEmpty
          ? _commandEndpointKey(
              command.first as String,
              command.skip(1).cast<String>().toList(),
            )
          : null;
      final Resource? managed = endpoint == null
          ? null
          : managedByEndpoint[endpoint];
      if (managed == null) continue;
      yield AppIssue(
        id: '${_issueId(AppIssueKind.duplicateMcp, managed.id, target.file.path)}:${jsonEncode(name)}',
        source: agentResourceSyncIssueSource,
        resourceId: managed.id,
        resourceTitle: managed.title,
        kind: AppIssueKind.duplicateMcp,
        severity: AppIssueSeverity.warning,
        title: 'Duplicate MCP server',
        detail:
            '"$name" in ${target.clientName} uses the same endpoint as the '
            'DingDong-managed "${managed.title}". Both load their tools on '
            'every request; remove the copy you no longer need.',
        clientName: '${target.clientName} · $name',
        targetPath: target.file.path,
        duplicateEntryName: name,
      );
    }
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
  ) => SafeManagedFile(file).update(
    (ManagedFileSnapshot snapshot) {
      Map<String, Object?> root = <String, Object?>{};
      if (snapshot.contents.trim().isNotEmpty) {
        root = Map<String, Object?>.from(
          decodeStrictJson(snapshot.contents) as Map,
        );
      }
      final String serversKey = _mcpServersKey(kind);
      final servers = root[serversKey];
      if (servers != null && servers is! Map) {
        throw FormatException('$serversKey must be an object.');
      }
      String? next = snapshot.contents.trim().isEmpty
          ? '{}'
          : snapshot.contents;
      for (final name in previousNames) {
        next = installer_edits.JsonEdit.remove(next, [serversKey, name]);
      }
      for (final resource in resources) {
        next = installer_edits.JsonEdit.set(
          next,
          [
            serversKey,
            managedMcpServerName(title: resource.title, id: resource.id),
          ],
          _jsonMcp(
            McpConfiguration.parse(resource.content),
            kind,
            activation: resource.activation,
          ),
        );
      }
      // Preserve the established empty-map contract for user-owned config files.
      return next ?? '{}';
    },
    validate: (String value) => decodeStrictJson(value) as Map<String, Object?>,
  );

  Future<void> _syncCodex(
    File file,
    List<Resource> resources,
    Set<String> previousNames,
  ) => SafeManagedFile(file).update((ManagedFileSnapshot snapshot) {
    final current = snapshot.contents;
    final names = <String>{
      ...previousNames,
      for (final resource in resources)
        managedMcpServerName(title: resource.title, id: resource.id),
    };
    String? next = current.replaceAll(_managedMcpBlockPattern, '');
    _rejectDuplicateTomlTables(next, file.path);
    for (final name in names) {
      next = installer_edits.CodexToml.removeServer(next, name);
    }
    for (final resource in resources) {
      final config = McpConfiguration.parse(resource.content);
      final Map<String, Object?> entry;
      if (config.transport == McpTransport.stdio) {
        entry = {
          'command': config.command,
          if (config.arguments.isNotEmpty) 'args': config.arguments,
          if (config.environment.isNotEmpty) 'env': config.environment,
        };
      } else if (config.transport == McpTransport.streamableHttp) {
        entry = {
          'url': config.url,
          if (config.tokenEnvironmentVariable.isNotEmpty)
            'bearer_token_env_var': config.tokenEnvironmentVariable,
          if (config.headers.isNotEmpty) 'http_headers': config.headers,
        };
      } else {
        throw FormatException('MCP ${resource.title} must use STDIO or HTTP.');
      }
      next = installer_edits.CodexToml.setServer(
        next,
        managedMcpServerName(title: resource.title, id: resource.id),
        {...entry, 'enabled': true},
      );
    }
    final result = next ?? '';
    _rejectDuplicateTomlTables(result, file.path);
    return result.isEmpty ? '' : '${result.trimRight()}\n';
  });

  Future<Map<String, Set<String>>> _readManagedMcpState() async {
    final ManagedFileSnapshot snapshot = await SafeManagedFile(
      managedStateFile,
    ).snapshot();
    if (!snapshot.exists) {
      return <String, Set<String>>{};
    }
    try {
      final Map<String, Object?> decoded = Map<String, Object?>.from(
        decodeStrictJson(snapshot.contents) as Map,
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
    final String contents = const JsonEncoder.withIndent('  ')
        .convert(<String, Object?>{
          for (final MapEntry<String, Set<String>> entry in managed.entries)
            entry.key: entry.value.toList(growable: false)..sort(),
        });
    await SafeManagedFile(managedStateFile).update(
      (_) => contents,
      validate: (String value) =>
          decodeStrictJson(value) as Map<String, Object?>,
    );
  }
}
