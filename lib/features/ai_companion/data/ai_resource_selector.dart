import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:dingdong/features/agent_api/domain/bridge_resource_selection.dart';

import '../domain/ai_companion_privacy.dart';
import '../domain/ai_companion_usage.dart';
import 'ai_companion_client.dart';
import 'ai_companion_store.dart';

/// Optional read-only model routing. Stores bounded decision hashes, never task
/// bodies. Null failures are cached too, to avoid retry costs on every Bridge.
final class AiResourceSelector {
  AiResourceSelector({
    required this.store,
    AiCompanionClient? client,
    this.onUsage,
    this.capacity = 64,
  }) : _client = client ?? AiCompanionClient();
  final AiCompanionStore store;
  final AiCompanionClient _client;
  final AiCompanionUsageSink? onUsage;
  final int capacity;
  final _cache = <String, Future<Set<String>?>>{};
  String? _configuration;

  Future<String> _digest(Object value) async => (await Sha256().hash(
    utf8.encode(jsonEncode(value)),
  )).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  Future<Set<String>?> select(BridgeResourceSelectionRequest request) async {
    try {
      final settings = await store.loadSettings();
      if (!settings.autoResourceSelection) {
        _cache.clear();
        _configuration = null;
        _client.dispose();
        return null;
      }
      final key = await store.readApiKey();
      final configuration = await _digest([settings.toJson(), key]);
      if (configuration != _configuration) {
        _cache.clear();
        _client.dispose();
        _configuration = configuration;
      }
      if (request.task.trim().isEmpty ||
          request.task.length > 4000 ||
          request.taskContext.length > 4000 ||
          request.candidates.length > 64) {
        return null;
      }
      if (request.candidates.isEmpty) return <String>{};
      final candidates = request.candidates;
      final input = <String, Object>{
        'task': request.task,
        'taskContext': request.taskContext,
        'resources': [
          for (var i = 0; i < candidates.length; i++)
            {
              'id': 'r$i',
              'type': candidates[i].type,
              'title': candidates[i].title.length > 120
                  ? candidates[i].title.substring(0, 120)
                  : candidates[i].title,
              'description': candidates[i].description.length > 500
                  ? candidates[i].description.substring(0, 500)
                  : candidates[i].description,
            },
        ],
      };
      final routingText = [
        request.task,
        request.taskContext,
        for (final item in input['resources']! as List<Map<String, String>>)
          '${item['title']}\n${item['description']}',
      ].join('\n');
      if (!const AiCompanionPrivacy().isSafeRoutingInput(
        routingText,
        providerKey: key,
      )) {
        return null;
      }
      final cacheKey = await _digest([
        configuration,
        request.workspacePath,
        request.repositoryUrl,
        request.source,
        request.conversationId,
        input,
        [
          for (final candidate in candidates) [candidate.id, candidate.version],
        ],
      ]);
      final cached = _cache.remove(cacheKey);
      if (cached != null) {
        _cache[cacheKey] = cached;
        return await cached;
      }
      final result = (() async {
        try {
          final aliases = await _client.selectResources(
            settings,
            key,
            input,
            onUsage: onUsage,
          );
          final current = await store.loadSettings();
          final currentKey = await store.readApiKey();
          if (!current.autoResourceSelection ||
              configuration != await _digest([current.toJson(), currentKey])) {
            return null;
          }
          if (aliases == null) return null;
          final allowed = {
            for (var i = 0; i < candidates.length; i++) 'r$i': candidates[i].id,
          };
          if (aliases.any((id) => !allowed.containsKey(id))) return null;
          return Set<String>.unmodifiable(aliases.map((id) => allowed[id]!));
        } on Object {
          return null;
        }
      })();
      _cache.addAll({cacheKey: result});
      while (_cache.length > capacity.clamp(1, 128)) {
        final oldest = _cache.keys.first;
        _cache.removeWhere((key, _) => key == oldest);
      }
      return await result;
    } on Object {
      return null;
    }
  }
}
