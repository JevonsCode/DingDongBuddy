import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/domain/agent_setup_revision.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/library_transfer_gateway.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/library/ui/library_screen.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/shell/ui/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty activity connects an Agent again after setup was viewed', (
    WidgetTester tester,
  ) async {
    _useCompactWindow(tester);
    final MemoryPreferencesBackend backend =
        MemoryPreferencesBackend(<String, Object>{
          'dingdong.onboarding.mcpAccessSeen': true,
          'dingdong.agentApi.acknowledgedSetupRevision':
              currentAgentSetupRevision,
        });
    final ShellController controller = ShellController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      DingDongApp(
        settingsRepository: SettingsRepository(backend),
        shellController: controller,
      ),
    );
    await tester.pumpAndSettle();

    for (int visit = 0; visit < 2; visit += 1) {
      await tester.tap(find.byKey(const Key('today-connect-agent')));
      await tester.pumpAndSettle();
      expect(controller.selectedIndex, 3);
      expect(find.byKey(const Key('agent-api-setup-prompt')), findsOneWidget);
      expect(
        find.byKey(const Key('agent-api-copy-setup-prompt')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('agent-api-copy-health')), findsNothing);
      expect(
        backend.values['dingdong.agentApi.acknowledgedSetupRevision'],
        currentAgentSetupRevision,
      );
      controller.open(0);
      await tester.pumpAndSettle();
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty popup library opens a new resource in the manager', (
    WidgetTester tester,
  ) async {
    _useCompactWindow(tester);
    final _ResourceLauncher launcher = _ResourceLauncher();
    final ShellController controller = ShellController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      DingDongApp(
        resourceStore: _ResourceStore(),
        resourceManagerLauncher: launcher,
        shellController: controller,
      ),
    );
    await tester.pumpAndSettle();
    controller.open(1);
    await tester.pumpAndSettle();

    expect(find.text('No resources yet'), findsOneWidget);
    expect(find.text('No matching resources'), findsNothing);
    await tester.tap(find.byKey(const Key('library-empty-create')));
    await tester.pumpAndSettle();

    expect(launcher.openCount, 1);
    expect(launcher.request?.type, ResourceType.prompt);
    expect(launcher.request?.content, '');
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty manager offers working import and create actions', (
    WidgetTester tester,
  ) async {
    _useCompactWindow(tester);
    final _ResourceStore store = _ResourceStore();
    final LibraryViewModel model = LibraryViewModel(store);
    addTearDown(model.dispose);
    await model.load();
    final _TransferGateway transfer = _TransferGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LibraryScreen(viewModel: model, transferGateway: transfer),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('library-empty-import-json')));
    await tester.pumpAndSettle();
    expect(transfer.importRequests, 1);
    expect(store.resources, isEmpty);

    await tester.tap(find.byKey(const Key('library-empty-create')));
    await tester.pumpAndSettle();
    expect(model.isCreating, isTrue);
    expect(find.byKey(const Key('resource-editor')), findsOneWidget);
    expect(store.resources, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an unmatched search does not present an existing library as new',
    (WidgetTester tester) async {
      _useCompactWindow(tester);
      final DateTime now = DateTime.utc(2026, 10, 9);
      final LibraryViewModel model = LibraryViewModel(
        _ResourceStore(<Resource>[
          Resource(
            id: 'existing',
            type: ResourceType.prompt,
            title: 'Existing prompt',
            content: 'Remember the project conventions.',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );
      addTearDown(model.dispose);
      await model.load();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: LibraryScreen(viewModel: model)),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('resource-search')),
        'missing',
      );
      await tester.pumpAndSettle();
      expect(find.text('No matching resources'), findsOneWidget);
      expect(find.text('No resources yet'), findsNothing);
      expect(find.byKey(const Key('library-empty-create')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

void _useCompactWindow(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 760);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
}

final class _ResourceLauncher implements ResourceManagerLauncher {
  int openCount = 0;
  ResourceManagerCreateRequest? request;

  @override
  Future<void> show({
    String? editingResourceId,
    ResourceManagerCreateRequest? createRequest,
    ResourceManagerDestination destination =
        ResourceManagerDestination.resources,
  }) async {
    openCount += 1;
    request = createRequest;
  }
}

final class _ResourceStore implements ResourceStore {
  _ResourceStore([this.resources = const <Resource>[]]);

  List<Resource> resources;

  @override
  Future<List<Resource>> load() async => resources;

  @override
  Future<void> save(List<Resource> resources) async {
    this.resources = resources;
  }
}

final class _TransferGateway implements LibraryTransferGateway {
  int importRequests = 0;

  @override
  Future<String?> chooseImportDirectory() async => null;

  @override
  Future<String?> chooseImportJson() async {
    importRequests += 1;
    return null;
  }

  @override
  Future<String?> saveExport({required String contents}) async => null;
}
