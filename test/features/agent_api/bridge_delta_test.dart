import 'dart:convert';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/agent_bridge.dart';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/bridge_snapshot_cache.dart';
import 'package:dingdong/features/agent_api/data/http_request_data.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 22);
Resource _prompt(String id, String text) => Resource(
  id: id,
  type: ResourceType.prompt,
  title: id,
  content: text,
  activation: ResourceActivation.always,
  createdAt: _now,
  updatedAt: _now,
);
Resource _skill(String text) => Resource(
  id: 'skill',
  type: ResourceType.skill,
  title: 'Review',
  content: '---\nname: review\ndescription: Review code\n---\n$text',
  createdAt: _now,
  updatedAt: _now,
);

class _Fixture {
  _Fixture(List<Resource> resources)
    : store = InMemoryResourceStore(resources) {
    router = AgentRouter(resourceStore: store);
  }
  final InMemoryResourceStore store;
  late AgentRouter router;
  Future<Map<String, Object?>> bridge({
    String? hash,
    bool delta = true,
    String conversation = 'a',
    String source = 'Codex',
    String workspace = '',
    String expand = 'prompts',
  }) async => (await router.route(
    HttpRequestData(
      method: 'POST',
      uri: '/agent/bridge',
      body: jsonEncode({
        'source': source,
        'conversationId': conversation,
        'workspacePath': workspace,
        'expand': expand,
        'acceptDelta': delta,
        'knownHash': ?hash,
      }),
    ),
  )).json;
  Future<Map<String, Object?>> load({String? version}) async =>
      (await router.route(
        HttpRequestData(
          method: 'GET',
          uri: Uri(
            path: '/agent/skills/load',
            queryParameters: {
              'id': 'skill',
              'source': 'Codex',
              'knownVersion': ?version,
            },
          ).toString(),
        ),
      )).json;
}

Map _active(Map response) => response['active'] as Map;
String _hash(Map response) => response['hash'] as String;

void main() {
  test(
    'delta chain reconstructs authoritative snapshots and survives a lost reply',
    () async {
      final f = _Fixture([
        _prompt('a', 'stable rules ' * 1000),
        _prompt('b', 'old'),
        _skill('old'),
      ]);
      final first = await f.bridge();
      final retained = Map<String, Object?>.from(_active(first));
      var hash = _hash(first);
      for (final resources in [
        [
          _prompt('a', 'stable rules ' * 1000),
          _prompt('b', 'new'),
          _skill('changed'),
        ],
        [_prompt('c', 'added'), _skill('changed')],
        <Resource>[],
      ]) {
        await f.store.save(resources);
        await f.bridge(
          hash: hash,
        ); // Simulate a response the caller did not retain.
        final update = await f.bridge(hash: hash);
        expect(update['mode'], 'delta');
        expect(update['baseHash'], hash);
        final delta = update['delta'] as Map;
        final upsert = delta['upsert'] as Map;
        final remove = delta['remove'] as Map;
        final order = delta['order'] as Map;
        for (final kind in {
          ...retained.keys,
          ...upsert.keys,
          ...remove.keys,
          ...order.keys,
        }) {
          final byId = <Object?, Map>{
            for (final item in ((retained[kind] as List?) ?? []).cast<Map>())
              item['id']: item,
          };
          for (final item in ((upsert[kind] as List?) ?? []).cast<Map>()) {
            byId[item['id']] = item;
          }
          for (final id in ((remove[kind] as List?) ?? [])) {
            byId.remove(id);
          }
          retained[kind as String] = order.containsKey(kind)
              ? (order[kind] as List).map((id) => byId[id]!).toList()
              : byId.values.toList();
        }
        hash = _hash(update);
        final full = await f.bridge();
        expect(retained, full['active']);
        expect(hash, _hash(full));
      }
    },
  );

  test('GET compatibility route also supports acknowledged deltas', () async {
    final f = _Fixture([_prompt('a', 'first')]);
    Future<Map> get([String? hash]) async => (await f.router.route(
      HttpRequestData(
        method: 'GET',
        uri: Uri(
          path: '/agent/bridge',
          queryParameters: {
            'source': 'Codex',
            'expand': 'prompts',
            'acceptDelta': 'true',
            'knownHash': ?hash,
          },
        ).toString(),
      ),
    )).json;
    final first = await get();
    expect((await get(_hash(first)))['unchanged'], true);
    await f.store.save([_prompt('a', 'second')]);
    expect((await get(_hash(first)))['mode'], 'delta');
  });

  test(
    'cache eviction and oversize snapshots safely restore full content',
    () async {
      final store = InMemoryResourceStore([_prompt('a', 'one')]);
      final bridge = AgentBridge(
        store,
        snapshots: BridgeSnapshotCache(capacity: 1, maximumResources: 1),
      );
      Future<Map> call([String? hash]) async => (await bridge.respond(
        jsonEncode({'acceptDelta': true, 'knownHash': ?hash}),
      )).json;
      final first = await call();
      await store.save([_prompt('a', 'two')]);
      await call();
      await store.save([_prompt('a', 'three')]);
      expect((await call(_hash(first)))['active'], isNotNull);
      final small = await call();
      await store.save([_prompt('a', 'three'), _prompt('b', 'four')]);
      expect((await call(_hash(small)))['active'], isNotNull);
    },
  );

  test('reordering never repeats retained bodies', () async {
    final f = _Fixture([
      _prompt('a', 'first').copyWith(sortOrder: 0),
      _prompt('b', 'second').copyWith(sortOrder: 1),
    ]);
    final first = await f.bridge();
    await f.store.save([
      _prompt('a', 'first').copyWith(sortOrder: 1),
      _prompt('b', 'second').copyWith(sortOrder: 0),
    ]);
    final delta = (await f.bridge(hash: _hash(first)))['delta'] as Map;
    expect(delta['upsert'], isEmpty);
    expect((delta['order'] as Map)['prompts'], ['b', 'a']);
  });

  test('package revision and body each invalidate the Skill version', () async {
    final f = _Fixture([
      _skill('body').copyWith(skillPackageDigest: 'package-one'),
    ]);
    final first = await f.load();
    final version = (first['skill'] as Map)['version'] as String;
    await f.store.save([
      _skill('body').copyWith(skillPackageDigest: 'package-two'),
    ]);
    expect((await f.load(version: version)).containsKey('unchanged'), false);
    final second = await f.load();
    await f.store.save([
      _skill('edited body').copyWith(skillPackageDigest: 'package-two'),
    ]);
    expect(
      (await f.load(
        version: (second['skill'] as Map)['version'] as String,
      )).containsKey('unchanged'),
      false,
    );
  });

  test(
    'out-of-scope conditional loads still reject retained versions',
    () async {
      final f = _Fixture([_skill('body')]);
      final first = await f.load();
      await f.store.save([
        _skill(
          'body',
        ).copyWith(strictProjectSkill: true, skillProjectPaths: ['/only-here']),
      ]);
      expect(
        (await f.load(
          version: (first['skill'] as Map)['version'] as String,
        ))['status'],
        'error',
      );
    },
  );

  test(
    'same baseline suppresses bodies; no acknowledgement restores full',
    () async {
      final f = _Fixture([_prompt('a', 'rules')]);
      final first = await f.bridge();
      expect((await f.bridge(hash: _hash(first)))['unchanged'], true);
      expect(_active(await f.bridge())['prompts'], isNotEmpty);
    },
  );

  test(
    'one changed Prompt returns only its body, not other resources',
    () async {
      final f = _Fixture([_prompt('a', 'unchanged'), _prompt('b', 'old')]);
      final first = await f.bridge();
      await f.store.save([_prompt('a', 'unchanged'), _prompt('b', 'new')]);
      final next = await f.bridge(hash: _hash(first));
      expect(next['mode'], 'delta');
      expect(next['baseHash'], _hash(first));
      final delta = next['delta'] as Map;
      expect((delta['upsert'] as Map)['prompts'], [containsPair('id', 'b')]);
      expect(jsonEncode(next), isNot(contains('unchanged')));
    },
  );

  test('resource removals and ordering are explicit', () async {
    final f = _Fixture([_prompt('a', 'a'), _prompt('b', 'b')]);
    final first = await f.bridge();
    await f.store.save([_prompt('b', 'b')]);
    final next = await f.bridge(hash: _hash(first));
    final delta = next['delta'] as Map;
    expect((delta['remove'] as Map)['prompts'], ['a']);
    expect((delta['order'] as Map)['prompts'], ['b']);
  });

  test(
    'Skill body-only changes invalidate catalog and conditional load',
    () async {
      final f = _Fixture([_skill('old body')]);
      final first = await f.bridge();
      final loaded = await f.load();
      final version = (loaded['skill'] as Map)['version'] as String;
      expect(
        ((_active(first)['skills'] as List).single as Map)['version'],
        version,
      );
      final same = await f.load(version: version);
      expect(same['unchanged'], true);
      expect(jsonEncode(same), isNot(contains('old body')));
      await f.store.save([_skill('new body')]);
      final updated = await f.bridge(hash: _hash(first));
      expect(_hash(updated), isNot(_hash(first)));
      expect(
        (await f.load(version: version))['skill'],
        containsPair('content', contains('new body')),
      );
    },
  );

  test('conditional load still checks enabled state', () async {
    final f = _Fixture([_skill('body')]);
    final loaded = await f.load();
    final version = (loaded['skill'] as Map)['version'] as String;
    await f.store.save([_skill('body').copyWith(enabled: false)]);
    expect((await f.load(version: version))['status'], 'error');
  });

  test('unknown baseline and restarted server return full snapshots', () async {
    final f = _Fixture([_prompt('a', 'old')]);
    final first = await f.bridge();
    await f.store.save([_prompt('a', 'new')]);
    expect((await f.bridge(hash: 'unknown'))['active'], isNotNull);
    f.router = AgentRouter(resourceStore: f.store);
    expect((await f.bridge(hash: _hash(first)))['active'], isNotNull);
  });

  test('legacy clients still get a full changed snapshot', () async {
    final f = _Fixture([_prompt('a', 'old')]);
    final first = await f.bridge(delta: false);
    await f.store.save([_prompt('a', 'new')]);
    final next = await f.bridge(hash: _hash(first), delta: false);
    expect(next['active'], isNotNull);
    expect(next.containsKey('delta'), false);
  });

  test(
    'baseline cannot cross conversation, source, workspace or expansion',
    () async {
      final f = _Fixture([_prompt('a', 'rules')]);
      final first = await f.bridge();
      for (final next in [
        await f.bridge(hash: _hash(first), conversation: 'b'),
        await f.bridge(hash: _hash(first), source: 'Cursor'),
        await f.bridge(
          hash: _hash(first),
          workspace: '/missing-review-workspace',
        ),
        await f.bridge(hash: _hash(first), expand: 'none'),
      ]) {
        expect(next['active'], isNotNull);
        expect(next.containsKey('delta'), false);
        expect(next.containsKey('unchanged'), false);
      }
    },
  );
}
