import 'dart:convert';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/agent_state_routes.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'session hydration keeps only recent records but old ids stay patchable',
    () async {
      final DateTime base = DateTime.utc(2026, 8, 24);
      final InMemoryResourceStore store = InMemoryResourceStore(
        List<Resource>.generate(140, (int index) {
          final DateTime timestamp = base.add(Duration(minutes: index));
          final Map<String, Object?> session = <String, Object?>{
            'id': 'session-$index',
            'task': 'Task $index',
            'status': 'active',
            'createdAt': timestamp.toIso8601String(),
            'updatedAt': timestamp.toIso8601String(),
          };
          return Resource(
            id: 'session-$index',
            type: ResourceType.knowledge,
            group: 'Agent Sessions',
            title: 'Task $index',
            content: jsonEncode(session),
            tags: const <String>['agent-session'],
            createdAt: timestamp,
            updatedAt: timestamp,
          );
        }),
      );
      final AgentStateRoutes routes = AgentStateRoutes(
        resourceStore: store,
        idGenerator: () => 'unused',
        now: () => base.add(const Duration(days: 1)),
      );

      final listed = await routes.route(
        method: 'GET',
        path: '/agent/sessions',
        query: const <String, String>{'limit': '100'},
        body: '',
      );
      final List<Object?> sessions = listed?.json['sessions']! as List<Object?>;
      expect(sessions, hasLength(100));
      expect((sessions.first as Map<String, Object?>)['id'], 'session-139');
      expect((sessions.last as Map<String, Object?>)['id'], 'session-40');

      final patched = await routes.route(
        method: 'PATCH',
        path: '/agent/session/session-0',
        query: const <String, String>{},
        body: '{"status":"completed"}',
      );
      expect(patched?.statusCode, 200);
      final Resource old = (await store.load()).first;
      expect(
        (jsonDecode(old.content) as Map<String, Object?>)['status'],
        'completed',
      );

      final afterPatch = await routes.route(
        method: 'GET',
        path: '/agent/sessions',
        query: const <String, String>{'limit': '100'},
        body: '',
      );
      final List<Object?> patchedSessions =
          afterPatch?.json['sessions']! as List<Object?>;
      expect(
        (patchedSessions.first as Map<String, Object?>)['id'],
        'session-0',
      );
      expect(
        (patchedSessions.last as Map<String, Object?>)['id'],
        'session-41',
      );

      await routes.route(
        method: 'POST',
        path: '/agent/session',
        query: const <String, String>{},
        body: '{"task":"Newest task"}',
      );
      final afterCreate = await routes.route(
        method: 'GET',
        path: '/agent/sessions',
        query: const <String, String>{'limit': '1'},
        body: '',
      );
      final List<Object?> createdSessions =
          afterCreate?.json['sessions']! as List<Object?>;
      expect((createdSessions.single as Map<String, Object?>)['id'], 'unused');
    },
  );

  test(
    'sessions and handoffs remain available after route reconstruction',
    () async {
      final InMemoryResourceStore store = InMemoryResourceStore();
      int nextId = 0;
      AgentStateRoutes routes() => AgentStateRoutes(
        resourceStore: store,
        idGenerator: () => 'record-${nextId += 1}',
        now: () => DateTime.utc(2026, 7, 12),
      );
      final AgentStateRoutes first = routes();

      await first.route(
        method: 'POST',
        path: '/agent/session',
        query: const <String, String>{},
        body: '{"task":"Refactor desktop","source":"Codex"}',
      );
      await first.route(
        method: 'POST',
        path: '/agent/handoff',
        query: const <String, String>{},
        body: '{"title":"Windows QA","summary":"Run the Windows build"}',
      );

      final AgentStateRoutes reconstructed = routes();
      final sessions = await reconstructed.route(
        method: 'GET',
        path: '/agent/sessions',
        query: const <String, String>{},
        body: '',
      );
      final handoffs = await reconstructed.route(
        method: 'GET',
        path: '/agent/handoffs',
        query: const <String, String>{},
        body: '',
      );

      expect(sessions?.json['count'], 1);
      expect(handoffs?.json['count'], 1);
    },
  );
}
