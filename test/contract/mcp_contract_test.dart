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
      expect(result['instructions'], contains('authoritative Skill catalog'));
      expect(result['instructions'], contains('every valid, enabled'));
      expect(result['instructions'], contains('dingdong_load_skill'));
      expect(result['instructions'], contains('dingdong_read_skill_file'));
      expect(
        result['instructions'],
        contains('MCP entries are tool references'),
      );
      expect(result['instructions'], contains('conversation.capsule.visible'));
      expect(result['instructions'], contains('conversation.line'));
      expect(
        result['instructions'],
        contains('dingdong_render_conversation_footer'),
      );
      expect(
        result['instructions'],
        contains('conversation.presentations.ansi.line'),
      );
      expect(result['instructions'], contains('by capability'));
      expect(result['instructions'], contains('Never paste the MCP App HTML'));
      expect(result['instructions'], contains('confirmedUse is true'));
      expect(result['instructions'], contains('same mergeKey'));
      expect(result['instructions'], contains('must never be displayed'));
      expect(
        result['instructions'],
        contains('does not claim that every instruction was followed'),
      );
      expect(result['instructions'], contains('dingdong_install_skill'));
      expect(result['instructions'], contains('strict project scope'));
      expect(result['instructions'], contains('completion hook'));
      expect(result['instructions'], contains('dingdong_notify'));
      expect(capabilities['resources'], <String, Object?>{
        'subscribe': false,
        'listChanged': false,
      });
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
          'dingdong_render_conversation_footer',
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
        containsAll(<String>[
          'workspacePath',
          'repositoryUrl',
          'conversationId',
        ]),
      );
      expect(bridge['description'], contains('id, name, and description'));
      expect(bridge['description'], contains('authoritative Prompt snapshot'));
      expect(bridge['description'], contains('authoritative Skill catalog'));
      expect(bridge['description'], contains('every valid, enabled'));
      expect(
        bridge['description'],
        contains('Every active, scope-matched MCP'),
      );
      expect(bridge['description'], contains('MCP Apps render tool'));
      expect(bridge['description'], contains('ANSI line'));
      expect(bridge['description'], contains('Markdown conversation.line'));
      expect(bridge['description'], contains('confirmedUse=true'));
      expect(properties, isNot(contains('limit')));

      Map<String, Object?> toolNamed(String name) => tools
          .cast<Map<String, Object?>>()
          .singleWhere((Map<String, Object?> tool) => tool['name'] == name);
      final Map<String, Object?> render = toolNamed(
        'dingdong_render_conversation_footer',
      );
      expect((render['_meta'] as Map<String, Object?>)['ui'], <String, Object?>{
        'resourceUri': 'ui://dingdong/conversation-footer/v1.html',
      });
      expect(
        (render['_meta'] as Map<String, Object?>)['openai/outputTemplate'],
        'ui://dingdong/conversation-footer/v1.html',
      );
      expect(
        (render['inputSchema'] as Map<String, Object?>)['required'],
        <String>['capsule'],
      );
      expect(render['outputSchema'], isA<Map<String, Object?>>());
      final Map<String, Object?> renderCapsuleProperties =
          ((render['inputSchema'] as Map<String, Object?>)['properties']
                  as Map<String, Object?>)['capsule']
              as Map<String, Object?>;
      final Map<String, Object?> renderItemSchema =
          ((renderCapsuleProperties['properties']
                      as Map<String, Object?>)['items']
                  as Map<String, Object?>)['items']
              as Map<String, Object?>;
      expect(
        renderItemSchema['properties'] as Map<String, Object?>,
        contains('mergeKey'),
      );
      final Map<String, Object?> installSchema =
          toolNamed('dingdong_install_skill')['inputSchema']
              as Map<String, Object?>;
      expect(installSchema['required'], <String>['source']);
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

  test('resources expose one self-contained MCP Apps footer', () async {
    final McpServer server = McpServer();

    final Map<String, Object?> listed =
        jsonDecode(
              (await server.handleLine(
                '{"jsonrpc":"2.0","id":3,"method":"resources/list"}',
              ))!,
            )
            as Map<String, Object?>;
    final List<Object?> resources =
        (listed['result'] as Map<String, Object?>)['resources']!
            as List<Object?>;
    expect(resources, hasLength(1));
    expect(
      resources.single,
      containsPair('uri', 'ui://dingdong/conversation-footer/v1.html'),
    );
    expect(
      resources.single,
      containsPair('mimeType', 'text/html;profile=mcp-app'),
    );

    final Map<String, Object?> read =
        jsonDecode(
              (await server.handleLine(
                '{"jsonrpc":"2.0","id":4,"method":"resources/read","params":{"uri":"ui://dingdong/conversation-footer/v1.html"}}',
              ))!,
            )
            as Map<String, Object?>;
    final List<Object?> contents =
        (read['result'] as Map<String, Object?>)['contents']! as List<Object?>;
    final Map<String, Object?> resource =
        contents.single as Map<String, Object?>;
    final String html = resource['text']! as String;
    expect(resource['mimeType'], 'text/html;profile=mcp-app');
    expect(html, contains('ui/notifications/tool-result'));
    expect(html, contains('event.source !== window.parent'));
    expect(html, contains('textContent'));
    expect(html, isNot(contains('innerHTML')));
    expect(html, isNot(contains('<script src=')));
    expect(html, isNot(contains('<link ')));
    expect((resource['_meta'] as Map<String, Object?>)['ui'], <String, Object?>{
      'prefersBorder': false,
    });
  });

  test('render tool normalizes evidence and returns every fallback', () async {
    final McpServer server = McpServer();
    final String request = jsonEncode(<String, Object?>{
      'jsonrpc': '2.0',
      'id': 5,
      'method': 'tools/call',
      'params': <String, Object?>{
        'name': 'dingdong_render_conversation_footer',
        'arguments': <String, Object?>{
          'capsule': <String, Object?>{
            'label': 'DingDong',
            'items': <Map<String, Object?>>[
              <String, Object?>{
                'title': 'Policy <b>',
                'type': 'prompt',
                'usage': 'active',
                'mergeKey': 'prompt:policy',
              },
              <String, Object?>{
                'title': 'Candidate',
                'type': 'skill',
                'usage': 'candidate',
                'confirmedUse': true,
                'marker': '*',
              },
              <String, Object?>{
                'title': 'Loaded',
                'type': 'skill',
                'usage': 'loaded',
                'confirmedUse': true,
                'marker': '*',
                'mergeKey': 'skill:loaded',
              },
              <String, Object?>{
                'title': 'Figma',
                'type': 'mcp',
                'usage': 'available',
              },
            ],
          },
        },
      },
    });

    final Map<String, Object?> response =
        jsonDecode((await server.handleLine(request))!) as Map<String, Object?>;
    final Map<String, Object?> result =
        response['result']! as Map<String, Object?>;
    final Map<String, Object?> structured =
        result['structuredContent']! as Map<String, Object?>;
    final Map<String, Object?> conversation =
        structured['conversation']! as Map<String, Object?>;
    final Map<String, Object?> capsule =
        conversation['capsule']! as Map<String, Object?>;
    final List<Map<String, Object?>> items =
        (capsule['items']! as List<Object?>).cast<Map<String, Object?>>();

    expect(result['isError'], isFalse);
    expect(items[1]['marker'], '');
    expect(items[1]['confirmedUse'], isFalse);
    expect(items[2]['marker'], '*');
    expect(items[2]['confirmedUse'], isTrue);
    expect(items.first['mergeKey'], 'prompt:policy');
    expect(items[2]['mergeKey'], 'skill:loaded');
    expect(conversation['line'], contains('Policy &lt;b&gt;'));
    expect(conversation['line'], isNot(contains('Policy <b>')));
    expect(conversation['line'], isNot(contains('prompt:policy')));
    expect(conversation['line'], contains('🔵 Loaded*'));
    expect(conversation['ansiLine'], contains('\u001B[38;5;178m'));
    expect(
      ((conversation['presentations'] as Map<String, Object?>)['rich']
          as Map<String, Object?>)['resourceUri'],
      'ui://dingdong/conversation-footer/v1.html',
    );
    expect(
      ((result['content'] as List<Object?>).single
          as Map<String, Object?>)['text'],
      conversation['line'],
    );
  });

  test('render tool rejects an empty footer without an executor', () async {
    final McpServer server = McpServer();
    final String output = (await server.handleLine(
      '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"dingdong_render_conversation_footer","arguments":{"capsule":{"items":[]}}}}',
    ))!;
    final Map<String, Object?> response =
        jsonDecode(output) as Map<String, Object?>;
    final Map<String, Object?> result =
        response['result']! as Map<String, Object?>;

    expect(result['isError'], isTrue);
    expect(
      ((result['structuredContent'] as Map<String, Object?>)['message']),
      contains('no displayable items'),
    );
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
