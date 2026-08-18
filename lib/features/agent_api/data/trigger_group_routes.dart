import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/library/data/configuration_transaction_journal.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/resource_scope_policy.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:path/path.dart' as path;

/// Public CRUD for reusable project, repository, and Agent-source scopes.
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

  Future<HttpResponseData> create(String body) =>
      _withMutationLock(() => _create(body));

  Future<HttpResponseData> upsert(String body) =>
      _withMutationLock(() => _upsert(body));

  Future<HttpResponseData> update(String id, String body) =>
      _withMutationLock(() => _update(id, body));

  Future<HttpResponseData> delete(String id) =>
      _withMutationLock(() => _delete(id));

  Future<HttpResponseData> _create(String body) async {
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

  Future<HttpResponseData> _upsert(String body) async {
    try {
      final Map<String, Object?> payload = _decode(body);
      final String name = (payload['name'] as String? ?? '').trim();
      final String projectPath = (payload['projectPath'] as String? ?? '')
          .trim();
      final String repositoryUrl = (payload['repositoryUrl'] as String? ?? '')
          .trim();
      final String source = (payload['source'] as String? ?? '').trim();
      final List<TriggerRule> rules = <TriggerRule>[
        if (projectPath.isNotEmpty)
          TriggerRule(
            field: TriggerRuleField.projectPath,
            operator: TriggerRuleOperator.equals,
            value: projectPath,
          ),
        if (repositoryUrl.isNotEmpty)
          TriggerRule(
            field: TriggerRuleField.repositoryUrl,
            operator: TriggerRuleOperator.equals,
            value: repositoryUrl,
          ),
        if (source.isNotEmpty)
          TriggerRule(
            field: TriggerRuleField.source,
            operator: TriggerRuleOperator.equals,
            value: source,
          ),
      ];
      final HttpResponseData? invalid = _validate(name, rules);
      if (invalid != null) {
        return invalid;
      }
      final List<TriggerGroup> groups = List<TriggerGroup>.of(
        await store.load(),
      );
      final List<int> matches = <int>[
        for (var index = 0; index < groups.length; index += 1)
          if (groups[index].name.toLowerCase() == name.toLowerCase()) index,
      ];
      if (matches.length > 1) {
        return const HttpResponseData(
          statusCode: 409,
          json: <String, Object?>{
            'status': 'error',
            'message': 'Multiple trigger groups use this name',
          },
        );
      }
      final DateTime timestamp = now().toUtc();
      if (matches.isEmpty) {
        final TriggerGroup group = TriggerGroup(
          id: idGenerator(),
          name: name,
          rules: rules,
          createdAt: timestamp,
          updatedAt: timestamp,
        );
        await store.save(<TriggerGroup>[...groups, group]);
        return HttpResponseData(
          statusCode: 201,
          json: <String, Object?>{'status': 'created', 'group': group.toJson()},
        );
      }
      final int index = matches.single;
      final List<TriggerGroup> previousGroups = List<TriggerGroup>.of(groups);
      final TriggerGroup updated = groups[index].copyWith(
        name: name,
        rules: rules,
        updatedAt: timestamp,
      );
      groups[index] = updated;
      final _ResourceMutation? resourceMutation =
          await _strictSkillMutationForGroupUpdate(
            changedGroupId: updated.id,
            proposedGroups: groups,
            timestamp: timestamp,
          );
      await _saveCoordinatedChange(
        previousGroups: previousGroups,
        proposedGroups: groups,
        resourceMutation: resourceMutation,
      );
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{'status': 'updated', 'group': updated.toJson()},
      );
    } on FormatException catch (error) {
      return _badRequest(error.message.toString());
    } on Object {
      return _badRequest('Invalid trigger group JSON body');
    }
  }

  Future<HttpResponseData> _update(String id, String body) async {
    final List<TriggerGroup> groups = List<TriggerGroup>.of(await store.load());
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
      final List<TriggerGroup> previousGroups = List<TriggerGroup>.of(groups);
      final DateTime timestamp = now().toUtc();
      final TriggerGroup updated = existing.copyWith(
        name: name,
        rules: rules,
        updatedAt: timestamp,
      );
      groups[index] = updated;
      final _ResourceMutation? resourceMutation =
          await _strictSkillMutationForGroupUpdate(
            changedGroupId: updated.id,
            proposedGroups: groups,
            timestamp: timestamp,
          );
      await _saveCoordinatedChange(
        previousGroups: previousGroups,
        proposedGroups: groups,
        resourceMutation: resourceMutation,
      );
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{'status': 'updated', 'group': updated.toJson()},
      );
    } on FormatException catch (error) {
      return _badRequest(error.message.toString());
    } on Object {
      return _badRequest('Invalid trigger group JSON body');
    }
  }

  Future<HttpResponseData> _delete(String id) async {
    final List<TriggerGroup> groups = await store.load();
    if (!groups.any((TriggerGroup group) => group.id == id)) {
      return _notFound();
    }
    final List<TriggerGroup> proposedGroups = groups
        .where((TriggerGroup group) => group.id != id)
        .toList(growable: false);
    final _ResourceMutation? resourceMutation =
        await _resourceMutationForGroupDeletion(
          deletedGroupId: id,
          proposedGroups: proposedGroups,
          timestamp: now().toUtc(),
        );
    await _saveCoordinatedChange(
      previousGroups: groups,
      proposedGroups: proposedGroups,
      resourceMutation: resourceMutation,
    );
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'deleted',
        'id': id,
        'detachedResourceCount': resourceMutation?.affectedCount ?? 0,
      },
    );
  }

  Future<_ResourceMutation?> _strictSkillMutationForGroupUpdate({
    required String changedGroupId,
    required List<TriggerGroup> proposedGroups,
    required DateTime timestamp,
  }) async {
    final ResourceStore? resources = resourceStore;
    if (resources == null) {
      return null;
    }
    final List<Resource> previous = List<Resource>.of(await resources.load());
    final Map<String, TriggerGroup> groupsById = <String, TriggerGroup>{
      for (final TriggerGroup group in proposedGroups) group.id: group,
    };
    var affectedCount = 0;
    final List<Resource> proposed = previous
        .map((Resource resource) {
          if (resource.type != ResourceType.skill ||
              !resource.strictProjectSkill ||
              !resource.triggerGroupIds.contains(changedGroupId)) {
            return resource;
          }
          final List<String> projectPaths = resolveStrictSkillProjectPaths(
            resource.triggerGroupIds,
            groupsById,
          );
          if (_sameStrings(projectPaths, resource.skillProjectPaths)) {
            return resource;
          }
          affectedCount += 1;
          return resource.copyWith(
            skillProjectPaths: projectPaths,
            updatedAt: timestamp,
          );
        })
        .toList(growable: false);
    return _ResourceMutation(
      store: resources,
      previous: previous,
      proposed: proposed,
      affectedCount: affectedCount,
    );
  }

  Future<_ResourceMutation?> _resourceMutationForGroupDeletion({
    required String deletedGroupId,
    required List<TriggerGroup> proposedGroups,
    required DateTime timestamp,
  }) async {
    final ResourceStore? resources = resourceStore;
    if (resources == null) {
      return null;
    }
    final List<Resource> previous = List<Resource>.of(await resources.load());
    final Map<String, TriggerGroup> groupsById = <String, TriggerGroup>{
      for (final TriggerGroup group in proposedGroups) group.id: group,
    };
    var affectedCount = 0;
    final List<Resource> proposed = previous
        .map((Resource resource) {
          if (!resource.triggerGroupIds.contains(deletedGroupId)) {
            return resource;
          }
          affectedCount += 1;
          final List<String> remainingGroupIds = resource.triggerGroupIds
              .where((String groupId) => groupId != deletedGroupId)
              .toList(growable: false);
          var enabled = remainingGroupIds.isEmpty ? false : resource.enabled;
          List<String> projectPaths = resource.skillProjectPaths;
          if (resource.type == ResourceType.skill &&
              resource.strictProjectSkill) {
            if (remainingGroupIds.isEmpty) {
              projectPaths = const <String>[];
            } else {
              try {
                projectPaths = resolveStrictSkillProjectPaths(
                  remainingGroupIds,
                  groupsById,
                );
              } on FormatException {
                projectPaths = const <String>[];
                enabled = false;
              }
            }
          }
          return resource.copyWith(
            triggerGroupIds: remainingGroupIds,
            skillProjectPaths: projectPaths,
            enabled: enabled,
            updatedAt: timestamp,
          );
        })
        .toList(growable: false);
    return _ResourceMutation(
      store: resources,
      previous: previous,
      proposed: proposed,
      affectedCount: affectedCount,
    );
  }

  Future<void> _saveCoordinatedChange({
    required List<TriggerGroup> previousGroups,
    required List<TriggerGroup> proposedGroups,
    required _ResourceMutation? resourceMutation,
  }) async {
    final bool changesResources =
        resourceMutation != null && resourceMutation.affectedCount > 0;
    final ConfigurationTransactionJournal? journal = changesResources
        ? _transactionJournal()
        : null;
    final ConfigurationTransactionRecord? transaction =
        journal == null || resourceMutation == null
        ? null
        : ConfigurationTransactionRecord(
            mode: ConfigurationTransactionMode.commit,
            resourceFilePath: _resourceFile()!.absolute.path,
            triggerGroupFilePath: _triggerGroupFile()!.absolute.path,
            previousResources: resourceMutation.previous,
            proposedResources: resourceMutation.proposed,
            previousGroups: previousGroups,
            proposedGroups: proposedGroups,
          );
    if (journal != null && transaction != null) {
      await journal.write(transaction);
    }
    try {
      await store.save(proposedGroups);
      if (changesResources) {
        await resourceMutation.store.save(resourceMutation.proposed);
      }
    } on Object catch (error, stackTrace) {
      var rollbackComplete = true;
      try {
        await store.save(previousGroups);
      } on Object {
        rollbackComplete = false;
      }
      if (changesResources) {
        try {
          await resourceMutation.store.save(resourceMutation.previous);
        } on Object {
          rollbackComplete = false;
        }
      }
      if (journal != null && transaction != null) {
        if (rollbackComplete) {
          await journal.clear();
        } else {
          try {
            await journal.write(
              transaction.copyWith(mode: ConfigurationTransactionMode.rollback),
            );
          } on Object {
            // The original commit intent remains recoverable if changing the
            // journal mode fails.
          }
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
    await journal?.clear();
  }

  Future<T> _withMutationLock<T>(Future<T> Function() action) {
    Future<T> recoverThenAct() async {
      await _recoverPendingTransaction();
      return action();
    }

    Future<T> withTriggerGroupLock() {
      final TriggerGroupStore current = store;
      if (current is ExclusiveTriggerGroupStore) {
        return (current as ExclusiveTriggerGroupStore).exclusiveMutation(
          recoverThenAct,
        );
      }
      return recoverThenAct();
    }

    final ResourceStore? resources = resourceStore;
    if (resources is ExclusiveResourceStore) {
      return (resources as ExclusiveResourceStore).exclusiveMutation(
        withTriggerGroupLock,
      );
    }
    return withTriggerGroupLock();
  }

  Future<void> _recoverPendingTransaction() async {
    final ConfigurationTransactionJournal? journal = _transactionJournal();
    final ResourceStore? resources = resourceStore;
    final File? resourceFile = _resourceFile();
    final File? triggerFile = _triggerGroupFile();
    if (journal == null ||
        resources == null ||
        resourceFile == null ||
        triggerFile == null) {
      return;
    }
    final ConfigurationTransactionRecord? transaction = await journal.read();
    if (transaction == null) {
      return;
    }
    if (transaction.resourceFilePath != resourceFile.absolute.path ||
        transaction.triggerGroupFilePath != triggerFile.absolute.path) {
      throw StateError(
        'DingDong configuration transaction targets do not match the active stores.',
      );
    }
    final bool rollback =
        transaction.mode == ConfigurationTransactionMode.rollback;
    await store.save(
      rollback ? transaction.previousGroups : transaction.proposedGroups,
    );
    await resources.save(
      rollback ? transaction.previousResources : transaction.proposedResources,
    );
    await journal.clear();
  }

  ConfigurationTransactionJournal? _transactionJournal() {
    final File? resourceFile = _resourceFile();
    final File? triggerFile = _triggerGroupFile();
    if (resourceFile == null || triggerFile == null) {
      return null;
    }
    return ConfigurationTransactionJournal(
      File(
        path.join(
          triggerFile.parent.path,
          '.dingdong-configuration-transaction.json',
        ),
      ),
    );
  }

  File? _resourceFile() {
    final ResourceStore? resources = resourceStore;
    return resources is ResourceFileLocator
        ? (resources as ResourceFileLocator).resourceFile
        : null;
  }

  File? _triggerGroupFile() {
    final TriggerGroupStore groups = store;
    return groups is TriggerGroupFileLocator
        ? (groups as TriggerGroupFileLocator).triggerGroupFile
        : null;
  }
}

final class _ResourceMutation {
  const _ResourceMutation({
    required this.store,
    required this.previous,
    required this.proposed,
    required this.affectedCount,
  });

  final ResourceStore store;
  final List<Resource> previous;
  final List<Resource> proposed;
  final int affectedCount;
}

bool _sameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
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
