import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/agent_source_identity.dart';
import 'package:dingdong/features/agent_api/data/conversation_footer_protocol.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/agent_api/data/resource_query_utils.dart';
import 'package:dingdong/features/agent_api/data/skill_delivery_resolver.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/resource_scope_policy.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:path/path.dart' as path;

/// A task start observed at the Bridge boundary before resource resolution.
final class AgentBridgeTaskStart {
  const AgentBridgeTaskStart({
    required this.task,
    required this.source,
    required this.startedAt,
    this.workspacePath,
    this.repositoryUrl,
    this.conversationId,
  });

  final String task;
  final String source;
  final DateTime startedAt;
  final String? workspacePath;
  final String? repositoryUrl;
  final String? conversationId;
}

/// Delivers required Prompt instructions and the dynamic Skill catalog.
///
/// Prompt bodies are returned in full. Skills remain metadata-only until the
/// Agent deliberately loads one through [loadSkill].
final class AgentBridge {
  AgentBridge(
    this._store, {
    TriggerGroupStore? triggerGroupStore,
    DateTime Function()? now,
    this.querySkillDeploymentPresence,
    this.onTaskStarted,
  }) : _triggerGroupStore = triggerGroupStore ?? InMemoryTriggerGroupStore(),
       _now = now ?? DateTime.now;

  final ResourceStore _store;
  final TriggerGroupStore _triggerGroupStore;
  final DateTime Function() _now;
  final SkillDeploymentPresenceQuery? querySkillDeploymentPresence;
  final void Function(AgentBridgeTaskStart start)? onTaskStarted;

  static const int _maximumSkillPackageFiles = 200;
  static const int _maximumSkillFileBytes = 5 * 1024 * 1024;

  Future<HttpResponseData> respond(String body) async {
    try {
      final Map<String, Object?> request = body.trim().isEmpty
          ? <String, Object?>{}
          : jsonDecode(body) as Map<String, Object?>;
      final String task = (request['task'] as String? ?? '').trim();
      final String requestedSource = (request['source'] as String? ?? 'Agent')
          .trim();
      final String source = requestedSource.isEmpty ? 'Agent' : requestedSource;
      final String expand = request['expand'] as String? ?? 'prompts';
      final DateTime startedAt = _now().toUtc();
      final TriggerContext context = TriggerContext(
        projectPath: _firstString(request, const <String>[
          'workspacePath',
          'projectPath',
          'cwd',
        ]),
        repositoryUrl: _firstString(request, const <String>[
          'repositoryUrl',
          'repository',
          'projectUrl',
        ]),
        source: source,
      );
      if (task.isNotEmpty) {
        try {
          onTaskStarted?.call(
            AgentBridgeTaskStart(
              task: task,
              source: source,
              startedAt: startedAt,
              workspacePath: context.projectPath,
              repositoryUrl: context.repositoryUrl,
              conversationId: _firstString(request, const <String>[
                'conversationId',
                'sessionId',
                'threadId',
              ]),
            ),
          );
        } on Object {
          // Lifecycle observation must never prevent Prompt and Skill delivery.
        }
      }
      final Set<String> terms = task
          .toLowerCase()
          .split(RegExp(r'[^\p{L}\p{N}_-]+', unicode: true))
          .where((String value) => value.length >= 2)
          .toSet();
      final List<Resource> resources = await _store.load();
      final List<TriggerGroup> triggerGroups = await _triggerGroupStore.load();
      final Map<String, TriggerGroup> triggerGroupsById = _groupsById(
        triggerGroups,
      );
      final List<Resource> available = resources
          .where((Resource resource) => resource.enabled)
          .where(
            (Resource resource) =>
                resourceMatchesScope(resource, context, triggerGroupsById),
          )
          .toList(growable: false);
      final List<Resource> prompts =
          available
              .where(
                (Resource resource) => resource.type == ResourceType.prompt,
              )
              .where((Resource resource) => _isActive(resource, terms))
              .toList(growable: false)
            ..sort(compareResources);
      List<Resource> candidates(ResourceType type) =>
          available
              .where((Resource resource) => resource.type == type)
              .where((Resource resource) => _isActive(resource, terms))
              .toList(growable: false)
            ..sort(compareResources);
      final List<Resource> mcps = candidates(ResourceType.mcp);
      final List<Resource> knowledge = candidates(ResourceType.knowledge);
      final List<Resource> selected = <Resource>[
        ...prompts,
        ...mcps,
        ...knowledge,
      ];
      final SkillDeliveryResolution skillResolution =
          await resolveSkillDelivery(
            resources: available.where(
              (Resource resource) => resource.type == ResourceType.skill,
            ),
            agentId: resolveAgentAdapterId(source),
            workspacePath: context.projectPath,
            queryPresence: querySkillDeploymentPresence,
          );
      final List<DynamicSkillCandidate> skillCandidates =
          List<DynamicSkillCandidate>.of(skillResolution.candidates)
            ..sort((DynamicSkillCandidate left, DynamicSkillCandidate right) {
              final int name = left.configuration.name.compareTo(
                right.configuration.name,
              );
              return name != 0
                  ? name
                  : left.resource.id.compareTo(right.resource.id);
            });
      final Set<String> selectedIds = selected
          .map((Resource resource) => resource.id)
          .toSet();
      final DateTime usedAt = startedAt;
      List<Resource> updatedResources = resources;
      if (selectedIds.isNotEmpty) {
        final ResourceStore store = _store;
        final ResourceUsageStore? usageStore = store is ResourceUsageStore
            ? store as ResourceUsageStore
            : null;
        if (usageStore != null) {
          updatedResources = await usageStore.recordUsage(selectedIds, usedAt);
        } else {
          updatedResources = resources
              .map(
                (Resource resource) => selectedIds.contains(resource.id)
                    ? resource.copyWith(
                        usageCount: resource.usageCount + 1,
                        lastUsedAt: usedAt,
                      )
                    : resource,
              )
              .toList(growable: false);
          await store.save(updatedResources);
        }
      }
      final Map<String, Resource> updatedById = <String, Resource>{
        for (final Resource resource in updatedResources) resource.id: resource,
      };
      final List<Resource> used = selected
          .map((Resource resource) => updatedById[resource.id] ?? resource)
          .toList(growable: false);
      final Set<String> matchedTriggerGroupIds = triggerGroups
          .where((TriggerGroup group) => group.matches(context))
          .map((TriggerGroup group) => group.id)
          .toSet();
      final List<Resource> conversationResources = <Resource>[
        ...prompts.where(_isVisibleInAgentConversation),
        ...skillCandidates
            .where(
              (DynamicSkillCandidate skill) =>
                  _isVisibleInAgentConversation(skill.resource),
            )
            .map((DynamicSkillCandidate skill) => skill.resource),
        ...mcps.where(_isVisibleInAgentConversation),
      ];
      final List<Map<String, Object?>> conversationItems = conversationResources
          .map(_conversationCapsuleItem)
          .where(
            (Map<String, Object?> item) => (item['title'] as String).isNotEmpty,
          )
          .toList(growable: false);
      final Map<String, Object?> conversation = buildDingDongConversationFooter(
        items: conversationItems,
      );

      List<Map<String, Object?>> items(ResourceType type) {
        return used
            .where((Resource resource) => resource.type == type)
            .map((Resource resource) {
              final bool contentIncluded =
                  type == ResourceType.prompt || expand == 'all';
              return <String, Object?>{
                ...(contentIncluded
                    ? resource.toApiJson()
                    : resource.toSummaryApiJson()),
                'contentIncluded': contentIncluded,
              };
            })
            .toList(growable: false);
      }

      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': 'ok',
          'task': task,
          'source': source,
          'context': <String, Object?>{
            'workspacePath': context.projectPath,
            'repositoryUrl': context.repositoryUrl,
            'source': context.source,
            'matchedTriggerGroupIds': matchedTriggerGroupIds.toList(),
          },
          'active': <String, Object?>{
            'prompts': items(ResourceType.prompt),
            'skills': skillCandidates
                .map(_skillCandidateJson)
                .toList(growable: false),
            if (skillResolution.conflicts.isNotEmpty)
              'skillConflicts': skillResolution.conflicts
                  .map((SkillDeliveryConflict conflict) => conflict.toJson())
                  .toList(growable: false),
            if (skillResolution.suppressed.isNotEmpty)
              'skillSuppressions': skillResolution.suppressed
                  .map(
                    (SkillDeliverySuppression suppression) =>
                        suppression.toJson(),
                  )
                  .toList(growable: false),
            'mcps': items(ResourceType.mcp),
            'knowledge': items(ResourceType.knowledge),
          },
          'conversation': conversation,
          'delivery': <String, Object?>{
            'prompts': 'full-required-instructions',
            'promptSnapshot': 'authoritative-replace',
            'skills': 'dynamic-id-name-description-catalog-load-on-match',
            'skillCatalogSnapshot': 'authoritative-replace',
            'mcps': 'summary-call-on-demand',
          },
          'privacy': const <String, Object?>{
            'clipboardIncluded': false,
            'summaryFirst': true,
            'summaryFirstTypes': <String>['skill', 'mcp', 'knowledge'],
            'fullTypes': <String>['prompt'],
          },
        },
      );
    } on Object {
      return const HttpResponseData(
        statusCode: 400,
        json: <String, Object?>{
          'status': 'error',
          'message': 'Invalid agent bridge request',
        },
      );
    }
  }

  /// Loads one full Skill after re-checking its enabled state and scope.
  Future<HttpResponseData> loadSkill(Map<String, String> query) {
    final ResourceStore store = _store;
    final ExclusiveResourceStore? exclusive = store is ExclusiveResourceStore
        ? store as ExclusiveResourceStore
        : null;
    return exclusive == null
        ? _loadSkill(query)
        : exclusive.exclusiveMutation(() => _loadSkill(query));
  }

  Future<HttpResponseData> _loadSkill(Map<String, String> query) async {
    try {
      final _SkillLookup lookup = await _lookupSkill(query);
      final HttpResponseData? error = lookup.error;
      if (error != null) {
        return error;
      }
      final DynamicSkillCandidate skill = lookup.skill!;
      final List<Resource> resources = lookup.resources;
      final DateTime usedAt = _now().toUtc();
      final ResourceStore store = _store;
      final ResourceUsageStore? usageStore = store is ResourceUsageStore
          ? store as ResourceUsageStore
          : null;
      late final Resource tracked;
      if (usageStore != null) {
        final List<Resource> updated = await usageStore.recordUsage(<String>{
          skill.resource.id,
        }, usedAt);
        tracked = updated.firstWhere(
          (Resource resource) => resource.id == skill.resource.id,
        );
      } else {
        final int resourceIndex = resources.indexWhere(
          (Resource resource) => resource.id == skill.resource.id,
        );
        tracked = skill.resource.copyWith(
          usageCount: skill.resource.usageCount + 1,
          lastUsedAt: usedAt,
        );
        resources[resourceIndex] = tracked;
        await store.save(resources);
      }
      final Map<String, Object?> package = await _packageSummary(tracked);
      final Map<String, Object?> conversationItem =
          normalizeDingDongConversationFooterItem(
            _conversationCapsuleItem(tracked, confirmedSkillUse: true),
          )!;
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': 'ok',
          'context': _contextJson(lookup.context),
          'skill': <String, Object?>{
            'id': tracked.id,
            'type': ResourceType.skill.name,
            'name': skill.configuration.name,
            'description': skill.configuration.description,
            'content': tracked.content,
            'contentIncluded': true,
            'package': package,
          },
          if (_isVisibleInAgentConversation(tracked))
            'conversation': <String, Object?>{
              'item': conversationItem,
              'evidence': 'successful-full-skill-load',
              'merge': 'replace-same-merge-key-in-final-capsule',
            },
          'delivery': const <String, Object?>{
            'content': 'full-skill-md-required-workflow',
            'supportingFiles': 'manifest-read-on-demand',
          },
        },
      );
    } on Object {
      return const HttpResponseData(
        statusCode: 400,
        json: <String, Object?>{
          'status': 'error',
          'message': 'Invalid Skill load request',
        },
      );
    }
  }

  /// Reads one package file without exposing an unrestricted local path.
  Future<HttpResponseData> readSkillFile(Map<String, String> query) async {
    try {
      final String requestedPath = (query['path'] ?? '').trim();
      final List<String>? segments = _safeSkillFileSegments(requestedPath);
      if (segments == null) {
        return const HttpResponseData(
          statusCode: 400,
          json: <String, Object?>{
            'status': 'error',
            'message': 'path must be a safe relative Skill package path',
          },
        );
      }
      final _SkillLookup lookup = await _lookupSkill(query);
      final HttpResponseData? error = lookup.error;
      if (error != null) {
        return error;
      }
      final DynamicSkillCandidate skill = lookup.skill!;
      final String? packagePath = skill.resource.packagePath;
      if (packagePath == null) {
        return const HttpResponseData(
          statusCode: 404,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Skill package file not found',
          },
        );
      }
      final Directory root = Directory(packagePath);
      if (await FileSystemEntity.type(root.path, followLinks: false) !=
          FileSystemEntityType.directory) {
        return const HttpResponseData(
          statusCode: 404,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Skill package file not found',
          },
        );
      }
      final File file = File(path.joinAll(<String>[root.path, ...segments]));
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        return const HttpResponseData(
          statusCode: 404,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Skill package file not found',
          },
        );
      }
      final String resolvedRoot = await root.resolveSymbolicLinks();
      final String resolvedFile = await file.resolveSymbolicLinks();
      if (!path.isWithin(resolvedRoot, resolvedFile)) {
        return const HttpResponseData(
          statusCode: 400,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Skill package path escapes its root',
          },
        );
      }
      final int byteCount = await file.length();
      if (byteCount > _maximumSkillFileBytes) {
        return const HttpResponseData(
          statusCode: 413,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Skill package file exceeds the 5 MiB limit',
          },
        );
      }
      final List<int> bytes = await file.readAsBytes();
      String? text;
      try {
        text = utf8.decode(bytes);
      } on FormatException {
        text = null;
      }
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': 'ok',
          'context': _contextJson(lookup.context),
          'skill': <String, Object?>{
            'id': skill.resource.id,
            'name': skill.configuration.name,
          },
          'file': <String, Object?>{
            'path': segments.join('/'),
            'byteCount': byteCount,
            'encoding': text == null ? 'base64' : 'utf-8',
            'content': text ?? base64Encode(bytes),
          },
        },
      );
    } on Object {
      return const HttpResponseData(
        statusCode: 400,
        json: <String, Object?>{
          'status': 'error',
          'message': 'Invalid Skill file request',
        },
      );
    }
  }

  Future<_SkillLookup> _lookupSkill(Map<String, String> query) async {
    final String id = (query['id'] ?? '').trim();
    final String name = (query['name'] ?? '').trim().toLowerCase();
    final TriggerContext context = _contextFromStrings(query);
    if (id.isEmpty && name.isEmpty) {
      return _SkillLookup.error(
        context,
        const HttpResponseData(
          statusCode: 400,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Skill name or id is required',
          },
        ),
      );
    }
    final List<Resource> resources = List<Resource>.of(await _store.load());
    final Map<String, TriggerGroup> triggerGroupsById = _groupsById(
      await _triggerGroupStore.load(),
    );
    final SkillDeliveryResolution resolution = await resolveSkillDelivery(
      resources: resources.where(
        (Resource resource) =>
            resource.enabled &&
            resource.type == ResourceType.skill &&
            resourceMatchesScope(resource, context, triggerGroupsById),
      ),
      agentId: resolveAgentAdapterId(context.source),
      workspacePath: context.projectPath,
      queryPresence: querySkillDeploymentPresence,
    );
    final List<DynamicSkillCandidate> matches = resolution.candidates
        .where(
          (DynamicSkillCandidate skill) =>
              id.isEmpty || skill.resource.id == id,
        )
        .where(
          (DynamicSkillCandidate skill) =>
              name.isEmpty || skill.configuration.name == name,
        )
        .toList(growable: false);
    if (matches.isEmpty) {
      final SkillDeliveryConflict? conflict = resolution.conflicts
          .where(
            (SkillDeliveryConflict value) =>
                (name.isEmpty || value.name == name) &&
                (id.isEmpty || value.resourceIds.contains(id)),
          )
          .firstOrNull;
      if (conflict != null) {
        return _SkillLookup.error(
          context,
          HttpResponseData(
            statusCode: 409,
            json: <String, Object?>{
              'status': 'error',
              'message':
                  'Skill name resolves to different artifacts; choose one delivery source first',
              'name': conflict.name,
              'candidateIds': conflict.resourceIds,
            },
          ),
        );
      }
      return _SkillLookup.error(
        context,
        const HttpResponseData(
          statusCode: 404,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Skill is disabled, out of scope, or not found',
          },
        ),
      );
    }
    if (matches.length > 1) {
      return _SkillLookup.error(
        context,
        HttpResponseData(
          statusCode: 409,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Skill name is ambiguous; include its id',
            'candidateIds': matches
                .map((DynamicSkillCandidate skill) => skill.resource.id)
                .toList(growable: false),
          },
        ),
      );
    }
    return _SkillLookup.success(context, resources, matches.single);
  }

  Future<Map<String, Object?>> _packageSummary(Resource resource) async {
    final String? packagePath = resource.packagePath;
    if (packagePath == null) {
      return const <String, Object?>{
        'available': false,
        'fileCount': 0,
        'truncated': false,
        'files': <Object?>[],
      };
    }
    final Directory root = Directory(packagePath);
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      return const <String, Object?>{
        'available': false,
        'fileCount': 0,
        'truncated': false,
        'files': <Object?>[],
      };
    }
    final List<Map<String, Object?>> files = <Map<String, Object?>>[];
    await for (final FileSystemEntity entity in root.list(
      recursive: true,
      followLinks: false,
    )) {
      if (files.length > _maximumSkillPackageFiles) {
        break;
      }
      if (entity is! File ||
          await FileSystemEntity.type(entity.path, followLinks: false) !=
              FileSystemEntityType.file) {
        continue;
      }
      final String relative = path
          .relative(entity.path, from: root.path)
          .replaceAll(path.separator, '/');
      if (relative == 'SKILL.md' || relative == '.dingdong-managed') {
        continue;
      }
      files.add(<String, Object?>{
        'path': relative,
        'byteCount': await entity.length(),
      });
    }
    files.sort(
      (Map<String, Object?> left, Map<String, Object?> right) =>
          (left['path']! as String).compareTo(right['path']! as String),
    );
    final bool truncated = files.length > _maximumSkillPackageFiles;
    final List<Map<String, Object?>> visible = truncated
        ? files.take(_maximumSkillPackageFiles).toList(growable: false)
        : files;
    return <String, Object?>{
      'available': true,
      'fileCount': visible.length,
      'truncated': truncated,
      'files': visible,
    };
  }
}

String _firstString(Map<String, Object?> values, List<String> keys) {
  for (final String key in keys) {
    final String value = (values[key] as String? ?? '').trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

bool _matches(Resource resource, Set<String> terms) {
  if (terms.isEmpty) {
    return false;
  }
  final String haystack = <String>[
    resource.title,
    resource.group,
    ...resource.tags,
    resource.content,
  ].join(' ').toLowerCase();
  return terms.any(haystack.contains);
}

bool _isActive(Resource resource, Set<String> terms) {
  return switch (resource.activation) {
    ResourceActivation.always => true,
    ResourceActivation.taskMatch => _matches(resource, terms),
    ResourceActivation.manual => false,
  };
}

Map<String, TriggerGroup> _groupsById(List<TriggerGroup> groups) =>
    <String, TriggerGroup>{
      for (final TriggerGroup group in groups) group.id: group,
    };

Map<String, Object?> _skillCandidateJson(DynamicSkillCandidate skill) =>
    <String, Object?>{
      'id': skill.resource.id,
      'name': skill.configuration.name,
      'description': skill.configuration.description,
    };

const int _maximumConversationTitleCharacters = 8;

String _conversationResourceName(Resource resource) =>
    resource.agentSessionName ?? resource.title;

bool _isVisibleInAgentConversation(Resource resource) =>
    !resource.hideInAgentConversation;

Map<String, Object?> _conversationCapsuleItem(
  Resource resource, {
  bool confirmedSkillUse = false,
}) {
  final String title = _displayResourceTitle(
    _conversationResourceName(resource),
  );
  final String type = resource.type.name;
  final bool skill = resource.type == ResourceType.skill;
  final String marker = skill && confirmedSkillUse ? '*' : '';
  return <String, Object?>{
    'title': title,
    'type': type,
    'tone': type,
    'usage': switch (resource.type) {
      ResourceType.prompt => 'active',
      ResourceType.skill => confirmedSkillUse ? 'loaded' : 'candidate',
      ResourceType.mcp => 'available',
      _ => 'available',
    },
    'mergeKey': '${resource.type.name}:${resource.id}',
    if (skill) 'confirmedUse': confirmedSkillUse,
    if (skill) 'marker': marker,
    'lineToken': '${_conversationTypeIndicator(resource.type)} $title$marker',
  };
}

String _conversationTypeIndicator(ResourceType type) => switch (type) {
  ResourceType.prompt => '🟠',
  ResourceType.skill => '🔵',
  ResourceType.mcp => '🟢',
  _ => '⚪',
};

String _displayResourceTitle(String value) {
  final String normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) {
    return '';
  }
  final List<int> characters = normalized.runes.toList(growable: false);
  if (characters.length <= _maximumConversationTitleCharacters) {
    return normalized;
  }
  return '${String.fromCharCodes(characters.take(_maximumConversationTitleCharacters))}...';
}

TriggerContext _contextFromStrings(Map<String, String> values) {
  final String source = _firstNonEmptyString(values, const <String>['source']);
  return TriggerContext(
    projectPath: _firstNonEmptyString(values, const <String>[
      'workspacePath',
      'projectPath',
      'cwd',
    ]),
    repositoryUrl: _firstNonEmptyString(values, const <String>[
      'repositoryUrl',
      'repository',
      'projectUrl',
    ]),
    source: source.isEmpty ? 'Agent' : source,
  );
}

String _firstNonEmptyString(Map<String, String> values, List<String> keys) {
  for (final String key in keys) {
    final String value = (values[key] ?? '').trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return '';
}

Map<String, Object?> _contextJson(TriggerContext context) => <String, Object?>{
  'workspacePath': context.projectPath,
  'repositoryUrl': context.repositoryUrl,
  'source': context.source,
};

List<String>? _safeSkillFileSegments(String value) {
  if (value.isEmpty ||
      value.startsWith('/') ||
      value.contains(r'\') ||
      value.contains('\u0000')) {
    return null;
  }
  final List<String> segments = value.split('/');
  if (segments.any(
    (String segment) => segment.isEmpty || segment == '.' || segment == '..',
  )) {
    return null;
  }
  return segments;
}

final class _SkillLookup {
  const _SkillLookup._(
    this.context, {
    required this.resources,
    this.skill,
    this.error,
  });

  factory _SkillLookup.success(
    TriggerContext context,
    List<Resource> resources,
    DynamicSkillCandidate skill,
  ) => _SkillLookup._(context, resources: resources, skill: skill);

  factory _SkillLookup.error(TriggerContext context, HttpResponseData error) =>
      _SkillLookup._(context, resources: const <Resource>[], error: error);

  final TriggerContext context;
  final List<Resource> resources;
  final DynamicSkillCandidate? skill;
  final HttpResponseData? error;
}
