import 'dart:io';

import 'package:dingdong/features/library/data/trigger_group_file_service.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('trigger groups persist through the atomic file repository', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-trigger-groups-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final TriggerGroupRepository repository = TriggerGroupRepository(
      TriggerGroupFileService(File('${directory.path}/trigger-groups.json')),
    );
    final TriggerGroup group = TriggerGroup(
      id: 'dingdong',
      name: 'DingDong',
      rules: <TriggerRule>[
        TriggerRule(
          field: TriggerRuleField.projectPath,
          operator: TriggerRuleOperator.contains,
          value: 'dingdong',
        ),
      ],
      createdAt: DateTime.utc(2026, 7, 16),
      updatedAt: DateTime.utc(2026, 7, 16),
    );

    await repository.save(<TriggerGroup>[group]);

    expect(await repository.load(), <TriggerGroup>[group]);
  });
}
