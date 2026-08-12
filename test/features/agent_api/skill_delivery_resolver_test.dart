import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/skill_delivery_resolver.dart';
import 'package:dingdong/features/library/domain/skill_deployment_plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 8, 12);

  Resource skill(
    String id, {
    String name = 'reviewer',
    String digest = 'sha256:one',
    Map<String, SkillDeliveryMode> delivery =
        const <String, SkillDeliveryMode>{},
  }) => Resource(
    id: id,
    type: ResourceType.skill,
    title: id,
    content: '---\nname: $name\ndescription: Review application changes\n---\n',
    skillPackageDigest: digest,
    skillDeliveryByAgent: delivery,
    createdAt: now,
    updatedAt: now,
  );

  test(
    'native delivery is mutually exclusive with the dynamic catalog',
    () async {
      final SkillDeliveryResolution result = await resolveSkillDelivery(
        resources: <Resource>[
          skill(
            'native',
            delivery: const <String, SkillDeliveryMode>{
              'codex': SkillDeliveryMode.nativeProject,
            },
          ),
        ],
        agentId: 'codex',
        workspacePath: '/workspace/app',
      );

      expect(result.candidates, isEmpty);
      expect(result.suppressed.single.resourceId, 'native');
      expect(
        result.suppressed.single.reason,
        SkillSuppressionReason.nativeDelivery,
      );
    },
  );

  test(
    'unknown caller fails closed when a native route is configured',
    () async {
      final SkillDeliveryResolution result = await resolveSkillDelivery(
        resources: <Resource>[
          skill(
            'native',
            delivery: const <String, SkillDeliveryMode>{
              'codex': SkillDeliveryMode.nativeUser,
            },
          ),
        ],
        workspacePath: '/workspace/app',
      );

      expect(result.candidates, isEmpty);
      expect(
        result.suppressed.single.reason,
        SkillSuppressionReason.unknownAgentWithNativeRoute,
      );
    },
  );

  test(
    'dynamic delivery waits until old native copies are confirmed absent',
    () async {
      var presence = SkillDeploymentPresence.possiblyPresent;
      final Resource resource = skill('switching');

      Future<SkillDeploymentPresence> lookup({
        required String resourceId,
        required String agentId,
        required String workspace,
      }) async => presence;

      final SkillDeliveryResolution duringRemoval = await resolveSkillDelivery(
        resources: <Resource>[resource],
        agentId: 'codex',
        workspacePath: '/workspace/app',
        queryPresence: lookup,
      );
      expect(duringRemoval.candidates, isEmpty);
      expect(
        duringRemoval.suppressed.single.reason,
        SkillSuppressionReason.nativePresenceUncertain,
      );

      presence = SkillDeploymentPresence.confirmedAbsent;
      final SkillDeliveryResolution removed = await resolveSkillDelivery(
        resources: <Resource>[resource],
        agentId: 'codex',
        workspacePath: '/workspace/app',
        queryPresence: lookup,
      );
      expect(removed.candidates.single.resource.id, 'switching');
    },
  );

  test('same artifact is folded but different artifacts conflict', () async {
    final SkillDeliveryResolution duplicate = await resolveSkillDelivery(
      resources: <Resource>[
        skill('b', digest: 'sha256:same'),
        skill('a', digest: 'sha256:same'),
      ],
      agentId: 'codex',
      workspacePath: '/workspace/app',
    );
    expect(duplicate.candidates.single.resource.id, 'a');
    expect(duplicate.candidates.single.deduplicatedResourceIds, <String>['b']);
    expect(duplicate.conflicts, isEmpty);

    final SkillDeliveryResolution conflict = await resolveSkillDelivery(
      resources: <Resource>[
        skill('a', digest: 'sha256:first'),
        skill('b', digest: 'sha256:second'),
      ],
      agentId: 'codex',
      workspacePath: '/workspace/app',
    );
    expect(conflict.candidates, isEmpty);
    expect(conflict.conflicts.single.name, 'reviewer');
    expect(conflict.conflicts.single.resourceIds, <String>['a', 'b']);
  });
}
