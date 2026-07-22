import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/utils/uuid.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/built_in_resources.dart';
import 'package:dingdong/features/library/domain/knowledge_indexer.dart';
import 'package:dingdong/features/library/domain/library_bundle.dart';
import 'package:dingdong/features/library/domain/library_importer.dart';
import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:path/path.dart' as path;

/// Handles resource-library reads and mutations that share the public API.
final class LibraryRoutes {
  LibraryRoutes(
    this._store, {
    TriggerGroupStore? triggerGroupStore,
    SkillPackageInstaller? skillPackageInstaller,
    DateTime Function()? now,
    String Function()? idGenerator,
  }) : // Named private initializing formals are not callable cross-library.
       // ignore: prefer_initializing_formals
       _triggerGroupStore = triggerGroupStore,
       // Named private initializing formals are not callable cross-library.
       // ignore: prefer_initializing_formals
       _skillPackageInstaller = skillPackageInstaller,
       _idGenerator = idGenerator ?? generateUuid,
       _now = now ?? _utcNow,
       _importer = LibraryImporter(now: now, idGenerator: idGenerator);

  static const int _maximumExportLimit = 100000;

  final ResourceStore _store;
  final TriggerGroupStore? _triggerGroupStore;
  final SkillPackageInstaller? _skillPackageInstaller;
  final String Function() _idGenerator;
  final DateTime Function() _now;
  final LibraryImporter _importer;
  final KnowledgeIndexer _knowledgeIndexer = KnowledgeIndexer();

  Future<HttpResponseData> installSkill(String body) async {
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
      final Uri? parsedSource = Uri.tryParse(source);
      final Uri? sourceUri = parsedSource == null
          ? null
          : parsedSource.scheme.isEmpty && path.isAbsolute(source)
          ? Uri.file(path.normalize(source))
          : parsedSource;
      if (sourceUri == null ||
          (sourceUri.scheme != 'https' && sourceUri.scheme != 'file')) {
        return _invalidUpdate(
          'source must be an HTTPS GitHub Skill URL or absolute local Skill path',
        );
      }
      final String normalizedSource = sourceUri.toString();
      final SkillPackageInstallResult installed = await installer.install(
        sourceUri,
      );
      final SkillConfiguration skill = SkillConfiguration.parseOnline(
        installed.skillDocument,
      );
      final List<Resource> resources = List<Resource>.of(await _store.load());
      final List<Resource> sourceMatches = resources
          .where(
            (Resource resource) =>
                resource.type == ResourceType.skill &&
                resource.updateUrl == normalizedSource,
          )
          .toList(growable: false);
      final List<Resource> nameMatches = resources
          .where(
            (Resource resource) =>
                resource.type == ResourceType.skill &&
                _onlineSkillName(resource) == skill.name,
          )
          .toList(growable: false);
      if (sourceMatches.length > 1 || nameMatches.length > 1) {
        return const HttpResponseData(
          statusCode: 409,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Multiple matching Skill resources already exist',
          },
        );
      }
      final Resource? sameName = nameMatches.firstOrNull;
      final Resource? existing = sourceMatches.firstOrNull ?? sameName;
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
          id: _idGenerator(),
          type: ResourceType.skill,
          group: group.isEmpty ? null : group,
          title: title.isEmpty ? skill.name : title,
          content: installed.skillDocument,
          tags: tags ?? const <String>[],
          source: 'DingDong MCP',
          updateUrl: normalizedSource,
          packagePath: installed.directoryPath,
          enabled: false,
          activation: ResourceActivation.taskMatch,
          createdAt: timestamp,
          updatedAt: timestamp,
        );
        await _store.save(<Resource>[...resources, resource]);
      } else {
        resource = existing.copyWith(
          group: group.isEmpty ? existing.group : group,
          title: title.isEmpty ? existing.title : title,
          content: installed.skillDocument,
          tags: tags,
          updateUrl: normalizedSource,
          packagePath: installed.directoryPath,
          enabled: existing.enabled,
          updatedAt: timestamp,
        );
        resources[existingIndex!] = resource;
        await _store.save(resources);
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

  Future<HttpResponseData> bindScope(String id, String body) async {
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
          final List<TriggerRule> selectedRules = triggerGroupIds
              .expand((String groupId) => groupsById[groupId]!.rules)
              .toList(growable: false);
          if (selectedRules.any(
            (TriggerRule rule) =>
                rule.field != TriggerRuleField.projectPath ||
                rule.operator != TriggerRuleOperator.equals,
          )) {
            return _invalidUpdate(
              'Strict project Skill scope accepts only exact absolute projectPath rules',
            );
          }
          final List<String> requestedPaths = selectedRules
              .map((TriggerRule rule) => rule.value)
              .toSet()
              .toList(growable: false);
          if (requestedPaths.isEmpty) {
            return _invalidUpdate(
              'Strict project Skill scope requires an exact absolute projectPath rule',
            );
          }
          final List<String> resolvedPaths = <String>[];
          for (final String requestedPath in requestedPaths) {
            final String normalized = path.normalize(requestedPath);
            final Directory directory = Directory(normalized);
            if (!path.isAbsolute(normalized) ||
                path.equals(normalized, path.dirname(normalized)) ||
                !await directory.exists()) {
              return _invalidUpdate(
                'Strict project Skill scope requires an exact absolute projectPath that exists: $requestedPath',
              );
            }
            resolvedPaths.add(await directory.resolveSymbolicLinks());
          }
          skillProjectPaths = resolvedPaths.toSet().toList(growable: false)
            ..sort();
        }
      }
      final Resource updated = existing.copyWith(
        triggerGroupIds: triggerGroupIds,
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
        final LibraryBundleImportResult result = LibraryBundle.importPayload(
          payload,
          existing: existing,
        );
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
            .map((Resource resource) => resource.toJson())
            .toList(growable: false),
      },
    );
  }

  Future<HttpResponseData> update(String id, String body) async {
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

  Future<HttpResponseData> delete(String id) async {
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
