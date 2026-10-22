import 'dart:convert';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/http_request_data.dart';
import 'package:dingdong/features/agent_api/domain/bridge_resource_selection.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/managed_mcp_identity.dart';
import 'package:flutter_test/flutter_test.dart';

Resource resource(
  String id,
  ResourceType type, {
  ResourceActivation activation = ResourceActivation.taskMatch,
  bool enabled = true,
  List<String> groups = const [],
}) => Resource(
  id: id,
  type: type,
  title: id,
  content: type == ResourceType.skill
      ? '---\nname: $id\ndescription: Describe $id\n---\nprivate skill body'
      : '{"apiKey":"private-config"}',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
  activation: activation,
  enabled: enabled,
  triggerGroupIds: groups,
);
void main() {
  test(
    'explicit eligible MCP title or managed name survives empty model selection without expanding scope',
    () async {
      final database = resource(
        'db',
        ResourceType.mcp,
      ).copyWith(title: 'Database');
      final router = AgentRouter(
        resourceStore: InMemoryResourceStore([
          database,
          resource('data', ResourceType.mcp).copyWith(title: 'Data'),
          resource(
            'manual',
            ResourceType.mcp,
            activation: ResourceActivation.manual,
          ),
          resource('disabled', ResourceType.mcp, enabled: false),
          resource('scoped', ResourceType.mcp, groups: ['missing']),
        ]),
        selectBridgeResources: (_) async => <String>{},
      );
      Future<Set<Object?>> names(String task) async {
        final response = await router.route(
          HttpRequestData(
            method: 'POST',
            uri: '/agent/bridge',
            body: jsonEncode({'task': task, 'source': 'Codex'}),
          ),
        );
        return (((response.json['active'] as Map)['mcps'] as List)
                .cast<Map<String, Object?>>())
            .map((item) => item['id'])
            .toSet();
      }

      expect(await names('Use Database; also manual disabled scoped'), {'db'});
      final managed = managedMcpServerName(
        title: database.title,
        id: database.id,
      );
      expect(await names('Call `$managed` for this task'), {'db'});
      expect(await names('Use DatabaseBackup for this task'), isEmpty);
      expect(await names('Call ${managed}Backup'), isEmpty);
    },
  );

  test(
    'Skill activation is availability metadata; explicit names survive model omission',
    () async {
      BridgeResourceSelectionRequest? seen;
      final router = AgentRouter(
        resourceStore: InMemoryResourceStore([
          resource(
            'explicit-skill',
            ResourceType.skill,
            activation: ResourceActivation.always,
          ),
          resource(
            'unrelated-skill',
            ResourceType.skill,
            activation: ResourceActivation.always,
          ),
          resource(
            'rules',
            ResourceType.prompt,
            activation: ResourceActivation.always,
          ),
        ]),
        selectBridgeResources: (request) async {
          seen = request;
          return <String>{};
        },
      );
      final response = await router.route(
        HttpRequestData(
          method: 'POST',
          uri: '/agent/bridge',
          body: jsonEncode({
            'task': r'Use $explicit-skill for this task',
            'source': 'Codex',
          }),
        ),
      );
      final active = response.json['active'] as Map;
      expect(
        (active['skills'] as List).cast<Map<String, Object?>>().map(
          (e) => e['id'],
        ),
        ['explicit-skill'],
      );
      expect(
        (active['prompts'] as List).cast<Map<String, Object?>>().map(
          (e) => e['id'],
        ),
        ['rules'],
      );
      expect(seen!.candidates.map((e) => e.id).toSet(), {
        'explicit-skill',
        'unrelated-skill',
      });
    },
  );

  test(
    'Bridge applies AI choices only to eligible optional references and preserves Prompts/always',
    () async {
      BridgeResourceSelectionRequest? seen;
      final store = InMemoryResourceStore([
        resource(
          'prompt',
          ResourceType.prompt,
          activation: ResourceActivation.always,
        ),
        resource(
          'always',
          ResourceType.mcp,
          activation: ResourceActivation.always,
        ),
        resource('chosen', ResourceType.skill),
        resource('hidden', ResourceType.skill),
        resource('database', ResourceType.mcp),
        resource('disabled', ResourceType.skill, enabled: false),
        resource('scoped', ResourceType.skill, groups: ['missing']),
        resource(
          'manual',
          ResourceType.mcp,
          activation: ResourceActivation.manual,
        ),
      ]);
      final router = AgentRouter(
        resourceStore: store,
        selectBridgeResources: (request) async {
          seen = request;
          return {'chosen', 'database', 'disabled', 'scoped', 'manual'};
        },
      );
      Future<Map<String, Object?>> bridge({
        String? hash,
        bool get = false,
      }) async {
        final input = {
          'task': 'unmatched task',
          'taskContext': 'explicit context',
          'source': 'Codex',
          'expand': 'prompts',
          'acceptDelta': true,
          'knownHash': ?hash,
        };
        return (await router.route(
          HttpRequestData(
            method: get ? 'GET' : 'POST',
            uri: get
                ? Uri(
                    path: '/agent/bridge',
                    queryParameters: input.map((k, v) => MapEntry(k, '$v')),
                  ).toString()
                : '/agent/bridge',
            body: get ? '' : jsonEncode(input),
          ),
        )).json;
      }

      final first = await bridge();
      final active = first['active'] as Map;
      expect(
        (active['prompts'] as List).cast<Map<String, Object?>>().map(
          (e) => e['id'],
        ),
        ['prompt'],
      );
      expect(
        (active['skills'] as List).cast<Map<String, Object?>>().map(
          (e) => e['id'],
        ),
        ['chosen'],
      );
      expect(
        (active['mcps'] as List)
            .cast<Map<String, Object?>>()
            .map((e) => e['id'])
            .toSet(),
        {'always', 'database'},
      );
      expect(seen!.taskContext, 'explicit context');
      expect(seen!.candidates.map((e) => e.id).toSet(), {
        'chosen',
        'hidden',
        'database',
      });
      expect(
        seen!.candidates.map((e) => e.description).join(),
        isNot(contains('private-config')),
      );
      expect(
        seen!.candidates.map((e) => e.description).join(),
        isNot(contains('private skill body')),
      );
      expect((await bridge(hash: first['hash'] as String))['unchanged'], true);
      expect((await bridge(get: true))['active'], active);
    },
  );
  test(
    'null or failed selector retains deterministic original catalog',
    () async {
      for (final fails in [false, true]) {
        final router = AgentRouter(
          resourceStore: InMemoryResourceStore([
            resource('review', ResourceType.skill),
            resource('database', ResourceType.mcp),
          ]),
          selectBridgeResources: (_) async {
            if (fails) throw StateError('offline');
            return null;
          },
        );
        final result = await router.route(
          HttpRequestData(
            method: 'POST',
            uri: '/agent/bridge',
            body: jsonEncode({
              'task': 'unmatched',
              'source': 'Codex',
              'expand': 'prompts',
            }),
          ),
        );
        expect(result.statusCode, 200);
        final active = result.json['active'] as Map;
        expect(
          (active['skills'] as List).cast<Map<String, Object?>>().map(
            (e) => e['id'],
          ),
          ['review'],
        );
        expect(active['mcps'], isEmpty);
      }
    },
  );
}
