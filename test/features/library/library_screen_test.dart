import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/ui/library_screen.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
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
    await tester.enterText(find.byKey(const Key('resource-search')), 'release');
    await tester.pump();
    await tester.tap(find.text('Release note writer'));
    await tester.pump();

    expect(find.text('Architecture notes'), findsNothing);
    expect(find.byKey(const Key('resource-editor')), findsOneWidget);
    final TextField titleField = tester.widget<TextField>(
      find.byKey(const Key('resource-title')),
    );
    expect(titleField.controller?.text, 'Release note writer');
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
    await tester.pump();

    expect(model.selectedResource?.title, 'Updated release writer');
    expect(store.resources.single.title, 'Updated release writer');
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
    await tester.enterText(
      find.byKey(const Key('resource-title')),
      'Release checklist',
    );
    await tester.enterText(
      find.byKey(const Key('resource-content')),
      'Run tests before publishing.',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(store.resources.single.title, 'Release checklist');
    expect(store.resources.single.type, ResourceType.prompt);
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
    await tester.tap(find.byKey(const Key('resource-type')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skill').last);
    await tester.enterText(
      find.byKey(const Key('resource-title')),
      'TDD skill',
    );
    await tester.enterText(
      find.byKey(const Key('resource-content')),
      'Red green refactor',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(store.resources.single.type, ResourceType.skill);
    expect(store.resources.single.group, 'Skills');
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

  testWidgets('resource metadata fields persist group, tags, and pin state', (
    WidgetTester tester,
  ) async {
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
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final LibraryViewModel model = LibraryViewModel(store);
    await model.load();
    await tester.pumpWidget(MaterialApp(home: LibraryScreen(viewModel: model)));
    await tester.tap(find.text('Release helper'));
    await tester.pump();

    await tester.enterText(find.byKey(const Key('resource-group')), 'Release');
    await tester.enterText(
      find.byKey(const Key('resource-tags')),
      'release, writing',
    );
    await tester.tap(find.byKey(const Key('resource-pinned')));
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(store.resources.single.group, 'Release');
    expect(store.resources.single.tags, <String>['release', 'writing']);
    expect(store.resources.single.pinned, isTrue);
    expect(store.resources.single.activation, ResourceActivation.always);
  });

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
