import 'package:dingdong/features/agent_api/data/agent_state_routes.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
