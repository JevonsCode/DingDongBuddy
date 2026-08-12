import 'package:dingdong/features/agent_api/data/agent_compatibility_routes.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'capabilities advertise the complete native Skill delivery API',
    () async {
      final AgentCompatibilityRoutes routes = AgentCompatibilityRoutes(
        resourceStore: InMemoryResourceStore(),
      );

      final HttpResponseData response = (await routes.get(
        '/agent/capabilities',
        const <String, String>{},
      ))!;

      expect(response.statusCode, 200);
      expect(
        response.json['features'],
        containsAll(<String>[
          'perAgentSkillDelivery',
          'nativeSkillDeployments',
          'skillDeploymentReconciliation',
        ]),
      );
      expect(
        (response.json['endpoints']! as List<Object?>)
            .map((Object? value) => Map<String, String>.from(value! as Map))
            .toSet(),
        containsAll(<Map<String, String>>[
          const <String, String>{
            'method': 'PUT',
            'path': '/library/skills/{id}/delivery',
          },
          const <String, String>{
            'method': 'GET',
            'path': '/library/skills/{id}/deployments',
          },
          const <String, String>{
            'method': 'POST',
            'path': '/library/skills/{id}/reconcile',
          },
        ]),
      );
    },
  );
}
