import 'dart:async';

import 'package:dingdong/features/agent_api/data/agent_bridge.dart';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/http_request_data.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Bridge reports the task start with its real request context', () async {
    final DateTime now = DateTime.utc(2026, 8, 11, 8, 12, 30);
    AgentBridgeTaskStart? observed;
    final AgentRouter router = AgentRouter(
      resourceStore: InMemoryResourceStore(),
      now: () => now,
      onAgentTaskStarted: (AgentBridgeTaskStart start) => observed = start,
    );

    final response = await router.route(
      const HttpRequestData(
        method: 'POST',
        uri: '/agent/bridge',
        body:
            '{"task":"实现手机实时状态","source":"Codex",'
            '"workspacePath":"/workspace/dingdong",'
            '"repositoryUrl":"https://example.test/dingdong.git",'
            '"conversationId":"thread-42","expand":"prompts"}',
      ),
    );

    expect(response.statusCode, 200);
    expect(observed?.task, '实现手机实时状态');
    expect(observed?.source, 'Codex');
    expect(observed?.workspacePath, '/workspace/dingdong');
    expect(observed?.repositoryUrl, 'https://example.test/dingdong.git');
    expect(observed?.conversationId, 'thread-42');
    expect(observed?.startedAt, now);
  });

  test('Bridge waits for asynchronous lifecycle filtering', () async {
    final Completer<void> classification = Completer<void>();
    var recorded = false;
    final AgentRouter router = AgentRouter(
      resourceStore: InMemoryResourceStore(),
      onAgentTaskStarted: (AgentBridgeTaskStart start) async {
        await classification.future;
        recorded = true;
      },
    );

    var responseCompleted = false;
    final Future<void> response = router
        .route(
          const HttpRequestData(
            method: 'POST',
            uri: '/agent/bridge',
            body:
                '{"task":"background work","source":"Codex","conversationId":"thread-42"}',
          ),
        )
        .then<void>((_) {
          responseCompleted = true;
        });
    await Future<void>.delayed(Duration.zero);

    expect(recorded, isFalse);
    expect(responseCompleted, isFalse);

    classification.complete();
    await response;
    expect(recorded, isTrue);
  });
}
