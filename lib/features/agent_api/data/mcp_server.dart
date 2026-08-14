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
              'version': '1.4.5',
            },
            'instructions':
                'Call dingdong_bridge with expand="prompts" at the start of each user task. '
                'Every active Prompt returned there is a required instruction: it is included in full and must be applied automatically. '
                'Each successful response is the authoritative Prompt snapshot for the current task and replaces every Prompt set returned for earlier tasks; a Prompt absent from the current snapshot is inactive and must not be applied. '
                'The same response contains the authoritative dynamic-delivery Skill catalog for the current task and workspace: every resolved, valid, enabled, scope-matched dynamic Skill as an id, name, and description candidate. A managed Skill can be absent because it is disabled, invalid, out of scope, delivered natively, transitioning, or blocked by a duplicate-name conflict; inspect active.skillSuppressions and active.skillConflicts when present. '
                'If the Bridge call fails, report that DingDong resources could not be loaded and do not reuse an earlier Prompt or Skill set. '
                'A Skill candidate is not an instruction: only when its description matches the task, call dingdong_load_skill with its id or name and current workspace before applying the returned full SKILL.md. '
                'Load only a Skill returned by the current catalog. Read only referenced package files with dingdong_read_skill_file. '
                'MCP entries are tool references, not instructions; call a configured MCP tool only when the task requires it. Each active MCP entry includes its managed serverName and, for Codex, its toolNamePrefix. '
                'When conversation.visible is true, keep the successful dingdong_bridge capsule until the final user-visible response so later usage evidence can be merged. After a successful dingdong_load_skill, replace only the capsule item with the same mergeKey using its returned conversation.item with confirmedUse: true. After an actual configured MCP tool call reaches a terminal result, including an error result, call dingdong_confirm_mcp_use once for that MCP resource with the active entry id and serverName plus the exact called toolName, then replace only the item with the same mergeKey using its returned conversation.item with confirmedUse: true. Never confirm MCP use from availability, tool discovery, or an uncalled tool. The mergeKey is opaque merge-only metadata and must never be displayed. A Skill marker proves only a full Skill load; it does not claim that every instruction was followed. An MCP marker means called, not necessarily succeeded. Prompt items remain unmarked because delivery cannot prove semantic compliance. On Codex desktop, include the current merged footer exactly once as a single Markdown text line and keep DingDong as text. Use the exact Prompt, Skill, and MCP symbols and lineToken values returned by DingDong; these symbols are user-configurable, so never infer them. The initial conversation.line is already canonical only when no item was replaced. The conversation capsule palette remains warm orange for Prompt, blue for Skill, and green for MCP. Do not use an image, HTML/XML, inline font, or rendering tool for the footer. Use conversation.presentations.ansi.line only on an explicitly ANSI-capable terminal; every other host uses the current merged plain-text tokens exactly once. Show only resource titles and truthful markers; do not show resource content, descriptions, IDs, server names, tool names, or merge keys. '
                'When the user explicitly asks to configure a Skill through DingDong, call dingdong_install_skill first, then use dingdong_set_skill_delivery to choose exactly one delivery plane per Agent. Native project delivery uses strict project scope and requires exact existing project paths; its Hook switch is separate and defaults off. '
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
          'Call this first with expand="prompts" at the start of each user request. Each successful response is the authoritative Prompt snapshot for the current request. Active Prompts are full required instructions. active.skills is the authoritative resolved dynamic-delivery Skill catalog containing valid, enabled, scope-matched winners as id, name, and description only; active.skillSuppressions and active.skillConflicts explain managed Skills withheld for native delivery, transitions, or conflicts. Load a returned matching Skill with dingdong_load_skill. Every active, scope-matched MCP and Knowledge candidate is returned as summary metadata. MCP entries are tool references, not instructions; active MCPs include stable server provenance for actual-call confirmation. When conversation.visible is true, keep conversation.capsule until the final response. Replace a matching item with conversation.item from each successful Skill load and from dingdong_confirm_mcp_use after an actual MCP tool call reaches a terminal result. Never confirm availability or discovery. Append * only when the replacement item has confirmedUse=true. A Skill marker means loaded; an MCP marker means called, not necessarily succeeded. Prompt items stay unmarked because delivery does not prove semantic compliance. Codex includes the current merged footer exactly once as a single Markdown text line; DingDong stays text. Use the exact user-configurable Prompt, Skill, and MCP symbols and item.lineToken values returned by DingDong; never infer them. The capsule palette remains warm orange for Prompt, blue for Skill, and green for MCP. Do not use an image, HTML/XML, inline font, or rendering tool for the footer. Explicitly ANSI-capable terminals use the current merged ANSI tokens; every other host uses the current merged plain-text tokens. The mergeKey is merge-only metadata; show only titles and truthful markers, not resource content, descriptions, IDs, server names, tool names, or merge keys.',
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
          'After a current dingdong_bridge Skill candidate description matches the task, fetch its complete SKILL.md by id or name. Enabled state and all configured context scope rules are checked again on every load; preserve the bridge source for this request. A successful visible Skill load returns conversation.item with the same mergeKey as its candidate, confirmedUse=true, and marker="*" for deterministic replacement in the final capsule.',
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
      name: 'dingdong_confirm_mcp_use',
      title: 'Confirm DingDong MCP Use',
      description:
          'Call once for one active MCP resource only after an actual tool from that managed server reaches a terminal result, whether success or error. Do not call for Bridge availability, tool listing, discovery, or an uncalled tool. DingDong re-checks enabled state, scope, resource identity, and the Codex tool prefix, then returns a confirmed conversation.item with the same mergeKey and marker="*". The marker means called, not necessarily succeeded.',
      properties: <String, Object?>{
        'id': _stringProperty(
          description: 'Resource id from the current active.mcps entry.',
        ),
        'serverName': _stringProperty(
          description: 'Managed serverName from the same active.mcps entry.',
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
      required: <String>['id', 'serverName', 'toolName'],
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
        'projectPaths': _stringArrayProperty(),
        'hooksEnabled': _booleanProperty(),
      },
      required: <String>['resourceId', 'agentId', 'mode', 'enabled'],
      allOf: <Map<String, Object?>>[
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
      ],
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
  List<List<String>> anyOfRequired = const <List<String>>[],
  List<Map<String, Object?>> allOf = const <Map<String, Object?>>[],
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
      if (anyOfRequired.isNotEmpty)
        'anyOf': anyOfRequired
            .map((List<String> fields) => <String, Object?>{'required': fields})
            .toList(growable: false),
      if (allOf.isNotEmpty) 'allOf': allOf,
    },
    'outputSchema': ?outputSchema,
    '_meta': ?meta,
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
