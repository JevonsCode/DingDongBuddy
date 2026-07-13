// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

/// Executes one advertised MCP tool against DingDong's local services.
abstract interface class McpToolExecutor {
  Future<Map<String, Object?>> execute(
    String name,
    Map<String, Object?> arguments,
  );
}

/// Line-delimited JSON-RPC server used by the `dingdong-mcp` executable.
final class McpServer {
  McpServer({McpToolExecutor? executor}) : _executor = executor;

  final McpToolExecutor? _executor;

  Future<String?> handleLine(String line) async {
    try {
      final Map<String, Object?> message =
          jsonDecode(line) as Map<String, Object?>;
      if (!message.containsKey('id')) {
        return null;
      }
      final Object? id = message['id'];
      final String? method = message['method'] as String?;
      if (method == 'initialize') {
        return jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          'result': <String, Object?>{
            'protocolVersion': '2025-03-26',
            'capabilities': <String, Object?>{
              'tools': <String, Object?>{'listChanged': false},
            },
            'serverInfo': <String, Object?>{
              'name': 'dingdong',
              'version': '0.7.3',
            },
          },
        });
      }
      if (method == 'tools/list') {
        return jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          'result': <String, Object?>{'tools': tools},
        });
      }
      if (method == 'tools/call') {
        final Map<String, Object?> params =
            message['params'] as Map<String, Object?>? ?? <String, Object?>{};
        final String? name = params['name'] as String?;
        final Map<String, Object?> arguments =
            params['arguments'] as Map<String, Object?>? ?? <String, Object?>{};
        if (name == null || _executor == null) {
          return _toolResult(
            id: id,
            payload: <String, Object?>{
              'status': 'error',
              'message': name == null
                  ? 'Tool name is required'
                  : 'DingDong local service is unavailable',
            },
            isError: true,
          );
        }
        try {
          final Map<String, Object?> payload = await _executor.execute(
            name,
            arguments,
          );
          return _toolResult(id: id, payload: payload, isError: false);
        } on Object catch (error) {
          return _toolResult(
            id: id,
            payload: <String, Object?>{
              'status': 'error',
              'message': error.toString(),
            },
            isError: true,
          );
        }
      }
      return _error(id: id, code: -32601, message: 'Method not found');
    } on Object {
      return _error(id: null, code: -32700, message: 'Parse error');
    }
  }

  static final List<Map<String, Object?>>
  tools = List<Map<String, Object?>>.unmodifiable(<Map<String, Object?>>[
    _tool(
      name: 'dingdong_bridge',
      title: 'DingDong Bridge',
      description:
          'Call this first at the start of each user request. It fetches summary-first DingDong prompt, skill, and MCP routing for the current task.',
      properties: <String, Object?>{
        'task': _stringProperty(),
        'source': _stringProperty(),
        'limit': _integerProperty(maximum: 60),
        'expand': _enumProperty(<String>['none', 'prompts', 'all']),
      },
    ),
    _tool(
      name: 'dingdong_search_assets',
      title: 'Search DingDong Assets',
      description:
          'Search DingDong resources and return bounded metadata plus excerpts. Clipboard content remains hidden by default.',
      properties: <String, Object?>{
        'query': _stringProperty(),
        'type': _enumProperty(<String>[
          'all',
          'prompt',
          'skill',
          'mcp',
          'knowledge',
          'clipboard',
        ]),
        'limit': _integerProperty(maximum: 80),
      },
      required: <String>['query'],
    ),
    _tool(
      name: 'dingdong_get_asset',
      title: 'Get DingDong Asset',
      description:
          'Fetch one DingDong resource by id. Summary mode removes full content from the MCP response.',
      properties: <String, Object?>{
        'id': _stringProperty(),
        'mode': _enumProperty(<String>['summary', 'full']),
        'includeClipboard': _booleanProperty(),
        'includeSensitiveClipboard': _booleanProperty(),
      },
      required: <String>['id'],
    ),
    _tool(
      name: 'dingdong_load_skill',
      title: 'Load DingDong Skill',
      description: 'Fetch full content for one DingDong skill by id.',
      properties: <String, Object?>{'id': _stringProperty()},
      required: <String>['id'],
    ),
    _tool(
      name: 'dingdong_recommend_mcp',
      title: 'Recommend MCP',
      description:
          'Recommend DingDong MCP references for a task without installing them natively.',
      properties: <String, Object?>{
        'task': _stringProperty(),
        'limit': _integerProperty(maximum: 20),
      },
      required: <String>['task'],
    ),
    _tool(
      name: 'dingdong_install_native_mcp',
      title: 'Install Native MCP',
      description:
          'Install a DingDong MCP reference into Codex or Claude native MCP config.',
      properties: <String, Object?>{
        'id': _stringProperty(),
        'target': _enumProperty(<String>['codex', 'claude']),
        'serverName': _stringProperty(),
        'dryRun': _booleanProperty(),
        'confirm': _stringProperty(),
      },
      required: <String>['id', 'target'],
    ),
    _tool(
      name: 'dingdong_notify',
      title: 'Notify DingDong',
      description:
          'Notify DingDong once when the whole user-visible task is complete, blocked, or waiting for attention.',
      properties: <String, Object?>{
        'message': _stringProperty(),
        'source': _stringProperty(),
        'flashCount': _integerProperty(maximum: 20),
      },
      required: <String>['message'],
    ),
  ]);
}

String _toolResult({
  required Object? id,
  required Map<String, Object?> payload,
  required bool isError,
}) {
  return jsonEncode(<String, Object?>{
    'jsonrpc': '2.0',
    'id': id,
    'result': <String, Object?>{
      'content': <Map<String, Object?>>[
        <String, Object?>{'type': 'text', 'text': jsonEncode(payload)},
      ],
      'structuredContent': payload,
      'isError': isError,
    },
  });
}

Map<String, Object?> _tool({
  required String name,
  required String title,
  required String description,
  required Map<String, Object?> properties,
  List<String> required = const <String>[],
}) {
  return <String, Object?>{
    'name': name,
    'title': title,
    'description': description,
    'inputSchema': <String, Object?>{
      'type': 'object',
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
    },
  };
}

Map<String, Object?> _stringProperty() => const <String, Object?>{
  'type': 'string',
};

Map<String, Object?> _booleanProperty() => const <String, Object?>{
  'type': 'boolean',
};

Map<String, Object?> _integerProperty({required int maximum}) {
  return <String, Object?>{'type': 'integer', 'minimum': 0, 'maximum': maximum};
}

Map<String, Object?> _enumProperty(List<String> values) {
  return <String, Object?>{'type': 'string', 'enum': values};
}

String _error({
  required Object? id,
  required int code,
  required String message,
}) {
  return jsonEncode(<String, Object?>{
    'jsonrpc': '2.0',
    'id': id,
    'error': <String, Object?>{'code': code, 'message': message},
  });
}
