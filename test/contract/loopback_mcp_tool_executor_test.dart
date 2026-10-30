import 'dart:io';

import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test(
    'notify requires an explicit nonempty conversation ID before sending',
    () async {
      for (final invalid in <Object?>[null, '', '   ', 42]) {
        final transport = _RecordingMcpHttpTransport();
        final executor = LoopbackMcpToolExecutor(
          transport,
          conversationIdResolver: () => 'another-host-context',
        );
        await expectLater(
          executor.execute('dingdong_notify', {
            'message': 'Waiting',
            'conversationId': ?invalid,
          }),
          throwsArgumentError,
        );
        expect(transport.path, isNull);
      }
    },
  );

  test(
    'desktop MCP keeps resource routing and sends desktop notifications',
    () async {
      final transport = _RecordingMcpHttpTransport();
      final executor = LoopbackMcpToolExecutor(
        transport,
        currentDirectory: () => '/workspace',
        repositoryUrlResolver: (_) async => null,
        sourceResolver: () => 'Claude Desktop',
        conversationIdResolver: () => 'cli-123',
        hostSessionIdResolver: () => 'local_desktop-123',
      );

      await executor.execute('dingdong_bridge', {
        'task': 'work',
        'source': 'Claude Code',
      });
      expect(transport.body?['source'], 'Claude Code');
      expect(transport.body?['activitySource'], 'Claude Desktop');

      await executor.execute('dingdong_notify', {
        'message': 'Waiting',
        'conversationId': 'cli-123',
        'source': 'Claude Code',
      });
      expect(transport.body?['source'], 'Claude Desktop');
      expect(transport.body?['conversationId'], 'cli-123');
      expect(transport.body?['hostSessionId'], 'local_desktop-123');

      await executor.execute('dingdong_notify', {
        'message': 'Other conversation',
        'conversationId': 'different-cli',
      });
      expect(transport.body?['conversationId'], 'different-cli');
      expect(transport.body, isNot(contains('hostSessionId')));

      await executor.execute('dingdong_load_skill', {
        'id': 'skill',
        'source': 'Claude Desktop',
      });
      expect(transport.query?['source'], 'Claude Code');
    },
  );

  test(
    'named reminder tools preserve structured IDs and imported paths',
    () async {
      final transport = _RecordingMcpHttpTransport();
      final executor = LoopbackMcpToolExecutor(transport);
      await executor.execute('dingdong_list_reminders', {});
      expect(transport.method, 'GET');
      expect(transport.path, '/settings/reminders');
      await executor.execute('dingdong_upsert_reminder', {
        'id': 'error',
        'name': 'Build failed',
      });
      expect(transport.body, {
        'id': 'error',
        'name': 'Build failed',
        'action': 'upsert',
      });
      await executor.execute('dingdong_import_reminder_sound', {
        'name': 'Chime',
        'path': '/tmp/chime.wav',
      });
      expect(transport.body?['action'], 'importSound');
      expect(transport.body?['path'], '/tmp/chime.wav');
      await executor.execute('dingdong_notify', {
        'message': 'Failed',
        'conversationId': 'reminder-thread',
        'reminderId': 'error',
      });
      expect(transport.body?['reminderId'], 'error');
      await executor.execute('dingdong_delete_reminder', {'id': 'error'});
      expect(transport.body, {'id': 'error', 'action': 'delete'});
    },
  );

  test(
    'version acknowledgements pass through without implicit session reuse',
    () async {
      final transport = _RecordingMcpHttpTransport();
      final executor = LoopbackMcpToolExecutor(
        transport,
        currentDirectory: () => '/workspace/test',
        repositoryUrlResolver: (_) async => null,
      );
      await executor.execute('dingdong_bridge', {
        'acceptDelta': true,
        'knownHash': 'retained',
      });
      expect(transport.body?['acceptDelta'], true);
      expect(transport.body?['knownHash'], 'retained');
      await executor.execute('dingdong_bridge', {});
      expect(transport.body?.containsKey('knownHash'), false);
      await executor.execute('dingdong_load_skill', {
        'id': 'review',
        'knownVersion': 'loaded',
      });
      expect(transport.query?['knownVersion'], 'loaded');
      await executor.execute('dingdong_load_skill', {'id': 'review'});
      expect(transport.query?.containsKey('knownVersion'), false);
    },
  );
  test(
    'Jev inherits only the current successful bridge conversation',
    () async {
      final transport = _RecordingMcpHttpTransport();
      final executor = LoopbackMcpToolExecutor(
        transport,
        currentDirectory: () => '/workspace/test',
        repositoryUrlResolver: (_) async => null,
        conversationIdResolver: () => null,
        sourceResolver: () => 'Codex',
      );
      await executor.execute('dingdong_bridge', {
        'conversationId': 'explicit-one',
      });
      await executor.execute('dingdong_jev_check', {
        'state': 'test',
        'instructions': 'test?',
      });
      expect(transport.body?['conversationId'], 'explicit-one');
      await executor.execute('dingdong_jev_check', {
        'conversationId': 'explicit-override',
      });
      expect(transport.body?['conversationId'], 'explicit-override');
      await executor.execute('dingdong_bridge', {});
      await executor.execute('dingdong_jev_check', {});
      expect(transport.body?['conversationId'], '');
      await executor.execute('dingdong_bridge', {
        'conversationId': 'explicit-two',
      });
      transport.response = {'status': 'error'};
      await executor.execute('dingdong_bridge', {'conversationId': 'failed'});
      await executor.execute('dingdong_jev_check', {});
      expect(transport.body?['conversationId'], '');
    },
  );

  test('notify maps to the stable ding loopback route', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_notify', <String, Object?>{
      'message': 'Finished',
      'conversationId': 'current-thread',
      'source': 'Codex',
    });

    expect(transport.method, 'POST');
    expect(transport.path, '/ding');
    expect(transport.body?['message'], 'Finished');
    expect(transport.body?['notificationKind'], 'attention');
  });

  test('notify adds Agent context used for subagent filtering', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
      transport,
      currentDirectory: () => '/workspace/dingdong',
      repositoryUrlResolver: (_) async => null,
      conversationIdResolver: () => 'subagent-thread-1',
      sourceResolver: () => 'Codex',
    );

    await executor.execute('dingdong_notify', <String, Object?>{
      'message': 'Waiting for approval',
      'conversationId': 'subagent-thread-1',
    });

    expect(transport.body?['conversationId'], 'subagent-thread-1');
    expect(transport.body?['source'], 'Codex');
    expect(transport.body?['workspacePath'], '/workspace/dingdong');
  });

  test(
    'asset search maps bounded arguments to library query parameters',
    () async {
      final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
      final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
        transport,
      );

      await executor.execute('dingdong_search_assets', <String, Object?>{
        'query': 'release',
        'type': 'prompt',
        'limit': 8,
      });

      expect(transport.method, 'GET');
      expect(transport.path, '/library');
      expect(transport.query, <String, String>{
        'query': 'release',
        'type': 'prompt',
        'limit': '8',
      });
    },
  );

  test(
    'asset search preserves the all selector for the library route',
    () async {
      final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
      final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
        transport,
      );

      await executor.execute('dingdong_search_assets', <String, Object?>{
        'query': 'release',
        'type': 'all',
      });

      expect(transport.query, <String, String>{
        'query': 'release',
        'type': 'all',
      });
    },
  );

  test('Prompt creation is disabled until scope is configured', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_create_resource', <String, Object?>{
      'type': 'prompt',
      'title': 'Project rules',
      'content': 'Follow the project rules.',
    });

    expect(transport.method, 'POST');
    expect(transport.path, '/library');
    expect(transport.body?['type'], 'prompt');
    expect(transport.body?['enabled'], isFalse);
    expect(transport.body?['source'], 'DingDong MCP');
  });

  test('Skill creation is rejected in favor of the package installer', () {
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
      _RecordingMcpHttpTransport(),
    );

    expect(
      () => executor.execute('dingdong_create_resource', <String, Object?>{
        'type': 'skill',
        'title': 'Reviewer',
        'content': '---\nname: reviewer\n---',
      }),
      throwsArgumentError,
    );
  });

  test('Prompt updates verify the resource type before patching', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport()
      ..queuedResponses.addAll(<Map<String, Object?>>[
        <String, Object?>{
          'status': 'ok',
          'item': <String, Object?>{'id': 'prompt-1', 'type': 'prompt'},
        },
        <String, Object?>{'status': 'updated'},
      ]);
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_update_resource', <String, Object?>{
      'resourceId': 'prompt-1',
      'enabled': true,
    });

    expect(transport.requests, hasLength(2));
    expect(transport.requests.first.method, 'GET');
    expect(transport.requests.first.path, '/library/prompt-1');
    expect(transport.requests.first.query, <String, String>{'mode': 'summary'});
    expect(transport.method, 'PATCH');
    expect(transport.path, '/library/prompt-1');
    expect(transport.body, <String, Object?>{'enabled': true});
  });

  test('Skill updates are rejected before mutation', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport()
      ..response = <String, Object?>{
        'status': 'ok',
        'item': <String, Object?>{'id': 'skill-1', 'type': 'skill'},
      };
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await expectLater(
      executor.execute('dingdong_update_resource', <String, Object?>{
        'resourceId': 'skill-1',
        'title': 'Unsafe edit',
      }),
      throwsStateError,
    );

    expect(transport.requests, hasLength(1));
    expect(transport.requests.single.method, 'GET');
  });

  test('bridge adds working directory and repository context', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
      transport,
      currentDirectory: () => '/workspace/dingdong',
      repositoryUrlResolver: (_) async =>
          'https://github.com/example/dingdong.git',
    );

    await executor.execute('dingdong_bridge', <String, Object?>{
      'task': 'Review changes',
    });

    expect(transport.body?['workspacePath'], '/workspace/dingdong');
    expect(
      transport.body?['repositoryUrl'],
      'https://github.com/example/dingdong.git',
    );
  });

  test('bridge adds the Agent conversation identity when available', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
      transport,
      currentDirectory: () => '/workspace/dingdong',
      repositoryUrlResolver: (_) async => null,
      conversationIdResolver: () => 'thread-42',
      sourceResolver: () => 'Codex',
    );

    await executor.execute('dingdong_bridge', <String, Object?>{
      'task': 'Track lifecycle',
    });

    expect(transport.body?['conversationId'], 'thread-42');
    expect(transport.body?['source'], 'Codex');
  });

  test('bridge source is reused by subsequent Skill reads', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    transport.response = <String, Object?>{'status': 'ok', 'source': 'Codex'};
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
      transport,
      currentDirectory: () => '/workspace/dingdong',
      repositoryUrlResolver: (_) async => null,
    );

    await executor.execute('dingdong_bridge', <String, Object?>{
      'task': 'Review changes',
      'source': 'Codex',
    });
    await executor.execute('dingdong_load_skill', <String, Object?>{
      'id': 'reviewer-id',
    });

    expect(transport.query?['source'], 'Codex');
  });

  test('failed Bridge clears a previously remembered source', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
      transport,
      currentDirectory: () => '/workspace/dingdong',
      repositoryUrlResolver: (_) async => null,
    );

    transport.response = <String, Object?>{'status': 'ok', 'source': 'Codex'};
    await executor.execute('dingdong_bridge', <String, Object?>{
      'task': 'Review changes',
      'source': 'Codex',
    });
    transport.response = <String, Object?>{'status': 'error'};
    await executor.execute('dingdong_bridge', <String, Object?>{
      'task': 'Unavailable request',
      'source': 'Cursor',
    });
    await executor.execute('dingdong_load_skill', <String, Object?>{
      'id': 'reviewer-id',
    });

    expect(transport.query?.containsKey('source'), isFalse);
  });

  test('full asset reads add current workspace context', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
      transport,
      currentDirectory: () => '/workspace/dingdong',
      repositoryUrlResolver: (_) async =>
          'https://github.com/example/dingdong.git',
    );

    await executor.execute('dingdong_get_asset', <String, Object?>{
      'id': 'reviewer-id',
      'mode': 'full',
      'source': 'Codex',
      // Legacy callers cannot opt into clipboard reads through this tool.
      'includeClipboard': true,
      'includeSensitiveClipboard': true,
    });

    expect(transport.method, 'GET');
    expect(transport.path, '/library/reviewer-id');
    expect(transport.query, <String, String>{
      'mode': 'full',
      'trackUsage': 'true',
      'source': 'Codex',
      'workspacePath': '/workspace/dingdong',
      'repositoryUrl': 'https://github.com/example/dingdong.git',
    });
  });

  test('Skill loading adds identity and current workspace context', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
      transport,
      currentDirectory: () => '/workspace/dingdong',
      repositoryUrlResolver: (_) async =>
          'https://github.com/example/dingdong.git',
    );

    await executor.execute('dingdong_load_skill', <String, Object?>{
      'name': 'reviewer',
      'id': 'reviewer-id',
      'source': 'Cursor',
    });

    expect(transport.method, 'GET');
    expect(transport.path, '/agent/skills/load');
    expect(transport.query, <String, String>{
      'id': 'reviewer-id',
      'name': 'reviewer',
      'source': 'Cursor',
      'workspacePath': '/workspace/dingdong',
      'repositoryUrl': 'https://github.com/example/dingdong.git',
    });
  });

  test('Skill supporting-file reads keep the relative path', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
      transport,
      currentDirectory: () => '/workspace/dingdong',
      repositoryUrlResolver: (_) async => null,
    );

    await executor.execute('dingdong_read_skill_file', <String, Object?>{
      'name': 'reviewer',
      'path': 'references/policy.md',
      'source': 'Claude Code',
    });

    expect(transport.method, 'GET');
    expect(transport.path, '/agent/skills/file');
    expect(transport.query, <String, String>{
      'name': 'reviewer',
      'path': 'references/policy.md',
      'source': 'Claude Code',
      'workspacePath': '/workspace/dingdong',
    });
  });

  test('MCP use confirmation keeps provenance and Agent context', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
      transport,
      currentDirectory: () => '/workspace/dingdong',
      repositoryUrlResolver: (_) async =>
          'https://github.com/example/dingdong.git',
    );

    await executor.execute('dingdong_confirm_mcp_use', <String, Object?>{
      'id': 'figma-id',
      'serverName': 'dingdong-figma-abcdef',
      'toolName': 'mcp__dingdong_figma_abcdef__get_metadata',
      'source': 'Codex',
    });

    expect(transport.method, 'GET');
    expect(transport.path, '/agent/mcps/confirm-use');
    expect(transport.query, <String, String>{
      'id': 'figma-id',
      'serverName': 'dingdong-figma-abcdef',
      'toolName': 'mcp__dingdong_figma_abcdef__get_metadata',
      'source': 'Codex',
      'workspacePath': '/workspace/dingdong',
      'repositoryUrl': 'https://github.com/example/dingdong.git',
    });
  });

  test('Skill installation maps to the dedicated write route', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_install_skill', <String, Object?>{
      'source': 'https://github.com/acme/skills/tree/main/reviewer',
      'title': 'Reviewer',
    });

    expect(transport.method, 'POST');
    expect(transport.path, '/library/skills/install');
    expect(
      transport.body?['source'],
      'https://github.com/acme/skills/tree/main/reviewer',
    );
  });

  test(
    'local Skill installation stages the package before loopback access',
    () async {
      final Directory source = Directory.systemTemp.createTempSync(
        'dingdong-mcp-source-',
      );
      addTearDown(() => source.deleteSync(recursive: true));
      File(p.join(source.path, 'SKILL.md')).writeAsStringSync(
        '---\n'
        'name: local-probe\n'
        'description: Use when testing local Skill staging.\n'
        '---\n\n'
        '# Local Probe',
      );
      File(p.join(source.path, 'references', 'probe.md'))
        ..createSync(recursive: true)
        ..writeAsStringSync('DD_LOCAL_REFERENCE');
      final _InspectingInstallTransport transport = _InspectingInstallTransport(
        originalSource: source.path,
      );
      final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(
        transport,
      );

      await executor.execute('dingdong_install_skill', <String, Object?>{
        'source': source.path,
        'title': 'Local Probe',
      });

      expect(transport.receivedSource, isNot(source.path));
      expect(transport.receivedSourceReference, source.path);
      expect(transport.sawCompletePackage, isTrue);
      expect(
        Directory(transport.receivedSource!).existsSync(),
        isFalse,
        reason: 'The private staging package must be removed after the call.',
      );
    },
  );

  test('trigger-group upsert maps to the idempotent write route', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_upsert_trigger_group', <String, Object?>{
      'name': 'Checkout',
      'projectPath': '/work/checkout',
      'repositoryUrl': 'https://github.com/acme/checkout.git',
      'source': 'Codex',
    });

    expect(transport.method, 'POST');
    expect(transport.path, '/library/trigger-groups/upsert');
    expect(transport.body?['projectPath'], '/work/checkout');
    expect(transport.body?['source'], 'Codex');
  });

  test('resource scope binding keeps the resource id in the route', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_bind_resource_scope', <String, Object?>{
      'resourceId': 'skill-1',
      'triggerGroupIds': <String>['checkout'],
      'strictProjectSkill': true,
    });

    expect(transport.method, 'POST');
    expect(transport.path, '/library/skill-1/scope');
    expect(transport.body?.containsKey('resourceId'), isFalse);
    expect(transport.body?['triggerGroupIds'], <String>['checkout']);
    expect(transport.body?['strictProjectSkill'], isTrue);
  });

  test('Skill delivery maps to the atomic per-Agent route', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_set_skill_delivery', <String, Object?>{
      'resourceId': 'skill-1',
      'agentId': 'codex',
      'mode': 'nativeProject',
      'projectPaths': <String>['/work/checkout'],
      'hooksEnabled': true,
    });

    expect(transport.method, 'PUT');
    expect(transport.path, '/library/skills/skill-1/delivery');
    expect(transport.body?.containsKey('resourceId'), isFalse);
    expect(transport.body?['agentId'], 'codex');
    expect(transport.body?['mode'], 'nativeProject');
  });

  test('Skill deployment status maps to the read route', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_get_skill_deployments', <String, Object?>{
      'resourceId': 'skill-1',
    });

    expect(transport.method, 'GET');
    expect(transport.path, '/library/skills/skill-1/deployments');
    expect(transport.body, isNull);
  });

  test('Skill reconcile maps to the idempotent retry route', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_reconcile_skill', <String, Object?>{
      'resourceId': 'skill-1',
    });

    expect(transport.method, 'POST');
    expect(transport.path, '/library/skills/skill-1/reconcile');
    expect(transport.body, isNull);
  });

  test('real MCP transport rejects oversized loopback responses', () async {
    final Directory temp = await Directory.systemTemp.createTemp(
      'dingdong-mcp-transport-',
    );
    final File activePort = File(p.join(temp.path, 'active-port'));
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    await activePort.writeAsString('${server.port}');
    server.listen((HttpRequest request) async {
      request.response
        ..headers.contentType = ContentType.json
        ..write('{"payload":"${List<String>.filled(128, 'x').join()}"}');
      await request.response.close();
    });
    final DartIoMcpHttpTransport transport = DartIoMcpHttpTransport(
      activePort,
      maximumResponseBytes: 64,
    );
    addTearDown(() async {
      transport.close(force: true);
      await server.close(force: true);
      await temp.delete(recursive: true);
    });

    await expectLater(
      transport.request(method: 'GET', path: '/agent/bridge'),
      throwsA(
        isA<StateError>().having(
          (StateError error) => error.message,
          'message',
          contains('exceeds 64 bytes'),
        ),
      ),
    );
  });
}

final class _InspectingInstallTransport implements McpHttpTransport {
  _InspectingInstallTransport({required this.originalSource});

  final String originalSource;
  String? receivedSource;
  String? receivedSourceReference;
  bool sawCompletePackage = false;

  @override
  Future<Map<String, Object?>> request({
    required String method,
    required String path,
    Map<String, String> query = const <String, String>{},
    Map<String, Object?>? body,
  }) async {
    receivedSource = body?['source'] as String?;
    receivedSourceReference = body?['sourceReference'] as String?;
    final String? staged = receivedSource;
    if (method == 'POST' &&
        path == '/library/skills/install' &&
        staged != null &&
        staged != originalSource) {
      sawCompletePackage =
          File(
            p.join(staged, 'SKILL.md'),
          ).readAsStringSync().contains('name: local-probe') &&
          File(p.join(staged, 'references', 'probe.md')).readAsStringSync() ==
              'DD_LOCAL_REFERENCE';
    }
    return const <String, Object?>{'status': 'created'};
  }
}

final class _RecordingMcpHttpTransport implements McpHttpTransport {
  _RecordingMcpHttpTransport();

  Map<String, Object?> response = <String, Object?>{'status': 'ok'};
  final List<Map<String, Object?>> queuedResponses = <Map<String, Object?>>[];
  final List<_RecordedMcpRequest> requests = <_RecordedMcpRequest>[];
  String? method;
  String? path;
  Map<String, String>? query;
  Map<String, Object?>? body;

  @override
  Future<Map<String, Object?>> request({
    required String method,
    required String path,
    Map<String, String> query = const <String, String>{},
    Map<String, Object?>? body,
  }) async {
    this.method = method;
    this.path = path;
    this.query = query;
    this.body = body;
    requests.add(
      _RecordedMcpRequest(method: method, path: path, query: query, body: body),
    );
    return queuedResponses.isEmpty ? response : queuedResponses.removeAt(0);
  }
}

final class _RecordedMcpRequest {
  const _RecordedMcpRequest({
    required this.method,
    required this.path,
    required this.query,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, String> query;
  final Map<String, Object?>? body;
}
