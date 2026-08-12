import 'dart:io';

import 'package:dingdong/features/agent_adapters/data/codex_completion_hook_gateway.dart';
import 'package:dingdong/features/library/data/codex_project_hook_inventory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test('hooks/list returns only the requested project inventory', () async {
    final Directory root = Directory.systemTemp.createTempSync(
      'dingdong-hook-inventory-',
    );
    addTearDown(() => root.deleteSync(recursive: true));
    final Directory project = Directory(path.join(root.path, 'project'))
      ..createSync();
    final Directory other = Directory(path.join(root.path, 'other'))
      ..createSync();
    final _Connection connection = _Connection(<String, Object?>{
      'data': <Object?>[
        _cwdEntry(other, command: 'echo unrelated'),
        _cwdEntry(project, command: 'echo project'),
      ],
    });
    final CodexAppServerProjectHookInventory inventory =
        CodexAppServerProjectHookInventory(
          connectionFactory: _ConnectionFactory(connection),
        );

    final hooks = await inventory.list(project);

    expect(hooks, hasLength(1));
    expect(hooks.single.command, 'echo project');
    expect(
      hooks.single.sourcePath,
      path.join(project.path, '.codex', 'hooks.json'),
    );
    expect(connection.method, 'hooks/list');
    expect(connection.params, <String, Object?>{
      'cwds': <Object?>[project.absolute.path],
    });
    expect(connection.closed, isTrue);
  });

  test(
    'hooks/list errors fail closed instead of returning partial data',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-hook-inventory-error-',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      final Map<String, Object?> entry = _cwdEntry(
        project,
        command: 'echo partial',
      )..['errors'] = <Object?>['could not load one Hook source'];
      final _Connection connection = _Connection(<String, Object?>{
        'data': <Object?>[entry],
      });

      await expectLater(
        CodexAppServerProjectHookInventory(
          connectionFactory: _ConnectionFactory(connection),
        ).list(project),
        throwsA(isA<CodexAppServerProtocolException>()),
      );
      expect(connection.closed, isTrue);
    },
  );
}

Map<String, Object?> _cwdEntry(Directory cwd, {required String command}) =>
    <String, Object?>{
      'cwd': cwd.absolute.path,
      'hooks': <Object?>[
        <String, Object?>{
          'eventName': 'stop',
          'handlerType': 'command',
          'command': command,
          'sourcePath': path.join(cwd.path, '.codex', 'hooks.json'),
          'enabled': true,
        },
      ],
      'warnings': <Object?>[],
      'errors': <Object?>[],
    };

final class _ConnectionFactory implements CodexAppServerConnectionFactory {
  const _ConnectionFactory(this.connection);

  final _Connection connection;

  @override
  Future<CodexAppServerConnection> open() async => connection;
}

final class _Connection implements CodexAppServerConnection {
  _Connection(this.response);

  final Map<String, Object?> response;
  String? method;
  Map<String, Object?>? params;
  bool closed = false;

  @override
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?>? params,
  ]) async {
    this.method = method;
    this.params = params;
    return response;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
