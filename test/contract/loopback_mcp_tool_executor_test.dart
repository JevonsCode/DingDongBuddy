import 'dart:io';

import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';
import 'package:dingdong/features/agent_api/data/native_mcp_installer.dart';
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

  test('native MCP installation defaults to a no-write preview', () async {
    final Directory directory = Directory.systemTemp.createTempSync(
      'dingdong-loopback-installer-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport(
      response: <String, Object?>{
        'status': 'ok',
        'item': <String, Object?>{
          'id': 'mcp-1',
          'type': 'mcp',
          'title': 'Release MCP',
          'content': '{"command":"npx","args":["release-mcp"]}',
        },
      },
    );
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
      transport,
      installer: NativeMcpInstaller(
        codexConfigFile: File('${directory.path}/config.toml'),
        claudeConfigFile: File('${directory.path}/claude.json'),
      ),
    );

    final result = await executor.execute(
      'dingdong_install_native_mcp',
      <String, Object?>{'id': 'mcp-1', 'target': 'codex'},
    );

    expect(result['status'], 'dry_run');
    expect(File('${directory.path}/config.toml').existsSync(), isFalse);
  });
}

final class _RecordingMcpHttpTransport implements McpHttpTransport {
  _RecordingMcpHttpTransport({
    this.response = const <String, Object?>{'status': 'ok'},
  });

  final Map<String, Object?> response;
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
