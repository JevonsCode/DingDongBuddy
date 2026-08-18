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

  test('two repositories serialize trigger-group mutations', () async {
    final Directory directory = await Directory.systemTemp.createTemp(
      'dingdong-trigger-groups-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final File file = File('${directory.path}/trigger-groups.json');
    final TriggerGroupRepository first = TriggerGroupRepository(
      TriggerGroupFileService(file),
    );
    final TriggerGroupRepository second = TriggerGroupRepository(
      TriggerGroupFileService(file),
    );

    Future<void> append(TriggerGroupRepository repository, String id) =>
        repository.exclusiveMutation(() async {
          final List<TriggerGroup> current = await repository.load();
          await Future<void>.delayed(const Duration(milliseconds: 20));
          final DateTime now = DateTime.utc(2026, 8, 18);
          await repository.save(<TriggerGroup>[
            ...current,
            TriggerGroup(
              id: id,
              name: id,
              rules: <TriggerRule>[
                TriggerRule(
                  field: TriggerRuleField.source,
                  operator: TriggerRuleOperator.equals,
                  value: id,
                ),
              ],
              createdAt: now,
              updatedAt: now,
            ),
          ]);
        });

    await Future.wait(<Future<void>>[
      append(first, 'codex'),
      append(second, 'pi'),
    ]);

    expect(
      (await first.load()).map((TriggerGroup group) => group.id).toSet(),
      <String>{'codex', 'pi'},
    );
  });
}
