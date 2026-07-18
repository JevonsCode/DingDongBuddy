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
