import 'dart:io';

import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:url_launcher/url_launcher.dart';

typedef AgentUriOpener = Future<bool> Function(Uri uri);
typedef AgentProcessStarter =
    Future<void> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });

/// Opens only known Agent clients using identifiers captured from their hooks.
final class NativeAgentConversationLauncher
    implements AgentConversationLauncher {
  NativeAgentConversationLauncher({
    String? operatingSystem,
    AgentUriOpener? uriOpener,
    AgentProcessStarter? processStarter,
  }) : _operatingSystem = operatingSystem ?? Platform.operatingSystem,
       _uriOpener = uriOpener ?? _openExternalUri,
       _processStarter = processStarter ?? _startDetached;

  final String _operatingSystem;
  final AgentUriOpener _uriOpener;
  final AgentProcessStarter _processStarter;

  @override
  bool canOpen(AgentConversationTarget target) {
    final String? id = _safeConversationId(target.conversationId);
    final String? workspace = _safeWorkspacePath(target.workspacePath);
    return switch (target.client) {
      AgentClient.codex => id != null,
      AgentClient.claudeCode ||
      AgentClient.geminiCli => id != null && workspace != null,
      AgentClient.cursor =>
        (id != null && id.startsWith('bc-')) || workspace != null,
      AgentClient.kiro => workspace != null,
      AgentClient.unknown => false,
    };
  }

  @override
  Future<void> open(AgentConversationTarget target) async {
    if (!canOpen(target)) {
      throw StateError('This Agent item has no supported destination.');
    }
    final String? id = _safeConversationId(target.conversationId);
    final String? workspace = _safeWorkspacePath(target.workspacePath);
    switch (target.client) {
      case AgentClient.codex:
        await _openUri(
          Uri(scheme: 'codex', host: 'threads', pathSegments: <String>[id!]),
        );
      case AgentClient.claudeCode:
        await _openCliSession(
          executable: 'claude',
          arguments: <String>['--resume', id!],
          workspacePath: workspace!,
        );
      case AgentClient.geminiCli:
        await _openCliSession(
          executable: 'gemini',
          arguments: <String>['--resume', id!],
          workspacePath: workspace!,
        );
      case AgentClient.cursor:
        if (id != null && id.startsWith('bc-')) {
          await _openUri(
            Uri(
              scheme: 'cursor',
              host: 'anysphere.cursor-deeplink',
              path: '/background-agent',
              queryParameters: <String, String>{'bcId': id},
            ),
          );
        } else {
          await _openDesktopApp('Cursor', 'cursor', workspace!);
        }
      case AgentClient.kiro:
        if (id != null && workspace != null) {
          await _openCliSession(
            executable: 'kiro-cli',
            arguments: <String>['chat', '--resume-id', id],
            workspacePath: workspace,
          );
        } else {
          await _openDesktopApp('Kiro', 'kiro', workspace!);
        }
      case AgentClient.unknown:
        throw StateError('Unsupported Agent client.');
    }
  }

  Future<void> _openUri(Uri uri) async {
    if (!await _uriOpener(uri)) {
      throw StateError('Could not open ${uri.scheme} Agent destination.');
    }
  }

  Future<void> _openCliSession({
    required String executable,
    required List<String> arguments,
    required String workspacePath,
  }) async {
    if (_operatingSystem == 'macos') {
      final String command = <String>[
        'cd -- ${_shellQuote(workspacePath)}',
        'exec ${_shellQuote(executable)} ${arguments.map(_shellQuote).join(' ')}',
      ].join(' && ');
      final String script =
          'tell application "Terminal"\n'
          'activate\n'
          'do script "${_appleScriptQuote(command)}"\n'
          'end tell';
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
