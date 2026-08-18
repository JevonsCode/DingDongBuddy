// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_api/data/agent_repository_context.dart';
import 'package:dingdong/features/agent_api/data/agent_source_identity.dart';
import 'package:dingdong/features/agent_api/data/mcp_server.dart';
import 'package:dingdong/features/library/domain/skill_package_installer.dart';

/// HTTP boundary used by the stdio MCP adapter.
abstract interface class McpHttpTransport {
  Future<Map<String, Object?>> request({
    required String method,
    required String path,
    Map<String, String> query = const <String, String>{},
    Map<String, Object?>? body,
  });
}

/// Maps stable MCP tool names to DingDong's loopback HTTP contract.
final class LoopbackMcpToolExecutor implements McpToolExecutor {
  LoopbackMcpToolExecutor(
    this._transport, {
    String Function()? currentDirectory,
    Future<String?> Function(String directory)? repositoryUrlResolver,
    String? Function()? conversationIdResolver,
    String? Function()? sourceResolver,
  }) : _currentDirectory = currentDirectory ?? _defaultCurrentDirectory,
       _repositoryUrlResolver =
           repositoryUrlResolver ?? resolveGitRepositoryUrl,
       _conversationIdResolver =
           conversationIdResolver ?? _defaultConversationId,
       _sourceResolver = sourceResolver ?? _defaultAgentSource;

  final McpHttpTransport _transport;
  final String Function() _currentDirectory;
  final Future<String?> Function(String directory) _repositoryUrlResolver;
  final String? Function() _conversationIdResolver;
  final String? Function() _sourceResolver;
  String? _lastBridgeSource;

  @override
  Future<Map<String, Object?>> execute(
    String name,
    Map<String, Object?> arguments,
  ) async {
    return switch (name) {
      'dingdong_bridge' => _bridge(arguments),
      'dingdong_search_assets' => _transport.request(
        method: 'GET',
        path: '/library',
        query: _stringQuery(arguments, <String>['query', 'type', 'limit']),
      ),
      'dingdong_get_asset' => _contextualGet(
        path: '/library/${arguments['id'] ?? ''}',
        arguments: arguments,
        keys: const <String>[
          'mode',
          'includeClipboard',
          'includeSensitiveClipboard',
          'source',
        ],
        extraQuery: const <String, String>{'trackUsage': 'true'},
      ),
      'dingdong_load_skill' => _contextualGet(
        path: '/agent/skills/load',
        arguments: arguments,
        keys: const <String>['id', 'name', 'source'],
      ),
      'dingdong_confirm_mcp_use' => _contextualGet(
        path: '/agent/mcps/confirm-use',
        arguments: arguments,
        keys: const <String>['id', 'serverName', 'toolName', 'source'],
      ),
      'dingdong_read_skill_file' => _contextualGet(
        path: '/agent/skills/file',
        arguments: arguments,
        keys: const <String>['id', 'name', 'path', 'source'],
      ),
      'dingdong_recommend_mcp' => _transport.request(
        method: 'GET',
        path: '/library',
        query: <String, String>{
          'type': 'mcp',
          if (arguments['task'] != null) 'query': '${arguments['task']}',
          if (arguments['limit'] != null) 'limit': '${arguments['limit']}',
        },
      ),
      'dingdong_install_skill' => _installSkill(arguments),
      'dingdong_upsert_trigger_group' => _transport.request(
        method: 'POST',
        path: '/library/trigger-groups/upsert',
        body: arguments,
      ),
      'dingdong_bind_resource_scope' => _bindResourceScope(arguments),
      'dingdong_set_skill_delivery' => _setSkillDelivery(arguments),
      'dingdong_get_skill_deployments' => _skillDeployments(arguments),
      'dingdong_reconcile_skill' => _reconcileSkill(arguments),
      'dingdong_notify' => _notify(arguments),
      _ => throw ArgumentError.value(name, 'name', 'Unknown DingDong tool'),
    };
  }

  Future<Map<String, Object?>> _bindResourceScope(
    Map<String, Object?> arguments,
  ) {
    final String resourceId = (arguments['resourceId'] as String? ?? '').trim();
    final Map<String, Object?> body = Map<String, Object?>.of(arguments)
      ..remove('resourceId');
    return _transport.request(
      method: 'POST',
      path: '/library/$resourceId/scope',
      body: body,
    );
  }

  Future<Map<String, Object?>> _setSkillDelivery(
    Map<String, Object?> arguments,
  ) {
    final String resourceId = (arguments['resourceId'] as String? ?? '').trim();
    final Map<String, Object?> body = Map<String, Object?>.of(arguments)
      ..remove('resourceId');
    return _transport.request(
      method: 'PUT',
      path: '/library/skills/$resourceId/delivery',
      body: body,
    );
  }

  Future<Map<String, Object?>> _skillDeployments(
    Map<String, Object?> arguments,
  ) {
    final String resourceId = (arguments['resourceId'] as String? ?? '').trim();
    return _transport.request(
      method: 'GET',
      path: '/library/skills/$resourceId/deployments',
    );
  }

  Future<Map<String, Object?>> _reconcileSkill(Map<String, Object?> arguments) {
    final String resourceId = (arguments['resourceId'] as String? ?? '').trim();
    return _transport.request(
      method: 'POST',
      path: '/library/skills/$resourceId/reconcile',
    );
  }

  Future<Map<String, Object?>> _installSkill(
    Map<String, Object?> arguments,
  ) async {
    final String source = (arguments['source'] as String? ?? '').trim();
    final Uri? parsed = parseSkillPackageSource(source);
    final Uri? localSource = parsed?.scheme == 'file' ? parsed : null;
    if (localSource == null) {
      return _transport.request(
        method: 'POST',
        path: '/library/skills/install',
        body: arguments,
      );
    }

    // The GUI app may not have macOS protected-folder permission for a
    // workspace under Documents/Desktop/Downloads. The MCP process already
    // operates in the Agent's authorized workspace, so copy and validate the
    // complete package in a private system-temporary directory first.
    final Directory stagingRoot = await Directory.systemTemp.createTemp(
      'dingdong-mcp-skill-',
    );
    try {
      final SkillPackageInstallResult staged =
          await GitHubSkillPackageInstaller(stagingRoot).install(localSource);
      final Map<String, Object?> body = Map<String, Object?>.of(arguments)
        ..['source'] = staged.directoryPath
        ..['sourceReference'] = source;
      return await _transport.request(
        method: 'POST',
        path: '/library/skills/install',
        body: body,
      );
    } finally {
      if (await stagingRoot.exists()) {
        await stagingRoot.delete(recursive: true);
      }
    }
  }

  Future<Map<String, Object?>> _bridge(Map<String, Object?> arguments) async {
    final Map<String, Object?> body = Map<String, Object?>.of(arguments);
    final String directory =
        (body['workspacePath'] as String? ?? '').trim().isEmpty
        ? _currentDirectory()
        : (body['workspacePath'] as String).trim();
    body['workspacePath'] = directory;
    if ((body['conversationId'] as String? ?? '').trim().isEmpty) {
      final String? conversationId = _conversationIdResolver()?.trim();
      if (conversationId != null && conversationId.isNotEmpty) {
        body['conversationId'] = conversationId;
      }
    }
    if ((body['source'] as String? ?? '').trim().isEmpty) {
      final String? source = _sourceResolver()?.trim();
      if (source != null && source.isNotEmpty) {
        body['source'] = source;
      }
    }
    if ((body['repositoryUrl'] as String? ?? '').trim().isEmpty) {
      final String? repositoryUrl = await _repositoryUrlResolver(directory);
      if (repositoryUrl != null && repositoryUrl.trim().isNotEmpty) {
        body['repositoryUrl'] = repositoryUrl.trim();
      }
    }
    final Map<String, Object?> response;
    try {
      response = await _transport.request(
        method: 'POST',
        path: '/agent/bridge',
        body: body,
      );
    } on Object {
      _lastBridgeSource = null;
      rethrow;
    }
    if (response['status'] != 'ok') {
      _lastBridgeSource = null;
      return response;
    }
    final String? source = _responseSource(response);
    if (source != null) {
      _lastBridgeSource = source;
    } else {
      final String requestedSource = (body['source'] as String? ?? '').trim();
      _lastBridgeSource = requestedSource.isEmpty ? 'Agent' : requestedSource;
    }
    return response;
  }

  Future<Map<String, Object?>> _notify(Map<String, Object?> arguments) {
    final Map<String, Object?> body = Map<String, Object?>.of(arguments);
    body.putIfAbsent('notificationKind', () => 'attention');
    if ((body['conversationId'] as String? ?? '').trim().isEmpty) {
      final String? conversationId = _conversationIdResolver()?.trim();
      if (conversationId != null && conversationId.isNotEmpty) {
        body['conversationId'] = conversationId;
      }
    }
    if ((body['source'] as String? ?? '').trim().isEmpty) {
      final String? source = _lastBridgeSource ?? _sourceResolver()?.trim();
      if (source != null && source.isNotEmpty) {
        body['source'] = source;
      }
    }
    if ((body['workspacePath'] as String? ?? '').trim().isEmpty) {
      body['workspacePath'] = _currentDirectory();
    }
    return _transport.request(method: 'POST', path: '/ding', body: body);
  }

  Future<Map<String, Object?>> _contextualGet({
    required String path,
    required Map<String, Object?> arguments,
    required List<String> keys,
    Map<String, String> extraQuery = const <String, String>{},
  }) async {
    final Map<String, String> query = <String, String>{
      ..._stringQuery(arguments, keys),
      ...extraQuery,
    };
    final String explicitSource = (arguments['source'] as String? ?? '').trim();
    if (explicitSource.isNotEmpty) {
      query['source'] = explicitSource;
    } else if (_lastBridgeSource case final String source
        when source.isNotEmpty) {
      query['source'] = source;
    }
    final String directory =
        (arguments['workspacePath'] as String? ?? '').trim().isEmpty
        ? _currentDirectory()
        : (arguments['workspacePath'] as String).trim();
    query['workspacePath'] = directory;
    final String explicitRepository =
        (arguments['repositoryUrl'] as String? ?? '').trim();
    if (explicitRepository.isNotEmpty) {
      query['repositoryUrl'] = explicitRepository;
    } else {
      final String? repositoryUrl = await _repositoryUrlResolver(directory);
      if (repositoryUrl != null && repositoryUrl.trim().isNotEmpty) {
        query['repositoryUrl'] = repositoryUrl.trim();
      }
    }
    return _transport.request(method: 'GET', path: path, query: query);
  }
}

String? _responseSource(Map<String, Object?> response) {
  final String topLevel = (response['source'] as String? ?? '').trim();
  if (topLevel.isNotEmpty) {
    return topLevel;
  }
  final Object? context = response['context'];
  if (context is Map) {
    final String nested = (context['source'] as String? ?? '').trim();
    if (nested.isNotEmpty) {
      return nested;
    }
  }
  return null;
}

String _defaultCurrentDirectory() => Directory.current.path;

String? _defaultConversationId() => _firstEnvironmentValue(const <String>[
  'CODEX_THREAD_ID',
  'CLAUDE_SESSION_ID',
  'CURSOR_SESSION_ID',
  'GEMINI_SESSION_ID',
  'KIRO_SESSION_ID',
  'PI_SESSION_ID',
]);

String? _defaultAgentSource() =>
    inferAgentSourceFromEnvironment(Platform.environment);

String? _firstEnvironmentValue(List<String> keys) {
  for (final String key in keys) {
    final String value = (Platform.environment[key] ?? '').trim();
    if (value.isNotEmpty) {
      return value;
    }
  }
  return null;
}

Map<String, String> _stringQuery(
  Map<String, Object?> arguments,
  List<String> keys,
) {
  return <String, String>{
    for (final String key in keys)
      if (arguments[key] != null) key: '${arguments[key]}',
  };
}

/// Real loopback transport that discovers the running app's active port file.
final class DartIoMcpHttpTransport implements McpHttpTransport {
  const DartIoMcpHttpTransport(this._activePortFile);

  final File _activePortFile;

  @override
  Future<Map<String, Object?>> request({
    required String method,
    required String path,
    Map<String, String> query = const <String, String>{},
    Map<String, Object?>? body,
  }) async {
    final int? port = int.tryParse(
      (await _activePortFile.readAsString()).trim(),
    );
    if (port == null || port < 1 || port > 65535) {
      throw StateError('DingDong active port is invalid.');
    }
    final Uri uri = Uri(
      scheme: 'http',
      host: '127.0.0.1',
      port: port,
      path: path,
      queryParameters: query.isEmpty ? null : query,
    );
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.openUrl(method, uri);
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final HttpClientResponse response = await request.close();
      final String responseBody = await utf8.decoder.bind(response).join();
      final Map<String, Object?> payload = responseBody.isEmpty
          ? <String, Object?>{}
          : jsonDecode(responseBody) as Map<String, Object?>;
      if (response.statusCode >= 400) {
        throw StateError(
          payload['message']?.toString() ?? 'DingDong request failed.',
        );
      }
      return payload;
    } finally {
      client.close(force: true);
    }
  }
}
