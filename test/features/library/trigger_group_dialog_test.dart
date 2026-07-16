import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:dingdong/features/library/ui/trigger_group_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('trigger-group picker searches and keeps multi-selection', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final DateTime now = DateTime.utc(2026, 7, 16);
    final List<TriggerGroup> groups =
        <String>['Alpha', 'Beta', 'DingDong', 'Docs', 'Ideas', 'Release']
            .indexed
            .map(((int, String) entry) {
              return TriggerGroup(
                id: '${entry.$1}',
                name: entry.$2,
                rules: <TriggerRule>[
                  TriggerRule(
                    field: TriggerRuleField.projectPath,
                    operator: TriggerRuleOperator.contains,
                    value: entry.$2.toLowerCase(),
                  ),
                ],
                createdAt: now,
                updatedAt: now,
              );
            })
            .toList(growable: false);
    Set<String>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () async {
              result = await showDialog<Set<String>>(
                context: context,
                builder: (BuildContext context) => TriggerGroupPickerDialog(
                  groups: groups,
                  selectedIds: const <String>{'0'},
                  onCreate:
                      ({
                        required String name,
                        required List<TriggerRule> rules,
                      }) async => TriggerGroup(
                        id: 'new',
                        name: name,
                        rules: rules,
                        createdAt: now,
                        updatedAt: now,
                      ),
                  onUpdate: (_) async {},
                  onDelete: (_) async {},
                ),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trigger-group-search')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('trigger-group-search')),
      'ding',
    );
    await tester.pump();
    await tester.tap(find.text('DingDong'));
    await tester.tap(find.byKey(const Key('apply-trigger-groups')));
    await tester.pumpAndSettle();

    expect(result, <String>{'0', '2'});
  });

  testWidgets('trigger-group editor returns a complete path rule', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TriggerGroupEditResult? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => FilledButton(
            onPressed: () async {
              result = await showDialog<TriggerGroupEditResult>(
                context: context,
                builder: (BuildContext context) =>
                    const TriggerGroupEditorDialog(),
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('trigger-group-name')),
      'DingDong project',
    );
    final Finder ruleField = find.byType(TextField).last;
    await tester.enterText(ruleField, '/workspace/dingdong');
    await tester.tap(find.byKey(const Key('save-trigger-group')));
    await tester.pumpAndSettle();

    expect(result?.name, 'DingDong project');
    expect(result?.rules.single.value, '/workspace/dingdong');
  });
}
