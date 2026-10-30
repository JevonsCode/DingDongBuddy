import 'dart:convert';
import 'dart:io';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/agent_api/data/agent_install_gateway.dart';
import 'package:dingdong/features/agent_api/domain/agent_install.dart';
import 'package:dingdong/features/agent_api/ui/agent_api_screen.dart';
import 'package:dingdong/features/agent_api/ui/agent_install_card.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String _mcp =
    '/Applications/DingDong.app/Contents/MCP/bundle/bin/dingdong_mcp';

void main() {
  testWidgets(
    'connection page leads with detection and keeps manual setup optional',
    (tester) async {
      final settings = SettingsViewModel(
        SettingsRepository(MemoryPreferencesBackend()),
      );
      await settings.load();
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AgentApiScreen(
              settingsViewModel: settings,
              agentInstallGateway: _FakeGateway()..previewOnly = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('agent-install-card')), findsOneWidget);
      expect(find.byKey(const Key('agent-api-setup-prompt')), findsNothing);
      final context = tester.element(find.byType(AgentApiScreen));
      expect(find.text(context.l10n.agentSetupGettingStarted), findsNothing);
      final manual = find.byKey(const Key('agent-install-show-manual'));
      await tester.ensureVisible(manual);
      await tester.pumpAndSettle();
      await tester.tap(manual);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('agent-api-setup-prompt')), findsOneWidget);
    },
  );

  group('LocalAgentInstallGateway', () {
    late Directory home;
    late LocalAgentInstallGateway gateway;

    String? read(String relative) {
      final File file = File('${home.path}/$relative');
      return file.existsSync() ? file.readAsStringSync() : null;
    }

    void write(String relative, String content) {
      File('${home.path}/$relative')
        ..parent.createSync(recursive: true)
        ..writeAsStringSync(content);
    }

    setUp(() {
      home = Directory.systemTemp.createTempSync('dingdong-agent-install-');
      gateway = LocalAgentInstallGateway(
        mcpCommandPath: _mcp,
        environment: <String, String>{'HOME': home.path, 'PATH': ''},
        extensionsDirectory: '${home.path}/extensions',
        backupDirectory: '${home.path}/backups',
        runInIsolate: false,
      );
    });

    tearDown(() => home.deleteSync(recursive: true));

    for (final operation in ['apply', 'remove']) {
      test('DEV rejects $operation even when called directly', () async {
        write('.claude.json', '{"numStartups": 3}\n');
        Directory('${home.path}/.claude').createSync();
        final preview = LocalAgentInstallGateway(
          mcpCommandPath: _mcp,
          environment: <String, String>{'HOME': home.path, 'PATH': ''},
          extensionsDirectory: '${home.path}/extensions',
          backupDirectory: '${home.path}/backups',
          runInIsolate: false,
          previewOnly: true,
        );
        expect((await _client(preview, 'claude-code')).detected, isTrue);
        expect(
          (await preview.plan(<String>['claude-code'])).single.changes,
          isNotEmpty,
        );
        await expectLater(
          operation == 'apply'
              ? preview.apply(<String>['claude-code'])
              : preview.remove(<String>['claude-code']),
          throwsA(isA<StateError>()),
        );
        expect(read('.claude.json'), '{"numStartups": 3}\n');
        expect(read('.claude/settings.json'), isNull);
        expect(Directory('${home.path}/backups').existsSync(), isFalse);
      });
    }

    test(
      'removal preview is read only and lists exactly the applied files',
      () async {
        write('.claude.json', '{"numStartups":3}\n');
        write('.claude/CLAUDE.md', 'Personal instructions\n');
        await gateway.apply(['claude-code']);
        final before = {
          for (final name in [
            '.claude.json',
            '.claude/settings.json',
            '.claude/CLAUDE.md',
          ])
            name: read(name),
        };
        final preview = (await gateway.planRemoval(['claude-code'])).single;
        expect(
          preview.changes.map((change) => change.path),
          contains('~/.claude/CLAUDE.md'),
        );
        expect(
          preview.changes.expand((change) => change.components),
          containsAll(['mcp', 'hooks', 'instructions']),
        );
        for (final entry in before.entries) {
          expect(
            read(entry.key),
            entry.value,
            reason: 'Removal preview must not write.',
          );
        }
        final result = (await gateway.remove(['claude-code'])).single;
        expect(
          result.changes.map((change) => change.path).toSet(),
          preview.changes.map((change) => change.path).toSet(),
        );
        expect(read('.claude/CLAUDE.md'), 'Personal instructions\n');
      },
    );

    test(
      'same-name foreign MCP is left untouched during install and cleanup',
      () async {
        const foreign =
            '{"mcpServers":{"dingdong":{"command":"foreign-service"}}}\n';
        write('.claude.json', foreign);
        expect(
          (await _client(gateway, 'claude-code')).state,
          AgentInstallState.conflict,
        );
        await gateway.apply(['claude-code']);
        expect(read('.claude.json'), foreign);
        final preview = (await gateway.planRemoval(['claude-code'])).single;
        expect(
          preview.changes.map((change) => change.path),
          isNot(contains('~/.claude.json')),
        );
        await gateway.remove(['claude-code']);
        expect(read('.claude.json'), foreign);
      },
    );

    test('installs the MCP server and Hooks into Claude Code', () async {
      write('.claude.json', '{"numStartups": 3}\n');
      Directory('${home.path}/.claude').createSync();

      Future<AgentInstallClient> claude() => _client(gateway, 'claude-code');
      expect((await claude()).detected, isTrue);
      expect((await claude()).state, AgentInstallState.notConnected);

      final List<AgentInstallOutcome> plan = await gateway.plan(<String>[
        'claude-code',
      ]);
      expect(
        plan.single.changes.map((AgentInstallChange c) => c.path),
        containsAll(<String>['~/.claude.json', '~/.claude/settings.json']),
      );
      expect(read('.claude/settings.json'), isNull, reason: 'plan writes');

      await gateway.apply(<String>['claude-code']);
      final Map<String, Object?> config =
          jsonDecode(read('.claude.json')!) as Map<String, Object?>;
      expect(config['numStartups'], 3);
      expect(
        (config['mcpServers']! as Map<String, Object?>)['dingdong'],
        containsPair('command', _mcp),
      );
      final String settings = read('.claude/settings.json')!;
      expect(
        settings,
        contains('$_mcp --notify-stop --source \'Claude Code\''),
      );
      expect(settings, contains('--acknowledge-session-start'));
      expect(settings, contains('"matcher": "startup|resume"'));
      expect((await claude()).state, AgentInstallState.connected);

      await gateway.remove(<String>['claude-code']);
      expect(read('.claude.json'), '{"numStartups": 3}\n');
      expect(read('.claude/settings.json'), isNull);
    });

    test('takes over hooks that were added by hand in Codex', () async {
      const String toml =
          'model = "gpt-5"\n'
          '\n'
          '[mcp_servers.dingdong]\n'
          'command = "$_mcp"\n'
          '\n'
          '[[hooks.Stop]]\n'
          '\n'
          '[[hooks.Stop.hooks]]\n'
          'command = \'"$_mcp" --notify-stop --source "Codex"\'\n'
          'type = "command"\n'
          '\n'
          '[[hooks.Stop]]\n'
          '\n'
          '[[hooks.Stop.hooks]]\n'
          'command = "other --stop"\n'
          'type = "command"\n';
      write('.codex/config.toml', toml);

      expect(
        (await _client(gateway, 'codex')).state,
        AgentInstallState.updateAvailable,
      );
      final AgentInstallOutcome applied = (await gateway.apply(<String>[
        'codex',
      ])).single;
      expect(applied.needsHookTrust, isTrue);
      final String config = read('.codex/config.toml')!;
      expect('--notify-stop'.allMatches(config), hasLength(1));
      expect(config, contains('command = "other --stop"'));
      expect(config, contains(r'matcher = "^(startup|resume)$"'));
      expect(config, contains('$_mcp --notify-stop --source Codex'));
      expect(read('.codex/hooks.json'), isNull);
      expect(
        (await _client(gateway, 'codex')).state,
        AgentInstallState.connected,
      );

      await gateway.remove(<String>['codex']);
      final String removed = read('.codex/config.toml')!;
      expect(removed, isNot(contains('dingdong')));
      expect(removed, contains('command = "other --stop"'));
    });

    test('Cursor is notified with the final reply', () async {
      Directory('${home.path}/.cursor').createSync();
      await gateway.apply(<String>['cursor']);
      final Map<String, Object?> hooks =
          jsonDecode(read('.cursor/hooks.json')!) as Map<String, Object?>;
      expect((hooks['hooks']! as Map<String, Object?>).keys, <String>[
        'afterAgentResponse',
      ]);
      expect(
        read('.cursor/hooks.json'),
        contains('$_mcp --notify-stop --source Cursor'),
      );
      expect(read('.cursor/mcp.json'), contains('"dingdong"'));
    });

    test('Agents that are not installed are not offered', () async {
      final List<AgentInstallClient> clients = await gateway.scan();
      expect(clients, isNotEmpty);
      expect(clients.where((AgentInstallClient c) => c.detected), isEmpty);
    });
  });

  group('AgentInstallCard', () {
    testWidgets(
      'DEV detects clients and previews without writing configuration',
      (WidgetTester tester) async {
        final gateway = _FakeGateway()..previewOnly = true;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: AgentInstallCard(gateway: gateway),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Claude Code'), findsOneWidget);
        expect(
          find.byKey(const Key('agent-install-preview-only')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('agent-install-remove-cursor')),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('agent-install-selected')));
        await tester.pumpAndSettle();
        expect(gateway.planned, <String>['claude-code', 'codex']);
        expect(find.byKey(const Key('agent-install-preview')), findsOneWidget);
        expect(find.text('Create  ~/.claude/settings.json'), findsOneWidget);
        expect(find.byKey(const Key('agent-install-confirm')), findsNothing);
        await tester.tap(find.byKey(const Key('agent-install-cancel')));
        await tester.pumpAndSettle();
        expect(gateway.applied, isNull);
        await tester.tap(find.byKey(const Key('agent-install-remove-cursor')));
        await tester.pumpAndSettle();
        expect(gateway.removalPlanned, ['cursor']);
        expect(find.textContaining('DEV only previews'), findsOneWidget);
        expect(find.byKey(const Key('agent-install-confirm')), findsNothing);
        await tester.tap(find.byKey(const Key('agent-install-cancel')));
        await tester.pumpAndSettle();
        expect(gateway.removed, isNull);

      },
    );

    testWidgets(
      'cleanup previews one Agent and requires confirmation before removing',
      (tester) async {
        final gateway = _FakeGateway();
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: AgentInstallCard(gateway: gateway)),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('agent-install-remove-cursor')));
        await tester.pumpAndSettle();
        expect(gateway.removalPlanned, ['cursor']);
        expect(gateway.removed, isNull);
        expect(find.textContaining('~/.cursor/mcp.json'), findsOneWidget);
        await tester.tap(find.byKey(const Key('agent-install-cancel')));
        await tester.pumpAndSettle();
        expect(gateway.removed, isNull);
        await tester.tap(find.byKey(const Key('agent-install-remove-cursor')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('agent-install-confirm')));
        await tester.pumpAndSettle();
        expect(gateway.removed, ['cursor']);
      },
    );

    testWidgets('selects new Agents, previews the files, then installs', (
      WidgetTester tester,
    ) async {
      final _FakeGateway gateway = _FakeGateway();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AgentInstallCard(gateway: gateway),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Claude Code'), findsOneWidget);
      expect(find.text('Cursor'), findsOneWidget);
      expect(find.text('Gemini CLI'), findsNothing, reason: 'not installed');
      expect(
        find.byKey(const Key('agent-install-remove-cursor')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('agent-install-selected')));
      await tester.pumpAndSettle();
      expect(gateway.planned, <String>['claude-code', 'codex']);
      expect(find.byKey(const Key('agent-install-preview')), findsOneWidget);
      expect(find.text('Create  ~/.claude/settings.json'), findsOneWidget);
      expect(gateway.applied, isNull);

      await tester.tap(find.byKey(const Key('agent-install-confirm')));
      await tester.pumpAndSettle();
      expect(gateway.applied, <String>['claude-code', 'codex']);
      expect(
        find.text(
          "In Codex, run /hooks and trust DingDong's Hooks so they can run.",
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('agent-install-state-claude-code')),
        findsOneWidget,
      );
      expect(find.text('Connected'), findsNWidgets(3));
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('agent-install-selected')),
            )
            .onPressed,
        isNull,
        reason: 'Configured Agents no longer need installation.',
      );
    });

    testWidgets('unchecking an Agent leaves it out', (
      WidgetTester tester,
    ) async {
      final _FakeGateway gateway = _FakeGateway();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: AgentInstallCard(gateway: gateway)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('agent-install-client-codex')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('agent-install-selected')));
      await tester.pumpAndSettle();
      expect(gateway.planned, <String>['claude-code']);
      await tester.tap(find.byKey(const Key('agent-install-cancel')));
      await tester.pumpAndSettle();
      expect(gateway.applied, isNull);
    });
  });
}

Future<AgentInstallClient> _client(
  AgentInstallGateway gateway,
  String id,
) async =>
    (await gateway.scan()).singleWhere((AgentInstallClient c) => c.id == id);

final class _FakeGateway implements AgentInstallGateway {
  @override
  bool previewOnly = false;
  final Map<String, AgentInstallState> states = <String, AgentInstallState>{
    'claude-code': AgentInstallState.notConnected,
    'codex': AgentInstallState.updateAvailable,
    'cursor': AgentInstallState.connected,
  };
  List<String>? planned;
  List<String>? applied;

  @override
  Future<List<AgentInstallClient>> scan() async => <AgentInstallClient>[
    for (final MapEntry<String, AgentInstallState> e in states.entries)
      AgentInstallClient(
        id: e.key,
        name: switch (e.key) {
          'claude-code' => 'Claude Code',
          'codex' => 'Codex',
          _ => 'Cursor',
        },
        detected: true,
        state: e.value,
      ),
    const AgentInstallClient(
      id: 'gemini-cli',
      name: 'Gemini CLI',
      detected: false,
      state: AgentInstallState.notConnected,
    ),
  ];

  @override
  Future<List<AgentInstallOutcome>> plan(List<String> clientIds) async {
    planned = clientIds;
    return <AgentInstallOutcome>[
      for (final String id in clientIds)
        AgentInstallOutcome(
          id: id,
          name: id == 'codex' ? 'Codex' : 'Claude Code',
          state: states[id]!,
          changes: <AgentInstallChange>[
            id == 'codex'
                ? const AgentInstallChange(
                    path: '~/.codex/config.toml',
                    action: 'update',
                  )
                : const AgentInstallChange(
                    path: '~/.claude/settings.json',
                    action: 'create',
                  ),
          ],
        ),
    ];
  }

  @override
  Future<List<AgentInstallOutcome>> apply(List<String> clientIds) async {
    applied = clientIds;
    for (final String id in clientIds) {
      states[id] = AgentInstallState.connected;
    }
    return <AgentInstallOutcome>[
      for (final String id in clientIds)
        AgentInstallOutcome(
          id: id,
          name: id,
          state: AgentInstallState.connected,
          needsHookTrust: id == 'codex',
        ),
    ];
  }

  List<String>? removalPlanned;
  List<String>? removed;
  @override
  Future<List<AgentInstallOutcome>> planRemoval(List<String> clientIds) async {
    removalPlanned = clientIds;
    return [
      AgentInstallOutcome(
        id: clientIds.single,
        name: 'Cursor',
        state: AgentInstallState.connected,
        changes: [
          const AgentInstallChange(
            path: '~/.cursor/mcp.json',
            action: 'update',
            components: ['mcp'],
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<AgentInstallOutcome>> remove(List<String> clientIds) async {
    removed = clientIds;
    return const [];
  }
}
