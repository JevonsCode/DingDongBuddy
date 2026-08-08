import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_adapters/domain/codex_completion_hook.dart';
import 'package:path/path.dart' as path;

abstract interface class CodexAppServerConnection {
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?>? params,
  ]);

  Future<void> close();
}

abstract interface class CodexAppServerConnectionFactory {
  Future<CodexAppServerConnection> open();
}

final class NativeCodexAppServerConnectionFactory
    implements CodexAppServerConnectionFactory {
  NativeCodexAppServerConnectionFactory({
    required this.homeDirectory,
    this.executableCandidates = const <String>[],
  });

  final String homeDirectory;
  final List<String> executableCandidates;

  @override
  Future<CodexAppServerConnection> open() async {
    final String executable = await _findExecutable();
    return StdioCodexAppServerConnection.start(
      executable,
      workingDirectory: homeDirectory,
    );
  }

  Future<String> _findExecutable() async {
    final List<String> candidates = <String>[
      ...executableCandidates,
      if ((Platform.environment['CODEX_CLI_PATH'] ?? '').trim().isNotEmpty)
        Platform.environment['CODEX_CLI_PATH']!.trim(),
      if (Platform.isMacOS) ...<String>[
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
    ];
    for (final String candidate in candidates) {
      if (path.isAbsolute(candidate) && await File(candidate).exists()) {
        return candidate;
      }
    }

    final ProcessResult located = Platform.isWindows
        ? await Process.run('where.exe', const <String>['codex.exe'])
        : await Process.run('/usr/bin/which', const <String>['codex']);
    if (located.exitCode == 0) {
      for (final String line in const LineSplitter().convert(
        located.stdout.toString(),
      )) {
        final String candidate = line.trim();
        if (path.isAbsolute(candidate) && await File(candidate).exists()) {
          return candidate;
        }
      }
    }
    throw const CodexAppServerUnavailableException(
      'Codex CLI with App Server support was not found.',
    );
  }
}

final class StdioCodexAppServerConnection implements CodexAppServerConnection {
  StdioCodexAppServerConnection._(
    this._process,
    this._lines,
    this._stderrSubscription,
  );

  static const Duration _requestTimeout = Duration(seconds: 10);

  static Future<StdioCodexAppServerConnection> start(
    String executable, {
    required String workingDirectory,
  }) async {
    final Process process;
    try {
      process = await Process.start(executable, const <String>[
        'app-server',
        '--stdio',
      ], workingDirectory: workingDirectory);
    } on ProcessException catch (error) {
      throw CodexAppServerUnavailableException(
        'Codex App Server could not start: ${error.message}',
      );
    }
    final StreamIterator<String> lines = StreamIterator<String>(
      process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
    );
    final StreamSubscription<String> stderrSubscription = process.stderr
        .transform(utf8.decoder)
        .listen((_) {});
    final StdioCodexAppServerConnection connection =
        StdioCodexAppServerConnection._(process, lines, stderrSubscription);
    try {
      await connection.request('initialize', <String, Object?>{
        'clientInfo': <String, Object?>{
          'name': 'dingdong',
          'title': 'DingDong',
          'version': '1.2.8',
        },
        'capabilities': <String, Object?>{
          'experimentalApi': true,
          'requestAttestation': false,
        },
      });
      await connection._notify('initialized', const <String, Object?>{});
      return connection;
    } on Object {
      await connection.close();
      rethrow;
    }
  }

  final Process _process;
  final StreamIterator<String> _lines;
  final StreamSubscription<String> _stderrSubscription;
  int _nextRequestId = 0;
  bool _closed = false;

  @override
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?>? params,
  ]) async {
    if (_closed) {
      throw StateError('Codex App Server connection is closed.');
    }
    final int id = ++_nextRequestId;
    final Map<String, Object?> request = <String, Object?>{
      'method': method,
      'id': id,
    };
    if (params != null) {
      request['params'] = params;
    }
    _process.stdin.writeln(jsonEncode(request));
    await _process.stdin.flush();
    return _readResponse(id).timeout(_requestTimeout);
  }

  Future<void> _notify(String method, Map<String, Object?> params) async {
    _process.stdin.writeln(
      jsonEncode(<String, Object?>{'method': method, 'params': params}),
    );
    await _process.stdin.flush();
  }

  Future<Map<String, Object?>> _readResponse(int id) async {
    while (await _lines.moveNext()) {
      final String line = _lines.current.trim();
      if (line.isEmpty) {
        continue;
      }
      final Object? decoded;
      try {
        decoded = jsonDecode(line);
      } on FormatException {
        continue;
      }
      if (decoded is! Map<Object?, Object?> || decoded['id'] != id) {
        continue;
      }
      final Object? error = decoded['error'];
      if (error is Map<Object?, Object?>) {
        throw CodexAppServerProtocolException(
          (error['message'] as String? ?? 'Codex App Server request failed.')
              .trim(),
        );
      }
      final Object? result = decoded['result'];
      if (result is Map<Object?, Object?>) {
        return Map<String, Object?>.from(result);
      }
      return const <String, Object?>{};
    }
    throw const CodexAppServerProtocolException(
      'Codex App Server closed before returning a response.',
    );
  }

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    await _process.stdin.close();
    try {
      await _process.exitCode.timeout(const Duration(seconds: 1));
    } on TimeoutException {
      _process.kill();
      try {
        await _process.exitCode.timeout(const Duration(seconds: 1));
      } on TimeoutException {
        // The OS will reclaim this diagnostic child with the parent process.
      }
    }
    await _lines.cancel();
    await _stderrSubscription.cancel();
  }
}

final class CodexAppServerCompletionHookGateway
    implements CodexCompletionHookGateway {
  CodexAppServerCompletionHookGateway({
    required this.connectionFactory,
    required this.homeDirectory,
    required this.dingDongMcpCommandPath,
  });

  final CodexAppServerConnectionFactory connectionFactory;
  final String homeDirectory;
  final String dingDongMcpCommandPath;

  String get _expectedCommand =>
      '"${path.normalize(dingDongMcpCommandPath)}" '
      '--notify-stop --source "Codex"';

  String get _expectedSourcePath =>
      path.normalize(path.join(homeDirectory, '.codex', 'config.toml'));

  @override
  Future<CodexCompletionHookStatus> inspect() async {
    CodexAppServerConnection? connection;
    try {
      connection = await connectionFactory.open();
      return await _inspectConnection(connection);
    } on CodexAppServerUnavailableException catch (error) {
      return CodexCompletionHookStatus(
        review: CodexCompletionHookReview.unavailable,
        enabled: false,
        detail: _safeMessage(error.message),
      );
    } on Object catch (error) {
      return CodexCompletionHookStatus(
        review: CodexCompletionHookReview.failed,
        enabled: false,
        detail: _safeMessage(error.toString()),
      );
    } finally {
      await connection?.close();
    }
  }

  @override
  Future<CodexCompletionHookStatus> repair({
    required String expectedKey,
    required String expectedHash,
  }) async {
    CodexAppServerConnection? connection;
    try {
      connection = await connectionFactory.open();
      final CodexCompletionHookStatus before = await _inspectConnection(
        connection,
      );
      if (!before.canRepair) {
        return before;
      }
      if (before.key != expectedKey || before.currentHash != expectedHash) {
        return CodexCompletionHookStatus(
          review: CodexCompletionHookReview.modified,
          enabled: before.enabled,
          key: before.key,
          command: before.command,
          currentHash: before.currentHash,
          detail:
              'The Hook changed after the last review. Check the current hash before trusting it.',
        );
      }
      await connection.request('config/batchWrite', <String, Object?>{
        'edits': <Object?>[
          <String, Object?>{
            'keyPath': 'hooks.state',
            'value': <String, Object?>{
              before.key!: <String, Object?>{
                'enabled': true,
                'trusted_hash': before.currentHash!,
              },
            },
            'mergeStrategy': 'upsert',
          },
        ],
        'reloadUserConfig': true,
      });
      final CodexCompletionHookStatus after = await _inspectConnection(
        connection,
      );
      if (!after.isOperational) {
        return CodexCompletionHookStatus(
          review: CodexCompletionHookReview.failed,
          enabled: after.enabled,
          key: after.key,
          command: after.command,
          currentHash: after.currentHash,
          detail:
              'Codex accepted the write but did not report the Hook as trusted and enabled.',
        );
      }
      return after;
    } on CodexAppServerUnavailableException catch (error) {
      return CodexCompletionHookStatus(
        review: CodexCompletionHookReview.unavailable,
        enabled: false,
        detail: _safeMessage(error.message),
      );
    } on Object catch (error) {
      return CodexCompletionHookStatus(
        review: CodexCompletionHookReview.failed,
        enabled: false,
        detail: _safeMessage(error.toString()),
      );
    } finally {
      await connection?.close();
    }
  }

  Future<CodexCompletionHookStatus> _inspectConnection(
    CodexAppServerConnection connection,
  ) async {
    final Map<String, Object?> response = await connection.request(
      'hooks/list',
      <String, Object?>{
        'cwds': <Object?>[homeDirectory],
      },
    );
    final Object? dataValue = response['data'];
    if (dataValue is! List<Object?> || dataValue.isEmpty) {
      throw const CodexAppServerProtocolException(
        'Codex returned no Hook inventory.',
      );
    }
    final Object? entryValue = dataValue.first;
    if (entryValue is! Map<Object?, Object?>) {
      throw const CodexAppServerProtocolException(
        'Codex returned an invalid Hook inventory.',
      );
    }
    final Object? hooksValue = entryValue['hooks'];
    if (hooksValue is! List<Object?>) {
      throw const CodexAppServerProtocolException(
        'Codex returned an invalid Hook list.',
      );
    }
    final List<Map<String, Object?>> hooks = hooksValue
        .whereType<Map<Object?, Object?>>()
        .map(Map<String, Object?>.from)
        .toList(growable: false);
    final List<Map<String, Object?>> exact = hooks
        .where(_isExactDingDongHook)
        .toList(growable: false);
    if (exact.length > 1) {
      return const CodexCompletionHookStatus(
        review: CodexCompletionHookReview.failed,
        enabled: false,
        detail:
            'Multiple identical DingDong Stop Hooks were found. Remove duplicates before trusting.',
      );
    }
    if (exact.isEmpty) {
      final Map<String, Object?>? mismatched = hooks
          .where(_looksLikeDingDongHook)
          .firstOrNull;
      if (mismatched != null) {
        return CodexCompletionHookStatus(
          review: CodexCompletionHookReview.mismatched,
          enabled: mismatched['enabled'] as bool? ?? false,
          command: mismatched['command'] as String?,
          detail:
              'A DingDong completion Hook exists, but its command does not match this installed app.',
        );
      }
      return const CodexCompletionHookStatus(
        review: CodexCompletionHookReview.missing,
        enabled: false,
        detail: 'The expected DingDong Stop Hook is not configured in Codex.',
      );
    }
    return _statusFrom(exact.single);
  }

  bool _isExactDingDongHook(Map<String, Object?> hook) =>
      _isStopCommand(hook) &&
      hook['source'] == 'user' &&
      path.normalize(hook['sourcePath'] as String? ?? '') ==
          _expectedSourcePath &&
      hook['command'] == _expectedCommand;

  bool _looksLikeDingDongHook(Map<String, Object?> hook) {
    final String command = hook['command'] as String? ?? '';
    return _isStopCommand(hook) &&
        command.contains('dingdong_mcp') &&
        command.contains('--notify-stop');
  }

  bool _isStopCommand(Map<String, Object?> hook) =>
      (hook['eventName'] as String? ?? '').replaceAll('_', '').toLowerCase() ==
          'stop' &&
      hook['handlerType'] == 'command';

  CodexCompletionHookStatus _statusFrom(Map<String, Object?> hook) {
    final bool managed = hook['isManaged'] as bool? ?? false;
    final String trust = hook['trustStatus'] as String? ?? '';
    final CodexCompletionHookReview review = managed || trust == 'managed'
        ? CodexCompletionHookReview.managed
        : switch (trust) {
            'trusted' => CodexCompletionHookReview.trusted,
            'modified' => CodexCompletionHookReview.modified,
            'untrusted' => CodexCompletionHookReview.untrusted,
            _ => CodexCompletionHookReview.failed,
          };
    final String? currentHash = hook['currentHash'] as String?;
    return CodexCompletionHookStatus(
      review: review,
      enabled: hook['enabled'] as bool? ?? false,
      key: hook['key'] as String?,
      command: hook['command'] as String?,
      currentHash: currentHash,
      detail: currentHash == null || currentHash.isEmpty
          ? 'Codex did not return the current Hook hash.'
          : null,
    );
  }
}

final class CodexAppServerUnavailableException implements Exception {
  const CodexAppServerUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class CodexAppServerProtocolException implements Exception {
  const CodexAppServerProtocolException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _safeMessage(String message) {
  final String oneLine = message.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (oneLine.length <= 280) {
    return oneLine;
  }
  return '${oneLine.substring(0, 277)}...';
}
