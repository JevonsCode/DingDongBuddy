import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_api/data/agent_install_gateway.dart';
import 'package:dingdong/features/agent_api/domain/agent_install.dart';
import 'package:dingdong/features/agent_api/ui/agent_install_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const String _mcp =
    '/Applications/DingDong.app/Contents/MCP/bundle/bin/dingdong_mcp';

void main() {
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
        environment: <String, String>{
          'HOME': home.path,
          'USERPROFILE': home.path,
          'APPDATA': '${home.path}${Platform.pathSeparator}AppData',
          'PATH': '',
        },
        extensionsDirectory: '${home.path}/extensions',
        backupDirectory: '${home.path}/backups',
        runInIsolate: false,
      );
    });

    tearDown(() => home.deleteSync(recursive: true));

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
      final List<String> commands = <String>[
        for (final Object? groups
            in ((jsonDecode(settings) as Map<String, Object?>)['hooks']!
                    as Map<String, Object?>)
                .values)
          for (final Object? group in groups! as List<Object?>)
            for (final Object? hook
                in (group! as Map<String, Object?>)['hooks']! as List<Object?>)
              (hook! as Map<String, Object?>)['command']! as String,
      ];
      // Each platform's shell quotes the client name its own way.
      final String source = Platform.isWindows
          ? '"Claude Code"'
          : "'Claude Code'";
      expect(commands, contains('$_mcp --notify-stop --source $source'));
      expect(
        commands,
        contains('$_mcp --acknowledge-session-start --source $source'),
      );
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

  @override
  Future<List<AgentInstallOutcome>> remove(List<String> clientIds) async =>
      const <AgentInstallOutcome>[];
}
