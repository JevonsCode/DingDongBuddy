import 'dart:convert';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';

/// Builds a bounded, summary-first context response for agent request startup.
final class AgentBridge {
  AgentBridge(
    this._store, {
    TriggerGroupStore? triggerGroupStore,
    DateTime Function()? now,
  }) : _triggerGroupStore = triggerGroupStore ?? InMemoryTriggerGroupStore(),
       _now = now ?? DateTime.now;

  final ResourceStore _store;
  final TriggerGroupStore _triggerGroupStore;
  final DateTime Function() _now;

  Future<HttpResponseData> respond(String body) async {
    try {
      final Map<String, Object?> request = body.trim().isEmpty
          ? <String, Object?>{}
          : jsonDecode(body) as Map<String, Object?>;
      final String task = (request['task'] as String? ?? '').trim();
      final String source = (request['source'] as String? ?? 'Agent').trim();
      final String expand = request['expand'] as String? ?? 'none';
      final int limit = (request['limit'] as int? ?? 12).clamp(1, 60);
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
      );
      final Set<String> terms = task
          .toLowerCase()
          .split(RegExp(r'[^\p{L}\p{N}_-]+', unicode: true))
          .where((String value) => value.length >= 2)
          .toSet();
      final List<Resource> resources = await _store.load();
      final List<TriggerGroup> triggerGroups = await _triggerGroupStore.load();
      final Map<String, TriggerGroup> triggerGroupsById =
          <String, TriggerGroup>{
            for (final TriggerGroup group in triggerGroups) group.id: group,
          };
      bool matchesScope(Resource resource) {
        if (resource.triggerGroupIds.isEmpty) {
          return true;
        }
        return resource.triggerGroupIds.any(
          (String id) => triggerGroupsById[id]?.matches(context) ?? false,
        );
      }

      final List<Resource> selected = resources
          .where((Resource resource) => resource.enabled)
          .where(matchesScope)
          .where(
            (Resource resource) =>
                resource.pinned ||
                resource.activation == ResourceActivation.always ||
                _matches(resource, terms),
          )
          .take(limit)
          .toList(growable: false);
      final Set<String> selectedIds = selected
          .map((Resource resource) => resource.id)
          .toSet();
      final DateTime usedAt = _now().toUtc();
      final List<Resource> updatedResources = resources
          .map(
            (Resource resource) => selectedIds.contains(resource.id)
                ? resource.copyWith(
                    usageCount: resource.usageCount + 1,
                    lastUsedAt: usedAt,
                  )
                : resource,
          )
          .toList(growable: false);
      if (selectedIds.isNotEmpty) {
        await _store.save(updatedResources);
      }
      final List<Resource> used = updatedResources
          .where((Resource resource) => selectedIds.contains(resource.id))
          .toList(growable: false);
      final Set<String> matchedTriggerGroupIds = triggerGroups
          .where((TriggerGroup group) => group.matches(context))
          .map((TriggerGroup group) => group.id)
          .toSet();

      List<Map<String, Object?>> items(ResourceType type) {
        return used
            .where((Resource resource) => resource.type == type)
            .map((Resource resource) {
              final bool contentIncluded =
                  expand == 'all' ||
                  (expand == 'prompts' && type == ResourceType.prompt);
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
          'source': source.isEmpty ? 'Agent' : source,
          'context': <String, Object?>{
            'workspacePath': context.projectPath,
            'repositoryUrl': context.repositoryUrl,
            'matchedTriggerGroupIds': matchedTriggerGroupIds.toList(),
          },
          'active': <String, Object?>{
            'prompts': items(ResourceType.prompt),
            'skills': items(ResourceType.skill),
            'mcps': items(ResourceType.mcp),
            'knowledge': items(ResourceType.knowledge),
          },
          'privacy': const <String, Object?>{
            'clipboardIncluded': false,
            'summaryFirst': true,
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
