import 'dart:convert';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';

/// Bounded coordination state plus durable memory, bundle, and handoff records.
final class AgentStateRoutes {
  AgentStateRoutes({
    required this.resourceStore,
    required this.idGenerator,
    required this.now,
  });

  final ResourceStore resourceStore;
  final String Function() idGenerator;
  final DateTime Function() now;
  final Map<String, Map<String, Object?>> _presence =
      <String, Map<String, Object?>>{};
  final Map<String, Map<String, Object?>> _sessions =
      <String, Map<String, Object?>>{};
  final Map<String, Map<String, Object?>> _handoffs =
      <String, Map<String, Object?>>{};

  Future<HttpResponseData?> route({
    required String method,
    required String path,
    required Map<String, String> query,
    required String body,
  }) async {
    if (path == '/agent/presence') {
      return method == 'GET'
          ? _listPresence(query)
          : method == 'POST'
          ? _upsertPresence(body)
          : null;
    }
    if (path == '/agent/session' && method == 'POST') {
      return _createSession(body);
    }
    if (path.startsWith('/agent/session/') && method == 'PATCH') {
      return _patchSession(path.substring('/agent/session/'.length), body);
    }
    if (path == '/agent/sessions' && method == 'GET') {
      return _listSessions(query);
    }
    if (path == '/agent/memory' && method == 'POST') {
      return _createMemory(body);
    }
    if (path == '/agent/memories' && method == 'GET') {
      return _listMemories(query);
    }
    if (path == '/agent/bundle' && method == 'POST') {
      return _createBundle(body);
    }
    if (path == '/agent/handoff' && method == 'POST') {
      return _createHandoff(body);
    }
    if (path.startsWith('/agent/handoff/') && method == 'PATCH') {
      return _patchHandoff(path.substring('/agent/handoff/'.length), body);
    }
    if (path == '/agent/handoffs' && method == 'GET') {
      return _listHandoffs(query);
    }
    return null;
  }

  HttpResponseData _upsertPresence(String body) {
    try {
      final Map<String, Object?> payload = _decode(body);
      final String source = (payload['source'] as String? ?? '').trim();
      if (source.isEmpty) {
        return _badRequest('source is required');
      }
      final String status = (payload['status'] as String? ?? 'active').trim();
      final Map<String, Object?> record = <String, Object?>{
        'source': source,
        'status': status.isEmpty ? 'active' : status,
        'task': payload['task'] as String? ?? '',
        'capabilities':
            payload['capabilities'] as List<Object?>? ?? const <Object?>[],
        'updatedAt': now().toUtc().toIso8601String(),
      };
      _presence[source.toLowerCase()] = record;
      _trimMap(_presence, 50);
      return HttpResponseData(statusCode: 200, json: record);
    } on Object {
      return _badRequest('Invalid agent presence JSON body');
    }
  }

  HttpResponseData _listPresence(Map<String, String> query) {
    final int limit = (int.tryParse(query['limit'] ?? '') ?? 20).clamp(0, 50);
    final List<Map<String, Object?>> records = _presence.values
        .where(
          (record) =>
              query['status'] == null || record['status'] == query['status'],
        )
        .take(limit)
        .toList(growable: false);
    return _ok(<String, Object?>{'agents': records, 'count': records.length});
  }

  Future<HttpResponseData> _createSession(String body) async {
    try {
      final Map<String, Object?> payload = _decode(body);
      final String task = (payload['task'] as String? ?? '').trim();
      if (task.isEmpty) {
        return _badRequest('task is required');
      }
      final String timestamp = now().toUtc().toIso8601String();
      final String id = idGenerator();
      final Map<String, Object?> session = <String, Object?>{
        'id': id,
        ...payload,
        'task': task,
        'status': payload['status'] as String? ?? 'active',
        'createdAt': timestamp,
        'updatedAt': timestamp,
      };
      _sessions[id] = session;
      _trimMap(_sessions, 100);
      await _appendResource(
        _agentResource(
          payload,
          id: id,
          group: 'Agent Sessions',
          title: task,
          content: jsonEncode(session),
          marker: 'agent-session',
        ),
      );
      return HttpResponseData(
        statusCode: 201,
        json: <String, Object?>{'status': 'created', 'session': session},
      );
    } on Object {
      return _badRequest('Invalid agent session JSON body');
    }
  }

  Future<HttpResponseData> _patchSession(String id, String body) async {
    await _hydrateRecords(_sessions, 'agent-session');
    final Map<String, Object?>? existing = _sessions[id];
    if (existing == null) {
      return _notFound('Agent session not found');
    }
    try {
      final Map<String, Object?> updated = <String, Object?>{
        ...existing,
        ..._decode(body),
        'id': id,
        'updatedAt': now().toUtc().toIso8601String(),
      };
      _sessions[id] = updated;
      await _updateAgentResource(id, updated);
      return _ok(<String, Object?>{'session': updated});
    } on Object {
      return _badRequest('Invalid agent session patch JSON body');
    }
  }

  Future<HttpResponseData> _listSessions(Map<String, String> query) async {
    await _hydrateRecords(_sessions, 'agent-session');
    final int limit = (int.tryParse(query['limit'] ?? '') ?? 20).clamp(0, 100);
    final List<Map<String, Object?>> sessions = _sessions.values
        .where(
          (record) =>
              query['status'] == null || record['status'] == query['status'],
        )
        .where(
          (record) =>
              query['source'] == null || record['source'] == query['source'],
        )
        .take(limit)
        .toList(growable: false);
    return _ok(<String, Object?>{
      'sessions': sessions,
      'count': sessions.length,
    });
  }

  Future<HttpResponseData> _createMemory(String body) async {
    try {
      final Map<String, Object?> payload = _decode(body);
      final String title = (payload['title'] as String? ?? '').trim();
      final String content = (payload['content'] as String? ?? '').trim();
      if (title.isEmpty || content.isEmpty) {
        return _badRequest('title and content are required');
      }
      final String kind = (payload['kind'] as String? ?? 'note').trim();
      final String source = (payload['source'] as String? ?? 'Agent').trim();
      final DateTime timestamp = now().toUtc();
      final Resource memory = Resource(
        id: idGenerator(),
        type: ResourceType.knowledge,
        group: 'Agent Memories',
        title: title,
        content: content,
        tags: _unique(<String>[
          'agent-memory',
          'kind:$kind',
          'source:$source',
          ...(payload['tags'] as List<Object?>? ?? const <Object?>[])
              .cast<String>(),
        ]),
        source: source,
        pinned: payload['pinned'] as bool? ?? false,
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      await _appendResource(memory);
      return HttpResponseData(
        statusCode: 201,
        json: <String, Object?>{
          'status': 'created',
          'memory': memory.toApiJson(),
        },
      );
    } on Object {
      return _badRequest('Invalid agent memory JSON body');
    }
  }

  Future<HttpResponseData> _listMemories(Map<String, String> query) async {
    final String needle = (query['q'] ?? '').trim().toLowerCase();
    final int limit = (int.tryParse(query['limit'] ?? '') ?? 20).clamp(0, 100);
    final List<Resource> memories = (await resourceStore.load())
        .where((Resource item) => item.tags.contains('agent-memory'))
        .where(
          (Resource item) =>
              needle.isEmpty ||
              <String>[
                item.title,
                item.content,
                ...item.tags,
              ].join(' ').toLowerCase().contains(needle),
        )
        .take(limit)
        .toList(growable: false);
    return _ok(<String, Object?>{
      'memories': memories
          .map((Resource item) => item.toApiJson())
          .toList(growable: false),
      'count': memories.length,
    });
  }

  Future<HttpResponseData> _createBundle(String body) async {
    try {
      final Map<String, Object?> payload = _decode(body);
      final String title = (payload['title'] as String? ?? '').trim();
      final String task = (payload['task'] as String? ?? '').trim();
      if (title.isEmpty || task.isEmpty) {
        return _badRequest('title and task are required');
      }
      final List<Resource> candidates = (await resourceStore.load())
          .where((Resource item) => !item.tags.contains('agent-memory'))
          .where((Resource item) => _matches(item, task))
          .take((payload['limit'] as int? ?? 12).clamp(1, 30))
          .toList(growable: false);
      final Resource bundle = _agentResource(
        payload,
        group: 'Agent Bundles',
        title: title,
        content: const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'task': task,
          'resources': candidates
              .map((Resource item) => item.toSummaryApiJson())
              .toList(growable: false),
        }),
        marker: 'agent-bundle',
      );
      await _appendResource(bundle);
      return HttpResponseData(
        statusCode: 201,
        json: <String, Object?>{
          'status': 'created',
          'item': bundle.toApiJson(),
          'included': candidates
              .map((Resource item) => item.toSummaryApiJson())
              .toList(growable: false),
        },
      );
    } on Object {
      return _badRequest('Invalid agent bundle JSON body');
    }
  }

  Future<HttpResponseData> _createHandoff(String body) async {
    try {
      final Map<String, Object?> payload = _decode(body);
      final String title = (payload['title'] as String? ?? '').trim();
      final String summary = (payload['summary'] as String? ?? '').trim();
      if (title.isEmpty || summary.isEmpty) {
        return _badRequest('title and summary are required');
      }
      final String id = idGenerator();
      final String timestamp = now().toUtc().toIso8601String();
      final Map<String, Object?> handoff = <String, Object?>{
        'id': id,
        ...payload,
        'title': title,
        'summary': summary,
        'status': payload['status'] as String? ?? 'open',
        'createdAt': timestamp,
        'updatedAt': timestamp,
      };
      _handoffs[id] = handoff;
      _trimMap(_handoffs, 100);
      final Resource resource = _agentResource(
        payload,
        id: id,
        group: 'Agent Handoffs',
        title: title,
        content: jsonEncode(handoff),
        marker: 'agent-handoff',
      );
      await _appendResource(resource);
      return HttpResponseData(
        statusCode: 201,
        json: <String, Object?>{'status': 'created', 'handoff': handoff},
      );
    } on Object {
      return _badRequest('Invalid agent handoff JSON body');
    }
  }

  Future<HttpResponseData> _patchHandoff(String id, String body) async {
    await _hydrateRecords(_handoffs, 'agent-handoff');
    final Map<String, Object?>? existing = _handoffs[id];
    if (existing == null) {
      return _notFound('Agent handoff not found');
    }
    try {
      final Map<String, Object?> updated = <String, Object?>{
        ...existing,
        ..._decode(body),
        'id': id,
        'updatedAt': now().toUtc().toIso8601String(),
      };
      _handoffs[id] = updated;
      await _updateAgentResource(id, updated);
      return _ok(<String, Object?>{'handoff': updated});
    } on Object {
      return _badRequest('Invalid agent handoff patch JSON body');
    }
  }

  Future<HttpResponseData> _listHandoffs(Map<String, String> query) async {
    await _hydrateRecords(_handoffs, 'agent-handoff');
    final int limit = (int.tryParse(query['limit'] ?? '') ?? 20).clamp(0, 100);
    final List<Map<String, Object?>> handoffs = _handoffs.values
        .where(
          (record) =>
              query['status'] == null || record['status'] == query['status'],
        )
        .take(limit)
        .toList(growable: false);
    return _ok(<String, Object?>{
      'handoffs': handoffs,
      'count': handoffs.length,
    });
  }

  Resource _agentResource(
    Map<String, Object?> payload, {
    String? id,
    required String group,
    required String title,
    required String content,
    required String marker,
  }) {
    final DateTime timestamp = now().toUtc();
    return Resource(
      id: id ?? idGenerator(),
      type: ResourceType.knowledge,
      group: group,
      title: title,
      content: content,
      tags: _unique(<String>[
        marker,
        ...(payload['tags'] as List<Object?>? ?? const <Object?>[])
            .cast<String>(),
      ]),
      source: payload['source'] as String? ?? 'Agent',
      pinned: payload['pinned'] as bool? ?? false,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  Future<void> _appendResource(Resource resource) async {
    await resourceStore.save(<Resource>[
      ...await resourceStore.load(),
      resource,
    ]);
  }

  Future<void> _hydrateRecords(
    Map<String, Map<String, Object?>> destination,
    String marker,
  ) async {
    for (final Resource resource in await resourceStore.load()) {
      if (!resource.tags.contains(marker) ||
          destination.containsKey(resource.id)) {
        continue;
      }
      try {
        final Object? decoded = jsonDecode(resource.content);
        if (decoded is Map<String, Object?>) {
          destination[resource.id] = <String, Object?>{
            ...decoded,
            'id': resource.id,
          };
        }
      } on FormatException {
        // Older records without structured content remain library resources.
      }
    }
  }

  Future<void> _updateAgentResource(
    String id,
    Map<String, Object?> record,
  ) async {
    final List<Resource> resources = List<Resource>.of(
      await resourceStore.load(),
    );
    final int index = resources.indexWhere((Resource item) => item.id == id);
    if (index < 0) {
      return;
    }
    resources[index] = resources[index].copyWith(
      title: record['title'] as String? ?? record['task'] as String?,
      content: jsonEncode(record),
      updatedAt: now().toUtc(),
    );
    await resourceStore.save(resources);
  }
}

Map<String, Object?> _decode(String body) =>
    jsonDecode(body) as Map<String, Object?>;

bool _matches(Resource resource, String query) {
  final Set<String> tokens = query
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}_-]+', unicode: true))
      .where((String token) => token.length >= 2)
      .toSet();
  final String haystack = <String>[
    resource.title,
    resource.content,
    resource.group,
    ...resource.tags,
  ].join(' ').toLowerCase();
  return resource.pinned || tokens.any(haystack.contains);
}

List<String> _unique(List<String> values) => values.toSet().toList();

void _trimMap(Map<String, Map<String, Object?>> values, int limit) {
  while (values.length > limit) {
    values.remove(values.keys.first);
  }
}

HttpResponseData _ok(Map<String, Object?> values) => HttpResponseData(
  statusCode: 200,
  json: <String, Object?>{'status': 'ok', 'service': 'DingDong', ...values},
);

HttpResponseData _badRequest(String message) => HttpResponseData(
  statusCode: 400,
  json: <String, Object?>{'status': 'error', 'message': message},
);

HttpResponseData _notFound(String message) => HttpResponseData(
  statusCode: 404,
  json: <String, Object?>{'status': 'error', 'message': message},
);
