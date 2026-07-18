// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_api/data/mcp_server.dart';

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
  }) : _currentDirectory = currentDirectory ?? _defaultCurrentDirectory,
       _repositoryUrlResolver =
           repositoryUrlResolver ?? _defaultRepositoryUrlResolver;

  final McpHttpTransport _transport;
  final String Function() _currentDirectory;
  final Future<String?> Function(String directory) _repositoryUrlResolver;

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
      'dingdong_get_asset' => _transport.request(
        method: 'GET',
        path: '/library/${arguments['id'] ?? ''}',
        query: _stringQuery(arguments, <String>[
          'mode',
          'includeClipboard',
          'includeSensitiveClipboard',
        ])..['trackUsage'] = 'true',
      ),
      'dingdong_load_skill' => _transport.request(
        method: 'GET',
        path: '/library/${arguments['id'] ?? ''}',
        query: const <String, String>{
          'mode': 'full',
          'expectedType': 'skill',
          'trackUsage': 'true',
        },
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
      'dingdong_notify' => _transport.request(
        method: 'POST',
        path: '/ding',
        body: arguments,
      ),
      _ => throw ArgumentError.value(name, 'name', 'Unknown DingDong tool'),
    };
  }

  Future<Map<String, Object?>> _bridge(Map<String, Object?> arguments) async {
    final Map<String, Object?> body = Map<String, Object?>.of(arguments);
    final String directory =
        (body['workspacePath'] as String? ?? '').trim().isEmpty
        ? _currentDirectory()
        : (body['workspacePath'] as String).trim();
    body['workspacePath'] = directory;
    if ((body['repositoryUrl'] as String? ?? '').trim().isEmpty) {
      final String? repositoryUrl = await _repositoryUrlResolver(directory);
      if (repositoryUrl != null && repositoryUrl.trim().isNotEmpty) {
        body['repositoryUrl'] = repositoryUrl.trim();
      }
    }
    return _transport.request(
      method: 'POST',
      path: '/agent/bridge',
      body: body,
    );
  }
}

String _defaultCurrentDirectory() => Directory.current.path;

Future<String?> _defaultRepositoryUrlResolver(String directory) async {
  try {
    final ProcessResult result = await Process.run('git', const <String>[
      'config',
      '--get',
      'remote.origin.url',
    ], workingDirectory: directory).timeout(const Duration(seconds: 1));
    if (result.exitCode != 0) {
      return null;
    }
    final String value = result.stdout.toString().trim();
    return value.isEmpty ? null : value;
  } on Object {
    return null;
  }
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
