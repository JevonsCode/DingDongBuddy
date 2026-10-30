import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agent_session_launcher/agent_session_launcher.dart' as sessions;
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/domain/agent_launcher_configuration.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

typedef AgentUriOpener = Future<bool> Function(Uri uri);
typedef AgentProcessStarter =
    Future<void> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });
typedef AgentLauncherConfigurationLoader =
    Future<AgentLauncherConfiguration> Function();
typedef CodexConversationOpenability = Future<bool> Function(String threadId);
typedef CodexConversationOpenabilityBatch =
    Future<Set<String>> Function(Iterable<String> threadIds);
typedef CodexConversationPreflightBatch =
    Future<AgentConversationPreflightResult> Function(
      Iterable<String> threadIds,
    );

/// Opens only known Agent clients using identifiers captured from their hooks.
final class NativeAgentConversationLauncher extends ChangeNotifier
    implements AgentConversationLauncher {
  NativeAgentConversationLauncher({
    String? operatingSystem,
    AgentUriOpener? uriOpener,
    AgentProcessStarter? processStarter,
    AgentLauncherConfigurationLoader? configurationLoader,
    this.extensionsDirectory,
    this.codexConversationOpenability,
    this.codexConversationOpenabilityBatch,
    this.codexConversationPreflightBatch,
  }) : _operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _uriOpener = uriOpener ?? _openExternalUri,
       _processStarter = processStarter ?? _startDetached,
       _configurationLoader =
           configurationLoader ?? _loadDefaultLauncherConfiguration;

  final String _operatingSystem;
  final String? extensionsDirectory;
  sessions.LauncherConfig _sessionConfig = sessions.LauncherConfig.defaults;

  sessions.SessionTarget _sessionTarget(AgentConversationTarget target) =>
      sessions.SessionTarget(
        client: _sessionClientId(target.client),
        conversationId: target.conversationId,
        hostSessionId: target.hostSessionId,
        workspacePath: target.workspacePath,
      );

  sessions.SessionLauncher get _sessions => sessions.SessionLauncher(
    config: _sessionConfig,
    operatingSystem: _operatingSystem,
  );

  Future<void> _refreshSessionConfig() async {
    final legacy = await _configurationLoader();
    _sessionConfig = sessions.LauncherConfig.load(
      hostConfig: jsonEncode({
        'schemaVersion': 1,
        'preferences': legacy.defaults.toJson(),
        'clients': {
          for (final entry in legacy.agentOverrides.entries)
            _sessionClientId(entry.key): {'preferences': entry.value.toJson()},
        },
      }),
      extensionsDirectory:
          extensionsDirectory ?? sessions.defaultExtensionsDirectory(),
    );
  }

  final AgentUriOpener _uriOpener;
  final AgentProcessStarter _processStarter;
  final AgentLauncherConfigurationLoader _configurationLoader;
  final CodexConversationOpenability? codexConversationOpenability;
  final CodexConversationOpenabilityBatch? codexConversationOpenabilityBatch;
  final CodexConversationPreflightBatch? codexConversationPreflightBatch;
  final Map<String, bool> _codexOpenabilityCache = <String, bool>{};
  final Map<String, bool> _codexSubagentCache = <String, bool>{};
  final Map<String, Future<bool>> _codexOpenabilityRequests =
      <String, Future<bool>>{};

  @override
  bool canOpen(AgentConversationTarget target) {
    final String? id = _safeConversationId(target.conversationId);
    final String? workspace = _safeWorkspacePath(target.workspacePath);
    final client = _sessionConfig.client(_sessionClientId(target.client));
    if (client?.enabled == false) return false;
    // Workspace-only fallbacks remain host behavior, not session resume.
    if (target.client == AgentClient.cursor &&
        (id == null || !id.startsWith('bc-'))) {
      return workspace != null;
    }
    if (target.client == AgentClient.kiro && id == null) {
      return workspace != null;
    }
    try {
      final plan = _sessions.inspect(_sessionTarget(target));
      if (!_sessions.supportsOpening(plan)) return false;
    } on sessions.SessionLaunchException {
      return false;
    }
    return target.client != AgentClient.codex ||
        ((codexConversationOpenability == null &&
                codexConversationOpenabilityBatch == null &&
                codexConversationPreflightBatch == null) ||
            _codexOpenabilityCache[id] == true);
  }

  @override
  bool isSubagent(AgentConversationTarget target) {
    if (target.client != AgentClient.codex) {
      return false;
    }
    final String? id = _safeConversationId(target.conversationId);
    return id != null && _codexSubagentCache[id] == true;
  }

  /// Resolves Codex destinations before the activity UI offers them as links.
  ///
  /// The launcher used to perform this check only after the user clicked. That
  /// made background subagents look resumable until Codex rejected the deep
  /// link. Unknown Codex targets remain closed until this preflight completes.
  Future<void> preflight(Iterable<AgentConversationTarget> targets) async {
    final before = targets.map(canOpen).toList();
    await _refreshSessionConfig();
    if (!listEquals(before, targets.map(canOpen).toList())) notifyListeners();
    if (codexConversationOpenability == null &&
        codexConversationOpenabilityBatch == null &&
        codexConversationPreflightBatch == null) {
      return;
    }
    final Set<String> ids = targets
        .where(
          (AgentConversationTarget target) =>
              target.client == AgentClient.codex,
        )
        .map(
          (AgentConversationTarget target) =>
              _safeConversationId(target.conversationId),
        )
        .whereType<String>()
        .toSet();
    if (ids.isEmpty) {
      return;
    }
    if (codexConversationPreflightBatch != null) {
      final AgentConversationPreflightResult result =
          await _loadCodexPreflightBatch(ids);
      bool changed = false;
      for (final String id in ids) {
        final bool openable = result.openableConversationIds.contains(id);
        final bool subagent = result.subagentConversationIds.contains(id);
        if (_codexOpenabilityCache[id] != openable ||
            _codexSubagentCache[id] != subagent) {
          changed = true;
        }
        _codexOpenabilityCache[id] = openable;
        _codexSubagentCache[id] = subagent;
      }
      if (changed) {
        notifyListeners();
      }
      return;
    }
    if (codexConversationOpenabilityBatch != null) {
      final Set<String> openable = await _loadCodexOpenabilityBatch(ids);
      bool changed = false;
      for (final String id in ids) {
        final bool result = openable.contains(id);
        if (_codexOpenabilityCache[id] != result) {
          changed = true;
        }
        _codexOpenabilityCache[id] = result;
      }
      if (changed) {
        notifyListeners();
      }
      return;
    }
    await Future.wait(ids.map(_isCodexConversationOpenable));
  }

  @override
  Future<void> open(AgentConversationTarget target) async {
    await _refreshSessionConfig();
    if (!canOpen(target)) {
      throw StateError('This Agent item has no supported destination.');
    }
    final id = _safeConversationId(target.conversationId);
    final workspace = _safeWorkspacePath(target.workspacePath);
    if (target.client == AgentClient.codex &&
        (codexConversationOpenability != null ||
            codexConversationOpenabilityBatch != null ||
            codexConversationPreflightBatch != null) &&
        !await _isCodexConversationOpenable(id!)) {
      throw StateError('This Codex thread is not a resumable user thread.');
    }
    if (target.client == AgentClient.cursor &&
        (id == null || !id.startsWith('bc-'))) {
      await _openDesktopApp('Cursor', 'cursor', workspace!);
      return;
    }
    if (target.client == AgentClient.kiro && id == null) {
      await _openDesktopApp('Kiro', 'kiro', workspace!);
      return;
    }
    final plan = _sessions.inspect(_sessionTarget(target));
    if (plan.kind == 'uri') {
      await _openUri(plan.uri!);
    } else {
      final preferences = const sessions.LaunchPreferences()
          .over(
            _sessionConfig.client(_sessionClientId(target.client))?.preferences,
          )
          .over(_sessionConfig.preferences);
      await _openCliSession(
        executable: plan.executable!,
        arguments: plan.arguments,
        workspacePath: plan.workspacePath!,
        settings: AgentLauncherSettings(
          macosTerminal:
              preferences.macosTerminal == sessions.MacosTerminal.iterm
              ? MacOsTerminalApplication.iTerm
              : MacOsTerminalApplication.terminal,
          iTermOpenMode:
              preferences.itermOpenMode == sessions.ITermOpenMode.newTab
              ? ITermOpenMode.newTab
              : ITermOpenMode.newWindow,
        ),
      );
    }
  }

  Future<bool> _isCodexConversationOpenable(String threadId) async {
    final bool? cached = _codexOpenabilityCache[threadId];
    if (cached != null) {
      return cached;
    }
    final Future<bool>? pending = _codexOpenabilityRequests[threadId];
    if (pending != null) {
      return await pending;
    }

    final Future<bool> request = _loadCodexOpenability(threadId);
    _codexOpenabilityRequests[threadId] = request;
    try {
      final bool result = await request;
      final bool? previous = _codexOpenabilityCache[threadId];
      _codexOpenabilityCache[threadId] = result;
      if (previous != result) {
        notifyListeners();
      }
      return result;
    } finally {
      if (identical(_codexOpenabilityRequests[threadId], request)) {
        unawaited(_codexOpenabilityRequests.remove(threadId));
      }
    }
  }

  Future<bool> _loadCodexOpenability(String threadId) async {
    try {
      if (codexConversationOpenability != null) {
        return await codexConversationOpenability!(threadId);
      }
      if (codexConversationPreflightBatch != null) {
        final AgentConversationPreflightResult result =
            await _loadCodexPreflightBatch(<String>[threadId]);
        return result.openableConversationIds.contains(threadId);
      }
      final Set<String> openable = await _loadCodexOpenabilityBatch(<String>[
        threadId,
      ]);
      return openable.contains(threadId);
    } on Object {
      return false;
    }
  }

  Future<Set<String>> _loadCodexOpenabilityBatch(
    Iterable<String> threadIds,
  ) async {
    try {
      return await codexConversationOpenabilityBatch!(threadIds);
    } on Object {
      return const <String>{};
    }
  }

  Future<AgentConversationPreflightResult> _loadCodexPreflightBatch(
    Iterable<String> threadIds,
  ) async {
    try {
      return await codexConversationPreflightBatch!(threadIds);
    } on Object {
      return const AgentConversationPreflightResult();
    }
  }

  Future<void> _openUri(Uri uri) async {
    if (!await _uriOpener(uri)) {
      throw StateError('Could not open ${uri.scheme} Agent destination.');
    }
  }

  Future<void> _openCliSession({
    required AgentLauncherSettings settings,
    required String executable,
    required List<String> arguments,
    required String workspacePath,
  }) async {
    if (_operatingSystem == 'macos') {
      final String command = <String>[
        'cd -- ${_shellQuote(workspacePath)}',
        'exec ${_shellQuote(executable)} ${arguments.map(_shellQuote).join(' ')}',
      ].join(' && ');
      final String script = switch (settings.macosTerminal) {
        MacOsTerminalApplication.terminal => _terminalAppleScript(command),
        MacOsTerminalApplication.iTerm => _iTermAppleScript(
          command,
          settings.iTermOpenMode,
        ),
      };
      await _processStarter('osascript', <String>['-e', script]);
      return;
    }
    if (_operatingSystem == 'windows') {
      await _processStarter('wt.exe', <String>[
        '-d',
        workspacePath,
        executable,
        ...arguments,
      ]);
      return;
    }
    await _processStarter(
      executable,
      arguments,
      workingDirectory: workspacePath,
    );
  }

  Future<void> _openDesktopApp(
    String macApplicationName,
    String executable,
    String workspacePath,
  ) async {
    if (_operatingSystem == 'macos') {
      await _processStarter('open', <String>[
        '-a',
        macApplicationName,
        workspacePath,
      ]);
      return;
    }
    if (_operatingSystem == 'windows') {
      await _processStarter(executable, <String>[workspacePath]);
      return;
    }
    await _processStarter(executable, <String>[workspacePath]);
  }
}

String _sessionClientId(AgentClient client) => switch (client) {
  AgentClient.codex => 'codex-desktop',
  AgentClient.kiro => 'kiro-cli',
  _ => client.apiValue,
};

String? _safeConversationId(String? value) {
  final String trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty ||
      trimmed.length > 256 ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]*$').hasMatch(trimmed)) {
    return null;
  }
  return trimmed;
}

String? _safeWorkspacePath(String? value) {
  final String trimmed = value?.trim() ?? '';
  if (trimmed.isEmpty ||
      trimmed.length > 4096 ||
      trimmed.contains('\u0000') ||
      trimmed.contains('\n') ||
      trimmed.contains('\r') ||
      !PathAccess.isAbsolute(trimmed)) {
    return null;
  }
  return trimmed;
}

String _shellQuote(String value) => "'${value.replaceAll("'", "'\"'\"'")}'";

String _appleScriptQuote(String value) => value
    .replaceAll(r'\', r'\\')
    .replaceAll('"', r'\"')
    .replaceAll('\n', r'\n')
    .replaceAll('\r', r'\r');

String _terminalAppleScript(String command) =>
    'tell application "Terminal"\n'
    'activate\n'
    'do script "${_appleScriptQuote(command)}"\n'
    'end tell';

String _iTermAppleScript(String command, ITermOpenMode openMode) {
  final String quoted = _appleScriptQuote(command);
  return switch (openMode) {
    ITermOpenMode.newWindow =>
      'tell application "iTerm"\n'
          'activate\n'
          'create window with default profile command "$quoted"\n'
          'end tell',
    ITermOpenMode.newTab =>
      'tell application "iTerm"\n'
          'activate\n'
          'if (count of windows) = 0 then\n'
          'create window with default profile command "$quoted"\n'
          'else\n'
          'tell current window\n'
          'create tab with default profile command "$quoted"\n'
          'end tell\n'
          'end if\n'
          'end tell',
  };
}

Future<AgentLauncherConfiguration> _loadDefaultLauncherConfiguration() async =>
    const AgentLauncherConfiguration();

abstract final class PathAccess {
  static bool isAbsolute(String value) {
    if (value.startsWith('/')) {
      return true;
    }
    return RegExp(r'^[A-Za-z]:[\\/]').hasMatch(value) ||
        value.startsWith(r'\\');
  }
}

Future<bool> _openExternalUri(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _startDetached(
  String executable,
  List<String> arguments, {
  String? workingDirectory,
}) async {
  await Process.start(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    mode: ProcessStartMode.detached,
  );
}
