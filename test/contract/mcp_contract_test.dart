import 'dart:async';
import 'dart:convert';

import 'package:dingdong/features/agent_api/data/mcp_server.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Jev discovery timeout preserves built-in tools and later requests', () {
    final status = Completer<Map<String, Object?>>();
    final server = McpServer(executor: _WaitingJevExecutor(status));
    fakeAsync((async) {
      String? output;
      server
          .handleLine('{"jsonrpc":"2.0","id":1,"method":"tools/list"}')
          .then((value) => output = value);
      async.flushMicrotasks();
      expect(output, isNull);
      async.elapse(const Duration(seconds: 3));
      async.flushMicrotasks();

      expect(output, isNotNull);
      final response = jsonDecode(output!) as Map<String, Object?>;
      final result = response['result']! as Map<String, Object?>;
      expect(result['tools'], McpServer.tools);
      expect(response['id'], 1);

      String? next;
      server
          .handleLine(
            '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"dingdong_notify","arguments":{}}}',
          )
          .then((value) => next = value);
      async.flushMicrotasks();
      final nextResponse = jsonDecode(next!) as Map<String, Object?>;
      final nextResult = nextResponse['result']! as Map<String, Object?>;
      expect(nextResult['isError'], false);
      status.completeError(StateError('late-status-failure'));
      async.flushMicrotasks();
      expect(result['tools'], McpServer.tools);
    });
  });

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

      final String instructions = result['instructions']! as String;
      // Claude Code truncates server instructions at 2,048 characters; the
      // full protocol lives in the prompt file and tool descriptions.
      expect(instructions.length, lessThan(2048));
      for (final String required in <String>[
        'dingdong_bridge',
        'required instruction',
        'authoritative snapshot',
        'replaces',
        'dingdong_load_skill',
        'dingdong_read_skill_file',
        'dingdong_confirm_mcp_use',
        'tool references',
        'footer',
        'footerMark',
        'Never print `statusLine`',
        'completion hook',
        'dingdong_notify',
      ]) {
        expect(instructions, contains(required));
      }
      expect(result['instructions'], isNot(contains('iframe')));
      expect(
        result['instructions'],
        isNot(contains('dingdong_render_conversation_footer')),
      );
      expect(capabilities, isNot(contains('resources')));
    },
  );

  test('unknown tools are protocol errors; tool errors read cleanly', () async {
    final _RejectingExecutor executor = _RejectingExecutor();
    final McpServer server = McpServer(executor: executor);
    Future<Map<String, Object?>> call(Map<String, Object?> params) async =>
        jsonDecode(
              (await server.handleLine(
                jsonEncode(<String, Object?>{
                  'jsonrpc': '2.0',
                  'id': 7,
                  'method': 'tools/call',
                  'params': params,
                }),
              ))!,
            )
            as Map<String, Object?>;

    final Map<String, Object?> unknown = await call(<String, Object?>{
      'name': 'no_such_tool',
    });
    expect(unknown['error'], <String, Object?>{
      'code': -32602,
      'message': 'Unknown tool: no_such_tool',
    });
    expect((await call(<String, Object?>{}))['error'], <String, Object?>{
      'code': -32602,
      'message': 'Tool name is required',
    });
    expect(executor.calls, 0);

    final Map<String, Object?> failed =
        (await call(<String, Object?>{
              'name': 'dingdong_update_resource',
              'arguments': <String, Object?>{},
            }))['result']!
            as Map<String, Object?>;
    expect(failed['isError'], isTrue);
    expect(
      (failed['structuredContent']! as Map<String, Object?>)['message'],
      'A resource ID is required.',
    );
  });

  test('Claude Code is not sent the MCP confirmation tool', () async {
    Future<List<Object?>> listed(String source) async {
      final McpServer server = McpServer(
        omittedTools: McpServer.omittedToolsForSource(source),
      );
      final Map<String, Object?> response =
          jsonDecode(
                (await server.handleLine(
                  '{"jsonrpc":"2.0","id":1,"method":"tools/list"}',
                ))!,
              )
              as Map<String, Object?>;
      return ((response['result']! as Map<String, Object?>)['tools']!
              as List<Object?>)
          .map((Object? tool) => (tool! as Map<String, Object?>)['name'])
          .toList();
    }

    expect(
      await listed('Claude Code'),
      isNot(contains('dingdong_confirm_mcp_use')),
    );
    expect(await listed('Claude Code'), contains('dingdong_bridge'));
    expect(await listed('Codex'), contains('dingdong_confirm_mcp_use'));
    expect(McpServer.omittedToolsForSource(null), isEmpty);
  });

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
      expect(properties.keys, contains('knownHash'));
      for (final String required in <String>[
        'authoritative snapshot',
        'required instructions',
        'id, name and description',
        'dingdong_load_skill',
        'tool references',
        'footer',
        'footerMark',
        'never print statusLine',
        'knownHash',
        'expand="all"',
      ]) {
        expect(bridge['description'], contains(required));
      }
      // The description is resent with every request; keep it short.
      expect((bridge['description']! as String).length, lessThan(800));
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
      final Map<String, Object?> searchSchema =
          toolNamed('dingdong_search_assets')['inputSchema']
              as Map<String, Object?>;
      final Map<String, Object?> searchProperties =
          searchSchema['properties'] as Map<String, Object?>;
      expect(
        (searchProperties['type'] as Map<String, Object?>)['enum'],
        <String>['all', 'prompt', 'skill', 'mcp', 'knowledge'],
      );
      expect(
        toolNamed('dingdong_search_assets')['description'],
        contains('type="all" or omit type'),
      );
      expect(searchProperties, isNot(contains('clipboard')));
      final Map<String, Object?> loadSchema =
          toolNamed('dingdong_load_skill')['inputSchema']
              as Map<String, Object?>;
      expect(loadSchema['required'], isNull);
      expect(
        toolNamed('dingdong_load_skill')['description'],
        contains('footerMark'),
      );
      // Claude Code silently drops tools whose input schema has top-level
      // combinators, so name-or-id is enforced by the server instead.
      for (final Object? tool in tools) {
        final Map<String, Object?> schema =
            (tool! as Map<String, Object?>)['inputSchema']!
                as Map<String, Object?>;
        expect(
          schema.keys.toSet().intersection(<String>{
            'anyOf',
            'allOf',
            'oneOf',
            'not',
            'if',
          }),
          isEmpty,
          reason: '${(tool as Map<String, Object?>)['name']}',
        );
      }
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
      expect(confirmMcpSchema['required'], <String>['serverName', 'toolName']);
      expect(
        (confirmMcpSchema['properties'] as Map<String, Object?>).keys,
        contains('id'),
      );
      expect(
        toolNamed('dingdong_confirm_mcp_use')['description'],
        allOf(
          contains('succeeded or failed'),
          contains('Never call for availability'),
          contains('footerMark'),
        ),
      );
      expect(
        ((toolNamed('dingdong_get_asset')['inputSchema']
                    as Map<String, Object?>)['properties']
                as Map<String, Object?>)
            .keys,
        containsAll(<String>['workspacePath', 'repositoryUrl', 'source']),
      );
      final Map<String, Object?> getProperties =
          (toolNamed('dingdong_get_asset')['inputSchema']
                  as Map<String, Object?>)['properties']
              as Map<String, Object?>;
      expect(getProperties, isNot(contains('includeClipboard')));
      expect(getProperties, isNot(contains('includeSensitiveClipboard')));
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

final class _WaitingJevExecutor implements McpToolExecutor {
  _WaitingJevExecutor(this.status);
  final Completer<Map<String, Object?>> status;

  @override
  Future<Map<String, Object?>> execute(
    String name,
    Map<String, Object?> arguments,
  ) {
    if (name == 'dingdong_jev_status') return status.future;
    return Future.value(<String, Object?>{'status': 'triggered'});
  }
}

final class _RejectingExecutor implements McpToolExecutor {
  int calls = 0;

  @override
  Future<Map<String, Object?>> execute(
    String name,
    Map<String, Object?> arguments,
  ) async {
    calls += 1;
    if (name == 'dingdong_jev_status') return <String, Object?>{};
    throw ArgumentError.value('', 'resourceId', 'A resource ID is required.');
  }
}
