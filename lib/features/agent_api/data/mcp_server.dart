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
              'version': '1.2.7',
            },
            'instructions':
                'Call dingdong_bridge with expand="prompts" at the start of each user task. '
                'Every active Prompt returned there is a required instruction: it is included in full and must be applied automatically. '
                'Each successful response is the authoritative Prompt snapshot for the current task and replaces every Prompt set returned for earlier tasks; a Prompt absent from the current snapshot is inactive and must not be applied. '
                'The same response contains the authoritative Skill catalog for the current task and workspace: every valid, enabled, scope-matched Skill as an id, name, and description candidate. A Skill absent from the current catalog is unavailable, disabled, invalid, or out of scope. '
                'If the Bridge call fails, report that DingDong resources could not be loaded and do not reuse an earlier Prompt or Skill set. '
                'A Skill candidate is not an instruction: only when its description matches the task, call dingdong_load_skill with its id or name and current workspace before applying the returned full SKILL.md. '
                'Load only a Skill returned by the current catalog. Read only referenced package files with dingdong_read_skill_file. '
                'MCP entries are tool references, not instructions; call a configured MCP tool only when the task requires it. '
                'After a successful dingdong_bridge response, if conversation.capsule.visible is true and the host supports native capsule rendering, render that capsule once. Otherwise, if conversation.line is non-empty, include that line exactly once in the user-visible response. Show only the provided resource titles; do not include resource content, descriptions, or IDs. '
                'When the user explicitly asks to configure a Skill through DingDong for one project, use dingdong_install_skill, dingdong_upsert_trigger_group, and dingdong_bind_resource_scope with strict project scope. '
                'Use dingdong_notify when the task is blocked or waiting for '
                'the user. A configured completion hook normally handles the '
                'final task-complete alert; if the client has no completion '
                'hook, call dingdong_notify once before the final response.',
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
          'Call this first with expand="prompts" at the start of each user request. Each successful response is the authoritative Prompt snapshot for the current request. Active Prompts are full required instructions. active.skills is the authoritative Skill catalog containing every valid, enabled, scope-matched Skill as id, name, and description only. Load a returned matching Skill with dingdong_load_skill. Every active, scope-matched MCP and Knowledge candidate is returned as summary metadata. MCP entries are tool references, not instructions. If conversation.capsule.visible is true and the host supports native capsule rendering, render that capsule once; otherwise include conversation.line exactly once in the user-visible response. Show only the provided resource titles, not resource content, descriptions, or IDs.',
      properties: <String, Object?>{
        'task': _stringProperty(),
        'source': _stringProperty(
          description:
              'Current Agent source, such as Codex, Claude Code, or Cursor. '
              'Use the same source for subsequent scoped resource reads.',
        ),
        'workspacePath': _stringProperty(
          description:
              'Current project directory. DingDong fills this automatically when omitted.',
        ),
        'repositoryUrl': _stringProperty(
          description:
              'Current Git repository URL. DingDong resolves remote.origin.url when possible.',
        ),
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
          'Fetch one DingDong resource by id. Summary mode removes full content. Full mode re-checks enabled state and all configured context scope rules.',
      properties: <String, Object?>{
        'id': _stringProperty(),
        'mode': _enumProperty(<String>['summary', 'full']),
        'includeClipboard': _booleanProperty(),
        'includeSensitiveClipboard': _booleanProperty(),
        'workspacePath': _stringProperty(
          description:
              'Current project directory. DingDong fills this automatically when omitted.',
        ),
        'repositoryUrl': _stringProperty(
          description:
              'Current Git repository URL. DingDong resolves remote.origin.url when possible.',
        ),
        'source': _stringProperty(
          description:
              'Current Agent source, such as Codex, Claude Code, or Cursor.',
        ),
      },
      required: <String>['id'],
    ),
    _tool(
      name: 'dingdong_load_skill',
      title: 'Load DingDong Skill',
      description:
          'After a current dingdong_bridge Skill candidate description matches the task, fetch its complete SKILL.md by id or name. Enabled state and all configured context scope rules are checked again on every load; preserve the bridge source for this request.',
      properties: <String, Object?>{
        'name': _stringProperty(),
        'id': _stringProperty(),
        'workspacePath': _stringProperty(
          description:
              'Current project directory. DingDong fills this automatically when omitted.',
        ),
        'repositoryUrl': _stringProperty(
          description:
              'Current Git repository URL. DingDong resolves remote.origin.url when possible.',
        ),
        'source': _stringProperty(
          description:
              'Current Agent source, such as Codex, Claude Code, or Cursor.',
        ),
      },
      anyOfRequired: const <List<String>>[
        <String>['name'],
        <String>['id'],
      ],
    ),
    _tool(
      name: 'dingdong_read_skill_file',
      title: 'Read DingDong Skill File',
      description:
          'Read one supporting file referenced by a loaded SKILL.md. The Skill enabled state and all configured context scope rules are re-checked, paths cannot escape the package, and files are bounded to 5 MiB. Preserve the bridge source for this request.',
      properties: <String, Object?>{
        'name': _stringProperty(),
        'id': _stringProperty(),
        'path': _stringProperty(
          description:
              'Forward-slash relative path listed in the loaded Skill package manifest.',
        ),
        'workspacePath': _stringProperty(
          description:
              'Current project directory. DingDong fills this automatically when omitted.',
        ),
        'repositoryUrl': _stringProperty(
          description:
              'Current Git repository URL. DingDong resolves remote.origin.url when possible.',
        ),
        'source': _stringProperty(
          description:
              'Current Agent source, such as Codex, Claude Code, or Cursor.',
        ),
      },
      required: <String>['path'],
      anyOfRequired: const <List<String>>[
        <String>['name'],
        <String>['id'],
      ],
    ),
    _tool(
      name: 'dingdong_recommend_mcp',
      title: 'Recommend MCP',
      description:
          'Recommend MCP references for a task. Recommendations are not instructions; call the configured MCP tools only when needed.',
      properties: <String, Object?>{
        'task': _stringProperty(),
        'limit': _integerProperty(maximum: 20),
      },
      required: <String>['task'],
    ),
    _tool(
      name: 'dingdong_install_skill',
      title: 'Install DingDong Skill',
      description:
          'Install or update one complete Agent Skill package in DingDong from an official GitHub location or an absolute local Skill path. A new resource stays disabled until scope binding succeeds; use its returned id to finish the workflow.',
      properties: <String, Object?>{
        'source': _stringProperty(
          description:
              'GitHub repository, folder, or SKILL.md URL; or an absolute local directory/SKILL.md path.',
        ),
        'title': _stringProperty(),
        'group': _stringProperty(),
        'tags': _stringArrayProperty(),
      },
      required: <String>['source'],
    ),
    _tool(
      name: 'dingdong_upsert_trigger_group',
      title: 'Upsert DingDong Trigger Group',
      description:
          'Create or replace one exact trigger group by name. Use projectPath, repositoryUrl, or source (for example Codex, Claude Code, or Cursor) for non-strict routing. For strict project Skill loading, provide only an absolute local projectPath because rules are OR-ed.',
      properties: <String, Object?>{
        'name': _stringProperty(),
        'projectPath': _stringProperty(),
        'repositoryUrl': _stringProperty(),
        'source': _stringProperty(
          description:
              'Agent source that can trigger the group, such as Codex, Claude Code, or Cursor.',
        ),
      },
      required: <String>['name'],
    ),
    _tool(
      name: 'dingdong_bind_resource_scope',
      title: 'Bind DingDong Resource Scope',
      description:
          'Replace a resource project scope with known trigger-group ids. Skills default to strict project routing and require an exact existing absolute projectPath rule.',
      properties: <String, Object?>{
        'resourceId': _stringProperty(),
        'triggerGroupIds': _stringArrayProperty(),
        'strictProjectSkill': _booleanProperty(),
      },
      required: <String>['resourceId', 'triggerGroupIds'],
    ),
    _tool(
      name: 'dingdong_notify',
      title: 'Notify DingDong',
      description:
          'Notify DingDong when the task is blocked or waiting for attention. '
          'A configured completion hook sends the final task-complete alert. '
          'Do not call this tool before the final response when that hook is '
          'available; use it for completion only if the client has no '
          'completion hook. Use one short outcome sentence for message.',
      properties: <String, Object?>{
        'message': _stringProperty(),
        'source': _stringProperty(),
        'flashCount': _integerProperty(maximum: 20),
        'conversationId': _stringProperty(),
        'workspacePath': _stringProperty(),
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
  List<List<String>> anyOfRequired = const <List<String>>[],
}) {
  return <String, Object?>{
    'name': name,
    'title': title,
    'description': description,
    'inputSchema': <String, Object?>{
      'type': 'object',
      'properties': properties,
      if (required.isNotEmpty) 'required': required,
      if (anyOfRequired.isNotEmpty)
        'anyOf': anyOfRequired
            .map((List<String> fields) => <String, Object?>{'required': fields})
            .toList(growable: false),
    },
  };
}

Map<String, Object?> _stringProperty({String? description}) =>
    <String, Object?>{'type': 'string', 'description': ?description};

Map<String, Object?> _booleanProperty() => const <String, Object?>{
  'type': 'boolean',
};

Map<String, Object?> _stringArrayProperty() => const <String, Object?>{
  'type': 'array',
  'items': <String, Object?>{'type': 'string'},
};

Map<String, Object?> _integerProperty({int minimum = 0, required int maximum}) {
  return <String, Object?>{
    'type': 'integer',
    'minimum': minimum,
    'maximum': maximum,
  };
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
