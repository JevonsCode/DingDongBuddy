import 'dart:convert';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';

/// Public CRUD for reusable project and repository trigger scopes.
final class TriggerGroupRoutes {
  TriggerGroupRoutes({
    required this.store,
    this.resourceStore,
    required this.idGenerator,
    required this.now,
  });

  final TriggerGroupStore store;
  final ResourceStore? resourceStore;
  final String Function() idGenerator;
  final DateTime Function() now;

  Future<HttpResponseData> list() async => HttpResponseData(
    statusCode: 200,
    json: <String, Object?>{
      'status': 'ok',
      'groups': (await store.load())
          .map((TriggerGroup group) => group.toJson())
          .toList(growable: false),
    },
  );

  Future<HttpResponseData> create(String body) async {
    try {
      final Map<String, Object?> payload = _decode(body);
      final String name = (payload['name'] as String? ?? '').trim();
      final List<TriggerRule> rules = _rules(payload);
      final HttpResponseData? invalid = _validate(name, rules);
      if (invalid != null) {
        return invalid;
      }
      final DateTime timestamp = now().toUtc();
      final TriggerGroup group = TriggerGroup(
        id: idGenerator(),
        name: name,
        rules: rules,
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      await store.save(<TriggerGroup>[...await store.load(), group]);
      return HttpResponseData(
        statusCode: 201,
        json: <String, Object?>{'status': 'created', 'group': group.toJson()},
      );
    } on Object {
      return _badRequest('Invalid trigger group JSON body');
    }
  }

  Future<HttpResponseData> update(String id, String body) async {
    final List<TriggerGroup> groups = await store.load();
    final int index = groups.indexWhere((TriggerGroup group) => group.id == id);
    if (index < 0) {
      return _notFound();
    }
    try {
      final Map<String, Object?> payload = _decode(body);
      if (payload.isEmpty) {
        return _badRequest('At least one trigger group field is required');
      }
      final TriggerGroup existing = groups[index];
      final String name = payload.containsKey('name')
          ? (payload['name'] as String? ?? '').trim()
          : existing.name;
      final List<TriggerRule> rules = payload.containsKey('rules')
          ? _rules(payload)
          : existing.rules;
      final HttpResponseData? invalid = _validate(name, rules);
      if (invalid != null) {
        return invalid;
      }
      final TriggerGroup updated = existing.copyWith(
        name: name,
        rules: rules,
        updatedAt: now().toUtc(),
      );
      groups[index] = updated;
      await store.save(groups);
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{'status': 'updated', 'group': updated.toJson()},
      );
    } on Object {
      return _badRequest('Invalid trigger group JSON body');
    }
  }

  Future<HttpResponseData> delete(String id) async {
    final List<TriggerGroup> groups = await store.load();
    if (!groups.any((TriggerGroup group) => group.id == id)) {
      return _notFound();
    }
    var detachedResourceCount = 0;
    final ResourceStore? resources = resourceStore;
    if (resources != null) {
      final List<Resource> current = await resources.load();
      final DateTime timestamp = now().toUtc();
      final List<Resource> updated = current
          .map((Resource resource) {
            if (!resource.triggerGroupIds.contains(id)) {
              return resource;
            }
            detachedResourceCount += 1;
            return resource.copyWith(
              triggerGroupIds: resource.triggerGroupIds
                  .where((String groupId) => groupId != id)
                  .toList(growable: false),
              updatedAt: timestamp,
            );
          })
          .toList(growable: false);
      if (detachedResourceCount > 0) {
        await resources.save(updated);
      }
    }
    await store.save(
      groups.where((TriggerGroup group) => group.id != id).toList(),
    );
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'deleted',
        'id': id,
        'detachedResourceCount': detachedResourceCount,
      },
    );
  }
}

Map<String, Object?> _decode(String body) =>
    jsonDecode(body) as Map<String, Object?>;

List<TriggerRule> _rules(Map<String, Object?> payload) =>
    (payload['rules'] as List<Object?>? ?? const <Object?>[])
        .map(
          (Object? value) =>
              TriggerRule.fromJson(value as Map<String, Object?>),
        )
        .toList(growable: false);

HttpResponseData? _validate(String name, List<TriggerRule> rules) {
  if (name.isEmpty) {
    return _badRequest('name is required');
  }
  if (rules.isEmpty || rules.any((TriggerRule rule) => rule.value.isEmpty)) {
    return _badRequest('At least one complete rule is required');
  }
  return null;
}

HttpResponseData _badRequest(String message) => HttpResponseData(
  statusCode: 400,
  json: <String, Object?>{'status': 'error', 'message': message},
);

HttpResponseData _notFound() => const HttpResponseData(
  statusCode: 404,
  json: <String, Object?>{
    'status': 'error',
    'message': 'Trigger group not found',
  },
);
