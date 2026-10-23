import 'dart:async';

import 'package:dingdong/features/agent_plugins/domain/agent_plugin_inventory.dart';
import 'package:dingdong/features/agent_plugins/ui/agent_plugins_section.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/ui/library_screen.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/plugins/ui/plugins_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Agent plugin inventory belongs to resources, not DingDong plugins',
    (tester) async {
      final inventory = _Inventory();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: PluginsScreen())),
      );
      expect(find.byKey(const Key('agent-plugins-section')), findsNothing);
      expect(find.text('Agent plugins'), findsNothing);
      expect(find.byKey(const Key('plugin-row-screenshot')), findsOneWidget);

      final model = LibraryViewModel(InMemoryResourceStore());
      await model.load();
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryScreen(
              viewModel: model,
              agentPluginInventory: inventory,
            ),
          ),
        ),
      );
      expect(inventory.calls, 0);
      await tester.enterText(
        find.byKey(const Key('resource-search')),
        'needle',
      );
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const Key('library-agent-plugins-open')),
      );
      await tester.tap(find.byKey(const Key('library-agent-plugins-open')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('agent-plugins-section')), findsOneWidget);
      expect(inventory.calls, 0);
      await tester.tap(find.byKey(const Key('agent-plugins-refresh')));
      await tester.pump();
      expect(inventory.calls, 1);
      inventory.pending.complete(const []);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('library-agent-plugins-back')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('resource-list')), findsOneWidget);
      expect(find.byKey(const Key('agent-plugins-section')), findsNothing);
      expect(model.query, 'needle');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'needle',
      );
      await tester.tap(find.byTooltip('Clear search'));
      await tester.pump();
      expect(model.query, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [420.0, 580.0, 800.0, 1080.0]) {
    testWidgets('resource plugin entry fits a $width wide window', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final model = LibraryViewModel(InMemoryResourceStore());
      await model.load();
      addTearDown(model.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LibraryScreen(
              viewModel: model,
              agentPluginInventory: _Inventory(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final entry = find.byKey(const Key('library-agent-plugins-open'));
      if (entry.evaluate().isEmpty) {
        await tester.tap(find.byKey(const Key('library-actions')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Agent plugins'));
      } else {
        await tester.tap(entry);
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('agent-plugins-section')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('resource inventory starts at the top beside the sidebar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1080, 752));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final model = LibraryViewModel(InMemoryResourceStore());
    await model.load();
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [
              const SizedBox(width: 177),
              Expanded(
                child: LibraryScreen(
                  viewModel: model,
                  agentPluginInventory: _Inventory(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const Key('library-agent-plugins-open')));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const Key('library-agent-plugins-back'))).dy,
      lessThan(80),
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'inventory is on demand, refreshable, and separate from DingDong extensions',
    (tester) async {
      final _Inventory inventory = _Inventory();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AgentPluginsSection(inventory: inventory)),
        ),
      );
      expect(inventory.calls, 0);
      expect(find.text('Agent plugins'), findsOneWidget);
      expect(find.byKey(const Key('agent-plugins-not-read')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const Key('agent-plugins-refresh')),
      );
      await tester.tap(find.byKey(const Key('agent-plugins-refresh')));
      await tester.pump();
      expect(inventory.calls, 1);
      expect(find.byKey(const Key('agent-plugins-loading')), findsOneWidget);
      inventory.pending.complete(const <AgentPluginInventoryResult>[
        AgentPluginInventoryResult(
          host: AgentPluginHost.codex,
          state: AgentPluginInventoryState.ready,
          plugins: <AgentPluginEntry>[
            AgentPluginEntry(
              id: 'notes@official',
              name: 'Notes plugin',
              host: AgentPluginHost.codex,
              enablement: AgentPluginEnablement.enabled,
              sourceKind: AgentPluginSourceKind.local,
              sourceName: 'official',
              version: '1.2',
            ),
          ],
        ),
        AgentPluginInventoryResult(
          host: AgentPluginHost.claudeCode,
          state: AgentPluginInventoryState.missing,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Notes plugin'), findsOneWidget);
      expect(find.textContaining('Configuration enabled'), findsOneWidget);
      expect(find.text('Source: Local · official'), findsOneWidget);
      expect(
        find.text('No Claude Code plugin registry was found.'),
        findsOneWidget,
      );
      inventory.pending = Completer<List<AgentPluginInventoryResult>>();
      await tester.ensureVisible(
        find.byKey(const Key('agent-plugins-refresh')),
      );
      await tester.tap(find.byKey(const Key('agent-plugins-refresh')));
      await tester.pump();
      expect(inventory.calls, 2);
      inventory.pending.complete(const <AgentPluginInventoryResult>[
        AgentPluginInventoryResult(
          host: AgentPluginHost.codex,
          state: AgentPluginInventoryState.ready,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('Notes plugin'), findsNothing);
      expect(find.text('No installed plugins were reported.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid and timed-out inventories are never shown as empty success',
    (tester) async {
      final _Inventory inventory = _Inventory();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AgentPluginsSection(inventory: inventory)),
        ),
      );
      await tester.ensureVisible(
        find.byKey(const Key('agent-plugins-refresh')),
      );
      await tester.tap(find.byKey(const Key('agent-plugins-refresh')));
      inventory.pending.complete(const <AgentPluginInventoryResult>[
        AgentPluginInventoryResult(
          host: AgentPluginHost.codex,
          state: AgentPluginInventoryState.timedOut,
        ),
        AgentPluginInventoryResult(
          host: AgentPluginHost.claudeCode,
          state: AgentPluginInventoryState.invalid,
        ),
      ]);
      await tester.pumpAndSettle();
      expect(
        find.text('Reading the inventory timed out. Try refreshing.'),
        findsOneWidget,
      );
      expect(find.textContaining('unsupported or malformed'), findsOneWidget);
      expect(find.text('No installed plugins were reported.'), findsNothing);
      expect(find.text('Codex · 0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _Inventory implements AgentPluginInventory {
  int calls = 0;
  Completer<List<AgentPluginInventoryResult>> pending =
      Completer<List<AgentPluginInventoryResult>>();

  @override
  Future<List<AgentPluginInventoryResult>> load() {
    calls += 1;
    return pending.future;
  }
}
