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
      final Map<String, Object?> capabilities =
          result['capabilities']! as Map<String, Object?>;

      expect(result['instructions'], contains('dingdong_bridge'));
      expect(result['instructions'], contains('expand="prompts"'));
      expect(result['instructions'], contains('required instruction'));
      expect(result['instructions'], contains('authoritative Prompt snapshot'));
      expect(result['instructions'], contains('replaces'));
      expect(
        result['instructions'],
        contains('authoritative dynamic-delivery Skill catalog'),
      );
      expect(result['instructions'], contains('active.skillSuppressions'));
      expect(result['instructions'], contains('duplicate-name conflict'));
      expect(result['instructions'], contains('dingdong_load_skill'));
      expect(result['instructions'], contains('dingdong_confirm_mcp_use'));
      expect(result['instructions'], contains('dingdong_read_skill_file'));
      expect(
        result['instructions'],
        contains('MCP entries are tool references'),
      );
      expect(result['instructions'], contains('conversation.visible'));
      expect(result['instructions'], contains('single Markdown text line'));
      expect(result['instructions'], contains('keep DingDong as text'));
      expect(
        result['instructions'],
        contains('symbols and lineToken values returned by DingDong'),
      );
      expect(
        result['instructions'],
        contains('conversation.presentations.ansi.line'),
      );
      expect(result['instructions'], contains('merged plain-text tokens'));
      expect(result['instructions'], contains('confirmedUse'));
      expect(result['instructions'], contains('MCP marker means called'));
      expect(result['instructions'], contains('Prompt items remain unmarked'));
      expect(result['instructions'], contains('same mergeKey'));
      expect(result['instructions'], contains('must never be displayed'));
      expect(
        result['instructions'],
        contains('does not claim that every instruction was followed'),
      );
      expect(result['instructions'], contains('dingdong_install_skill'));
      expect(result['instructions'], contains('dingdong_create_resource'));
      expect(result['instructions'], contains('dingdong_update_resource'));
      expect(result['instructions'], contains('strict project scope'));
      expect(result['instructions'], contains('completion hook'));
      expect(result['instructions'], contains('dingdong_notify'));
      expect(result['instructions'], isNot(contains('iframe')));
      expect(
        result['instructions'],
        isNot(contains('dingdong_render_conversation_footer')),
      );
      expect(capabilities, isNot(contains('resources')));
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
          'dingdong_create_resource',
          'dingdong_update_resource',
          'dingdong_get_asset',
          'dingdong_load_skill',
          'dingdong_confirm_mcp_use',
          'dingdong_read_skill_file',
          'dingdong_recommend_mcp',
          'dingdong_install_skill',
          'dingdong_upsert_trigger_group',
          'dingdong_bind_resource_scope',
          'dingdong_set_skill_delivery',
          'dingdong_get_skill_deployments',
          'dingdong_reconcile_skill',
          'dingdong_notify',
        ],
      );
      expect(
        tools,
        isNot(
          contains(
            predicate<Map<String, Object?>>(
              (Map<String, Object?> tool) =>
                  tool['name'] == 'dingdong_render_conversation_footer',
            ),
          ),
        ),
      );
      final Map<String, Object?> bridge = tools.first as Map<String, Object?>;
      final Map<String, Object?> schema =
          bridge['inputSchema'] as Map<String, Object?>;
      final Map<String, Object?> properties =
          schema['properties'] as Map<String, Object?>;
      expect(
        properties.keys,
        containsAll(<String>[
          'workspacePath',
          'repositoryUrl',
          'conversationId',
        ]),
      );
      expect(bridge['description'], contains('id, name, and description'));
      expect(bridge['description'], contains('authoritative Prompt snapshot'));
      expect(
        bridge['description'],
        contains('authoritative resolved dynamic-delivery Skill catalog'),
      );
      expect(bridge['description'], contains('active.skillSuppressions'));
      expect(
        bridge['description'],
        contains('Every active, scope-matched MCP'),
      );
      expect(bridge['description'], contains('single Markdown text line'));
      expect(bridge['description'], contains('DingDong stays text'));
      expect(bridge['description'], contains('ANSI'));
      expect(bridge['description'], contains('confirmedUse=true'));
      expect(bridge['description'], contains('dingdong_confirm_mcp_use'));
      expect(bridge['description'], contains('MCP marker means called'));
      expect(bridge['description'], isNot(contains('iframe')));
      expect(bridge['description'], isNot(contains('render tool')));
      expect(properties, isNot(contains('limit')));

      Map<String, Object?> toolNamed(String name) => tools
          .cast<Map<String, Object?>>()
          .singleWhere((Map<String, Object?> tool) => tool['name'] == name);
      final Map<String, Object?> installSchema =
          toolNamed('dingdong_install_skill')['inputSchema']
              as Map<String, Object?>;
      expect(installSchema['required'], <String>['source']);
      final Map<String, Object?> createSchema =
          toolNamed('dingdong_create_resource')['inputSchema']
              as Map<String, Object?>;
      expect(createSchema['required'], <String>['type', 'title', 'content']);
      expect(
        ((createSchema['properties'] as Map<String, Object?>)['type']
            as Map<String, Object?>)['enum'],
        <String>['prompt', 'mcp'],
      );
      final Map<String, Object?> updateSchema =
          toolNamed('dingdong_update_resource')['inputSchema']
              as Map<String, Object?>;
      expect(updateSchema['required'], <String>['resourceId']);
      expect(
        toolNamed('dingdong_update_resource')['description'],
        allOf(contains('Prompt or MCP'), contains('Preserve omitted fields')),
      );
      final Map<String, Object?> loadSchema =
          toolNamed('dingdong_load_skill')['inputSchema']
              as Map<String, Object?>;
      expect(loadSchema['required'], isNull);
      expect(
        toolNamed('dingdong_load_skill')['description'],
        contains('marker="*"'),
      );
      expect(
        toolNamed('dingdong_load_skill')['description'],
        contains('same mergeKey'),
      );
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
      final Map<String, Object?> confirmMcpSchema =
          toolNamed('dingdong_confirm_mcp_use')['inputSchema']
              as Map<String, Object?>;
      expect(confirmMcpSchema['required'], <String>[
        'id',
        'serverName',
        'toolName',
      ]);
      expect(
        toolNamed('dingdong_confirm_mcp_use')['description'],
        allOf(
          contains('terminal result'),
          contains('Do not call for Bridge availability'),
          contains('marker="*"'),
          contains('not necessarily succeeded'),
        ),
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
      final Map<String, Object?> deliverySchema =
          toolNamed('dingdong_set_skill_delivery')['inputSchema']
              as Map<String, Object?>;
      expect(deliverySchema['additionalProperties'], isFalse);
      expect(deliverySchema['required'], <String>[
        'resourceId',
        'agentId',
        'mode',
        'enabled',
      ]);
      final Map<String, Object?> deliveryProperties =
          deliverySchema['properties'] as Map<String, Object?>;
      expect(
        (deliveryProperties['mode'] as Map<String, Object?>)['enum'],
        <String>['dynamic', 'nativeUser', 'nativeProject'],
      );
      expect(
        (deliveryProperties['projectPaths'] as Map<String, Object?>)['type'],
        'array',
      );
      expect(deliverySchema['allOf'], <Object?>[
        <String, Object?>{
          'if': <String, Object?>{
            'properties': <String, Object?>{
              'mode': <String, Object?>{'const': 'nativeProject'},
            },
            'required': <String>['mode'],
          },
          'then': <String, Object?>{
            'required': <String>['projectPaths'],
            'properties': <String, Object?>{
              'projectPaths': <String, Object?>{'minItems': 1},
            },
          },
          'else': <String, Object?>{
            'properties': <String, Object?>{
              'projectPaths': <String, Object?>{'maxItems': 0},
              'hooksEnabled': <String, Object?>{'const': false},
            },
          },
        },
        <String, Object?>{
          'if': <String, Object?>{
            'properties': <String, Object?>{
              'hooksEnabled': <String, Object?>{'const': true},
            },
            'required': <String>['hooksEnabled'],
          },
          'then': <String, Object?>{
            'properties': <String, Object?>{
              'agentId': <String, Object?>{'const': 'codex'},
              'mode': <String, Object?>{'const': 'nativeProject'},
            },
          },
        },
      ]);
      expect(
        toolNamed('dingdong_get_skill_deployments')['description'],
        allOf(
          contains('desired delivery policy'),
          contains('observed native deployments'),
          contains('active recovery operations'),
          isNot(contains('reload-required')),
        ),
      );
      expect(
        toolNamed('dingdong_reconcile_skill')['description'],
        allOf(
          contains('full native-resource synchronization'),
          contains('desired, observed, and active-operation snapshot'),
        ),
      );
      for (final String name in <String>[
        'dingdong_get_skill_deployments',
        'dingdong_reconcile_skill',
      ]) {
        expect(
          (toolNamed(name)['inputSchema'] as Map<String, Object?>)['required'],
          <String>['resourceId'],
        );
      }
      for (final Map<String, Object?> tool
          in tools.cast<Map<String, Object?>>()) {
        expect(
          (tool['inputSchema'] as Map<String, Object?>)['additionalProperties'],
          isFalse,
          reason: '${tool['name']} must reject undeclared tool arguments',
        );
      }
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

  test('MCP Apps resources are no longer exposed', () async {
    final McpServer server = McpServer();

    final Map<String, Object?> response =
        jsonDecode(
              (await server.handleLine(
                '{"jsonrpc":"2.0","id":3,"method":"resources/list"}',
              ))!,
            )
            as Map<String, Object?>;
    final Map<String, Object?> error =
        response['error']! as Map<String, Object?>;

    expect(error['code'], -32601);
    expect(error['message'], 'Method not found');
  });

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
