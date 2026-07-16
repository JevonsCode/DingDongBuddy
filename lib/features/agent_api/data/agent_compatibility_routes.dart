import 'dart:convert';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/agent_bridge.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';

/// Discovery and summary routes retained for native API client compatibility.
final class AgentCompatibilityRoutes {
  AgentCompatibilityRoutes({
    required this.resourceStore,
    this.clipboardStore,
    this.triggerGroupStore,
    DateTime Function()? now,
    Uri? baseUri,
  }) : _now = now ?? _utcNow,
       _baseUri = baseUri ?? Uri.parse('http://127.0.0.1:2333');

  final ResourceStore resourceStore;
  final ClipboardStore? clipboardStore;
  final TriggerGroupStore? triggerGroupStore;
  final DateTime Function() _now;
  Uri _baseUri;

  void updateBaseUri(Uri value) {
    _baseUri = value;
  }

  Future<HttpResponseData?> get(String path, Map<String, String> query) async {
    return switch (path) {
      '/agent/templates' => _templates(),
      '/agent/capabilities' => _capabilities(),
      '/agent/manifest' || '/.well-known/dingdong-agent.json' => _manifest(),
      '/system/status' => _systemStatus(),
      '/agent/brief' => _brief(),
      '/agent/recommend' => _recommend(query),
      '/agent/resolve' => _resolve(query),
      '/agent/context' => _context(query),
      '/agent/bridge' =>
        AgentBridge(
          resourceStore,
          triggerGroupStore: triggerGroupStore,
          now: _now,
        ).respond(
          jsonEncode(<String, Object?>{
            'task': query['task'] ?? query['q'] ?? '',
            'source': query['source'] ?? 'Agent',
            'expand': query['expand'] ?? 'none',
            'limit': int.tryParse(query['limit'] ?? '') ?? 12,
            'workspacePath':
                query['workspacePath'] ??
                query['projectPath'] ??
                query['cwd'] ??
                '',
            'repositoryUrl':
                query['repositoryUrl'] ?? query['repository'] ?? '',
          }),
        ),
      '/agent/toolkit' => _toolkit(),
      '/agent/startup' => _startup(query),
      '/agent/prepare' => _prepare(query),
      '/agent/workbench' => _workbench(query),
      '/agent/instructions' => _instructions(query),
      '/events' => const HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': 'ok',
          'service': 'DingDong',
          'events': <Object?>[],
        },
      ),
      _ when path.startsWith('/agent/resource/') => _resource(
        path.substring('/agent/resource/'.length),
        query,
      ),
      _ => null,
    };
  }

  HttpResponseData _templates() => HttpResponseData(
    statusCode: 200,
    json: <String, Object?>{
      'status': 'ok',
      'service': 'DingDong',
      'templates': _templatesData(),
    },
  );

  HttpResponseData _capabilities() => HttpResponseData(
    statusCode: 200,
    json: <String, Object?>{
      'status': 'ok',
      'service': 'DingDong',
      'baseURL': _origin,
      'transport': 'loopback-http',
      'resourceTypes': ResourceType.values
          .map((ResourceType type) => type.name)
          .toList(growable: false),
      'features': _features,
      'limits': const <String, Object?>{
        'clipboardHistory': 5000,
        'clipboardRetentionDays': 730,
        'resourceContentCharacters': 100000,
        'clipboardContentCharacters': 20000,
        'knowledgeIndexFiles': 40,
        'libraryImportItems': 50,
      },
      'endpoints': _endpoints,
    },
  );

  HttpResponseData _manifest() => HttpResponseData(
    statusCode: 200,
    json: <String, Object?>{
      'status': 'ok',
      'schemaVersion': '1.0',
      'service': 'DingDong',
      'description':
          'Local cross-platform AI companion for reminders, clipboard context, and shared agent resources.',
      'baseURL': _origin,
      'transport': <String, Object?>{
        'type': 'loopback-http',
        'host': '127.0.0.1',
      },
      'entrypoints': <String, String>{
        'health': '/health',
        'status': '/system/status',
        'toolkit': '/agent/toolkit',
        'bridge': '/agent/bridge?source=AGENT&task=TASK&limit=20',
        'startup': '/agent/startup?task=TASK&limit=10',
        'workbench': '/agent/workbench?task=TASK&limit=8',
        'instructions': '/agent/instructions?task=TASK&limit=6',
        'ding': '/ding',
      },
      'privacyDefaults': <String, Object?>{
        'clipboardContentIncluded': false,
        'sensitiveClipboardIncluded': false,
        'networkRule': 'DingDong listens on loopback only.',
        'knowledgeIndexing': 'On-demand and bounded.',
      },
      'features': _features,
      'endpointCount': 17,
      'endpoints': _endpoints,
    },
  );

  Future<HttpResponseData> _systemStatus() async {
    final List<Resource> resources = (await resourceStore.load())
        .where((Resource item) => item.type.isLibraryResource)
        .toList(growable: false);
    return _ok(<String, Object?>{
      'generatedAt': _now().toUtc().toIso8601String(),
      'runtime': const <String, Object?>{
        'host': '127.0.0.1',
        'transport': 'loopback-http',
      },
      'counts': <String, Object?>{
        'resources': resources.length,
        'pinnedResources': resources
            .where((Resource item) => item.pinned)
            .length,
        'clipboard': clipboardStore?.list(limit: 5000).length ?? 0,
        'byType': <String, int>{
          for (final ResourceType type in ResourceType.values)
            type.name: resources
                .where((Resource item) => item.type == type)
                .length,
        },
      },
      'performance': const <String, String>{
        'status': 'lightweight',
        'resourceRead': 'single bounded local JSON read',
        'knowledgeIndexing': 'on-demand only',
        'network': 'loopback only',
      },
    });
  }

  Future<HttpResponseData> _brief() async {
    final List<Resource> resources = (await resourceStore.load())
        .where((Resource item) => item.type.isLibraryResource)
        .toList(growable: false);
    return _ok(<String, Object?>{
      'generatedAt': _now().toUtc().toIso8601String(),
      'counts': <String, Object?>{
        'resources': resources.length,
        'pinned': resources.where((Resource item) => item.pinned).length,
      },
      'pinned': resources
          .where((Resource item) => item.pinned)
          .map((Resource item) => item.toSummaryApiJson())
          .toList(growable: false),
    });
  }

  Future<HttpResponseData> _recommend(Map<String, String> query) async {
    final String task = (query['q'] ?? query['task'] ?? '').trim();
    if (task.isEmpty) {
      return _badRequest('q or task is required');
    }
    final ResourceType? type = _optionalType(query['type']);
    if (query['type'] != null && type == null) {
      return _badRequest('Invalid resource type');
    }
    final int limit = (int.tryParse(query['limit'] ?? '') ?? 8).clamp(0, 30);
    final List<Resource> matches = await _matching(task, type: type);
    return _ok(<String, Object?>{
      'task': task,
      'recommendations': matches
          .take(limit)
          .map((Resource item) => item.toSummaryApiJson())
          .toList(growable: false),
    });
  }

  Future<HttpResponseData> _resolve(Map<String, String> query) async {
    final String task = (query['q'] ?? query['task'] ?? '').trim();
    if (task.isEmpty) {
      return _badRequest('q or task is required');
    }
    final List<Resource> matches = await _matching(
      task,
      type: _optionalType(query['type']),
    );
    return matches.isEmpty
        ? const HttpResponseData(
            statusCode: 404,
            json: <String, Object?>{
              'status': 'error',
              'message': 'No matching resource',
            },
          )
        : _ok(<String, Object?>{
            'task': task,
            'item': (await _recordUsage(<Resource>[
              matches.first,
            ])).single.toApiJson(),
          });
  }

  Future<HttpResponseData> _resource(
    String id,
    Map<String, String> query,
  ) async {
    Resource? item = (await resourceStore.load())
        .where(
          (Resource value) => value.id == id && value.type.isLibraryResource,
        )
        .firstOrNull;
    if (item != null && query['mode'] == 'full') {
      item = (await _recordUsage(<Resource>[item])).single;
    }
    return item == null
        ? const HttpResponseData(
            statusCode: 404,
            json: <String, Object?>{
              'status': 'error',
              'message': 'Resource not found',
            },
          )
        : _ok(<String, Object?>{
            'item': query['mode'] == 'full'
                ? item.toApiJson()
                : item.toSummaryApiJson(),
          });
  }

  Future<HttpResponseData> _context(Map<String, String> query) async {
    final String task = (query['q'] ?? query['task'] ?? '').trim();
    final int limit = (int.tryParse(query['limit'] ?? '') ?? 20).clamp(0, 50);
    final List<Resource> resources = task.isEmpty
        ? (await resourceStore.load())
              .where((Resource item) => item.type.isLibraryResource)
              .toList(growable: false)
        : await _matching(task);
    final List<Resource> selected = resources
        .take(limit)
        .toList(growable: false);
    final List<Resource> used = await _recordUsage(selected);
    return _ok(<String, Object?>{
      'task': task,
      'privacy': const <String, Object?>{
        'clipboardIncluded': false,
        'sensitiveClipboardIncluded': false,
      },
      'items': used
          .map((Resource item) => item.toApiJson())
          .toList(growable: false),
    });
  }

  HttpResponseData _toolkit() => _ok(<String, Object?>{
    'instructions': const <String>[
      'Check /health and /agent/manifest before using the local API.',
      'Use /agent/bridge for summary-first prompt, skill, and MCP routing.',
      'Call /ding once only when the whole user-visible task is final.',
    ],
    'commands': _templatesData(),
  });

  Future<List<Resource>> _recordUsage(List<Resource> selected) async {
    if (selected.isEmpty) {
      return selected;
    }
    final Set<String> ids = selected.map((Resource item) => item.id).toSet();
    final DateTime usedAt = _now().toUtc();
    final List<Resource> resources = (await resourceStore.load())
        .map(
          (Resource item) => ids.contains(item.id)
              ? item.copyWith(
                  usageCount: item.usageCount + 1,
                  lastUsedAt: usedAt,
                )
              : item,
        )
        .toList(growable: false);
    await resourceStore.save(resources);
    final Map<String, Resource> byId = <String, Resource>{
      for (final Resource item in resources) item.id: item,
    };
    return selected
        .map((Resource item) => byId[item.id] ?? item)
        .toList(growable: false);
  }

  String get _origin => _baseUri.toString().replaceFirst(RegExp(r'/$'), '');

  List<Map<String, String>> _templatesData() => <Map<String, String>>[
    <String, String>{
      'id': 'ding-complete',
      'title': 'Task Complete',
      'summary': 'Notify DingDong once when the whole task is final.',
      'command': 'curl -X POST $_origin/ding',
    },
    <String, String>{
      'id': 'system-status',
      'title': 'System Status',
      'summary': 'Check lightweight runtime status.',
      'command': 'curl $_origin/system/status',
    },
    <String, String>{
      'id': 'agent-bridge',
      'title': 'Agent Bridge Config',
      'summary': 'Fetch summary-first agent routing.',
      'command': 'curl $_origin/agent/bridge?task=TASK',
    },
  ];

  Future<HttpResponseData> _startup(Map<String, String> query) async =>
      _ok(<String, Object?>{
        'task': query['task'] ?? query['q'] ?? '',
        'brief': (await _brief()).json,
        'context': (await _context(query)).json,
      });

  Future<HttpResponseData> _prepare(Map<String, String> query) async =>
      _ok(<String, Object?>{
        'system': (await _systemStatus()).json,
        'startup': (await _startup(query)).json,
      });

  HttpResponseData _workbench(Map<String, String> query) =>
      _ok(<String, Object?>{
        'task': query['task'] ?? query['q'] ?? '',
        'sessions': const <Object?>[],
        'handoffs': const <Object?>[],
        'memories': const <Object?>[],
        'activeAgents': const <Object?>[],
        'nextCommands': const <String>[
          'POST /agent/presence',
          'GET /agent/context?q=TASK&limit=20',
        ],
      });

  HttpResponseData _instructions(Map<String, String> query) {
    final String task = query['task'] ?? query['q'] ?? 'the user task';
    return _ok(<String, Object?>{
      'task': task,
      'prompt':
          'Use DingDong local context for "$task". Start with GET /agent/bridge, load full resources only when needed, and call /ding once immediately before the final answer.',
    });
  }

  Future<List<Resource>> _matching(String task, {ResourceType? type}) async {
    final Set<String> tokens = task
        .toLowerCase()
        .split(RegExp(r'[^\p{L}\p{N}_-]+', unicode: true))
        .where((String token) => token.length >= 2)
        .toSet();
    final List<Resource> resources = (await resourceStore.load())
        .where((Resource item) => item.type.isLibraryResource && item.enabled)
        .where((Resource item) => type == null || item.type == type)
        .where((Resource item) {
          final String haystack = <String>[
            item.title,
            item.group,
            item.content,
            ...item.tags,
          ].join(' ').toLowerCase();
          return item.pinned || tokens.any(haystack.contains);
        })
        .toList();
    resources.sort((Resource left, Resource right) {
      if (left.pinned != right.pinned) {
        return left.pinned ? -1 : 1;
      }
      return right.updatedAt.compareTo(left.updatedAt);
    });
    return resources;
  }
}

ResourceType? _optionalType(String? value) {
  if (value == null) {
    return null;
  }
  try {
    final ResourceType type = ResourceType.parse(value);
    return type.isLibraryResource ? type : null;
  } on FormatException {
    return null;
  }
}

HttpResponseData _ok(Map<String, Object?> values) => HttpResponseData(
  statusCode: 200,
  json: <String, Object?>{'status': 'ok', 'service': 'DingDong', ...values},
);

HttpResponseData _badRequest(String message) => HttpResponseData(
  statusCode: 400,
  json: <String, Object?>{'status': 'error', 'message': message},
);

const List<String> _features = <String>[
  'systemStatus',
  'agentDiscoveryManifest',
  'resourceLibrary',
  'resourceLibraryExport',
  'clipboardCapture',
  'clipboardMonitoring',
  'clipboardInsights',
  'clipboardDigest',
  'clipboardSnippets',
  'clipboardPromotion',
  'knowledgeIndexing',
  'agentStartupPack',
  'agentMinimalBridge',
  'agentPreparePack',
  'agentWorkbench',
  'agentInstructionPack',
  'agentContextPack',
];

const List<Map<String, String>> _endpoints = <Map<String, String>>[
  <String, String>{'method': 'GET', 'path': '/health'},
  <String, String>{'method': 'GET', 'path': '/system/status'},
  <String, String>{'method': 'POST', 'path': '/ding'},
  <String, String>{'method': 'GET', 'path': '/agent/manifest'},
  <String, String>{'method': 'GET', 'path': '/agent/bridge'},
  <String, String>{'method': 'GET', 'path': '/agent/context'},
  <String, String>{'method': 'GET', 'path': '/library'},
  <String, String>{'method': 'POST', 'path': '/library'},
  <String, String>{'method': 'GET', 'path': '/clipboard/history'},
  <String, String>{'method': 'GET', 'path': '/clipboard/insights'},
  <String, String>{'method': 'GET', 'path': '/clipboard/digest'},
  <String, String>{'method': 'GET', 'path': '/clipboard/snippets'},
  <String, String>{'method': 'POST', 'path': '/clipboard/capture'},
  <String, String>{'method': 'POST', 'path': '/clipboard/promote/{id}'},
  <String, String>{'method': 'GET', 'path': '/knowledge/index'},
  <String, String>{'method': 'POST', 'path': '/ui/show'},
  <String, String>{'method': 'GET', 'path': '/events'},
];

DateTime _utcNow() => DateTime.now().toUtc();
