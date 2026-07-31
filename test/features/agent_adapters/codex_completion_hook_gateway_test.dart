import 'package:dingdong/features/agent_adapters/data/codex_completion_hook_gateway.dart';
import 'package:dingdong/features/agent_adapters/domain/codex_completion_hook.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const String home = '/Users/tester';
  const String mcp =
      '/Applications/DingDong.app/Contents/MCP/bundle/bin/dingdong_mcp';
  const String command = '"$mcp" --notify-stop --source "Codex"';
  const String key = '$home/.codex/config.toml:stop:0:0';
  const String hash = 'sha256:current-hook';

  test('inspects the exact DingDong Stop Hook through hooks/list', () async {
    final _FakeConnection connection = _FakeConnection(<String, Object?>{
      'data': <Object?>[_hookEntry(command: command, trustStatus: 'untrusted')],
    });
    final CodexAppServerCompletionHookGateway gateway =
        CodexAppServerCompletionHookGateway(
          connectionFactory: _FakeConnectionFactory(connection),
          homeDirectory: home,
          dingDongMcpCommandPath: mcp,
        );

    final CodexCompletionHookStatus status = await gateway.inspect();

    expect(status.review, CodexCompletionHookReview.untrusted);
    expect(status.canRepair, isTrue);
    expect(status.command, command);
    expect(connection.requests.single.method, 'hooks/list');
    expect(connection.requests.single.params, <String, Object?>{
      'cwds': <Object?>[home],
    });
    expect(connection.closed, isTrue);
  });

  test('writes only the current key and hash, then verifies again', () async {
    final _FakeConnection connection = _FakeConnection(
      <String, Object?>{
        'data': <Object?>[
          _hookEntry(command: command, trustStatus: 'untrusted'),
        ],
      },
      afterWriteHooksResponse: <String, Object?>{
        'data': <Object?>[_hookEntry(command: command, trustStatus: 'trusted')],
      },
    );
    final CodexAppServerCompletionHookGateway gateway =
        CodexAppServerCompletionHookGateway(
          connectionFactory: _FakeConnectionFactory(connection),
          homeDirectory: home,
          dingDongMcpCommandPath: mcp,
        );

    final CodexCompletionHookStatus status = await gateway.repair(
      expectedKey: key,
      expectedHash: hash,
    );

    expect(status.isOperational, isTrue);
    expect(
      connection.requests.map((_Request request) => request.method),
      <String>['hooks/list', 'config/batchWrite', 'hooks/list'],
    );
    expect(connection.requests[1].params, <String, Object?>{
      'edits': <Object?>[
        <String, Object?>{
          'keyPath': 'hooks.state',
          'value': <String, Object?>{
            key: <String, Object?>{'enabled': true, 'trusted_hash': hash},
          },
          'mergeStrategy': 'upsert',
        },
      ],
      'reloadUserConfig': true,
    });
  });

  test(
    'refuses a DingDong-looking command that is not an exact match',
    () async {
      final _FakeConnection connection = _FakeConnection(<String, Object?>{
        'data': <Object?>[
          _hookEntry(
            command: '"/tmp/dingdong_mcp" --notify-stop --source "Codex"',
            trustStatus: 'untrusted',
          ),
        ],
      });
      final CodexAppServerCompletionHookGateway gateway =
          CodexAppServerCompletionHookGateway(
            connectionFactory: _FakeConnectionFactory(connection),
            homeDirectory: home,
            dingDongMcpCommandPath: mcp,
          );

      final CodexCompletionHookStatus status = await gateway.repair(
        expectedKey: key,
        expectedHash: hash,
      );

      expect(status.review, CodexCompletionHookReview.mismatched);
      expect(status.canRepair, isFalse);
      expect(
        connection.requests.map((_Request request) => request.method),
        <String>['hooks/list'],
      );
    },
  );

  test('refuses a hash that changed after the user reviewed it', () async {
    final _FakeConnection connection = _FakeConnection(<String, Object?>{
      'data': <Object?>[
        _hookEntry(
          command: command,
          trustStatus: 'untrusted',
          currentHash: 'sha256:new-hook',
        ),
      ],
    });
    final CodexAppServerCompletionHookGateway gateway =
        CodexAppServerCompletionHookGateway(
          connectionFactory: _FakeConnectionFactory(connection),
          homeDirectory: home,
          dingDongMcpCommandPath: mcp,
        );

    final CodexCompletionHookStatus status = await gateway.repair(
      expectedKey: key,
      expectedHash: hash,
    );

    expect(status.review, CodexCompletionHookReview.modified);
    expect(status.currentHash, 'sha256:new-hook');
    expect(
      connection.requests.map((_Request request) => request.method),
      <String>['hooks/list'],
    );
  });

  test('does not repair an unknown future trust state', () async {
    final _FakeConnection connection = _FakeConnection(<String, Object?>{
      'data': <Object?>[
        _hookEntry(command: command, trustStatus: 'future-status'),
      ],
    });
    final CodexAppServerCompletionHookGateway gateway =
        CodexAppServerCompletionHookGateway(
          connectionFactory: _FakeConnectionFactory(connection),
          homeDirectory: home,
          dingDongMcpCommandPath: mcp,
        );

    final CodexCompletionHookStatus status = await gateway.repair(
      expectedKey: key,
      expectedHash: hash,
    );

    expect(status.review, CodexCompletionHookReview.failed);
    expect(status.canRepair, isFalse);
    expect(
      connection.requests.map((_Request request) => request.method),
      <String>['hooks/list'],
    );
  });
}

Map<String, Object?> _hookEntry({
  required String command,
  required String trustStatus,
  String currentHash = 'sha256:current-hook',
}) => <String, Object?>{
  'cwd': '/Users/tester',
  'hooks': <Object?>[
    <String, Object?>{
      'key': '/Users/tester/.codex/config.toml:stop:0:0',
      'eventName': 'stop',
      'handlerType': 'command',
      'isManaged': false,
      'command': command,
      'sourcePath': '/Users/tester/.codex/config.toml',
      'source': 'user',
      'enabled': true,
      'currentHash': currentHash,
      'trustStatus': trustStatus,
    },
  ],
  'warnings': <Object?>[],
  'errors': <Object?>[],
};

final class _FakeConnectionFactory implements CodexAppServerConnectionFactory {
  const _FakeConnectionFactory(this.connection);

  final _FakeConnection connection;

  @override
  Future<CodexAppServerConnection> open() async => connection;
}

final class _FakeConnection implements CodexAppServerConnection {
  _FakeConnection(
    this.initialHooksResponse, {
    Map<String, Object?>? afterWriteHooksResponse,
  }) : afterWriteHooksResponse =
           afterWriteHooksResponse ?? initialHooksResponse;

  final Map<String, Object?> initialHooksResponse;
  final Map<String, Object?> afterWriteHooksResponse;
  final List<_Request> requests = <_Request>[];
  bool wrote = false;
  bool closed = false;

  @override
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?>? params,
  ]) async {
    requests.add(_Request(method, params));
    if (method == 'hooks/list') {
      return wrote ? afterWriteHooksResponse : initialHooksResponse;
    }
    if (method == 'config/batchWrite') {
      wrote = true;
      return const <String, Object?>{};
    }
    throw StateError('Unexpected method: $method');
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

final class _Request {
  const _Request(this.method, this.params);

  final String method;
  final Map<String, Object?>? params;
}
