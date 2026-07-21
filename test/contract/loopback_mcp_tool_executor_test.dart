import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notify maps to the stable ding loopback route', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_notify', <String, Object?>{
      'message': 'Finished',
      'source': 'Codex',
    });

    expect(transport.method, 'POST');
    expect(transport.path, '/ding');
    expect(transport.body?['message'], 'Finished');
  });

  test(
    'asset search maps bounded arguments to library query parameters',
    () async {
      final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
      final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
        transport,
      );

      await executor.execute('dingdong_search_assets', <String, Object?>{
        'query': 'release',
        'type': 'prompt',
        'limit': 8,
      });

      expect(transport.method, 'GET');
      expect(transport.path, '/library');
      expect(transport.query, <String, String>{
        'query': 'release',
        'type': 'prompt',
        'limit': '8',
      });
    },
  );

  test('bridge adds working directory and repository context', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
      transport,
      currentDirectory: () => '/workspace/dingdong',
      repositoryUrlResolver: (_) async =>
          'https://github.com/example/dingdong.git',
    );

    await executor.execute('dingdong_bridge', <String, Object?>{
      'task': 'Review changes',
    });

    expect(transport.body?['workspacePath'], '/workspace/dingdong');
    expect(
      transport.body?['repositoryUrl'],
      'https://github.com/example/dingdong.git',
    );
  });

  test('Skill installation maps to the dedicated write route', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_install_skill', <String, Object?>{
      'source': 'https://github.com/acme/skills/tree/main/reviewer',
      'title': 'Reviewer',
    });

    expect(transport.method, 'POST');
    expect(transport.path, '/library/skills/install');
    expect(
      transport.body?['source'],
      'https://github.com/acme/skills/tree/main/reviewer',
    );
  });

  test('trigger-group upsert maps to the idempotent write route', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_upsert_trigger_group', <String, Object?>{
      'name': 'Checkout',
      'projectPath': '/work/checkout',
      'repositoryUrl': 'https://github.com/acme/checkout.git',
    });

    expect(transport.method, 'POST');
    expect(transport.path, '/library/trigger-groups/upsert');
    expect(transport.body?['projectPath'], '/work/checkout');
  });

  test('resource scope binding keeps the resource id in the route', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_bind_resource_scope', <String, Object?>{
      'resourceId': 'skill-1',
      'triggerGroupIds': <String>['checkout'],
      'strictProjectSkill': true,
    });

    expect(transport.method, 'POST');
    expect(transport.path, '/library/skill-1/scope');
    expect(transport.body?.containsKey('resourceId'), isFalse);
    expect(transport.body?['triggerGroupIds'], <String>['checkout']);
    expect(transport.body?['strictProjectSkill'], isTrue);
  });
}

final class _RecordingMcpHttpTransport implements McpHttpTransport {
  _RecordingMcpHttpTransport();

  static const Map<String, Object?> response = <String, Object?>{
    'status': 'ok',
  };
  String? method;
  String? path;
  Map<String, String>? query;
  Map<String, Object?>? body;

  @override
  Future<Map<String, Object?>> request({
    required String method,
    required String path,
    Map<String, String> query = const <String, String>{},
    Map<String, Object?>? body,
  }) async {
    this.method = method;
    this.path = path;
    this.query = query;
    this.body = body;
    return response;
  }
}
