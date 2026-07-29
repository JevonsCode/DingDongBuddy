import 'dart:io';

import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('notify maps to the stable ding loopback route', () async {
    final _RecordingMcpHttpTransport transport = _RecordingMcpHttpTransport();
    final LoopbackMcpToolExecutor executor = LoopbackMcpToolExecutor(transport);

    await executor.execute('dingdong_notify', <String, Object?>{
      'message': 'Finished',
      'source': 'Codex',
    });

    expect(transport.method, 'POST');
    expect(transport.path, '/ding');
    expect(transport.body?['message'], 'Finished');
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
    });

    expect(transport.method, 'GET');
    expect(transport.path, '/library/reviewer-id');
    expect(transport.query, <String, String>{
      'mode': 'full',
      'trackUsage': 'true',
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
    });

    expect(transport.method, 'GET');
    expect(transport.path, '/agent/skills/load');
    expect(transport.query, <String, String>{
      'id': 'reviewer-id',
      'name': 'reviewer',
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
    });

    expect(transport.method, 'GET');
    expect(transport.path, '/agent/skills/file');
    expect(transport.query, <String, String>{
      'name': 'reviewer',
      'path': 'references/policy.md',
      'workspacePath': '/workspace/dingdong',
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
    });

    expect(transport.method, 'POST');
    expect(transport.path, '/library/trigger-groups/upsert');
    expect(transport.body?['projectPath'], '/work/checkout');
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

  static const Map<String, Object?> response = <String, Object?>{
    'status': 'ok',
  };
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
    return response;
  }
}
