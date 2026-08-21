import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
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

    final AgentConversationPreflightResult result = await CodexThreadInspector(
      connectionFactory: factory,
    ).inspectThreadIds(<String>['subagent-1']);

    expect(result.openableConversationIds, isEmpty);
    expect(result.subagentConversationIds, contains('subagent-1'));
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

  test(
    'exact read finds a real-shaped subagent absent from thread list',
    () async {
      final _ScriptedConnectionFactory factory = _ScriptedConnectionFactory(
        <_ExpectedRequest>[
          _ExpectedRequest(
            method: 'thread/list',
            params: const <String, Object?>{'limit': 200},
            response: const <String, Object?>{
              'data': <Object?>[],
              'nextCursor': null,
            },
          ),
          _ExpectedRequest(
            method: 'thread/read',
            params: const <String, Object?>{
              'threadId': 'subagent-real-1',
              'includeTurns': false,
            },
            response: const <String, Object?>{
              'thread': <String, Object?>{
                'id': 'subagent-real-1',
                'parentThreadId': 'root-thread-1',
                'agentNickname': 'Goodall',
                'threadSource': 'subagent',
                'turns': <Object?>[],
              },
            },
          ),
        ],
      );
      final CodexThreadInspector inspector = CodexThreadInspector(
        connectionFactory: factory,
      );

      final AgentConversationPreflightResult historical = await inspector
          .inspectThreadIds(<String>['subagent-real-1']);
      final CodexThreadInspection exact = await inspector.inspectThreadId(
        'subagent-real-1',
      );

      expect(historical.openableConversationIds, isEmpty);
      expect(historical.subagentConversationIds, isEmpty);
      expect(exact.exists, isTrue);
      expect(exact.isSubagent, isTrue);
      expect(exact.isOpenable, isFalse);
      expect(factory.openCount, 2);
      expect(factory.pendingRequestCount, 0);

      expect(
        (await inspector.inspectThreadId('subagent-real-1')).isSubagent,
        isTrue,
      );
      expect(factory.openCount, 2);
    },
  );

  test(
    'exact read accepts direct thread fields and all worker markers',
    () async {
      final List<Map<String, Object?>> markers = <Map<String, Object?>>[
        <String, Object?>{'parentThreadId': 'root-thread'},
        <String, Object?>{'agentRole': 'reviewer'},
        <String, Object?>{'agentNickname': 'Averroes'},
        <String, Object?>{'ephemeral': true},
        <String, Object?>{'threadSource': 'subAgentReview'},
      ];

      for (int index = 0; index < markers.length; index += 1) {
        final String threadId = 'worker-$index';
        final _ScriptedConnectionFactory factory = _ScriptedConnectionFactory(
          <_ExpectedRequest>[
            _ExpectedRequest(
              method: 'thread/read',
              params: <String, Object?>{
                'threadId': threadId,
                'includeTurns': false,
              },
              response: <String, Object?>{'id': threadId, ...markers[index]},
            ),
          ],
        );

        final CodexThreadInspection result = await CodexThreadInspector(
          connectionFactory: factory,
        ).inspectThreadId(threadId);

        expect(result.isSubagent, isTrue, reason: 'marker ${markers[index]}');
        expect(result.isOpenable, isFalse);
      }
    },
  );

  test('exact read caches stable user-thread metadata', () async {
    final _ScriptedConnectionFactory factory = _ScriptedConnectionFactory(
      <_ExpectedRequest>[
        _ExpectedRequest(
          method: 'thread/read',
          params: const <String, Object?>{
            'threadId': 'root-thread-1',
            'includeTurns': false,
          },
          response: const <String, Object?>{
            'thread': <String, Object?>{
              'id': 'root-thread-1',
              'parentThreadId': null,
              'agentRole': null,
              'agentNickname': null,
              'ephemeral': false,
              'threadSource': 'user',
            },
          },
        ),
      ],
    );
    final CodexThreadInspector inspector = CodexThreadInspector(
      connectionFactory: factory,
    );

    final CodexThreadInspection first = await inspector.inspectThreadId(
      'root-thread-1',
    );
    final CodexThreadInspection second = await inspector.inspectThreadId(
      'root-thread-1',
    );

    expect(first.isSubagent, isFalse);
    expect(first.isOpenable, isTrue);
    expect(second.isSubagent, isFalse);
    expect(factory.openCount, 1);
    expect(factory.pendingRequestCount, 0);
  });

  test('exact read recognizes a Codex realtime voice thread preview', () async {
    final _ScriptedConnectionFactory factory = _ScriptedConnectionFactory(
      <_ExpectedRequest>[
        _ExpectedRequest(
          method: 'thread/read',
          params: const <String, Object?>{
            'threadId': 'voice-thread-1',
            'includeTurns': false,
          },
          response: const <String, Object?>{
            'thread': <String, Object?>{
              'id': 'voice-thread-1',
              'preview': '<realtime_delegation>\n  <input>Hello</input>',
              'threadSource': 'user',
            },
          },
        ),
      ],
    );

    final CodexThreadInspection result = await CodexThreadInspector(
      connectionFactory: factory,
    ).inspectThreadId('voice-thread-1');

    expect(result.isRealtimeVoice, isTrue);
    expect(result.isSubagent, isFalse);
    expect(result.isOpenable, isTrue);
  });

  test('exact read does not classify a normal preview as voice', () async {
    final _ScriptedConnectionFactory factory = _ScriptedConnectionFactory(
      <_ExpectedRequest>[
        _ExpectedRequest(
          method: 'thread/read',
          params: const <String, Object?>{
            'threadId': 'typed-thread-1',
            'includeTurns': false,
          },
          response: const <String, Object?>{
            'thread': <String, Object?>{
              'id': 'typed-thread-1',
              'preview': 'Please update the settings screen.',
              'threadSource': 'user',
            },
          },
        ),
      ],
    );

    final CodexThreadInspection result = await CodexThreadInspector(
      connectionFactory: factory,
    ).inspectThreadId('typed-thread-1');

    expect(result.isRealtimeVoice, isFalse);
  });

  test(
    'exact read suppresses a non-persisted ephemeral thread after it stops',
    () async {
      final _ScriptedConnectionFactory factory = _ScriptedConnectionFactory(
        <_ExpectedRequest>[
          _ExpectedRequest(
            method: 'thread/read',
            params: const <String, Object?>{
              'threadId': 'ephemeral-thread-1',
              'includeTurns': false,
            },
            error: const CodexAppServerProtocolException(
              'thread not loaded: ephemeral-thread-1',
            ),
          ),
        ],
      );

      final CodexThreadInspection result = await CodexThreadInspector(
        connectionFactory: factory,
      ).inspectThreadId('ephemeral-thread-1');

      expect(result.exists, isFalse);
      expect(result.isSubagent, isTrue);
      expect(result.isOpenable, isFalse);
      expect(factory.pendingRequestCount, 0);
    },
  );

  test('exact read failure stays fail-open and retryable', () async {
    final _ScriptedConnectionFactory factory = _ScriptedConnectionFactory(
      <_ExpectedRequest>[
        _ExpectedRequest(
          method: 'thread/read',
          params: const <String, Object?>{
            'threadId': 'retry-worker',
            'includeTurns': false,
          },
          error: StateError('app server unavailable'),
        ),
        _ExpectedRequest(
          method: 'thread/read',
          params: const <String, Object?>{
            'threadId': 'retry-worker',
            'includeTurns': false,
          },
          response: const <String, Object?>{
            'thread': <String, Object?>{
              'id': 'retry-worker',
              'threadSource': 'subagent',
            },
          },
        ),
      ],
    );
    final CodexThreadInspector inspector = CodexThreadInspector(
      connectionFactory: factory,
    );

    final CodexThreadInspection unavailable = await inspector.inspectThreadId(
      'retry-worker',
    );
    final CodexThreadInspection recovered = await inspector.inspectThreadId(
      'retry-worker',
    );

    expect(unavailable.exists, isFalse);
    expect(unavailable.isSubagent, isFalse);
    expect(recovered.isSubagent, isTrue);
    expect(factory.openCount, 2);
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

final class _ExpectedRequest {
  const _ExpectedRequest({
    required this.method,
    required this.params,
    this.response = const <String, Object?>{},
    this.error,
  });

  final String method;
  final Map<String, Object?> params;
  final Map<String, Object?> response;
  final Object? error;
}

final class _ScriptedConnectionFactory
    implements CodexAppServerConnectionFactory {
  _ScriptedConnectionFactory(List<_ExpectedRequest> requests)
    : _requests = List<_ExpectedRequest>.of(requests);

  final List<_ExpectedRequest> _requests;
  int openCount = 0;

  int get pendingRequestCount => _requests.length;

  @override
  Future<CodexAppServerConnection> open() async {
    openCount += 1;
    return _ScriptedConnection(_requests);
  }
}

final class _ScriptedConnection implements CodexAppServerConnection {
  _ScriptedConnection(this._requests);

  final List<_ExpectedRequest> _requests;

  @override
  Future<Map<String, Object?>> request(
    String method, [
    Map<String, Object?>? params,
  ]) async {
    final _ExpectedRequest expected = _requests.removeAt(0);
    expect(method, expected.method);
    expect(params, expected.params);
    if (expected.error case final Object error) {
      throw error;
    }
    return expected.response;
  }

  @override
  Future<void> close() async {}
}
