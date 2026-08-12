import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:dingdong/features/library/ui/resource_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory temp;
  late Directory project;
  late Directory package;
  late TriggerGroup scope;
  late DateTime now;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('dingdong-delivery-editor-');
    project = Directory(path.join(temp.path, 'project'))..createSync();
    package = Directory(path.join(temp.path, 'package'))..createSync();
    File(path.join(package.path, 'SKILL.md')).writeAsStringSync(
      '---\nname: impeccable\ndescription: Improve frontend design\n---\n',
    );
    now = DateTime.utc(2026, 8, 12);
    scope = TriggerGroup(
      id: 'project-scope',
      name: 'Project scope',
      rules: <TriggerRule>[
        TriggerRule(
          field: TriggerRuleField.projectPath,
          operator: TriggerRuleOperator.equals,
          value: project.path,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
  });

  tearDown(() => temp.deleteSync(recursive: true));

  Resource skill({
    Map<String, SkillDeliveryMode> delivery =
        const <String, SkillDeliveryMode>{},
    Map<String, bool> hooks = const <String, bool>{},
  }) => Resource(
    id: 'impeccable',
    type: ResourceType.skill,
    title: 'impeccable',
    content: File(path.join(package.path, 'SKILL.md')).readAsStringSync(),
    updateUrl: package.uri.toString(),
    packagePath: package.path,
    enabled: true,
    activation: ResourceActivation.taskMatch,
    triggerGroupIds: const <String>['project-scope'],
    strictProjectSkill: true,
    skillProjectPaths: <String>[project.path],
    skillDeliveryByAgent: delivery,
    skillHooksEnabledByAgent: hooks,
    createdAt: now,
    updatedAt: now,
  );

  Future<void> pumpEditor(
    WidgetTester tester,
    Resource resource, {
    required ValueChanged<Resource> onSave,
    List<SkillDeliveryAgentOption> agents =
        ResourceEditor.defaultSkillDeliveryAgents,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 900);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResourceEditor(
            resource: resource,
            isCreating: false,
            triggerGroups: <TriggerGroup>[scope],
            skillAgents: agents,
            onCreate: _unusedCreate,
            onDelete: null,
            onSave: (Resource value) async => onSave(value),
            onCreateTriggerGroup: _unusedTriggerCreate,
            onUpdateTriggerGroup: (TriggerGroup _) async {},
            onDeleteTriggerGroup: (String _) async {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets(
    'delivery and Hook choices round-trip without changing activation',
    (WidgetTester tester) async {
      Resource? saved;
      await pumpEditor(
        tester,
        skill(),
        onSave: (Resource value) => saved = value,
      );

      await tester.ensureVisible(
        find.byKey(const Key('skill-delivery-codex-native-project')),
      );
      await tester.tap(
        find.byKey(const Key('skill-delivery-codex-native-project')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const Key('skill-hook-codex')));
      await tester.ensureVisible(find.byKey(const Key('resource-save')));
      await tester.tap(find.byKey(const Key('resource-save')));
      await tester.pumpAndSettle();

      expect(saved, isNotNull);
      expect(
        saved!.skillDeliveryForAgent('codex'),
        SkillDeliveryMode.nativeProject,
      );
      expect(saved!.skillHooksEnabledForAgent('codex'), isTrue);
      expect(saved!.activation, ResourceActivation.taskMatch);
    },
  );

  testWidgets(
    'clearing the final project scope cannot retain native delivery',
    (WidgetTester tester) async {
      Resource? saved;
      await pumpEditor(
        tester,
        skill(
          delivery: const <String, SkillDeliveryMode>{
            'codex': SkillDeliveryMode.nativeProject,
          },
          hooks: const <String, bool>{'codex': true},
        ),
        onSave: (Resource value) => saved = value,
      );

      await tester.ensureVisible(
        find.byKey(const Key('resource-trigger-groups')),
      );
      await tester.tap(find.byKey(const Key('resource-trigger-groups')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('trigger-group-row-project-scope')),
      );
      await tester.tap(find.byKey(const Key('apply-trigger-groups')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('resource-save')));
      await tester.tap(find.byKey(const Key('resource-save')));
      await tester.pumpAndSettle();

      expect(saved, isNull);
      expect(find.byKey(const Key('resource-save-error')), findsOneWidget);
    },
  );

  testWidgets('same-id external update refreshes delivery state', (
    WidgetTester tester,
  ) async {
    Resource? saved;
    await pumpEditor(
      tester,
      skill(
        delivery: const <String, SkillDeliveryMode>{
          'codex': SkillDeliveryMode.nativeUser,
        },
      ),
      onSave: (Resource value) => saved = value,
    );
    final Resource externallyUpdated = skill(
      delivery: const <String, SkillDeliveryMode>{
        'codex': SkillDeliveryMode.nativeProject,
      },
      hooks: const <String, bool>{'codex': true},
    ).copyWith(updatedAt: now.add(const Duration(minutes: 1)));

    await pumpEditor(
      tester,
      externallyUpdated,
      onSave: (Resource value) => saved = value,
    );
    await tester.ensureVisible(find.byKey(const Key('resource-save')));
    await tester.tap(find.byKey(const Key('resource-save')));
    await tester.pumpAndSettle();

    expect(
      saved!.skillDeliveryForAgent('codex'),
      SkillDeliveryMode.nativeProject,
    );
    expect(saved!.skillHooksEnabledForAgent('codex'), isTrue);
  });

  testWidgets(
    'unavailable custom Agent remains visible and can return dynamic',
    (WidgetTester tester) async {
      Resource? saved;
      await pumpEditor(
        tester,
        skill(
          delivery: const <String, SkillDeliveryMode>{
            'custom-agent': SkillDeliveryMode.nativeUser,
          },
        ),
        agents: const <SkillDeliveryAgentOption>[],
        onSave: (Resource value) => saved = value,
      );

      expect(find.text('custom-agent'), findsOneWidget);
      expect(find.text('Not installed'), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('skill-delivery-custom-agent-dynamic')),
      );
      await tester.tap(
        find.byKey(const Key('skill-delivery-custom-agent-dynamic')),
      );
      await tester.ensureVisible(find.byKey(const Key('resource-save')));
      await tester.tap(find.byKey(const Key('resource-save')));
      await tester.pumpAndSettle();

      expect(
        saved!.skillDeliveryForAgent('custom-agent'),
        SkillDeliveryMode.dynamic,
      );
    },
  );

  testWidgets(
    'project-native delivery explains and exposes its project scope in place',
    (WidgetTester tester) async {
      await pumpEditor(
        tester,
        skill().copyWith(
          triggerGroupIds: const <String>[],
          strictProjectSkill: false,
          skillProjectPaths: const <String>[],
        ),
        onSave: (Resource _) {},
      );

      expect(find.byKey(const Key('skill-native-project-scope')), findsNothing);
      await tester.ensureVisible(
        find.byKey(const Key('skill-delivery-codex-native-project')),
      );
      await tester.tap(
        find.byKey(const Key('skill-delivery-codex-native-project')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('skill-native-project-scope')),
        findsOneWidget,
      );
      expect(find.text('Project installation scope'), findsOneWidget);
      expect(
        find.textContaining('each selected project\'s native directory'),
        findsOneWidget,
      );
      expect(find.text('Configure projects'), findsOneWidget);

      await tester.tap(find.byKey(const Key('resource-trigger-groups')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('trigger-group-picker')), findsOneWidget);
      expect(
        find.text(
          'Only exact, existing project directories can receive a native Skill.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('create-trigger-group')));
      await tester.pumpAndSettle();
      expect(find.text('Project directory · Equals'), findsOneWidget);
    },
  );

  testWidgets('uninstalled Agents stay collapsed until requested', (
    WidgetTester tester,
  ) async {
    await pumpEditor(
      tester,
      skill(),
      agents: const <SkillDeliveryAgentOption>[
        SkillDeliveryAgentOption(id: 'codex', label: 'Codex'),
        SkillDeliveryAgentOption(id: 'grok', label: 'Grok', available: false),
        SkillDeliveryAgentOption(id: 'pi', label: 'Pi', available: false),
      ],
      onSave: (Resource _) {},
    );

    expect(find.text('Not installed Agents (2)'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('skill-delivery-codex-dynamic')),
    );
    expect(
      find.byKey(const Key('skill-delivery-codex-dynamic')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('skill-delivery-grok-dynamic')).hitTestable(),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const Key('skill-delivery-uninstalled-agents')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('skill-delivery-grok-dynamic')).hitTestable(),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('skill-delivery-pi-dynamic')).hitTestable(),
      findsOneWidget,
    );
  });
}

Future<void> _unusedCreate({
  required ResourceType type,
  required String title,
  required String content,
  String? group,
  List<String>? tags,
  String? updateUrl,
  String? packagePath,
  String? skillPackageDigest,
  String? note,
  bool? pinned,
  bool? enabled,
  ResourceActivation? activation,
  List<String>? triggerGroupIds,
}) async {}

Future<TriggerGroup> _unusedTriggerCreate({
  required String name,
  required List<TriggerRule> rules,
}) => throw UnsupportedError('not used');
