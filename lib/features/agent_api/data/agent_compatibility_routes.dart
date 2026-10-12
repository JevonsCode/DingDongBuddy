import 'dart:convert';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/agent_bridge.dart';
import 'package:dingdong/features/agent_api/data/conversation_token_usage_resolver.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/agent_api/data/skill_delivery_resolver.dart';
import 'package:dingdong/features/agent_api/domain/conversation_footer_symbols.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/trigger_group_repository.dart';

/// Read-only discovery routes for native API clients: capabilities, the
/// discovery manifest, runtime status, and a query-string Bridge shortcut.
final class AgentCompatibilityRoutes {
  AgentCompatibilityRoutes({
    required this.resourceStore,
    this.clipboardStore,
    this.triggerGroupStore,
    this.querySkillDeploymentPresence,
    this.loadConversationFooterSymbols,
    this.loadShowConversationTokenUsage,
    this.loadConversationTokenUsage,
    this.loadJevUsage,
    DateTime Function()? now,
    Uri? baseUri,
  }) : _now = now ?? _utcNow,
       _baseUri = baseUri ?? Uri.parse('http://127.0.0.1:2333');

  final ResourceStore resourceStore;
  final ClipboardStore? clipboardStore;
  final TriggerGroupStore? triggerGroupStore;
  final SkillDeploymentPresenceQuery? querySkillDeploymentPresence;
  final Future<ConversationFooterSymbols> Function()?
  loadConversationFooterSymbols;
  final Future<bool> Function()? loadShowConversationTokenUsage;
  final ConversationTokenUsageLoader? loadConversationTokenUsage;
  final JevUsageLoader? loadJevUsage;
  final DateTime Function() _now;
  Uri _baseUri;

  void updateBaseUri(Uri value) {
    _baseUri = value;
  }

  Future<HttpResponseData?> get(String path, Map<String, String> query) async {
    return switch (path) {
      '/agent/capabilities' => _capabilities(),
      '/agent/manifest' || '/.well-known/dingdong-agent.json' => _manifest(),
      '/system/status' => _systemStatus(),
      '/agent/bridge' =>
        AgentBridge(
          resourceStore,
          triggerGroupStore: triggerGroupStore,
          querySkillDeploymentPresence: querySkillDeploymentPresence,
          loadConversationFooterSymbols: loadConversationFooterSymbols,
          loadShowConversationTokenUsage: loadShowConversationTokenUsage,
          loadConversationTokenUsage: loadConversationTokenUsage,
          loadJevUsage: loadJevUsage,
          now: _now,
        ).respond(
          jsonEncode(<String, Object?>{
            'task': query['task'] ?? query['q'] ?? '',
            'source': query['source'] ?? 'Agent',
            'expand': query['expand'] ?? 'none',
            'workspacePath':
                query['workspacePath'] ??
                query['projectPath'] ??
                query['cwd'] ??
                '',
            'repositoryUrl':
                query['repositoryUrl'] ?? query['repository'] ?? '',
            'conversationId':
                query['conversationId'] ??
                query['sessionId'] ??
                query['threadId'] ??
                '',
          }),
        ),
      _ => null,
    };
  }

  HttpResponseData _capabilities() => HttpResponseData.ok(<String, Object?>{
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
  });

  HttpResponseData _manifest() => HttpResponseData.ok(<String, Object?>{
    'schemaVersion': '1.0',
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
      'capabilities': '/agent/capabilities',
      'bridge': '/agent/bridge?source=AGENT&task=TASK',
      'ding': '/ding',
    },
    'privacyDefaults': <String, Object?>{
      'clipboardContentIncluded': false,
      'sensitiveClipboardIncluded': false,
      'clipboardContentPermission': 'Disabled in DingDong Settings by default.',
      'networkRule':
          'Loopback only; browser cross-origin requests are rejected.',
      'knowledgeIndexing': 'On-demand and bounded.',
    },
    'features': _features,
    'endpointCount': _endpoints.length,
    'endpoints': _endpoints,
  });

  Future<HttpResponseData> _systemStatus() async {
    final List<Resource> resources = (await resourceStore.load())
        .where((Resource item) => item.type.isLibraryResource)
        .toList(growable: false);
    return HttpResponseData.ok(<String, Object?>{
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
        'clipboard': clipboardStore?.historyCount() ?? 0,
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

  String get _origin => _baseUri.toString().replaceFirst(RegExp(r'/$'), '');
}

const List<String> _features = <String>[
  'systemStatus',
  'agentDiscoveryManifest',
  'resourceLibrary',
  'resourceLibraryExport',
  'triggerGroupConfiguration',
  'clipboardCapture',
  'clipboardMonitoring',
  'clipboardInsights',
  'clipboardDigest',
  'clipboardSnippets',
  'clipboardPromotion',
  'knowledgeIndexing',
  'agentMinimalBridge',
  'mcpWriteConfiguration',
  'strictProjectSkillScope',
  'perAgentSkillDelivery',
  'nativeSkillDeployments',
  'skillDeploymentReconciliation',
  'dynamicSkillCatalog',
  'scopedSkillLoading',
  'mcpUseConfirmation',
];

const List<Map<String, String>> _endpoints = <Map<String, String>>[
  <String, String>{'method': 'GET', 'path': '/health'},
  <String, String>{'method': 'GET', 'path': '/system/status'},
  <String, String>{'method': 'POST', 'path': '/ding'},
  <String, String>{'method': 'GET', 'path': '/agent/manifest'},
  <String, String>{'method': 'GET', 'path': '/agent/capabilities'},
  <String, String>{'method': 'POST', 'path': '/agent/bridge'},
  <String, String>{'method': 'GET', 'path': '/agent/skills/load'},
  <String, String>{'method': 'GET', 'path': '/agent/skills/file'},
  <String, String>{'method': 'GET', 'path': '/agent/mcps/confirm-use'},
  <String, String>{'method': 'GET', 'path': '/library'},
  <String, String>{'method': 'POST', 'path': '/library'},
  <String, String>{'method': 'POST', 'path': '/library/skills/install'},
  <String, String>{'method': 'PUT', 'path': '/library/skills/{id}/delivery'},
  <String, String>{'method': 'GET', 'path': '/library/skills/{id}/deployments'},
  <String, String>{'method': 'POST', 'path': '/library/skills/{id}/reconcile'},
  <String, String>{'method': 'GET', 'path': '/library/trigger-groups'},
  <String, String>{'method': 'POST', 'path': '/library/trigger-groups'},
  <String, String>{'method': 'POST', 'path': '/library/trigger-groups/upsert'},
  <String, String>{'method': 'PATCH', 'path': '/library/trigger-groups/{id}'},
  <String, String>{'method': 'DELETE', 'path': '/library/trigger-groups/{id}'},
  <String, String>{'method': 'POST', 'path': '/library/{id}/scope'},
  <String, String>{'method': 'GET', 'path': '/clipboard/history'},
  <String, String>{'method': 'GET', 'path': '/clipboard/insights'},
  <String, String>{'method': 'GET', 'path': '/clipboard/digest'},
  <String, String>{'method': 'GET', 'path': '/clipboard/snippets'},
  <String, String>{'method': 'POST', 'path': '/clipboard/capture'},
  <String, String>{'method': 'POST', 'path': '/clipboard/promote/{id}'},
  <String, String>{'method': 'GET', 'path': '/knowledge/index'},
  <String, String>{'method': 'POST', 'path': '/ui/show'},
];

DateTime _utcNow() => DateTime.now().toUtc();
