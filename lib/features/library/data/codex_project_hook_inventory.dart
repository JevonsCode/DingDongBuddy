import 'dart:io';

import 'package:dingdong/features/agent_adapters/data/codex_completion_hook_gateway.dart';
import 'package:dingdong/features/library/domain/project_hook_integration.dart';
import 'package:path/path.dart' as path;

/// Reads Codex's effective additive Hook inventory across user, project,
/// plugin, and managed sources before DingDong writes a project Hook.
final class CodexAppServerProjectHookInventory
    implements CodexProjectHookInventory {
  const CodexAppServerProjectHookInventory({required this.connectionFactory});

  final CodexAppServerConnectionFactory connectionFactory;

  @override
  Future<List<CodexEffectiveHook>> list(Directory projectRoot) async {
    CodexAppServerConnection? connection;
    try {
      connection = await connectionFactory.open();
      final Map<String, Object?> response = await connection.request(
        'hooks/list',
        <String, Object?>{
          'cwds': <Object?>[projectRoot.absolute.path],
        },
      );
      final Object? data = response['data'];
      if (data is! List<Object?> || data.isEmpty) {
        throw const CodexAppServerProtocolException(
          'Codex returned no effective Hook inventory for the project.',
        );
      }
      final String requestedCwd = path.normalize(projectRoot.absolute.path);
      final List<Map<String, Object?>> matching = <Map<String, Object?>>[];
      for (final Object? cwdValue in data) {
        if (cwdValue is! Map) {
          throw const CodexAppServerProtocolException(
            'Codex returned an invalid project Hook inventory.',
          );
        }
        final Map<String, Object?> entry = Map<String, Object?>.from(cwdValue);
        final Object? cwd = entry['cwd'];
        if (cwd is! String || cwd.trim().isEmpty) {
          throw const CodexAppServerProtocolException(
            'Codex returned a Hook inventory without a project path.',
          );
        }
        if (path.equals(path.normalize(path.absolute(cwd)), requestedCwd)) {
          matching.add(entry);
        }
      }
      if (matching.length != 1) {
        throw const CodexAppServerProtocolException(
          'Codex did not return exactly one Hook inventory for the project.',
        );
      }
      final Map<String, Object?> project = matching.single;
      final Object? errors = project['errors'];
      if (errors != null && (errors is! List<Object?> || errors.isNotEmpty)) {
        throw const CodexAppServerProtocolException(
          'Codex reported errors while loading the project Hook inventory.',
        );
      }
      final Object? hooks = project['hooks'];
      if (hooks is! List<Object?>) {
        throw const CodexAppServerProtocolException(
          'Codex returned an invalid project Hook list.',
        );
      }
      final List<CodexEffectiveHook> result = <CodexEffectiveHook>[];
      for (final Object? hookValue in hooks) {
        if (hookValue is! Map) {
          throw const CodexAppServerProtocolException(
            'Codex returned an invalid project Hook entry.',
          );
        }
        final Map<String, Object?> hook = Map<String, Object?>.from(hookValue);
        final Object? eventName = hook['eventName'];
        final Object? handlerType = hook['handlerType'];
        final Object? command = hook['command'];
        final Object? sourcePath = hook['sourcePath'];
        final Object? enabled = hook['enabled'];
        if (eventName is! String ||
            eventName.isEmpty ||
            handlerType is! String ||
            handlerType.isEmpty ||
            sourcePath is! String ||
            sourcePath.isEmpty ||
            enabled is! bool ||
            (_normalizedHandler(handlerType) == 'command' &&
                (command is! String || command.isEmpty))) {
          throw const CodexAppServerProtocolException(
            'Codex returned an incomplete project Hook entry.',
          );
        }
        result.add(
          CodexEffectiveHook(
            eventName: eventName,
            command: command is String ? command : '',
            sourcePath: sourcePath,
            handlerType: handlerType,
            enabled: enabled,
          ),
        );
      }
      return List<CodexEffectiveHook>.unmodifiable(result);
    } finally {
      await connection?.close();
    }
  }
}

String _normalizedHandler(String value) =>
    value.replaceAll('_', '').toLowerCase();
