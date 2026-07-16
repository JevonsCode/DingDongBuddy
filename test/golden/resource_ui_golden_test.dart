import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_group_dialog.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:dingdong/features/library/ui/resource_editor.dart';
import 'package:dingdong/features/library/ui/trigger_group_dialog.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'resource cards present Skill and MCP metadata distinctly',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final ShellController controller = ShellController(initialIndex: 1);
      addTearDown(controller.dispose);
      final DateTime now = DateTime.utc(2026, 7, 17);

      await tester.pumpWidget(
        DingDongApp(
          shellController: controller,
          resourceStore: InMemoryResourceStore(<Resource>[
            Resource(
              id: 'user-taste',
              type: ResourceType.skill,
              title: '',
              content: '''---
name: user-taste
description: Use when product decisions should follow saved preferences.
---

# User Taste

Apply the user's saved preferences.''',
              updateUrl:
                  'https://github.com/JevonsCode/codex-skills/tree/main/skills/user-taste',
              createdAt: now,
              updatedAt: now,
            ),
            Resource(
              id: 'dingdong-mcp',
              type: ResourceType.mcp,
              title: '',
              content: '''{
  "mcpServers": {
    "dingdong": {
      "type": "stdio",
      "command": "/Applications/DingDong.app/Contents/MCP/bundle/bin/dingdong_mcp"
    }
  }
}''',
              createdAt: now,
              updatedAt: now,
            ),
          ]),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('desktop-shell-golden')),
        matchesGoldenFile('goldens/resource_cards_by_type.png'),
      );
    },
    tags: <String>['golden'],
  );

  testWidgets(
    'local Skill editor follows the Cursor-style SKILL.md workflow',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(519, 700);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _testApp(
          ResourceEditor(
            resource: null,
            isCreating: true,
            initialType: ResourceType.skill,
            onCreate: _noopCreate,
            onDelete: null,
            onSave: (Resource resource) async {},
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('resource-title')),
        'user-taste',
      );
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('resource-editor')),
        matchesGoldenFile('goldens/resource_editor_local_skill.png'),
      );
    },
    tags: <String>['golden'],
  );

  testWidgets(
    'online Skill editor keeps the approved desktop hierarchy',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(519, 560);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _testApp(
          ResourceEditor(
            resource: null,
            isCreating: true,
            onCreate: _noopCreate,
            onDelete: null,
            onSave: (Resource resource) async {},
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('resource-type-skill')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('resource-skill-source-online')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('resource-title')),
        'user-taste',
      );
      await tester.enterText(
        find.byKey(const Key('resource-skill-update-url')),
        'https://github.com/JevonsCode/codex-skills/tree/main/skills/user-taste',
      );
      tester.testTextInput.hide();
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('resource-editor')),
        matchesGoldenFile('goldens/resource_editor_online.png'),
      );
    },
    tags: <String>['golden'],
  );

  testWidgets(
    'trigger-group selection uses a compact searchable multi-select surface',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(620, 650);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final DateTime now = DateTime.utc(2026, 7, 16);
      final List<TriggerGroup> groups =
          <String>['DingDong', 'Docs', 'Flutter', 'Release', 'Website', 'Work']
              .indexed
              .map(((int, String) entry) {
                return TriggerGroup(
                  id: 'group-${entry.$1}',
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

      await tester.pumpWidget(
        _testApp(
          Builder(
            builder: (BuildContext context) => Center(
              child: FilledButton(
                onPressed: () => showDialog<Set<String>>(
                  context: context,
                  builder: (BuildContext context) => TriggerGroupPickerDialog(
                    groups: groups,
                    selectedIds: const <String>{'group-0'},
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
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('trigger-group-picker')),
        matchesGoldenFile('goldens/trigger_group_picker.png'),
      );
    },
    tags: <String>['golden'],
  );

  testWidgets(
    'clipboard group selection uses the approved multi-select surface',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(620, 560);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _testApp(
          Builder(
            builder: (BuildContext context) => Center(
              child: FilledButton(
                onPressed: () => showDialog<Set<String>>(
                  context: context,
                  builder: (BuildContext context) => const ClipboardGroupDialog(
                    availableGroups: <String>['项目草稿', '工作资料', '灵感'],
                    selectedGroups: <String>{'工作资料'},
                  ),
                ),
                child: const Text('打开'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('clipboard-group-dialog')),
        matchesGoldenFile('goldens/clipboard_group_dialog.png'),
      );
    },
    tags: <String>['golden'],
  );
}

Future<void> _noopCreate({
  required ResourceType type,
  required String title,
  required String content,
  String? group,
  List<String>? tags,
  String? updateUrl,
  String? note,
  bool? pinned,
  bool? enabled,
  ResourceActivation? activation,
  List<String>? triggerGroupIds,
}) async {}

Widget _testApp(Widget home) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.desktopPanelLight(),
    locale: const Locale('zh'),
    supportedLocales: const <Locale>[Locale('en'), Locale('zh')],
    localizationsDelegates: const <LocalizationsDelegate<Object>>[
      DingDongLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(body: home),
  );
}
