import 'dart:convert';

import 'package:dingdong/features/agent_api/data/mcp_server.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'initialize advertises durable DingDong workflow instructions',
    () async {
      final McpServer server = McpServer();

      final String output = (await server.handleLine(
        '{"jsonrpc":"2.0","id":0,"method":"initialize"}',
      ))!;
      final Map<String, Object?> response =
          jsonDecode(output) as Map<String, Object?>;
      final Map<String, Object?> result =
          response['result']! as Map<String, Object?>;

      expect(result['instructions'], contains('dingdong_bridge'));
      expect(result['instructions'], contains('expand="prompts"'));
      expect(result['instructions'], contains('required instruction'));
      expect(result['instructions'], contains('Skill entries are candidates'));
      expect(
        result['instructions'],
        contains('MCP entries are tool references'),
      );
      expect(result['instructions'], contains('completion hook'));
      expect(result['instructions'], contains('dingdong_notify'));
    },
  );

  test(
    'tools/list exposes the complete DingDong bridge tool contract',
    () async {
      final McpServer server = McpServer();

      final String output = (await server.handleLine(
        '{"jsonrpc":"2.0","id":1,"method":"tools/list"}',
      ))!;
      final Map<String, Object?> response =
          jsonDecode(output) as Map<String, Object?>;
      final Map<String, Object?> result =
          response['result']! as Map<String, Object?>;
      final List<Object?> tools = result['tools']! as List<Object?>;

      expect(
        tools.map((Object? tool) => (tool as Map<String, Object?>)['name']),
        <String>[
          'dingdong_bridge',
          'dingdong_search_assets',
          'dingdong_get_asset',
          'dingdong_load_skill',
          'dingdong_recommend_mcp',
          'dingdong_notify',
        ],
      );
      final Map<String, Object?> bridge = tools.first as Map<String, Object?>;
      final Map<String, Object?> schema =
          bridge['inputSchema'] as Map<String, Object?>;
      final Map<String, Object?> properties =
          schema['properties'] as Map<String, Object?>;
      expect(
        properties.keys,
        containsAll(<String>['workspacePath', 'repositoryUrl']),
      );
      expect(
        bridge['description'],
        contains('Skill and MCP entries are summary-only candidates'),
      );
    },
  );

  test('tools/call executes a named tool and returns MCP text content', () async {
    final _FakeMcpToolExecutor executor = _FakeMcpToolExecutor();
    final McpServer server = McpServer(executor: executor);

    final String output = (await server.handleLine(
      '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"dingdong_notify","arguments":{"message":"Done"}}}',
    ))!;
    final Map<String, Object?> response =
        jsonDecode(output) as Map<String, Object?>;
    final Map<String, Object?> result =
        response['result']! as Map<String, Object?>;
    final List<Object?> content = result['content']! as List<Object?>;

    expect(executor.name, 'dingdong_notify');
    expect(executor.arguments, <String, Object?>{'message': 'Done'});
    expect((content.single as Map<String, Object?>)['type'], 'text');
    expect(result['isError'], isFalse);
  });
}

final class _FakeMcpToolExecutor implements McpToolExecutor {
  String? name;
  Map<String, Object?>? arguments;

  @override
  Future<Map<String, Object?>> execute(
    String name,
    Map<String, Object?> arguments,
  ) async {
    this.name = name;
    this.arguments = arguments;
    return <String, Object?>{'status': 'triggered'};
  }
}
