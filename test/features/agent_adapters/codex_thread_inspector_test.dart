import 'package:dingdong/features/agent_adapters/data/codex_completion_hook_gateway.dart';
import 'package:dingdong/features/agent_adapters/data/codex_thread_inspector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes a Codex subagent by its parent thread', () async {
    final _FakeConnectionFactory factory = _FakeConnectionFactory(
      <Map<String, Object?>>[
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'subagent-1',
              'parentThreadId': 'parent-1',
              'agentRole': null,
              'agentNickname': null,
              'ephemeral': false,
            },
          ],
          'nextCursor': null,
        },
      ],
    );

    expect(
      await CodexThreadInspector(
        connectionFactory: factory,
      ).isOpenable('subagent-1'),
      isFalse,
    );
  });

  test('allows a persisted user thread', () async {
    final _FakeConnectionFactory factory = _FakeConnectionFactory(
      <Map<String, Object?>>[
        <String, Object?>{
          'data': <Object?>[
            <String, Object?>{
              'id': 'user-thread-1',
              'parentThreadId': null,
              'agentRole': null,
              'agentNickname': null,
              'ephemeral': false,
            },
          ],
          'nextCursor': null,
        },
      ],
    );

    expect(
      await CodexThreadInspector(
        connectionFactory: factory,
      ).isOpenable('user-thread-1'),
      isTrue,
    );
  });

  test('blocks a thread that is absent from Codex history', () async {
    final _FakeConnectionFactory factory = _FakeConnectionFactory(
      <Map<String, Object?>>[
        <String, Object?>{'data': const <Object?>[], 'nextCursor': null},
      ],
    );

    expect(
      await CodexThreadInspector(
        connectionFactory: factory,
      ).isOpenable('missing-thread'),
      isFalse,
    );
  });
}

final class _FakeConnectionFactory implements CodexAppServerConnectionFactory {
  _FakeConnectionFactory(this.responses);

  final List<Map<String, Object?>> responses;

  @override
  Future<CodexAppServerConnection> open() async =>
      _FakeConnection(List<Map<String, Object?>>.of(responses));
}

final class _FakeConnection implements CodexAppServerConnection {
  _FakeConnection(this._responses);

  final List<Map<String, Object?>> _responses;

  @override
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?>? params,
  ]) async {
    expect(method, 'thread/list');
    return _responses.removeAt(0);
  }

  @override
  Future<void> close() async {}
}
