import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/utils/uuid.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/skill_deployment_store.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resources.dart';
import 'package:dingdong/features/library/domain/knowledge_indexer.dart';
import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:dingdong/features/library/domain/library_importer.dart';
import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:dingdong/features/library/domain/resource_scope_policy.dart';
import 'package:dingdong/features/library/domain/resource_update_fetcher.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:path/path.dart' as path;

/// Handles resource-library reads and mutations that share the public API.
final class LibraryRoutes {
  LibraryRoutes(
    this._store, {
    TriggerGroupStore? triggerGroupStore,
    SkillPackageInstaller? skillPackageInstaller,
    ResourceUpdateFetcher? updateFetcher,
    SkillDeploymentStore? skillDeploymentStore,
    DateTime Function()? now,
    String Function()? idGenerator,
  }) : // Named private initializing formals are not callable cross-library.
       // ignore: prefer_initializing_formals
       _triggerGroupStore = triggerGroupStore,
       // Named private initializing formals are not callable cross-library.
       // ignore: prefer_initializing_formals
       _skillPackageInstaller = skillPackageInstaller,
       // Named private initializing formals are not callable cross-library.
       // ignore: prefer_initializing_formals
       _skillDeploymentStore = skillDeploymentStore,
       _updateFetcher = updateFetcher ?? HttpResourceUpdateFetcher(),
       _idGenerator = idGenerator ?? generateUuid,
       _now = now ?? _utcNow,
       _importer = LibraryImporter(now: now, idGenerator: idGenerator);

  static const int _maximumExportLimit = 100000;

  final ResourceStore _store;
  final TriggerGroupStore? _triggerGroupStore;
  final SkillPackageInstaller? _skillPackageInstaller;
  final SkillDeploymentStore? _skillDeploymentStore;
  final ResourceUpdateFetcher _updateFetcher;
  final String Function() _idGenerator;
  final DateTime Function() _now;
  final LibraryImporter _importer;
  final KnowledgeIndexer _knowledgeIndexer = KnowledgeIndexer();

  Future<T> _exclusiveMutation<T>(Future<T> Function() action) {
    final ResourceStore store = _store;
    final ExclusiveResourceStore? exclusive = store is ExclusiveResourceStore
        ? store as ExclusiveResourceStore
        : null;
    return exclusive == null ? action() : exclusive.exclusiveMutation(action);
  }

  Future<HttpResponseData> installSkill(String body) =>
      _exclusiveMutation(() => _installSkill(body));

  Future<HttpResponseData> _installSkill(String body) async {
    final SkillPackageInstaller? installer = _skillPackageInstaller;
    if (installer == null) {
      return const HttpResponseData(
        statusCode: 503,
        json: <String, Object?>{
          'status': 'error',
          'message': 'Skill installation is not available',
        },
      );
    }
    try {
      final Map<String, Object?> payload =
          jsonDecode(body) as Map<String, Object?>;
      final String source = (payload['source'] as String? ?? '').trim();
      final Uri? sourceUri = parseSkillPackageSource(source);
      if (sourceUri == null ||
          (sourceUri.scheme != 'https' && sourceUri.scheme != 'file')) {
        return _invalidUpdate(
          'source must be an HTTPS GitHub Skill URL or absolute local Skill path',
        );
      }
      final String sourceReference =
          (payload['sourceReference'] as String? ?? '').trim();
      final Uri? sourceReferenceUri = sourceReference.isEmpty
          ? null
          : parseSkillPackageSource(sourceReference);
      if (sourceReference.isNotEmpty &&
          (sourceUri.scheme != 'file' ||
              sourceReferenceUri == null ||
              sourceReferenceUri.scheme != 'file')) {
        return _invalidUpdate(
          'sourceReference must be an absolute local Skill path',
        );
      }
      final Uri identitySource = sourceReferenceUri ?? sourceUri;
      final String normalizedSource = identitySource.toString();
      final String sourceKey = await skillPackageSourceKey(identitySource);
      final List<Resource> resources = List<Resource>.of(await _store.load());
      final List<Resource> sourceMatches = <Resource>[];
      for (final Resource resource in resources) {
        if (resource.type != ResourceType.skill || resource.updateUrl == null) {
          continue;
        }
        final Uri? installedSource = parseSkillPackageSource(
          resource.updateUrl!,
        );
        if (installedSource == null) {
          continue;
        }
        String installedSourceKey;
        try {
          installedSourceKey = await skillPackageSourceKey(installedSource);
        } on FormatException {
          installedSourceKey = installedSource.toString();
        }
        if (installedSourceKey == sourceKey) {
          sourceMatches.add(resource);
        }
      }
      if (sourceMatches.length > 1) {
        return _skillConflict(
          'Multiple resources already use this Skill source.',
          code: 'skill_source_conflict',
        );
      }
      final String explicitResourceId = (payload['resourceId'] as String? ?? '')
          .trim();
      final Resource? explicitResource = explicitResourceId.isEmpty
          ? null
          : resources
                .where(
                  (Resource resource) =>
                      resource.type == ResourceType.skill &&
                      resource.id == explicitResourceId,
                )
                .firstOrNull;
      if (explicitResourceId.isNotEmpty && explicitResource == null) {
        return _resourceNotFound();
      }
      if (explicitResource != null &&
          sourceMatches.isNotEmpty &&
          sourceMatches.single.id != explicitResource.id) {
        return _skillConflict(
          'The requested resource and Skill source identify different resources.',
          code: 'skill_identity_conflict',
        );
      }
      final Resource? sourceExisting =
          explicitResource ?? sourceMatches.firstOrNull;
      final String targetResourceId = sourceExisting?.id ?? _idGenerator();
      final ResourceKeyedSkillPackageInstaller? keyedInstaller =
          installer is ResourceKeyedSkillPackageInstaller
          ? installer as ResourceKeyedSkillPackageInstaller
          : null;
      final SkillPackageInstallResult installed = keyedInstaller == null
          ? await installer.install(sourceUri)
          : await keyedInstaller.installForResource(
              sourceUri,
              resourceId: targetResourceId,
            );
      final SkillConfiguration skill = SkillConfiguration.parseOnline(
        installed.skillDocument,
      );
      final List<Resource> nameMatches = resources
          .where(
            (Resource resource) =>
                resource.type == ResourceType.skill &&
                _onlineSkillName(resource) == skill.name,
          )
          .toList(growable: false);
      if (nameMatches.length > 1) {
        await keyedInstaller?.rollback(installed);
        return _skillConflict(
          'Multiple resources already use this Skill name.',
          code: 'skill_name_conflict',
        );
      }
      final Resource? sameName = nameMatches.firstOrNull;
      if (sameName != null &&
          (sourceExisting == null || sameName.id != sourceExisting.id)) {
        await keyedInstaller?.rollback(installed);
        return _skillConflict(
          'A different Skill source already uses the name "${skill.name}".',
          code: 'skill_name_conflict',
        );
      }
      final Resource? existing = sourceExisting ?? sameName;
      if (existing != null &&
          existing.skillPackageDigest != null &&
          existing.skillPackageDigest == installed.packageDigest &&
          existing.content == installed.skillDocument &&
          existing.packagePath != null &&
          path.equals(
            path.normalize(path.absolute(existing.packagePath!)),
            path.normalize(path.absolute(installed.directoryPath)),
          )) {
        return HttpResponseData(
          statusCode: 200,
          json: <String, Object?>{
            'status': 'unchanged',
            'item': existing.toApiJson(),
          },
        );
      }
      final DateTime timestamp = _now().toUtc();
      final String title = (payload['title'] as String? ?? '').trim();
      final String group = (payload['group'] as String? ?? '').trim();
      final List<String>? tags = payload['tags'] == null
          ? null
          : (payload['tags'] as List<Object?>)
                .map((Object? value) => value as String)
                .toList(growable: false);
      final Resource resource;
      final int? existingIndex = existing == null
          ? null
          : resources.indexWhere((Resource item) => item.id == existing.id);
      if (existing == null) {
        resource = Resource(
          id: targetResourceId,
          type: ResourceType.skill,
          group: group.isEmpty ? null : group,
          title: title.isEmpty ? skill.name : title,
          content: installed.skillDocument,
          tags: tags ?? const <String>[],
          source: 'DingDong MCP',
          updateUrl: normalizedSource,
          packagePath: installed.directoryPath,
          skillPackageDigest: installed.packageDigest.isEmpty
              ? null
              : installed.packageDigest,
          enabled: false,
          activation: ResourceActivation.taskMatch,
          createdAt: timestamp,
          updatedAt: timestamp,
        );
        try {
          await _store.save(<Resource>[...resources, resource]);
        } on Object {
          await keyedInstaller?.rollback(installed);
          rethrow;
        }
      } else {
        resource = existing.copyWith(
          group: group.isEmpty ? existing.group : group,
          title: title.isEmpty ? existing.title : title,
          content: installed.skillDocument,
          tags: tags,
          updateUrl: normalizedSource,
          packagePath: installed.directoryPath,
          skillPackageDigest: installed.packageDigest.isEmpty
              ? existing.skillPackageDigest
              : installed.packageDigest,
          enabled: existing.enabled,
          updatedAt: timestamp,
        );
        resources[existingIndex!] = resource;
        try {
          await _store.save(resources);
        } on Object {
          await keyedInstaller?.rollback(installed);
          rethrow;
        }
      }
      return HttpResponseData(
        statusCode: existing == null ? 201 : 200,
        json: <String, Object?>{
          'status': existing == null ? 'created' : 'updated',
          'item': resource.toApiJson(),
        },
      );
    } on Object catch (error) {
      return HttpResponseData(
        statusCode: 400,
        json: <String, Object?>{'status': 'error', 'message': error.toString()},
      );
    }
  }

  Future<HttpResponseData> setSkillDelivery(String id, String body) =>
      _exclusiveMutation(() => _setSkillDelivery(id, body));

  Future<HttpResponseData> _setSkillDelivery(String id, String body) async {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) {
        return _invalidUpdate('Skill delivery body must be a JSON object');
      }
      const Set<String> allowedKeys = <String>{
        'enabled',
        'agentId',
        'mode',
        'hooksEnabled',
        'projectPaths',
      };
      final List<String> unknownKeys = decoded.keys
          .where((String key) => !allowedKeys.contains(key))
          .toList(growable: false);
      if (unknownKeys.isNotEmpty) {
        return _invalidUpdate(
          'Unknown Skill delivery fields: ${unknownKeys.join(', ')}',
        );
      }
      final String agentId = (decoded['agentId'] as String? ?? '').trim();
      if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(agentId)) {
        return _invalidUpdate('agentId must be a lowercase Agent Adapter id');
      }
      final SkillDeliveryMode mode = SkillDeliveryMode.parse(decoded['mode']);
      final bool hooksEnabled = decoded['hooksEnabled'] as bool? ?? false;
      final List<String> requestedProjectPaths =
          (decoded['projectPaths'] as List<Object?>? ?? const <Object?>[])
              .map((Object? value) => (value as String).trim())
              .where((String value) => value.isNotEmpty)
              .toSet()
              .toList(growable: false);
      final List<String> projectPaths = <String>[];
      for (final String requested in requestedProjectPaths) {
        final String normalized = path.normalize(path.absolute(requested));
        if (!path.isAbsolute(requested) ||
            path.equals(normalized, path.dirname(normalized)) ||
            !Directory(normalized).existsSync()) {
          return _invalidUpdate(
            'nativeProject requires an existing absolute project path',
          );
        }
        projectPaths.add(Directory(normalized).resolveSymbolicLinksSync());
      }
      if (mode == SkillDeliveryMode.nativeProject && projectPaths.isEmpty) {
        return _invalidUpdate(
          'nativeProject requires an existing absolute project path',
        );
      }
      if (mode != SkillDeliveryMode.nativeProject &&
          (projectPaths.isNotEmpty || hooksEnabled)) {
        return _invalidUpdate(
          'Project paths and Hooks require nativeProject delivery',
        );
      }

      final List<Resource> resources = List<Resource>.of(await _store.load());
      final int index = resources.indexWhere(
        (Resource resource) =>
            resource.id == id && resource.type == ResourceType.skill,
      );
      if (index < 0) {
        return _resourceNotFound();
      }
      final Resource existing = resources[index];
      if (hooksEnabled &&
          (agentId != 'codex' || _onlineSkillName(existing) != 'impeccable')) {
        return _invalidUpdate(
          'Managed Hooks are currently available only for Impeccable on Codex',
        );
      }
      final bool anotherAgentUsesProjectDelivery = existing
          .skillDeliveryByAgent
          .entries
          .any(
            (MapEntry<String, SkillDeliveryMode> entry) =>
                entry.key != agentId &&
                entry.value == SkillDeliveryMode.nativeProject,
          );
      final bool anotherAgentUsesUserDelivery = existing
          .skillDeliveryByAgent
          .entries
          .any(
            (MapEntry<String, SkillDeliveryMode> entry) =>
                entry.key != agentId &&
                entry.value == SkillDeliveryMode.nativeUser,
          );
      if ((mode == SkillDeliveryMode.nativeUser &&
              anotherAgentUsesProjectDelivery) ||
          (mode == SkillDeliveryMode.nativeProject &&
              anotherAgentUsesUserDelivery)) {
        return _skillConflict(
          'One Skill cannot mix user-native and project-native delivery '
          'across Agents.',
          code: 'skill_native_scope_conflict',
        );
      }
      if (mode == SkillDeliveryMode.nativeProject &&
          anotherAgentUsesProjectDelivery &&
          !_sameStringSet(projectPaths, existing.skillProjectPaths)) {
        return _skillConflict(
          'Project-native delivery uses one shared exact project scope across '
          'all Agents for this Skill.',
          code: 'skill_project_scope_conflict',
        );
      }
      final Map<String, SkillDeliveryMode> delivery =
          <String, SkillDeliveryMode>{...existing.skillDeliveryByAgent};
      final Map<String, bool> hooks = <String, bool>{
        ...existing.skillHooksEnabledByAgent,
      };
      if (mode == SkillDeliveryMode.dynamic) {
        delivery.remove(agentId);
      } else {
        delivery[agentId] = mode;
      }
      if (hooksEnabled) {
        hooks[agentId] = true;
      } else {
        hooks.remove(agentId);
      }
      final bool hasProjectNative = delivery.values.any(
        (SkillDeliveryMode value) => value == SkillDeliveryMode.nativeProject,
      );
      final List<String> resolvedProjectPaths =
          mode == SkillDeliveryMode.nativeProject
          ? (anotherAgentUsesProjectDelivery
                ? existing.skillProjectPaths
                : (List<String>.of(projectPaths)..sort()))
          : (hasProjectNative ? existing.skillProjectPaths : const <String>[]);
      final Resource candidate = existing.copyWith(
        enabled: decoded['enabled'] as bool? ?? existing.enabled,
        triggerGroupIds: mode == SkillDeliveryMode.nativeUser
            ? const <String>[]
            : existing.triggerGroupIds,
        skillDeliveryByAgent: delivery,
        skillHooksEnabledByAgent: hooks,
        strictProjectSkill: hasProjectNative,
        skillProjectPaths: resolvedProjectPaths,
      );
      if (candidate == existing) {
        return HttpResponseData(
          statusCode: 200,
          json: <String, Object?>{
            'status': 'unchanged',
            'item': existing.toApiJson(),
            ..._skillDeliveryGuidance(
              mode: mode,
              enabled: existing.enabled,
              changed: false,
            ),
          },
        );
      }
      final Resource updated = candidate.copyWith(updatedAt: _now().toUtc());
      resources[index] = updated;
      await _store.save(resources);
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': 'updated',
          'item': updated.toApiJson(),
          ..._skillDeliveryGuidance(
            mode: mode,
            enabled: updated.enabled,
            changed: true,
          ),
        },
      );
    } on Object catch (error) {
      return HttpResponseData(
        statusCode: 400,
        json: <String, Object?>{'status': 'error', 'message': error.toString()},
      );
    }
  }

  static Map<String, Object?> _skillDeliveryGuidance({
    required SkillDeliveryMode mode,
    required bool enabled,
    required bool changed,
  }) {
    if (mode == SkillDeliveryMode.dynamic) {
      return <String, Object?>{
        'discovery': 'bridgeAfterNativeAbsenceVerified',
        'taskBoundaryRecommended': changed,
        'restartAgentIfMissing': false,
        'message': enabled
            ? 'Dynamic delivery becomes available through a new Agent task '
                  'after DingDong verifies native copies are absent.'
            : 'Dynamic delivery is configured but the Skill master switch is off.',
      };
    }
    return <String, Object?>{
      'discovery': 'automaticNativeScan',
      'taskBoundaryRecommended': changed,
      'restartAgentIfMissing': enabled,
      'message': enabled
          ? 'Supported Agents discover native Skill changes automatically; '
                'start a new task, and restart the Agent only if the Skill is '
                'still missing.'
          : 'Native delivery is configured but the Skill master switch is off.',
    };
  }

  static bool _sameStringSet(List<String> first, List<String> second) =>
      first.length == second.length && first.toSet().containsAll(second);

  Future<HttpResponseData> skillDeployments(String id) async {
    final SkillDeploymentStore? store = _skillDeploymentStore;
    if (store == null) {
      return const HttpResponseData(
        statusCode: 503,
        json: <String, Object?>{
          'status': 'error',
          'message': 'Native Skill deployment state is not available',
        },
      );
    }
    final Resource? resource = (await _store.load())
        .where(
          (Resource value) =>
              value.id == id && value.type == ResourceType.skill,
        )
        .firstOrNull;
    if (resource == null) {
      return _resourceNotFound();
    }
    final SkillDeploymentObservedState observed = await store.readObserved();
    final SkillDeploymentJournal journal = await store.readJournal();
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'ok',
        'desired': resource.toSummaryApiJson(),
        'deployments': observed.deployments.values
            .where((SkillDeploymentObservation value) => value.resourceId == id)
            .map((SkillDeploymentObservation value) => value.toJson())
            .toList(growable: false),
        'operations': journal.operations.values
            .where((SkillDeploymentOperation value) => value.resourceId == id)
            .map((SkillDeploymentOperation value) => value.toJson())
            .toList(growable: false),
      },
    );
  }

  Future<HttpResponseData> reconcileSkill(String id) =>
      _exclusiveMutation(() => _reconcileSkill(id));

  Future<HttpResponseData> _reconcileSkill(String id) async {
    if (_skillDeploymentStore == null) {
      return const HttpResponseData(
        statusCode: 503,
        json: <String, Object?>{
          'status': 'error',
          'message': 'Native Skill deployment state is not available',
        },
      );
    }
    final List<Resource> resources = await _store.load();
    if (!resources.any(
      (Resource value) => value.id == id && value.type == ResourceType.skill,
    )) {
      return _resourceNotFound();
    }
    // A synchronized ResourceStore treats this idempotent save as an explicit
    // full reconciliation request. Validation above prevents an unknown id
    // from causing unrelated global mutations.
    await _store.save(resources);
    return skillDeployments(id);
  }

  Future<HttpResponseData> bindScope(String id, String body) =>
      _exclusiveMutation(() => _bindScope(id, body));

  Future<HttpResponseData> _bindScope(String id, String body) async {
    try {
      final Map<String, Object?> payload =
          jsonDecode(body) as Map<String, Object?>;
      final List<String> triggerGroupIds =
          (payload['triggerGroupIds'] as List<Object?>? ?? const <Object?>[])
              .map((Object? value) => (value as String).trim())
              .where((String value) => value.isNotEmpty)
              .toSet()
              .toList(growable: false);
      final List<Resource> resources = List<Resource>.of(await _store.load());
      final int resourceIndex = resources.indexWhere(
        (Resource resource) => resource.id == id,
      );
      if (resourceIndex < 0) {
        return _resourceNotFound();
      }
      final TriggerGroupStore? triggerGroupStore = _triggerGroupStore;
      if (triggerGroupStore == null) {
        return _invalidUpdate('Trigger groups are not available');
      }
      final List<TriggerGroup> groups = await triggerGroupStore.load();
      final Map<String, TriggerGroup> groupsById = <String, TriggerGroup>{
        for (final TriggerGroup group in groups) group.id: group,
      };
      final List<String> unknownIds = triggerGroupIds
          .where((String groupId) => !groupsById.containsKey(groupId))
          .toList(growable: false);
      if (unknownIds.isNotEmpty) {
        return _invalidUpdate(
          'Unknown trigger group IDs: ${unknownIds.join(', ')}',
        );
      }
      final Resource existing = resources[resourceIndex];
      final bool strictProjectSkill =
          (payload['strictProjectSkill'] as bool?) ??
          (existing.type == ResourceType.skill);
      List<String> skillProjectPaths = existing.skillProjectPaths;
      if (existing.type == ResourceType.skill) {
        if (!strictProjectSkill || triggerGroupIds.isEmpty) {
          skillProjectPaths = const <String>[];
        } else {
          skillProjectPaths = resolveStrictSkillProjectPaths(
            triggerGroupIds,
            groupsById,
          );
        }
      }
      final Resource updated = existing.copyWith(
        triggerGroupIds: triggerGroupIds,
        strictProjectSkill:
            existing.type == ResourceType.skill && strictProjectSkill,
        skillProjectPaths: skillProjectPaths,
        enabled: existing.type == ResourceType.skill
            ? triggerGroupIds.isNotEmpty
            : existing.enabled,
        activation:
            existing.type == ResourceType.skill && triggerGroupIds.isNotEmpty
            ? ResourceActivation.always
            : existing.activation,
        updatedAt: _now().toUtc(),
      );
      resources[resourceIndex] = updated;
      await _store.save(resources);
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': 'updated',
          'item': updated.toApiJson(),
        },
      );
    } on Object catch (error) {
      return HttpResponseData(
        statusCode: 400,
        json: <String, Object?>{'status': 'error', 'message': error.toString()},
      );
    }
  }

  Future<HttpResponseData> importResources(String body) async {
    try {
      final Map<String, Object?> payload =
          jsonDecode(body) as Map<String, Object?>;
      final List<Resource> existing = await _store.load();
      if (payload['items'] is List<Object?>) {
        final List<Object?> items = payload['items'] as List<Object?>;
        final bool hasOnlineItems = items.any((Object? item) {
          if (item is! Map<String, Object?>) {
            return false;
          }
          return item['contentURL'] is String ||
              item['sourceURL'] is String ||
              (item['updateURL'] is String && item['content'] == null);
        });
        final LibraryBundleImportResult result = hasOnlineItems
            ? await LibraryBundle.decodeOnline(
                body,
                existing: existing,
                fetcher: _updateFetcher,
              )
            : LibraryBundle.importPayload(payload, existing: existing);
        if (result.imported.isNotEmpty) {
          await _store.save(<Resource>[...existing, ...result.imported]);
        }
        return HttpResponseData(
          statusCode: 200,
          json: <String, Object?>{
            'status': 'imported',
            'importedCount': result.imported.length,
            'skippedCount': result.skippedCount,
            'duplicateIds': result.duplicateIds,
            'conflictIds': result.conflictIds,
            'items': result.imported
                .map((Resource item) => item.toApiJson())
                .toList(growable: false),
          },
        );
      }
      final ResourceType type = ResourceType.parse(payload['type']);
      if (!type.isLibraryResource) {
        return _invalidUpdate('clipboard resources cannot be bulk imported');
      }
      final String importPath = (payload['path'] as String? ?? '').trim();
      if (importPath.isEmpty) {
        return _invalidUpdate('path is required');
      }
      final LibraryImportResult result = await _importer.scan(
        LibraryImportRequest(
          type: type,
          path: importPath,
          group: payload['group'] as String?,
          tags: (payload['tags'] as List<Object?>?)
              ?.map((Object? tag) => tag as String)
              .toList(growable: false),
          source: payload['source'] as String? ?? 'Library Import',
          limit: payload['limit'] as int? ?? 30,
        ),
        existing: existing,
      );
      await _store.save(<Resource>[...existing, ...result.imported]);
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': 'imported',
          'importedCount': result.imported.length,
          'skippedCount': result.skippedCount,
          'scannedCount': result.scannedCount,
          'items': result.imported
              .map((Resource item) => item.toApiJson())
              .toList(growable: false),
        },
      );
    } on FileSystemException {
      return _invalidUpdate('Import path is not a directory');
    } on Object {
      return _invalidUpdate('Invalid import JSON body');
    }
  }

  Future<HttpResponseData> seedDefaults() async {
    final List<Resource> existing = await _store.load();
    final bool alreadyPresent = existing.any(
      (Resource resource) => resource.id == builtInReplyMarkerPromptId,
    );
    if (alreadyPresent) {
      return const HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': 'ok',
          'inserted': 0,
          'skipped': 1,
          'items': <Object?>[],
        },
      );
    }

    final Resource prompt = builtInReplyMarkerPrompt(_now());
    await _store.save(<Resource>[...existing, prompt]);
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'ok',
        'inserted': 1,
        'skipped': 0,
        'items': <Object?>[prompt.toApiJson()],
      },
    );
  }

  Future<HttpResponseData> knowledgeIndex(Map<String, String> query) async {
    final String root = (query['root'] ?? query['path'] ?? '').trim();
    if (root.isEmpty) {
      return _invalidUpdate('root or path is required');
    }
    try {
      final KnowledgeIndexResult result = await _knowledgeIndexer.index(
        root,
        maxFiles: int.tryParse(query['limit'] ?? '') ?? 40,
      );
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': 'ok',
          'root': result.root,
          'files': result.files
              .map((KnowledgeIndexEntry entry) => entry.toJson())
              .toList(growable: false),
          'scannedCount': result.scannedCount,
          'skippedCount': result.skippedCount,
          'truncated': result.truncated,
        },
      );
    } on FileSystemException {
      return _invalidUpdate('Knowledge root is not a directory');
    }
  }

  Future<HttpResponseData> groups(Map<String, String> query) async {
    final ResourceType? selectedType = _libraryType(query['type']);
    if (query['type'] != null && selectedType == null) {
      return _invalidResourceType();
    }

    final Map<String, List<Resource>> buckets = <String, List<Resource>>{};
    for (final Resource resource in await _store.load()) {
      if (!resource.type.isLibraryResource ||
          (selectedType != null && resource.type != selectedType)) {
        continue;
      }
      buckets
          .putIfAbsent(
            '${resource.type.name}\u0000${resource.group}',
            () => <Resource>[],
          )
          .add(resource);
    }

    final List<Map<String, Object?>> summaries =
        buckets.values.map(_groupSummary).toList(growable: false)
          ..sort(_compareGroups);
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{'status': 'ok', 'groups': summaries},
    );
  }

  Future<HttpResponseData> export(Map<String, String> query) async {
    final String? typeName = query['type'];
    ResourceType? selectedType;
    if (typeName != null) {
      try {
        selectedType = ResourceType.parse(typeName);
      } on FormatException {
        return _invalidResourceType();
      }
      if (!selectedType.isLibraryResource) {
        return _invalidResourceType();
      }
    }

    final String needle = (query['q'] ?? '').trim().toLowerCase();
    final int? requestedLimit = int.tryParse(query['limit'] ?? '');
    final Set<String>? selectedIds = query['ids']
        ?.split(',')
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
    final List<Resource> matched = (await _store.load())
        .where(
          (Resource resource) =>
              selectedType == null || resource.type == selectedType,
        )
        .where(
          (Resource resource) =>
              selectedIds == null || selectedIds.contains(resource.id),
        )
        .where((Resource resource) => _matches(resource, needle))
        .toList(growable: false);
    // Clipboard history has its own store in Flutter and remains private here.
    final List<Resource> visible = matched
        .where((Resource resource) => resource.type.isLibraryResource)
        .toList(growable: false);
    final int limit = requestedLimit == null
        ? visible.length
        : min(max(0, requestedLimit), _maximumExportLimit);
    final List<Resource> returned = visible.take(limit).toList(growable: false);
    final Map<String, int> countsByType = <String, int>{
      for (final ResourceType type in ResourceType.values)
        type.name: visible.where((Resource item) => item.type == type).length,
    };

    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'ok',
        'service': 'DingDong',
        'schemaVersion': 2,
        'generatedAt': _now().toUtc().toIso8601String(),
        'filter': <String, Object?>{
          'type': selectedType?.name ?? 'all',
          'q': query['q'] ?? '',
          if (selectedIds != null) 'ids': selectedIds.toList(growable: false),
          'limit': limit,
        },
        'privacy': <String, Object?>{
          'clipboardIncluded': false,
          'sensitiveClipboardIncluded': false,
          'hiddenClipboardItems': matched.length - visible.length,
          'default':
              'clipboard resources are excluded unless includeClipboard=true',
          'sensitiveDefault':
              'sensitive clipboard records are excluded unless '
              'includeSensitiveClipboard=true',
        },
        'counts': <String, Object?>{
          'matched': matched.length,
          'visible': visible.length,
          'returned': returned.length,
          'byType': countsByType,
          'unused': visible
              .where((Resource resource) => resource.usageCount == 0)
              .length,
        },
        'analysis': <String, Object?>{
          'unusedIds': visible
              .where((Resource resource) => resource.usageCount == 0)
              .map((Resource resource) => resource.id)
              .toList(growable: false),
          'duplicateGroups': LibraryBundle.duplicateGroups(visible),
        },
        'limits': const <String, Object?>{
          'defaultItems': 'all',
          'maxItems': _maximumExportLimit,
          'resourceContentCharacters': 100000,
          'clipboardContentCharacters': 20000,
        },
        'items': returned
            .map(LibraryBundle.portableItem)
            .toList(growable: false),
      },
    );
  }

  Future<HttpResponseData> update(String id, String body) =>
      _exclusiveMutation(() => _update(id, body));

  Future<HttpResponseData> _update(String id, String body) async {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?> || decoded.isEmpty) {
        return _invalidUpdate('At least one resource field is required');
      }
      final List<Resource> resources = List<Resource>.of(await _store.load());
      final int index = resources.indexWhere(
        (Resource resource) =>
            resource.id == id && resource.type.isLibraryResource,
      );
      if (index < 0) {
        return _resourceNotFound();
      }

      final Resource existing = resources[index];
      final ResourceType? type = decoded.containsKey('type')
          ? _libraryType(decoded['type'])
          : null;
      if (decoded.containsKey('type') && type == null) {
        return _resourceNotFound();
      }
      final String? title = decoded['title'] as String?;
      final String? content = decoded['content'] as String?;
      final String? agentSessionName = decoded.containsKey('agentSessionName')
          ? decoded['agentSessionName'] as String? ?? ''
          : null;
      final bool? hideInAgentConversation =
          decoded.containsKey('hideInAgentConversation')
          ? decoded['hideInAgentConversation'] as bool? ?? false
          : null;
      if (title != null && title.trim().isEmpty) {
        return _invalidUpdate('title cannot be empty');
      }
      if (content != null && content.trim().isEmpty) {
        return _invalidUpdate('content cannot be empty');
      }
      if (content != null && content.length > 100000) {
        return const HttpResponseData(
          statusCode: 413,
          json: <String, Object?>{
            'status': 'error',
            'message': 'content exceeds the 100000 character limit',
          },
        );
      }

      final List<String>? triggerGroupIds =
          decoded.containsKey('triggerGroupIds')
          ? (decoded['triggerGroupIds'] as List<Object?>)
                .map((Object? value) => value as String)
                .toList(growable: false)
          : null;
      final TriggerGroupStore? triggerGroups = _triggerGroupStore;
      if (triggerGroups != null && triggerGroupIds != null) {
        final Set<String> knownIds = (await triggerGroups.load())
            .map((TriggerGroup group) => group.id)
            .toSet();
        final List<String> unknownIds =
            triggerGroupIds
                .where((String id) => !knownIds.contains(id))
                .toSet()
                .toList(growable: false)
              ..sort();
        if (unknownIds.isNotEmpty) {
          return _invalidUpdate(
            'Unknown trigger group IDs: ${unknownIds.join(', ')}',
          );
        }
      }

      final bool pinned = decoded['pinned'] as bool? ?? existing.pinned;
      if (decoded.containsKey('skillDeliveryByAgent') ||
          decoded.containsKey('skillHooksEnabledByAgent')) {
        return _invalidUpdate(
          'Use the atomic Skill delivery endpoint to change delivery or Hooks',
        );
      }
      final Resource updated = existing.copyWith(
        type: type,
        group: decoded['group'] as String?,
        title: title,
        content: content,
        tags: decoded.containsKey('tags')
            ? (decoded['tags'] as List<Object?>)
                  .map((Object? value) => value as String)
                  .toList(growable: false)
            : null,
        source: decoded['source'] as String?,
        updateUrl: decoded['updateURL'] as String?,
        agentSessionName: agentSessionName,
        hideInAgentConversation: hideInAgentConversation,
        pinned: decoded.containsKey('pinned') ? pinned : null,
        enabled: decoded['enabled'] as bool?,
        activation: decoded.containsKey('activation')
            ? ResourceActivation.parse(decoded['activation'], pinned: pinned)
            : null,
        triggerGroupIds: triggerGroupIds,
        sortOrder: decoded['sortOrder'] as int?,
        updatedAt: _now().toUtc(),
      );
      resources[index] = updated;
      await _store.save(resources);
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': 'updated',
          'item': updated.toApiJson(),
        },
      );
    } on Object {
      return const HttpResponseData(
        statusCode: 400,
        json: <String, Object?>{
          'status': 'error',
          'message': 'Invalid resource JSON body',
        },
      );
    }
  }

  Future<HttpResponseData> delete(String id) =>
      _exclusiveMutation(() => _delete(id));

  Future<HttpResponseData> _delete(String id) async {
    final List<Resource> resources = await _store.load();
    final Resource? existing = resources
        .where(
          (Resource resource) =>
              resource.id == id && resource.type.isLibraryResource,
        )
        .firstOrNull;
    if (existing == null) {
      return _resourceNotFound();
    }
    await _store.save(
      resources.where((Resource resource) => resource.id != id).toList(),
    );
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{'status': 'deleted', 'id': id},
    );
  }
}

Map<String, Object?> _groupSummary(List<Resource> resources) {
  final Resource first = resources.first;
  final DateTime latest = resources
      .map((Resource resource) => resource.updatedAt)
      .reduce(
        (DateTime left, DateTime right) => left.isAfter(right) ? left : right,
      );
  return <String, Object?>{
    'type': first.type.name,
    'group': first.group,
    'count': resources.length,
    'pinnedCount': resources
        .where((Resource resource) => resource.pinned)
        .length,
    'latestUpdatedAt': latest.toUtc().toIso8601String(),
  };
}

int _compareGroups(Map<String, Object?> left, Map<String, Object?> right) {
  final int typeComparison = ResourceType.values
      .indexWhere((ResourceType type) => type.name == left['type'])
      .compareTo(
        ResourceType.values.indexWhere(
          (ResourceType type) => type.name == right['type'],
        ),
      );
  if (typeComparison != 0) {
    return typeComparison;
  }
  final int pinnedComparison = (right['pinnedCount'] as int).compareTo(
    left['pinnedCount'] as int,
  );
  if (pinnedComparison != 0) {
    return pinnedComparison;
  }
  final int countComparison = (right['count'] as int).compareTo(
    left['count'] as int,
  );
  if (countComparison != 0) {
    return countComparison;
  }
  final int dateComparison = DateTime.parse(
    right['latestUpdatedAt'] as String,
  ).compareTo(DateTime.parse(left['latestUpdatedAt'] as String));
  if (dateComparison != 0) {
    return dateComparison;
  }
  return (left['group'] as String).toLowerCase().compareTo(
    (right['group'] as String).toLowerCase(),
  );
}

ResourceType? _libraryType(Object? value) {
  try {
    final ResourceType type = ResourceType.parse(value);
    return type.isLibraryResource ? type : null;
  } on FormatException {
    return null;
  }
}

bool _matches(Resource resource, String needle) {
  return needle.isEmpty ||
      resource.title.toLowerCase().contains(needle) ||
      resource.content.toLowerCase().contains(needle) ||
      resource.group.toLowerCase().contains(needle) ||
      resource.tags.any((String tag) => tag.toLowerCase().contains(needle));
}

String _onlineSkillName(Resource resource) {
  try {
    return SkillConfiguration.parseOnline(resource.content).name;
  } on Object {
    return '';
  }
}

HttpResponseData _invalidUpdate(String message) {
  return HttpResponseData(
    statusCode: 400,
    json: <String, Object?>{'status': 'error', 'message': message},
  );
}

HttpResponseData _skillConflict(String message, {required String code}) {
  return HttpResponseData(
    statusCode: 409,
    json: <String, Object?>{
      'status': 'error',
      'code': code,
      'message': message,
    },
  );
}

HttpResponseData _resourceNotFound() {
  return const HttpResponseData(
    statusCode: 404,
    json: <String, Object?>{'status': 'error', 'message': 'Resource not found'},
  );
}

HttpResponseData _invalidResourceType() {
  return const HttpResponseData(
    statusCode: 400,
    json: <String, Object?>{
      'status': 'error',
      'message': 'Invalid resource type',
    },
  );
}

DateTime _utcNow() => DateTime.now().toUtc();
