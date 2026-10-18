// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:dingdong/features/agent_api/data/agent_source_identity.dart';
import 'package:dingdong/features/agent_api/domain/agent_bridge_guidance.dart';
import 'package:dingdong/features/jev/data/jev_mcp_tools.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';

/// Executes one advertised MCP tool against DingDong's local services.
abstract interface class McpToolExecutor {
  Future<Map<String, Object?>> execute(
    String name,
    Map<String, Object?> arguments,
  );
}

/// Line-delimited JSON-RPC server used by the `dingdong-mcp` executable.
final class McpServer {
  McpServer({
    McpToolExecutor? executor,
    this.omittedTools = const <String>{},
  }) : _executor = executor;

  final McpToolExecutor? _executor;

  /// Tools left out of `tools/list` because the host does not need them.
  /// Claude Code accounts MCP use from its transcript, so it is never sent
  /// the schema for `dingdong_confirm_mcp_use`.
  final Set<String> omittedTools;

  /// Tools a host can skip, keyed by the Agent source it runs under.
  static Set<String> omittedToolsForSource(String? source) =>
      resolveAgentAdapterId(source ?? '') == 'claude-code'
      ? const <String>{'dingdong_confirm_mcp_use'}
      : const <String>{};

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
              'version': currentAppVersion,
            },
            'instructions': dingDongMcpInstructions,
          },
        });
      }
      if (method == 'tools/list') {
        return jsonEncode(<String, Object?>{
          'jsonrpc': '2.0',
          'id': id,
          'result': <String, Object?>{
            'tools': [
              ...tools.where((tool) => !omittedTools.contains(tool['name'])),
              ...await _jevTools(),
            ],
          },
        });
      }
      if (method == 'tools/call') {
        final Map<String, Object?> params =
            message['params'] as Map<String, Object?>? ?? <String, Object?>{};
        final String? name = params['name'] as String?;
        final Map<String, Object?> arguments =
            params['arguments'] as Map<String, Object?>? ?? <String, Object?>{};
        // Unknown or missing tool names are protocol errors, not tool results.
        if (name == null) {
          return _error(id: id, code: -32602, message: 'Tool name is required');
        }
        if (!<Map<String, Object?>>[
          ...tools,
          ...jevMcpTools,
        ].any((Map<String, Object?> tool) => tool['name'] == name)) {
          return _error(id: id, code: -32602, message: 'Unknown tool: $name');
        }
        if (_executor == null) {
          return _toolResult(
            id: id,
            payload: const <String, Object?>{
              'status': 'error',
              'message': 'DingDong local service is unavailable',
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
              // Dart prefixes these with "Invalid argument (name):" or
              // "Bad state:"; Agents only need the explanation.
              'message': switch (error) {
                ArgumentError(:final String message) => message,
                StateError(:final String message) => message,
                _ => error.toString(),
              },
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

  Future<List<Map<String, Object?>>> _jevTools() async {
    try {
      final executor = _executor;
      if (executor == null) return [];
      // Optional Jev discovery must not block the built-in MCP tools.
      final status = await executor
          .execute('dingdong_jev_status', {})
          .timeout(const Duration(seconds: 3));
      return status['installed'] == true ? jevMcpTools : [];
    } on Object {
      return [];
    }
  }

  static final List<Map<String, Object?>>
  tools = List<Map<String, Object?>>.unmodifiable(<Map<String, Object?>>[
    _tool(
      name: 'dingdong_bridge',
      title: 'DingDong Bridge',
      description:
          'Call first at the start of each user request. The response is the authoritative snapshot and replaces earlier ones. active.prompts are required instructions: apply each in full. active.skills lists id, name and description; load a matching one with dingdong_load_skill. active.mcps are tool references (serverName, title), not instructions. When footer is present, end the final reply with it exactly, applying footerMark replacements from Skill loads and MCP confirmations; never print statusLine. While the previous response is still in context, pass its hash as knownHash to get {unchanged:true} instead of a repeat. expand="all" adds diagnostics.',
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
        'conversationId': _stringProperty(
          description:
              'Stable Agent conversation or session identifier. DingDong fills this from the Agent process when available.',
        ),
        'expand': _enumProperty(<String>['none', 'prompts', 'all']),
        'knownHash': _stringProperty(
          description:
              'hash from the previous bridge response in this conversation.',
        ),
      },
    ),
    _tool(
      name: 'dingdong_search_assets',
      title: 'Search DingDong Assets',
      description:
          'Search DingDong library resources and return bounded metadata plus excerpts. Use type="all" or omit type to search every library resource.',
      properties: <String, Object?>{
        'query': _stringProperty(),
        'type': _enumProperty(<String>[
          'all',
          'prompt',
          'skill',
          'mcp',
          'knowledge',
        ]),
        'limit': _integerProperty(maximum: 80),
      },
      required: <String>['query'],
    ),
    _tool(
      name: 'dingdong_create_resource',
      title: 'Create DingDong Resource',
      description:
          'Create one Prompt or MCP resource after searching for duplicates. New resources default to disabled so scope can be configured before activation. Use dingdong_install_skill for Skills.',
      properties: <String, Object?>{
        'type': _enumProperty(<String>['prompt', 'mcp']),
        'title': _stringProperty(),
        'content': _stringProperty(
          description:
              'Full Prompt text or MCP configuration JSON accepted by DingDong.',
        ),
        'group': _stringProperty(),
        'tags': _stringArrayProperty(),
        'enabled': _booleanProperty(),
        'activation': _enumProperty(<String>['always', 'taskMatch', 'manual']),
        'agentSessionName': _stringProperty(),
        'hideInAgentConversation': _booleanProperty(),
      },
      required: <String>['type', 'title', 'content'],
    ),
    _tool(
      name: 'dingdong_update_resource',
      title: 'Update DingDong Resource',
      description:
          'Update selected fields on an existing DingDong Prompt or MCP after reading it. Preserve omitted fields. Use dedicated Skill delivery and installation tools for Skills.',
      properties: <String, Object?>{
        'resourceId': _stringProperty(),
        'title': _stringProperty(),
        'content': _stringProperty(),
        'group': _stringProperty(),
        'tags': _stringArrayProperty(),
        'enabled': _booleanProperty(),
        'activation': _enumProperty(<String>['always', 'taskMatch', 'manual']),
        'agentSessionName': _stringProperty(),
        'hideInAgentConversation': _booleanProperty(),
      },
      required: <String>['resourceId'],
    ),
    _tool(
      name: 'dingdong_get_asset',
      title: 'Get DingDong Asset',
      description:
          'Fetch one DingDong resource by id. Summary mode removes full content. Full mode re-checks enabled state and all configured context scope rules.',
      properties: <String, Object?>{
        'id': _stringProperty(),
        'mode': _enumProperty(<String>['summary', 'full']),
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
          'After a current dingdong_bridge Skill description matches the task, fetch its complete SKILL.md by id or name and apply it. Enabled state and scope are checked again on every load. Apply a returned footerMark to the footer.',
      properties: <String, Object?>{
        'name': _stringProperty(
          description:
              'Skill name. Provide name or id; id wins when both are set.',
        ),
        'id': _stringProperty(description: 'Skill resource id.'),
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
    ),
    _tool(
      name: 'dingdong_confirm_mcp_use',
      title: 'Confirm DingDong MCP Use',
      description:
          'Call once after a tool from a returned active.mcps server finishes, whether it succeeded or failed. Never call for availability, tool listing or an uncalled tool. DingDong re-checks enabled state, scope and the Codex tool prefix, records the call, and returns footerMark: replace its from token with its to token in the footer.',
      properties: <String, Object?>{
        'id': _stringProperty(
          description: 'Optional resource id; serverName is enough.',
        ),
        'serverName': _stringProperty(
          description: 'serverName from the current active.mcps entry.',
        ),
        'toolName': _stringProperty(
          description:
              'Exact name of the MCP tool that just reached a terminal result.',
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
      required: <String>['serverName', 'toolName'],
    ),
    _tool(
      name: 'dingdong_read_skill_file',
      title: 'Read DingDong Skill File',
      description:
          'Read one supporting file referenced by a loaded SKILL.md. The Skill enabled state and all configured context scope rules are re-checked, paths cannot escape the package, and files are bounded to 5 MiB. Preserve the bridge source for this request.',
      properties: <String, Object?>{
        'name': _stringProperty(
          description:
              'Skill name. Provide name or id; id wins when both are set.',
        ),
        'id': _stringProperty(description: 'Skill resource id.'),
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
          'Install or update one complete Agent Skill package in DingDong from a GitHub location or an absolute local Skill path. A new resource stays disabled; use its returned id with dingdong_set_skill_delivery to choose each Agent delivery plane explicitly.',
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
      name: 'dingdong_set_skill_delivery',
      title: 'Set DingDong Skill Delivery',
      description:
          'Atomically set the Skill master enabled switch and exactly one delivery plane for one Agent. Choose dynamic, nativeUser, or nativeProject. nativeProject requires at least one exact existing project path. The independent Hook switch is allowed only for Codex project-native Impeccable and defaults off.',
      properties: <String, Object?>{
        'resourceId': _stringProperty(),
        'agentId': _stringProperty(
          description:
              'Stable Agent Adapter id such as codex, claude-code, cursor, gemini, or kiro.',
        ),
        'mode': _enumProperty(<String>[
          'dynamic',
          'nativeUser',
          'nativeProject',
        ]),
        'enabled': _booleanProperty(),
        'projectPaths': _stringArrayProperty(
          description:
              'Required and non-empty only for nativeProject; omit for other modes.',
        ),
        'hooksEnabled': _booleanProperty(
          description: 'Only valid with agentId codex and mode nativeProject.',
        ),
      },
      required: <String>['resourceId', 'agentId', 'mode', 'enabled'],
    ),
    _tool(
      name: 'dingdong_get_skill_deployments',
      title: 'Get DingDong Skill Deployments',
      description:
          'Read one Skill resource\'s desired delivery policy, observed native deployments, and active recovery operations. This reports DingDong state; native Agent discovery is automatic and is not represented as a required reload.',
      properties: <String, Object?>{'resourceId': _stringProperty()},
      required: <String>['resourceId'],
    ),
    _tool(
      name: 'dingdong_reconcile_skill',
      title: 'Reconcile DingDong Skill',
      description:
          'Validate one Skill id, request an idempotent full native-resource synchronization, then return that Skill\'s desired, observed, and active-operation snapshot. Unmanaged copies, ownership conflicts, and drift fail closed.',
      properties: <String, Object?>{'resourceId': _stringProperty()},
      required: <String>['resourceId'],
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
        'notificationKind': <String, Object?>{
          'type': 'string',
          'enum': <String>['attention', 'completion'],
          'description':
              'Use attention when the user must respond or take over; use completion only for a confirmed final result.',
        },
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
  Map<String, Object?>? outputSchema,
  Map<String, Object?>? meta,
}) {
  return <String, Object?>{
    'name': name,
    'title': title,
    'description': description,
    'inputSchema': <String, Object?>{
      'type': 'object',
      'properties': properties,
      'additionalProperties': false,
      if (required.isNotEmpty) 'required': required,
    },
    'outputSchema': ?outputSchema,
    '_meta': ?meta,
  };
}

Map<String, Object?> _stringProperty({String? description}) =>
    <String, Object?>{'type': 'string', 'description': ?description};

Map<String, Object?> _booleanProperty({String? description}) =>
    <String, Object?>{'type': 'boolean', 'description': ?description};

Map<String, Object?> _stringArrayProperty({String? description}) =>
    <String, Object?>{
      'type': 'array',
      'items': const <String, Object?>{'type': 'string'},
      'description': ?description,
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
