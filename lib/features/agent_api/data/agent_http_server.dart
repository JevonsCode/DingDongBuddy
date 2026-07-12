import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/http_request_data.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';

/// Loopback-only HTTP transport for the framework-independent agent router.
final class AgentHttpServer {
  AgentHttpServer(this._router);

  final AgentRouter _router;
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;

  Uri get baseUri {
    final HttpServer? server = _server;
    if (server == null) {
      throw StateError('The agent HTTP server is not running.');
    }
    return Uri(scheme: 'http', host: '127.0.0.1', port: server.port);
  }

  Future<void> start({int port = 2333}) async {
    if (_server != null) {
      return;
    }
    late final HttpServer server;
    try {
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: false,
      );
    } on SocketException {
      if (port == 0) {
        rethrow;
      }
      server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
        shared: false,
      );
    }
    _server = server;
    _router.updateBaseUri(baseUri);
    _subscription = server.listen(_handleRequest);
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final String body = await utf8.decoder.bind(request).join();
      final HttpResponseData routed = await _router.route(
        HttpRequestData(
          method: request.method,
          uri: request.uri.toString(),
          body: body,
        ),
      );
      request.response
        ..statusCode = routed.statusCode
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(routed.json));
    } on Object {
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode(<String, Object?>{
            'status': 'error',
            'message': 'Internal server error',
          }),
        );
    } finally {
      await request.response.close();
    }
  }
}
