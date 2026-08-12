import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/http_request_data.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/data/skill_deployment_store.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test(
    'PUT delivery rejects a native project that is not an exact existing path',
    () async {
      final DateTime now = DateTime.utc(2026, 8, 12);
      final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
        Resource(
          id: 'skill-1',
          type: ResourceType.skill,
          title: 'Reviewer',
          content: '---\nname: reviewer\ndescription: Review changes\n---\n',
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final AgentRouter router = AgentRouter(resourceStore: store);

      final response = await router.route(
        const HttpRequestData(
          method: 'PUT',
          uri: '/library/skills/skill-1/delivery',
          body:
              '{"enabled":true,"agentId":"codex","mode":"nativeProject",'
              '"hooksEnabled":true,"projectPaths":["/workspace/app"]}',
        ),
      );

      expect(response.statusCode, 400);
      expect(response.json['message'], contains('existing absolute project'));
    },
  );

  test(
    'PUT delivery rejects unknown fields instead of ignoring them',
    () async {
      final DateTime now = DateTime.utc(2026, 8, 12);
      final AgentRouter router = AgentRouter(
        resourceStore: InMemoryResourceStore(<Resource>[
          Resource(
            id: 'skill-1',
            type: ResourceType.skill,
            title: 'Reviewer',
            content: '---\nname: reviewer\ndescription: Review changes\n---\n',
            createdAt: now,
            updatedAt: now,
          ),
        ]),
      );

      final HttpResponseData response = await router.route(
        const HttpRequestData(
          method: 'PUT',
          uri: '/library/skills/skill-1/delivery',
          body:
              '{"enabled":true,"agentId":"codex","mode":"dynamic",'
              '"hookEnabled":true}',
        ),
      );

      expect(response.statusCode, 400);
      expect(response.json['message'], contains('hookEnabled'));
    },
  );

  test('GET deployments reports observed state', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-delivery-route-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final SkillDeploymentStore deployments = SkillDeploymentStore(
      Directory(path.join(temp.path, 'state')),
    );
    final DateTime now = DateTime.utc(2026, 8, 12);
    final AgentRouter router = AgentRouter(
      resourceStore: InMemoryResourceStore(<Resource>[
        Resource(
          id: 'skill-1',
          type: ResourceType.skill,
          title: 'Reviewer',
          content: '---\nname: reviewer\ndescription: Review changes\n---\n',
          createdAt: now,
          updatedAt: now,
        ),
      ]),
      skillDeploymentStore: deployments,
    );

    final response = await router.route(
      const HttpRequestData(
        method: 'GET',
        uri: '/library/skills/skill-1/deployments',
      ),
    );

    expect(response.statusCode, 200);
    expect(response.json['deployments'], isEmpty);
  });

  test('reconcile validates the Skill before causing a save', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-reconcile-route-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final InMemoryResourceStore delegate = InMemoryResourceStore();
    var saveCount = 0;
    final AgentRouter router = AgentRouter(
      resourceStore: _CountingResourceStore(delegate, () => saveCount += 1),
      skillDeploymentStore: SkillDeploymentStore(
        Directory(path.join(temp.path, 'state')),
      ),
    );

    final response = await router.route(
      const HttpRequestData(
        method: 'POST',
        uri: '/library/skills/missing/reconcile',
      ),
    );

    expect(response.statusCode, 404);
    expect(saveCount, 0);
  });

  test(
    'PUT delivery is idempotent and cannot retarget another project Agent',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-delivery-project-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final Directory firstProject = Directory(path.join(temp.path, 'first'))
        ..createSync();
      final Directory secondProject = Directory(path.join(temp.path, 'second'))
        ..createSync();
      final DateTime now = DateTime.utc(2026, 8, 12);
      final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
        Resource(
          id: 'skill-1',
          type: ResourceType.skill,
          title: 'Reviewer',
          content: '---\nname: reviewer\ndescription: Review changes\n---\n',
          activation: ResourceActivation.taskMatch,
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      var saveCount = 0;
      final AgentRouter router = AgentRouter(
        resourceStore: _CountingResourceStore(store, () => saveCount += 1),
      );

      Future<HttpResponseData> update({
        required String agentId,
        required Directory project,
      }) => router.route(
        HttpRequestData(
          method: 'PUT',
          uri: '/library/skills/skill-1/delivery',
          body: jsonEncode(<String, Object?>{
            'enabled': true,
            'agentId': agentId,
            'mode': 'nativeProject',
            'projectPaths': <String>[project.path],
          }),
        ),
      );

      final created = await update(agentId: 'codex', project: firstProject);
      final unchanged = await update(agentId: 'codex', project: firstProject);
      final conflicting = await update(
        agentId: 'claude-code',
        project: secondProject,
      );

      expect(created.statusCode, 200);
      expect(created.json['status'], 'updated');
      expect(created.json, isNot(contains('reloadRequired')));
      expect(created.json['discovery'], 'automaticNativeScan');
      expect(created.json['taskBoundaryRecommended'], isTrue);
      expect(created.json['restartAgentIfMissing'], isTrue);
      expect(unchanged.statusCode, 200);
      expect(unchanged.json['status'], 'unchanged');
      expect(unchanged.json, isNot(contains('reloadRequired')));
      expect(unchanged.json['discovery'], 'automaticNativeScan');
      expect(unchanged.json['taskBoundaryRecommended'], isFalse);
      expect(unchanged.json['restartAgentIfMissing'], isTrue);
      expect(conflicting.statusCode, 409);
      expect(conflicting.json['code'], 'skill_project_scope_conflict');
      expect(saveCount, 1);
      final Resource stored = (await store.load()).single;
      expect(stored.activation, ResourceActivation.taskMatch);
      expect(stored.skillProjectPaths, <String>[
        firstProject.resolveSymbolicLinksSync(),
      ]);
    },
  );

  test(
    'dynamic delivery recommends a new task only after a real transition',
    () async {
      final DateTime now = DateTime.utc(2026, 8, 12);
      final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
        Resource(
          id: 'skill-1',
          type: ResourceType.skill,
          title: 'Reviewer',
          content: '---\nname: reviewer\ndescription: Review changes\n---\n',
          enabled: true,
          skillDeliveryByAgent: const <String, SkillDeliveryMode>{
            'codex': SkillDeliveryMode.nativeUser,
          },
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final AgentRouter router = AgentRouter(resourceStore: store);

      Future<HttpResponseData> useDynamic() => router.route(
        const HttpRequestData(
          method: 'PUT',
          uri: '/library/skills/skill-1/delivery',
          body: '{"enabled":true,"agentId":"codex","mode":"dynamic"}',
        ),
      );

      final HttpResponseData transitioned = await useDynamic();
      final HttpResponseData unchanged = await useDynamic();

      expect(transitioned.statusCode, 200);
      expect(
        transitioned.json['discovery'],
        'bridgeAfterNativeAbsenceVerified',
      );
      expect(transitioned.json['taskBoundaryRecommended'], isTrue);
      expect(transitioned.json['restartAgentIfMissing'], isFalse);
      expect(transitioned.json, isNot(contains('reloadRequired')));
      expect(unchanged.json['taskBoundaryRecommended'], isFalse);
      expect((await store.load()).single.skillDeliveryByAgent, isEmpty);
    },
  );

  test('concurrent PATCH cannot overwrite an atomic delivery change', () async {
    final DateTime now = DateTime.utc(2026, 8, 12);
    final _InterleavingResourceStore store =
        _InterleavingResourceStore(<Resource>[
          Resource(
            id: 'skill-1',
            type: ResourceType.skill,
            title: 'Reviewer',
            content: '---\nname: reviewer\ndescription: Review changes\n---\n',
            createdAt: now,
            updatedAt: now,
          ),
        ]);
    final AgentRouter router = AgentRouter(resourceStore: store);
    store.pauseNextLoad();
    final Future<HttpResponseData> patch = router.route(
      const HttpRequestData(
        method: 'PATCH',
        uri: '/library/skill-1',
        body: '{"title":"Updated title"}',
      ),
    );
    await store.loadEntered;
    expect(store.exclusiveInvocationCount, 1);
    final Future<HttpResponseData> delivery = router.route(
      const HttpRequestData(
        method: 'PUT',
        uri: '/library/skills/skill-1/delivery',
        body: '{"enabled":true,"agentId":"codex","mode":"nativeUser"}',
      ),
    );
    await Future<void>.delayed(Duration.zero);
    store.releaseLoad();

    expect((await patch).statusCode, 200);
    expect((await delivery).statusCode, 200);
    final Resource current = (await store.load()).single;
    expect(current.title, 'Updated title');
    expect(
      current.skillDeliveryForAgent('codex'),
      SkillDeliveryMode.nativeUser,
    );
  });

  test(
    'nativeUser clears project scope and cannot mix with project-native Agents',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-native-scope-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final DateTime now = DateTime.utc(2026, 8, 12);
      final InMemoryResourceStore store = InMemoryResourceStore(<Resource>[
        Resource(
          id: 'skill-1',
          type: ResourceType.skill,
          title: 'Reviewer',
          content: '---\nname: reviewer\ndescription: Review changes\n---\n',
          triggerGroupIds: const <String>['project'],
          strictProjectSkill: true,
          skillProjectPaths: <String>[temp.path],
          createdAt: now,
          updatedAt: now,
        ),
      ]);
      final AgentRouter router = AgentRouter(resourceStore: store);

      final HttpResponseData user = await router.route(
        const HttpRequestData(
          method: 'PUT',
          uri: '/library/skills/skill-1/delivery',
          body: '{"enabled":true,"agentId":"codex","mode":"nativeUser"}',
        ),
      );
      final HttpResponseData mixed = await router.route(
        HttpRequestData(
          method: 'PUT',
          uri: '/library/skills/skill-1/delivery',
          body: jsonEncode(<String, Object?>{
            'enabled': true,
            'agentId': 'claude-code',
            'mode': 'nativeProject',
            'projectPaths': <String>[temp.path],
          }),
        ),
      );

      expect(user.statusCode, 200);
      final Resource stored = (await store.load()).single;
      expect(stored.triggerGroupIds, isEmpty);
      expect(stored.strictProjectSkill, isFalse);
      expect(stored.skillProjectPaths, isEmpty);
      expect(mixed.statusCode, 409);
      expect(mixed.json['code'], 'skill_native_scope_conflict');
    },
  );

  test(
    'same source and digest is idempotent; different source same name conflicts',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-install-route-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      Directory source(String directory, String heading) {
        final Directory root = Directory(path.join(temp.path, directory))
          ..createSync();
        File(path.join(root.path, 'SKILL.md')).writeAsStringSync(
          '---\nname: reviewer\ndescription: Review changes\n---\n\n# $heading',
        );
        return root;
      }

      final Directory first = source('first', 'First');
      final Directory fork = source('fork', 'Fork');
      final InMemoryResourceStore store = InMemoryResourceStore();
      final AgentRouter router = AgentRouter(
        resourceStore: store,
        skillPackageInstaller: GitHubSkillPackageInstaller(
          Directory(path.join(temp.path, 'packages')),
        ),
        idGenerator: () => 'skill-1',
      );

      Future<HttpResponseData> install(Directory value) => router.route(
        HttpRequestData(
          method: 'POST',
          uri: '/library/skills/install',
          body: jsonEncode(<String, Object?>{'source': value.path}),
        ),
      );

      final created = await install(first);
      final unchanged = await install(first);
      final conflict = await install(fork);

      expect(created.statusCode, 201);
      expect(unchanged.statusCode, 200);
      expect(unchanged.json['status'], 'unchanged');
      expect(conflict.statusCode, 409);
      expect(conflict.json['code'], 'skill_name_conflict');
      expect((await store.load()), hasLength(1));
    },
  );

  test(
    'same artifact migrates a legacy package path instead of leaking',
    () async {
      final Directory temp = Directory.systemTemp.createTempSync(
        'dingdong-install-migrate-',
      );
      addTearDown(() => temp.deleteSync(recursive: true));
      final Directory source = Directory(path.join(temp.path, 'source'))
        ..createSync();
      final File sourceSkill = File(path.join(source.path, 'SKILL.md'))
        ..writeAsStringSync(
          '---\nname: reviewer\ndescription: Review changes\n---\n',
        );
      final Directory packages = Directory(path.join(temp.path, 'packages'));
      final InMemoryResourceStore store = InMemoryResourceStore();
      final AgentRouter router = AgentRouter(
        resourceStore: store,
        skillPackageInstaller: GitHubSkillPackageInstaller(packages),
        idGenerator: () => 'skill-1',
      );
      Future<HttpResponseData> install() => router.route(
        HttpRequestData(
          method: 'POST',
          uri: '/library/skills/install',
          body: jsonEncode(<String, Object?>{'source': source.path}),
        ),
      );

      expect((await install()).statusCode, 201);
      final Resource installed = (await store.load()).single;
      Directory(installed.packagePath!).deleteSync(recursive: true);
      final Directory legacy = Directory(path.join(packages.path, 'reviewer'))
        ..createSync(recursive: true);
      sourceSkill.copySync(path.join(legacy.path, 'SKILL.md'));
      await store.save(<Resource>[
        installed.copyWith(packagePath: legacy.path),
      ]);

      final HttpResponseData migrated = await install();

      expect(migrated.statusCode, 200);
      expect(migrated.json['status'], 'updated');
      final Resource current = (await store.load()).single;
      expect(path.equals(current.packagePath!, legacy.path), isFalse);
      expect(Directory(current.packagePath!).existsSync(), isTrue);
    },
  );

  test('concurrent installs of one source create one resource', () async {
    final Directory temp = Directory.systemTemp.createTempSync(
      'dingdong-concurrent-install-',
    );
    addTearDown(() => temp.deleteSync(recursive: true));
    final Directory source = Directory(path.join(temp.path, 'source'))
      ..createSync();
    File(path.join(source.path, 'SKILL.md')).writeAsStringSync(
      '---\nname: reviewer\ndescription: Review changes\n---\n',
    );
    var nextId = 0;
    final InMemoryResourceStore store = InMemoryResourceStore();
    final AgentRouter router = AgentRouter(
      resourceStore: store,
      skillPackageInstaller: GitHubSkillPackageInstaller(
        Directory(path.join(temp.path, 'packages')),
      ),
      idGenerator: () => 'skill-${nextId++}',
    );
    Future<HttpResponseData> install() => router.route(
      HttpRequestData(
        method: 'POST',
        uri: '/library/skills/install',
        body: jsonEncode(<String, Object?>{'source': source.path}),
      ),
    );

    final List<HttpResponseData> responses = await Future.wait(
      <Future<HttpResponseData>>[install(), install()],
    );

    expect(responses.map((HttpResponseData value) => value.statusCode), <int>[
      201,
      200,
    ]);
    expect((await store.load()), hasLength(1));
    expect(nextId, 1);
  });
}

final class _CountingResourceStore implements ResourceStore {
  _CountingResourceStore(this.delegate, this.onSave);

  final ResourceStore delegate;
  final void Function() onSave;

  @override
  Future<List<Resource>> load() => delegate.load();

  @override
  Future<void> save(List<Resource> resources) {
    onSave();
    return delegate.save(resources);
  }
}

final class _InterleavingResourceStore
    implements ResourceStore, ExclusiveResourceStore {
  _InterleavingResourceStore(List<Resource> resources)
    : _resources = List<Resource>.of(resources);

  List<Resource> _resources;
  Future<void> _mutationBarrier = Future<void>.value();
  int exclusiveInvocationCount = 0;
  Completer<void>? _loadEntered;
  Completer<void>? _releaseLoad;

  Future<void> get loadEntered => _loadEntered!.future;

  void pauseNextLoad() {
    _loadEntered = Completer<void>();
    _releaseLoad = Completer<void>();
  }

  void releaseLoad() {
    final Completer<void> release = _releaseLoad!;
    _releaseLoad = null;
    release.complete();
  }

  @override
  Future<T> exclusiveMutation<T>(Future<T> Function() action) async {
    exclusiveInvocationCount += 1;
    final Future<void> previous = _mutationBarrier;
    final Completer<void> gate = Completer<void>();
    _mutationBarrier = gate.future;
    await previous;
    try {
      return await action();
    } finally {
      gate.complete();
    }
  }

  @override
  Future<List<Resource>> load() async {
    final Completer<void>? entered = _loadEntered;
    final Completer<void>? release = _releaseLoad;
    if (entered != null && release != null) {
      _loadEntered = null;
      entered.complete();
      await release.future;
    }
    return List<Resource>.of(_resources);
  }

  @override
  Future<void> save(List<Resource> resources) async {
    _resources = List<Resource>.of(resources);
  }
}
