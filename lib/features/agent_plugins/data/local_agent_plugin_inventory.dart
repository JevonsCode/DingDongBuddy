import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_plugins/domain/agent_plugin_inventory.dart';
import 'package:path/path.dart' as path;

final class AgentPluginReadException implements Exception {
  const AgentPluginReadException(this.state);
  final AgentPluginInventoryState state;
}

final class AgentPluginCommandResult {
  const AgentPluginCommandResult(this.exitCode, this.output);
  final int exitCode;
  final String output;
}

abstract interface class AgentPluginCommandRunner {
  Future<AgentPluginCommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  });
}

typedef AgentPluginProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments, {
      required String workingDirectory,
    });

/// CLI output is bounded before decoding. Stderr is drained, never retained or
/// returned to the UI because a CLI error may contain private configuration.
final class BoundedAgentPluginCommandRunner
    implements AgentPluginCommandRunner {
  const BoundedAgentPluginCommandRunner({
    this.timeout = const Duration(seconds: 15),
    this.maxOutputBytes = 2 * 1024 * 1024,
    this.startProcess = _startProcess,
  });

  final Duration timeout;
  final int maxOutputBytes;
  final AgentPluginProcessStarter startProcess;

  static Future<Process> _startProcess(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) => Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    runInShell: false,
  );

  @override
  Future<AgentPluginCommandResult> run(
    String executable,
    List<String> arguments, {
    required String workingDirectory,
  }) async {
    final Process process = await startProcess(
      executable,
      arguments,
      workingDirectory: workingDirectory,
    );
    final List<int> bytes = <int>[];
    final Completer<void> outputDone = Completer<void>();
    final Completer<AgentPluginInventoryState> failure =
        Completer<AgentPluginInventoryState>();
    final StreamSubscription<List<int>> output = process.stdout.listen(
      (List<int> chunk) {
        if (failure.isCompleted) return;
        if (bytes.length + chunk.length > maxOutputBytes) {
          failure.complete(AgentPluginInventoryState.tooLarge);
          return;
        }
        bytes.addAll(chunk);
      },
      onDone: outputDone.complete,
      onError: (Object _) {
        if (!failure.isCompleted) {
          failure.complete(AgentPluginInventoryState.unavailable);
        }
      },
    );
    final StreamSubscription<List<int>> errors = process.stderr.listen(
      (_) {},
      onError: (Object _) {},
    );
    final Timer timer = Timer(timeout, () {
      if (!failure.isCompleted) {
        failure.complete(AgentPluginInventoryState.timedOut);
      }
    });
    try {
      final Object outcome = await Future.any<Object>(<Future<Object>>[
        Future.wait<Object>(<Future<Object>>[
          process.exitCode,
          outputDone.future.then<Object>((_) => true),
        ]),
        failure.future,
      ]);
      if (outcome is AgentPluginInventoryState) {
        throw AgentPluginReadException(outcome);
      }
      final List<Object> completed = outcome as List<Object>;
      return AgentPluginCommandResult(
        completed.first as int,
        utf8.decode(bytes),
      );
    } finally {
      timer.cancel();
      process.kill();
      await output.cancel();
      await errors.cancel();
    }
  }
}

/// Reads only native installation metadata. Loading does not install, enable,
/// synchronize, or execute plugin components.
final class LocalAgentPluginInventory implements AgentPluginInventory {
  LocalAgentPluginInventory({
    required this.homeDirectory,
    required this.environment,
    this.runner = const BoundedAgentPluginCommandRunner(),
    this.codexExecutable,
    bool? windows,
    bool? macOS,
  }) : windows = windows ?? Platform.isWindows,
       macOS = macOS ?? Platform.isMacOS;

  factory LocalAgentPluginInventory.production() => LocalAgentPluginInventory(
    homeDirectory:
        Platform.environment[Platform.isWindows ? 'USERPROFILE' : 'HOME'] ?? '',
    environment: Platform.environment,
  );

  static const int maxFileBytes = 2 * 1024 * 1024;
  final String homeDirectory;
  final Map<String, String> environment;
  final AgentPluginCommandRunner runner;
  final String? codexExecutable;
  final bool windows;
  final bool macOS;

  @override
  Future<List<AgentPluginInventoryResult>> load() => Future.wait(
    <Future<AgentPluginInventoryResult>>[_loadCodex(), _loadClaude()],
  );

  Future<AgentPluginInventoryResult> _loadCodex() async {
    const AgentPluginHost host = AgentPluginHost.codex;
    try {
      final String? executable = await _findCodex();
      if (executable == null || homeDirectory.isEmpty) {
        return const AgentPluginInventoryResult(
          host: host,
          state: AgentPluginInventoryState.missing,
        );
      }
      final AgentPluginCommandResult result = await runner.run(
        executable,
        const <String>['plugin', 'list', '--json'],
        workingDirectory: homeDirectory,
      );
      if (result.exitCode != 0) {
        throw const AgentPluginReadException(
          AgentPluginInventoryState.unavailable,
        );
      }
      final Map<String, Object?> root = _object(jsonDecode(result.output));
      final Object? installed = root['installed'];
      if (installed is! List) throw const FormatException();
      final List<AgentPluginEntry> plugins = <AgentPluginEntry>[];
      for (final Object? value in installed) {
        final Map<String, Object?> item = _object(value);
        final String? id = _metadata(item['pluginId']);
        final String? name = _metadata(item['name']);
        if (id == null || name == null || item['installed'] != true) {
          throw const FormatException();
        }
        final Map<String, Object?> source = item['source'] is Map
            ? _object(item['source'])
            : const <String, Object?>{};
        plugins.add(
          AgentPluginEntry(
            id: id,
            name: name,
            host: host,
            version: _metadata(item['version']),
            enablement: _enablement(item['enabled']),
            sourceKind: _sourceKind(source['source']),
            sourceName: _sourceName(item['marketplaceName']),
          ),
        );
      }
      return _ready(host, plugins);
    } on Object catch (error) {
      return _failed(host, error);
    }
  }

  Future<AgentPluginInventoryResult> _loadClaude() async {
    const AgentPluginHost host = AgentPluginHost.claudeCode;
    try {
      if (homeDirectory.isEmpty) {
        return const AgentPluginInventoryResult(
          host: host,
          state: AgentPluginInventoryState.missing,
        );
      }
      // Relative overrides resolve from the same explicit home directory used
      // for native CLI execution, never the UI process's incidental cwd.
      final String? configuredDirectory = environment['CLAUDE_CONFIG_DIR']
          ?.trim();
      final String directory =
          configuredDirectory == null || configuredDirectory.isEmpty
          ? path.join(homeDirectory, '.claude')
          : path.isAbsolute(configuredDirectory)
          ? path.normalize(configuredDirectory)
          : path.normalize(path.join(homeDirectory, configuredDirectory));
      final File registry = File(
        path.join(directory, 'plugins', 'installed_plugins.json'),
      );
      if (!await registry.exists()) {
        return const AgentPluginInventoryResult(
          host: host,
          state: AgentPluginInventoryState.missing,
        );
      }
      final Map<String, Object?> root = await _readObject(registry);
      final Map<String, Object?> installed = _object(root['plugins']);
      final File settingsFile = File(path.join(directory, 'settings.json'));
      final Map<String, Object?> settings = await settingsFile.exists()
          ? await _readObject(settingsFile)
          : const <String, Object?>{};
      final Object? enabledValue = settings['enabledPlugins'];
      if (enabledValue != null && enabledValue is! Map) {
        throw const FormatException();
      }
      final Map<String, Object?> enabled = enabledValue is Map
          ? _object(enabledValue)
          : const <String, Object?>{};
      final List<AgentPluginEntry> plugins = <AgentPluginEntry>[];
      final Set<String> seen = <String>{};
      for (final MapEntry<String, Object?> plugin in installed.entries) {
        final Object? installations = plugin.value;
        if (installations is! List) throw const FormatException();
        final String? id = _metadata(plugin.key);
        if (id == null) throw const FormatException();
        for (final Object? value in installations) {
          final Map<String, Object?> installation = _object(value);
          final String? version = _metadata(installation['version']);
          // Project/local settings can override user settings. Do not infer
          // their effective enablement from the user's settings.json.
          final AgentPluginEnablement enablement =
              installation['scope'] == 'user'
              ? _enablement(enabled[id])
              : AgentPluginEnablement.unknown;
          final String identity = '$id\u0000$version\u0000${enablement.name}';
          if (!seen.add(identity)) continue;
          final int separator = id.lastIndexOf('@');
          plugins.add(
            AgentPluginEntry(
              id: identity,
              name: separator > 0 ? id.substring(0, separator) : id,
              host: host,
              version: version,
              enablement: enablement,
              sourceKind: AgentPluginSourceKind.marketplace,
              sourceName: separator > 0
                  ? _sourceName(id.substring(separator + 1))
                  : null,
            ),
          );
        }
      }
      return _ready(host, plugins);
    } on Object catch (error) {
      return _failed(host, error);
    }
  }

  Future<String?> _findCodex() async {
    final List<String> candidates = <String>[
      ?codexExecutable,
      if (environment['CODEX_CLI_PATH'] case final String executable)
        executable,
      if (macOS) ...<String>[
        '/Applications/ChatGPT.app/Contents/Resources/codex',
        path.join(
          homeDirectory,
          'Applications',
          'ChatGPT.app',
          'Contents',
          'Resources',
          'codex',
        ),
      ],
      for (final String directory in (environment['PATH'] ?? '').split(
        windows ? ';' : ':',
      ))
        if (directory.trim().isNotEmpty && path.isAbsolute(directory.trim()))
          path.join(directory.trim(), windows ? 'codex.exe' : 'codex'),
    ];
    for (final String candidate in candidates) {
      if (await _isExecutableCandidate(candidate)) return candidate;
    }
    // The desktop app may start without the shell's PATH. Inspect only the
    // known Codex desktop binary directory, one level deep and at most 128 rows.
    final String? localAppData = environment['LOCALAPPDATA'];
    if (windows && localAppData != null && path.isAbsolute(localAppData)) {
      final Directory bin = Directory(
        path.join(localAppData, 'OpenAI', 'Codex', 'bin'),
      );
      if (await bin.exists()) {
        final List<({String file, DateTime modified})> found = [];
        await for (final FileSystemEntity entry
            in bin.list(followLinks: false).take(128)) {
          if (entry is! Directory) continue;
          final String file = path.join(entry.path, 'codex.exe');
          if (await _isExecutableCandidate(file)) {
            found.add((file: file, modified: await File(file).lastModified()));
          }
        }
        found.sort((left, right) => right.modified.compareTo(left.modified));
        if (found.isNotEmpty) return found.first.file;
      }
    }
    return null;
  }

  Future<bool> _isExecutableCandidate(String candidate) async =>
      path.isAbsolute(candidate) &&
      (!windows || path.extension(candidate).toLowerCase() == '.exe') &&
      await File(candidate).exists();

  static Future<Map<String, Object?>> _readObject(File file) async {
    if (await file.length() > maxFileBytes) {
      throw const AgentPluginReadException(AgentPluginInventoryState.tooLarge);
    }
    final List<int> bytes = <int>[];
    await for (final List<int> chunk in file.openRead()) {
      if (bytes.length + chunk.length > maxFileBytes) {
        throw const AgentPluginReadException(
          AgentPluginInventoryState.tooLarge,
        );
      }
      bytes.addAll(chunk);
    }
    return _object(jsonDecode(utf8.decode(bytes)));
  }

  static Map<String, Object?> _object(Object? value) {
    if (value is! Map) throw const FormatException();
    return Map<String, Object?>.from(value);
  }

  static String? _metadata(Object? value) {
    if (value is! String) return null;
    final String text = value.trim();
    return text.isEmpty ||
            text.length > 256 ||
            text.contains(RegExp(r'[\x00-\x1f]'))
        ? null
        : text;
  }

  static String? _sourceName(Object? value) {
    final String? name = _metadata(value);
    // A marketplace label is safe to display; URLs and filesystem paths are
    // deliberately excluded even if a future CLI puts them in this field.
    return name != null && RegExp(r'^[\w .@+-]+$').hasMatch(name) ? name : null;
  }

  static AgentPluginEnablement _enablement(Object? value) => switch (value) {
    true => AgentPluginEnablement.enabled,
    false => AgentPluginEnablement.disabled,
    _ => AgentPluginEnablement.unknown,
  };

  static AgentPluginSourceKind _sourceKind(Object? value) => switch (value) {
    'local' => AgentPluginSourceKind.local,
    'git' || 'github' => AgentPluginSourceKind.git,
    'remote' || 'remoteMarketplace' => AgentPluginSourceKind.remote,
    _ => AgentPluginSourceKind.unknown,
  };

  static AgentPluginInventoryResult _ready(
    AgentPluginHost host,
    List<AgentPluginEntry> plugins,
  ) {
    plugins.sort((left, right) => left.name.compareTo(right.name));
    return AgentPluginInventoryResult(
      host: host,
      state: AgentPluginInventoryState.ready,
      plugins: List<AgentPluginEntry>.unmodifiable(plugins),
    );
  }

  static AgentPluginInventoryResult _failed(
    AgentPluginHost host,
    Object error,
  ) => AgentPluginInventoryResult(
    host: host,
    state: switch (error) {
      AgentPluginReadException(:final state) => state,
      FormatException() || TypeError() => AgentPluginInventoryState.invalid,
      _ => AgentPluginInventoryState.unavailable,
    },
  );
}
