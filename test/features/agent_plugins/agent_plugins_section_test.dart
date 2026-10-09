import 'dart:async';

import 'package:dingdong/features/agent_plugins/domain/agent_plugin_inventory.dart';
import 'package:dingdong/features/plugins/ui/plugins_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'inventory is on demand, refreshable, and separate from DingDong extensions',
    (tester) async {
      final _Inventory inventory = _Inventory();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PluginsScreen(agentPluginInventory: inventory)),
        ),
      );
      expect(inventory.calls, 0);
      expect(find.text('DingDong extensions'), findsOneWidget);
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
          home: Scaffold(body: PluginsScreen(agentPluginInventory: inventory)),
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
