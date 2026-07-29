import 'dart:io';

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

  test(
    'existing project paths match across symbolic-link aliases',
    () {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-trigger-path-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final Directory target = Directory('${temp.path}/TargetProject')
        ..createSync();
      final Link alias = Link('${temp.path}/AliasProject')
        ..createSync(target.path);
      final TriggerRule rule = TriggerRule(
        field: TriggerRuleField.projectPath,
        operator: TriggerRuleOperator.equals,
        value: alias.path,
      );

      expect(
        rule.matches(
          TriggerContext(projectPath: target.resolveSymbolicLinksSync()),
        ),
        isTrue,
      );
    },
    skip: Platform.isWindows
        ? 'Creating symbolic links requires additional Windows privileges.'
        : false,
  );

  test(
    'contains keeps the lexical symbolic-link alias',
    () {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-trigger-contains-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final Directory target = Directory('${temp.path}/target-project')
        ..createSync();
      final Link alias = Link('${temp.path}/alias-project')
        ..createSync(target.path);
      final TriggerRule rule = TriggerRule(
        field: TriggerRuleField.projectPath,
        operator: TriggerRuleOperator.contains,
        value: 'alias-project',
      );

      expect(rule.matches(TriggerContext(projectPath: alias.path)), isTrue);
    },
    skip: Platform.isWindows
        ? 'Creating symbolic links requires additional Windows privileges.'
        : false,
  );
}
