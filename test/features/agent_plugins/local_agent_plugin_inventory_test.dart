import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_plugins/data/local_agent_plugin_inventory.dart';
import 'package:dingdong/features/agent_plugins/domain/agent_plugin_inventory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  late Directory home;
  late File executable;

  setUp(() async {
    home = await Directory.systemTemp.createTemp('dingdong-plugin-inventory-');
    executable = await File(path.join(home.path, 'codex.exe')).create();
  });
  tearDown(() async => home.delete(recursive: true));

  LocalAgentPluginInventory inventory(_Runner runner) =>
      LocalAgentPluginInventory(
        homeDirectory: home.path,
        environment: const <String, String>{},
        codexExecutable: executable.path,
        runner: runner,
        windows: true,
        macOS: false,
      );

  Future<void> claude(Map<String, Object?> registry, {Object? enabled}) async {
    final Directory directory = await Directory(
      path.join(home.path, '.claude', 'plugins'),
    ).create(recursive: true);
    await File(
      path.join(directory.path, 'installed_plugins.json'),
    ).writeAsString(jsonEncode(registry));
    if (enabled != null) {
      await File(
        path.join(home.path, '.claude', 'settings.json'),
      ).writeAsString(jsonEncode(<String, Object?>{'enabledPlugins': enabled}));
    }
  }

  test(
    'Codex reads only installed metadata with fixed CLI arguments',
    () async {
      final _Runner runner = _Runner(
        output: jsonEncode(<String, Object?>{
          'installed': <Object?>[
            <String, Object?>{
              'pluginId': 'notes@official',
              'name': 'notes',
              'version': '2.3',
              'enabled': false,
              'installed': true,
              'marketplaceName': 'official',
              'source': <String, Object?>{
                'source': 'local',
                'path': 'private-install-path',
              },
              'authPolicy': 'private-auth-data',
            },
          ],
          'available': <Object?>[
            <String, Object?>{'name': 'not-installed'},
          ],
        }),
      );
      final List<AgentPluginInventoryResult> result = await inventory(
        runner,
      ).load();
      expect(result.first.state, AgentPluginInventoryState.ready);
      final AgentPluginEntry plugin = result.first.plugins.single;
      expect(plugin.name, 'notes');
      expect(plugin.sourceName, 'official');
      expect(plugin.sourceKind, AgentPluginSourceKind.local);
      expect(plugin.version, '2.3');
      expect(plugin.enablement, AgentPluginEnablement.disabled);
      expect(runner.arguments, <String>['plugin', 'list', '--json']);
      expect(runner.workingDirectory, home.path);
      expect(result.last.state, AgentPluginInventoryState.missing);
    },
  );

  test(
    'empty installed list differs from missing or invalid inventory',
    () async {
      final List<AgentPluginInventoryResult> result = await inventory(
        _Runner(),
      ).load();
      expect(result.first.state, AgentPluginInventoryState.ready);
      expect(result.first.plugins, isEmpty);
      expect(result.last.state, AgentPluginInventoryState.missing);
      final invalid = await inventory(
        _Runner(output: '{"available": []}'),
      ).load();
      expect(invalid.first.state, AgentPluginInventoryState.invalid);
    },
  );

  test(
    'unreported enablement remains unknown and source paths stay private',
    () async {
      final List<AgentPluginInventoryResult> result = await inventory(
        _Runner(
          output: jsonEncode(<String, Object?>{
            'installed': <Object?>[
              <String, Object?>{
                'pluginId': 'notes',
                'name': 'notes',
                'installed': true,
                'marketplaceName': r'C:\private\registry',
                'source': <String, Object?>{'source': 'future-format'},
              },
            ],
          }),
        ),
      ).load();
      final AgentPluginEntry plugin = result.first.plugins.single;
      expect(plugin.enablement, AgentPluginEnablement.unknown);
      expect(plugin.sourceName, isNull);
      expect(plugin.sourceKind, AgentPluginSourceKind.unknown);
      expect(plugin.version, isNull);
    },
  );

  test(
    'Claude reads disabled plugins and does not infer project enablement',
    () async {
      await claude(
        <String, Object?>{
          'plugins': <String, Object?>{
            'notes@community': <Object?>[
              <String, Object?>{
                'version': '1.0',
                'scope': 'user',
                'installPath': 'private-path',
              },
              <String, Object?>{
                'version': '1.0',
                'scope': 'project',
                'projectPath': 'private-project',
              },
            ],
          },
        },
        enabled: <String, Object?>{'notes@community': false},
      );
      final List<AgentPluginInventoryResult> result = await inventory(
        _Runner(),
      ).load();
      expect(result.last.state, AgentPluginInventoryState.ready);
      expect(result.last.plugins, hasLength(2));
      expect(
        result.last.plugins.map((plugin) => plugin.enablement),
        containsAll(<AgentPluginEnablement>[
          AgentPluginEnablement.disabled,
          AgentPluginEnablement.unknown,
        ]),
      );
      expect(result.last.plugins.first.sourceName, 'community');
      expect(result.last.plugins.first.name, 'notes');
    },
  );

  test(
    'malformed Claude registry does not hide successful Codex result',
    () async {
      await claude(<String, Object?>{'plugins': 'bad-format'});
      final List<AgentPluginInventoryResult> result = await inventory(
        _Runner(),
      ).load();
      expect(result.first.state, AgentPluginInventoryState.ready);
      expect(result.last.state, AgentPluginInventoryState.invalid);
    },
  );

  test('oversized Claude registry is rejected before parsing', () async {
    final File registry = File(
      path.join(home.path, '.claude', 'plugins', 'installed_plugins.json'),
    );
    await registry.parent.create(recursive: true);
    await registry.writeAsString(
      'x' * (LocalAgentPluginInventory.maxFileBytes + 1),
    );
    final result = await inventory(_Runner()).load();
    expect(result.last.state, AgentPluginInventoryState.tooLarge);
  });

  test(
    'CLI failures and timeouts remain explicit, without raw output',
    () async {
      final failed = await inventory(
        _Runner(exitCode: 1, output: 'secret-or-diagnostic'),
      ).load();
      expect(failed.first.state, AgentPluginInventoryState.unavailable);
      expect(failed.first.plugins, isEmpty);
      final timedOut = await inventory(
        _Runner(
          error: const AgentPluginReadException(
            AgentPluginInventoryState.timedOut,
          ),
        ),
      ).load();
      expect(timedOut.first.state, AgentPluginInventoryState.timedOut);
    },
  );

  test('native executable lookup finds desktop install without PATH', () async {
    final String localData = path.join(home.path, 'Local');
    final File desktopExecutable = File(
      path.join(localData, 'OpenAI', 'Codex', 'bin', 'version-a', 'codex.exe'),
    );
    await desktopExecutable.parent.create(recursive: true);
    await desktopExecutable.create();
    final _Runner runner = _Runner();
    final result = await LocalAgentPluginInventory(
      homeDirectory: home.path,
      environment: <String, String>{'LOCALAPPDATA': localData},
      runner: runner,
      windows: true,
      macOS: false,
    ).load();
    expect(result.first.state, AgentPluginInventoryState.ready);
    expect(runner.executable, desktopExecutable.path);
  });

  test(
    'custom Claude directory is honored for absolute and home-relative paths',
    () async {
      final Directory configured = Directory(
        path.join(home.path, 'claude-custom'),
      );
      final File registry = File(
        path.join(configured.path, 'plugins', 'installed_plugins.json'),
      );
      await registry.parent.create(recursive: true);
      await registry.writeAsString('{"plugins":{}}');
      for (final String override in <String>[
        configured.path,
        'claude-custom',
      ]) {
        final result = await LocalAgentPluginInventory(
          homeDirectory: home.path,
          environment: <String, String>{'CLAUDE_CONFIG_DIR': override},
          runner: _Runner(),
          windows: true,
          macOS: false,
        ).load();
        expect(result.last.state, AgentPluginInventoryState.ready);
        expect(result.last.plugins, isEmpty);
      }
    },
  );

  test(
    'Windows lookup never executes a shell wrapper or relative executable',
    () async {
      final File wrapper = await File(
        path.join(home.path, 'codex.cmd'),
      ).create();
      final _Runner runner = _Runner();
      final result = await LocalAgentPluginInventory(
        homeDirectory: home.path,
        environment: <String, String>{'CODEX_CLI_PATH': wrapper.path},
        runner: runner,
        windows: true,
        macOS: false,
      ).load();
      expect(result.first.state, AgentPluginInventoryState.missing);
      expect(runner.executable, isNull);
      final relative = await LocalAgentPluginInventory(
        homeDirectory: home.path,
        environment: const <String, String>{'CODEX_CLI_PATH': 'codex.exe'},
        runner: runner,
        windows: true,
        macOS: false,
      ).load();
      expect(relative.first.state, AgentPluginInventoryState.missing);
      expect(runner.executable, isNull);
    },
  );

  test(
    'bounded runner kills a process when stdout exceeds its limit',
    () async {
      final _Process process = _Process(
        output: Stream<List<int>>.value(utf8.encode('too-large')),
      );
      final runner = BoundedAgentPluginCommandRunner(
        maxOutputBytes: 2,
        startProcess:
            (executable, arguments, {required workingDirectory}) async =>
                process,
      );
      await expectLater(
        runner.run('codex.exe', const <String>[], workingDirectory: home.path),
        throwsA(
          isA<AgentPluginReadException>().having(
            (error) => error.state,
            'state',
            AgentPluginInventoryState.tooLarge,
          ),
        ),
      );
      expect(process.killed, isTrue);
    },
  );

  test('bounded runner kills a hung process on timeout', () async {
    final _Process process = _Process(exit: Completer<int>().future);
    final runner = BoundedAgentPluginCommandRunner(
      timeout: const Duration(milliseconds: 10),
      startProcess:
          (executable, arguments, {required workingDirectory}) async => process,
    );
    await expectLater(
      runner.run('codex.exe', const <String>[], workingDirectory: home.path),
      throwsA(
        isA<AgentPluginReadException>().having(
          (error) => error.state,
          'state',
          AgentPluginInventoryState.timedOut,
        ),
      ),
    );
    expect(process.killed, isTrue);
  });
}

class _Runner implements AgentPluginCommandRunner {
  _Runner({this.output = '{"installed":[]}', this.exitCode = 0, this.error});
  final String output;
  final int exitCode;
  final Object? error;
  String? executable;
  List<String>? arguments;
  String? workingDirectory;

  @override
  Future<AgentPluginCommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    this.executable = executable;
    this.arguments = arguments;
    this.workingDirectory = workingDirectory;
    if (error != null) throw error!;
    return AgentPluginCommandResult(exitCode, output);
  }
}

class _Process implements Process {
  _Process({Stream<List<int>>? output, Future<int>? exit})
    : stdout = output ?? const Stream<List<int>>.empty(),
      exitCode = exit ?? Future<int>.value(0);

  bool killed = false;
  @override
  final Stream<List<int>> stdout;
  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();
  @override
  final Future<int> exitCode;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
