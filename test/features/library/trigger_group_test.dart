import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trigger groups match any normalized project condition', () {
    final TriggerGroup group = TriggerGroup(
      id: 'dingdong',
      name: 'DingDong project',
      rules: <TriggerRule>[
        TriggerRule(
          field: TriggerRuleField.projectPath,
          operator: TriggerRuleOperator.equals,
          value: r'\workspace\dingdong\',
        ),
        TriggerRule(
          field: TriggerRuleField.repositoryUrl,
          operator: TriggerRuleOperator.contains,
          value: 'DingDongBuddy',
        ),
      ],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

    expect(
      group.matches(const TriggerContext(projectPath: '/workspace/dingdong/')),
      isTrue,
    );
    expect(
      group.matches(
        const TriggerContext(
          repositoryUrl: 'https://github.com/example/dingdongbuddy.git',
        ),
      ),
      isTrue,
    );
    expect(
      group.matches(const TriggerContext(projectPath: '/workspace/other')),
      isFalse,
    );
  });

  test('trigger group JSON round-trips without losing rule order', () {
    final TriggerGroup original = TriggerGroup(
      id: 'frontend',
      name: 'Frontend projects',
      rules: <TriggerRule>[
        TriggerRule(
          field: TriggerRuleField.projectPath,
          operator: TriggerRuleOperator.contains,
          value: '/frontend/',
        ),
      ],
      createdAt: DateTime.utc(2026, 7, 16),
      updatedAt: DateTime.utc(2026, 7, 16, 1),
    );

    expect(TriggerGroup.fromJson(original.toJson()), original);
  });
}
