import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/desktop_context_menu_gateway.dart';
import 'package:dingdong/core/widgets/selection_mark.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';
import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:dingdong/features/library/ui/library_screen.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact library drills into the editor and can return', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026);
    final LibraryViewModel model = LibraryViewModel(
      _MemoryStore(<Resource>[
        Resource(
          id: 'compact-resource',
          type: ResourceType.prompt,
          title: 'Compact prompt',
          content: 'Edit me in the popup.',
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    );
    await model.load();
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(viewModel: model)));

    await tester.tap(find.text('Compact prompt'));
    await tester.pump();

    expect(find.byKey(const Key('resource-editor')), findsOneWidget);
    expect(find.byKey(const Key('library-editor-back')), findsOneWidget);

    await tester.tap(find.byKey(const Key('library-editor-back')));
    await tester.pump();

    expect(find.byKey(const Key('resource-list')), findsOneWidget);
    expect(find.byKey(const Key('resource-editor')), findsNothing);
  });

  testWidgets('searching and selecting a resource opens the details editor', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026);
    final LibraryViewModel model = LibraryViewModel(
      _MemoryStore(<Resource>[
        Resource(
          id: '4CE39B4E-7D2B-4F69-8292-5D76267A7099',
          type: ResourceType.prompt,
          title: 'Release note writer',
          content: 'Write concise release notes.',
          tags: const <String>['writing', 'release'],
          createdAt: now,
          updatedAt: now,
        ),
        Resource(
          id: '5B8C1C88-6C99-43EC-BAE4-327B181C9880',
          type: ResourceType.knowledge,
          title: 'Architecture notes',
          content: 'System boundaries.',
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    );
    await model.load();

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 1280,
          height: 800,
          child: LibraryScreen(viewModel: model),
        ),
      ),
    );
    expect(find.byKey(const Key('resource-editor')), findsNothing);
    await tester.enterText(find.byKey(const Key('resource-search')), 'release');
    await tester.pump();
    await tester.tap(find.text('Release note writer'));
    await tester.pump();

    expect(find.text('Architecture notes'), findsNothing);
    expect(find.byKey(const Key('resource-editor')), findsOneWidget);
    expect(find.byKey(const Key('resource-list')), findsNothing);
    expect(find.byKey(const Key('library-detail-breadcrumb')), findsOneWidget);
    final TextField titleField = tester.widget<TextField>(
      find.byKey(const Key('resource-title')),
    );
    expect(titleField.controller?.text, 'Release note writer');
  });

  testWidgets('resource selection uses a compact single-layer control', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026);
    final LibraryViewModel model = LibraryViewModel(
      _MemoryStore(<Resource>[
        Resource(
          id: 'export-resource',
          type: ResourceType.prompt,
          title: 'Export prompt',
          content: 'Share this prompt.',
          createdAt: now,
          updatedAt: now,
        ),
      ]),
    );
    await model.load();
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(viewModel: model)));

    final Finder control = find.byKey(
      const ValueKey<String>('resource-select-export-resource'),
    );
    expect(control, findsOneWidget);
    expect(tester.getSize(control), const Size.square(28));
    expect(
      find.descendant(of: control, matching: find.byType(Checkbox)),
      findsNothing,
    );
    expect(
      tester
          .widget<SelectionMark>(
            find.descendant(of: control, matching: find.byType(SelectionMark)),
          )
          .selected,
      isFalse,
    );

    await tester.tap(control);
    await tester.pump();

    expect(model.isSelected('export-resource'), isTrue);
    expect(
      tester
          .widget<SelectionMark>(
            find.descendant(of: control, matching: find.byType(SelectionMark)),
          )
          .selected,
      isTrue,
    );
  });

  testWidgets('resources support select all and bulk deletion', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026);
    final _MemoryStore store = _MemoryStore(<Resource>[
      Resource(
        id: 'first',
        type: ResourceType.prompt,
        title: 'First',
        content: 'First content',
        createdAt: now,
        updatedAt: now,
      ),
      Resource(
        id: 'second',
        type: ResourceType.skill,
        title: 'Second',
        content: '''---
name: second
description: Use for the second task.
---''',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final LibraryViewModel model = LibraryViewModel(store);
    await model.load();
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(viewModel: model)));

    expect(find.text('Select visible'), findsNothing);
    expect(find.text('Select all'), findsOneWidget);
    await tester.tap(find.byKey(const Key('resource-select-all')));
    await tester.pump();
    expect(model.selectionCount, 2);
    await tester.tap(find.byKey(const Key('resource-delete-selection')));
    await tester.pumpAndSettle();
    expect(find.text('Delete selected resources?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(store.resources, isEmpty);
  });

  testWidgets('a resource can be deleted from its right-click menu', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026);
    final _MemoryStore store = _MemoryStore(<Resource>[
      Resource(
        id: 'context-delete',
        type: ResourceType.prompt,
        title: 'Context delete',
        content: 'Delete me',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final LibraryViewModel model = LibraryViewModel(store);
    final _RecordingContextMenuGateway menuGateway =
        _RecordingContextMenuGateway('delete');
    await model.load();
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(viewModel: model, contextMenuGateway: menuGateway),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('resource-row-context-delete')),
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    expect(menuGateway.showCount, 1);
    expect(find.byType(PopupMenuItem), findsNothing);
    expect(find.text('Delete this resource?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(store.resources, isEmpty);
  });

  testWidgets('editing and saving updates the selected resource', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026);
    final _MemoryStore store = _MemoryStore(<Resource>[
      Resource(
        id: '4CE39B4E-7D2B-4F69-8292-5D76267A7099',
        type: ResourceType.prompt,
        title: 'Release note writer',
        content: 'Write concise release notes.',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final LibraryViewModel model = LibraryViewModel(store);
    await model.load();
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(viewModel: model)));
    await tester.tap(find.text('Release note writer'));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('resource-title')),
      'Updated release writer',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(model.selectedResource?.title, 'Updated release writer');
    expect(store.resources.single.title, 'Updated release writer');
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('New resource creates and selects a prompt from the editor', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final _MemoryStore store = _MemoryStore(<Resource>[]);
    final LibraryViewModel model = LibraryViewModel(
      store,
      idGenerator: () => 'D8E71448-7A1A-4210-98D4-CBEF4E792E5B',
      now: () => DateTime.utc(2026, 7, 12),
    );
    await model.load();
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(viewModel: model)));

    await tester.tap(find.text('New resource'));
    await tester.pump();
    expect(find.byKey(const Key('resource-type-prompt')), findsOneWidget);
    expect(find.byKey(const Key('resource-type-skill')), findsOneWidget);
    expect(find.byKey(const Key('resource-type-mcp')), findsOneWidget);
    expect(find.text('Knowledge'), findsNothing);
    await tester.enterText(
      find.byKey(const Key('resource-title')),
      'Release checklist',
    );
    await tester.enterText(
      find.byKey(const Key('resource-content')),
      'Run tests before publishing.',
    );
    await tester.tap(find.byKey(const Key('resource-activation-manual')));
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(store.resources.single.title, 'Release checklist');
    expect(store.resources.single.type, ResourceType.prompt);
    expect(store.resources.single.activation, ResourceActivation.manual);
    expect(model.selectedResource, store.resources.single);
  });

  testWidgets('new resource flow lets the user choose a skill before saving', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final _MemoryStore store = _MemoryStore(<Resource>[]);
    final LibraryViewModel model = LibraryViewModel(
      store,
      idGenerator: () => 'skill-id',
      now: () => DateTime.utc(2026, 7, 12),
    );
    await model.load();
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(viewModel: model)));

    await tester.tap(find.text('New resource'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('resource-type-skill')));
    await tester.pump();
    expect(find.text('SKILL.md content'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('resource-title')),
      'tdd-workflow',
    );
    await tester.enterText(find.byKey(const Key('resource-content')), '''---
name: tdd-workflow
description: Use when implementing a change test-first
---

# TDD workflow

Red green refactor''');
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(store.resources.single.type, ResourceType.skill);
    expect(store.resources.single.group, 'Skills');
    expect(store.resources.single.content, contains('name: tdd-workflow'));
    expect(
      store.resources.single.content,
      contains('description: "Use when implementing a change test-first"'),
    );
    expect(store.resources.single.content, contains('Red green refactor'));
  });

  testWidgets('online skill mode fetches a GitHub folder into local storage', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    const String sourceUrl =
        'https://github.com/JevonsCode/codex-skills/tree/main/skills/user-taste';
    const String fetched = '''
---
name: user-taste
description: "Remember user preferences"
---

Apply the user's saved preferences.
''';
    final _MemoryStore store = _MemoryStore(<Resource>[]);
    final _SkillInstaller installer = _SkillInstaller(fetched);
    Uri? opened;
    final LibraryViewModel model = LibraryViewModel(
      store,
      skillPackageInstaller: installer,
      idGenerator: () => 'online-skill',
      now: () => DateTime.utc(2026, 7, 16),
    );
    await model.load();
    await tester.pumpWidget(
      MaterialApp(
        home: LibraryScreen(
          viewModel: model,
          onOpenExternalLink: (Uri uri) async {
            opened = uri;
          },
        ),
      ),
    );

    await tester.tap(find.text('New resource'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('resource-type-skill')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('resource-skill-source-online')));
    await tester.pump();

    expect(find.byKey(const Key('resource-skill-update-url')), findsOneWidget);
    expect(find.byKey(const Key('resource-content')), findsNothing);

    await tester.enterText(
      find.byKey(const Key('resource-skill-update-url')),
      sourceUrl,
    );
    await tester.tap(find.byKey(const Key('resource-save')));
    await tester.pumpAndSettle();

    expect(installer.requested, Uri.parse(sourceUrl));
    expect(installer.requestCount, 1);
    expect(store.resources.single.updateUrl, sourceUrl);
    expect(store.resources.single.content, fetched);
    expect(store.resources.single.packagePath, '/tmp/user-taste');
    expect(store.resources.single.title, 'user-taste');
    expect(find.text('Remember user preferences'), findsOneWidget);
    final TextField installedName = tester.widget<TextField>(
      find.byKey(const Key('resource-skill-name')),
    );
    final TextField installedDescription = tester.widget<TextField>(
      find.byKey(const Key('resource-skill-description')),
    );
    expect(installedName.readOnly, isTrue);
    expect(installedDescription.readOnly, isTrue);
    expect(find.byKey(const Key('resource-title')), findsNothing);
    final TextField installedContent = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('resource-content')),
        matching: find.byType(TextField),
      ),
    );
    expect(installedContent.readOnly, isTrue);
    expect(find.byKey(const Key('resource-skill-open-source')), findsOneWidget);
    expect(find.byKey(const Key('resource-skill-update')), findsOneWidget);

    await tester.tap(find.byKey(const Key('resource-skill-open-source')));
    await tester.pump();
    expect(opened, Uri.parse(sourceUrl));

    installer.content = fetched.replaceFirst(
      "Apply the user's saved preferences.",
      'Apply the latest saved preferences.',
    );
    await tester.tap(find.byKey(const Key('resource-skill-update')));
    await tester.pumpAndSettle();

    expect(installer.requestCount, 2);
    expect(
      store.resources.single.content,
      contains('Apply the latest saved preferences.'),
    );
    expect(find.text('Updated'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('resource-skill-note')),
      'Only use this for product work.',
    );
    await tester.tap(find.byKey(const Key('resource-save')));
    await tester.pumpAndSettle();
    expect(store.resources.single.note, 'Only use this for product work.');

    await tester.tap(find.byKey(const Key('library-editor-back')));
    await tester.pumpAndSettle();
    expect(find.text('user-taste'), findsOneWidget);
    expect(find.text('Remember user preferences'), findsOneWidget);
    expect(find.textContaining('--- name:'), findsNothing);
  });

  testWidgets('online skill failure is actionable and hides internal errors', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final LibraryViewModel model = LibraryViewModel(_MemoryStore(<Resource>[]));
    await model.load();
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(viewModel: model)));

    await tester.tap(find.text('New resource'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('resource-type-skill')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('resource-skill-source-online')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('resource-title')),
      'remote-skill',
    );
    await tester.enterText(
      find.byKey(const Key('resource-skill-update-url')),
      'https://github.com/example/repo/tree/main/skills/remote-skill',
    );
    await tester.tap(find.byKey(const Key('resource-save')));
    await tester.pump();

    expect(find.textContaining('Online sync is not ready'), findsOneWidget);
    expect(find.textContaining('Bad state'), findsNothing);
  });

  testWidgets('MCP creation separates STDIO HTTP and raw configuration', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final _MemoryStore store = _MemoryStore(<Resource>[]);
    final LibraryViewModel model = LibraryViewModel(
      store,
      idGenerator: () => 'mcp-id',
      now: () => DateTime.utc(2026, 7, 12),
    );
    await model.load();
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(viewModel: model)));

    await tester.tap(find.text('New resource'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('resource-type-mcp')));
    await tester.pump();
    expect(find.byKey(const Key('resource-mcp-command')), findsOneWidget);
    expect(find.byKey(const Key('resource-mcp-url')), findsNothing);

    await tester.tap(find.byKey(const Key('resource-mcp-transport-http')));
    await tester.pump();
    expect(find.byKey(const Key('resource-mcp-url')), findsOneWidget);
    expect(find.byKey(const Key('resource-mcp-command')), findsNothing);

    await tester.tap(find.byKey(const Key('resource-mcp-transport-raw')));
    await tester.pump();
    expect(find.byKey(const Key('resource-mcp-raw')), findsOneWidget);

    await tester.tap(find.byKey(const Key('resource-mcp-transport-stdio')));
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('resource-title')),
      'Local tools',
    );
    await tester.enterText(
      find.byKey(const Key('resource-mcp-command')),
      'npx',
    );
    await tester.enterText(
      find.byKey(const Key('resource-mcp-args')),
      '-y\n@company/mcp',
    );
    await tester.enterText(
      find.byKey(const Key('resource-mcp-env')),
      'TOKEN=value',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();

    final McpConfiguration saved = McpConfiguration.parse(
      store.resources.single.content,
    );
    expect(saved.transport, McpTransport.stdio);
    expect(saved.command, 'npx');
    expect(saved.arguments, <String>['-y', '@company/mcp']);
    expect(saved.environment, <String, String>{'TOKEN': 'value'});
  });

  testWidgets('deleting from the editor requires confirmation', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026);
    final _MemoryStore store = _MemoryStore(<Resource>[
      Resource(
        id: '2562D4B7-A8EA-460A-890B-13345A992F22',
        type: ResourceType.mcp,
        title: 'Local MCP',
        content: 'npx local-mcp',
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final LibraryViewModel model = LibraryViewModel(store);
    await model.load();
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(viewModel: model)));
    await tester.tap(find.text('Local MCP'));
    await tester.pump();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this resource?'), findsOneWidget);
    expect(store.resources, hasLength(1));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(store.resources, isEmpty);
  });

  testWidgets(
    'generic group and tags stay hidden while legacy values persist',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final DateTime now = DateTime.utc(2026);
      final _MemoryStore store = _MemoryStore(<Resource>[
        Resource(
          id: 'A5FD935E-F649-470D-9D54-2CBA0364FC4F',
          type: ResourceType.prompt,
          title: 'Release helper',
          content: 'Write release notes.',
          group: 'Release',
          tags: const <String>['release', 'writing'],
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final LibraryViewModel model = LibraryViewModel(store);
      await model.load();
      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(viewModel: model)),
      );
      await tester.tap(find.text('Release helper'));
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const Key('resource-advanced-settings')),
      );
      await tester.tap(find.byKey(const Key('resource-advanced-settings')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('resource-group')), findsNothing);
      expect(find.byKey(const Key('resource-tags')), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('resource-pinned')));
      await tester.tap(find.byKey(const Key('resource-pinned')));
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pump();

      expect(store.resources.single.group, 'Release');
      expect(store.resources.single.tags, <String>['release', 'writing']);
      expect(store.resources.single.pinned, isTrue);
      expect(store.resources.single.activation, ResourceActivation.taskMatch);
    },
  );

  testWidgets('new resource follows the selected MCP filter', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final LibraryViewModel model = LibraryViewModel(_MemoryStore(<Resource>[]));
    await model.load();
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(viewModel: model)));

    await tester.tap(find.byKey(const Key('resource-filter-mcp')));
    await tester.pump();
    expect(find.byKey(const Key('resource-editor')), findsNothing);
    expect(find.byKey(const Key('resource-list')), findsOneWidget);
    await tester.tap(find.text('New resource'));
    await tester.pump();

    expect(find.byKey(const Key('resource-mcp-command')), findsOneWidget);
    expect(find.textContaining('SKILL.md'), findsNothing);
  });

  testWidgets(
    'resource can join searchable trigger groups and persists the selection',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final DateTime now = DateTime.utc(2026, 7, 16);
      final List<TriggerGroup> groups =
          <String>['Alpha', 'Beta', 'DingDong', 'Docs', 'Ideas', 'Release']
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
      final _MemoryStore store = _MemoryStore(<Resource>[
        Resource(
          id: 'scoped-resource',
          type: ResourceType.prompt,
          title: 'Scoped prompt',
          content: 'Only load this prompt for selected projects.',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final LibraryViewModel model = LibraryViewModel(
        store,
        triggerGroupStore: InMemoryTriggerGroupStore(groups),
      );
      await model.load();
      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(viewModel: model)),
      );

      await tester.tap(find.text('Scoped prompt'));
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('resource-trigger-groups')),
      );
      await tester.tap(find.byKey(const Key('resource-trigger-groups')));
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
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(store.resources.single.triggerGroupIds, <String>['group-2']);
      expect(find.text('Saved'), findsOneWidget);
    },
  );

  testWidgets(
    'type filters narrow the library without discarding the search context',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1280, 800);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final DateTime now = DateTime.utc(2026);
      final LibraryViewModel model = LibraryViewModel(
        _MemoryStore(<Resource>[
          Resource(
            id: 'prompt',
            type: ResourceType.prompt,
            title: 'Release prompt',
            content: 'release',
            createdAt: now,
            updatedAt: now,
          ),
          Resource(
            id: 'skill',
            type: ResourceType.skill,
            title: 'Release skill',
            content: 'release',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );
      await model.load();
      await tester.pumpWidget(
        MaterialApp(home: LibraryScreen(viewModel: model)),
      );
      await tester.enterText(
        find.byKey(const Key('resource-search')),
        'release',
      );

      await tester.tap(find.byKey(const Key('resource-filter-skill')));
      await tester.pump();

      expect(find.text('Release skill'), findsOneWidget);
      expect(find.text('Release prompt'), findsNothing);
    },
  );

  testWidgets('10000 resources build only the visible list window', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final DateTime now = DateTime.utc(2026);
    final LibraryViewModel model = LibraryViewModel(
      _MemoryStore(
        List<Resource>.generate(
          10000,
          (int index) => Resource(
            id: 'resource-$index',
            type: ResourceType.prompt,
            title: 'Resource $index',
            content: 'Content $index',
            createdAt: now,
            updatedAt: now,
          ),
        ),
      ),
    );
    await model.load();

    await tester.pumpWidget(MaterialApp(home: LibraryScreen(viewModel: model)));

    final Finder builtRows = find.byWidgetPredicate(
      (Widget widget) =>
          widget.key is ValueKey<String> &&
          (widget.key! as ValueKey<String>).value.startsWith('resource-row-'),
    );
    expect(builtRows.evaluate().length, inInclusiveRange(1, 99));
    expect(find.text('Resource 9999'), findsNothing);
  });
}

final class _RecordingContextMenuGateway implements DesktopContextMenuGateway {
  _RecordingContextMenuGateway(this.result);

  final String? result;
  int showCount = 0;

  @override
  Future<String?> show({
    required double x,
    required double y,
    required bool useChinese,
    required List<DesktopContextMenuItem> items,
  }) async {
    showCount += 1;
    return result;
  }
}

final class _MemoryStore implements ResourceStore {
  _MemoryStore(this.resources);

  List<Resource> resources;

  @override
  Future<List<Resource>> load() async => List<Resource>.of(resources);

  @override
  Future<void> save(List<Resource> resources) async {
    this.resources = List<Resource>.of(resources);
  }
}

final class _SkillInstaller implements SkillPackageInstaller {
  _SkillInstaller(this.content);

  String content;
  Uri? requested;
  int requestCount = 0;

  @override
  Future<SkillPackageInstallResult> install(Uri source) async {
    requested = source;
    requestCount += 1;
    return SkillPackageInstallResult(
      skillDocument: content,
      directoryPath: '/tmp/user-taste',
    );
  }
}
