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
      expect(result['instructions'], contains('authoritative Prompt snapshot'));
      expect(result['instructions'], contains('replaces'));
      expect(result['instructions'], contains('authoritative Skill catalog'));
      expect(result['instructions'], contains('every valid, enabled'));
      expect(result['instructions'], contains('dingdong_load_skill'));
      expect(result['instructions'], contains('dingdong_read_skill_file'));
      expect(
        result['instructions'],
        contains('MCP entries are tool references'),
      );
      expect(result['instructions'], contains('dingdong_install_skill'));
      expect(result['instructions'], contains('strict project scope'));
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
          'dingdong_read_skill_file',
          'dingdong_recommend_mcp',
          'dingdong_install_skill',
          'dingdong_upsert_trigger_group',
          'dingdong_bind_resource_scope',
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
      expect(bridge['description'], contains('id, name, and description'));
      expect(bridge['description'], contains('authoritative Prompt snapshot'));
      expect(bridge['description'], contains('authoritative Skill catalog'));
      expect(bridge['description'], contains('every valid, enabled'));
      expect(
        bridge['description'],
        contains('Every active, scope-matched MCP'),
      );
      expect(properties, isNot(contains('limit')));

      Map<String, Object?> toolNamed(String name) => tools
          .cast<Map<String, Object?>>()
          .singleWhere((Map<String, Object?> tool) => tool['name'] == name);
      final Map<String, Object?> installSchema =
          toolNamed('dingdong_install_skill')['inputSchema']
              as Map<String, Object?>;
      expect(installSchema['required'], <String>['source']);
      final Map<String, Object?> loadSchema =
          toolNamed('dingdong_load_skill')['inputSchema']
              as Map<String, Object?>;
      expect(loadSchema['required'], isNull);
      expect(loadSchema['anyOf'], <Map<String, Object?>>[
        <String, Object?>{
          'required': <String>['name'],
        },
        <String, Object?>{
          'required': <String>['id'],
        },
      ]);
      expect(
        (loadSchema['properties'] as Map<String, Object?>).keys,
        containsAll(<String>[
          'id',
          'name',
          'workspacePath',
          'repositoryUrl',
          'source',
        ]),
      );
      expect(
        (toolNamed('dingdong_read_skill_file')['inputSchema']
            as Map<String, Object?>)['required'],
        <String>['path'],
      );
      expect(
        ((toolNamed('dingdong_get_asset')['inputSchema']
                    as Map<String, Object?>)['properties']
                as Map<String, Object?>)
            .keys,
        containsAll(<String>['workspacePath', 'repositoryUrl', 'source']),
      );
      final Map<String, Object?> bindProperties =
          (toolNamed('dingdong_bind_resource_scope')['inputSchema']
                  as Map<String, Object?>)['properties']
              as Map<String, Object?>;
      expect(
        (bindProperties['triggerGroupIds'] as Map<String, Object?>)['type'],
        'array',
      );
      final Map<String, Object?> notifyProperties =
          (toolNamed('dingdong_notify')['inputSchema']
                  as Map<String, Object?>)['properties']
              as Map<String, Object?>;
      expect(
        toolNamed('dingdong_notify')['description'],
        allOf(contains('configured completion hook'), contains('Do not call')),
      );
      expect(
        notifyProperties.keys,
        containsAll(<String>['conversationId', 'workspacePath']),
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
