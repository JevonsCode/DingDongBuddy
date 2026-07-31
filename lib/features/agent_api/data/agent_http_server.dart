import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/agent_api/data/http_request_data.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';

/// Loopback-only HTTP transport for the framework-independent agent router.
final class AgentHttpServer {
  AgentHttpServer(
    this._router, {
    Uri? websiteUri,
    this.maxRequestBodyBytes = 8 * 1024 * 1024,
  }) : assert(maxRequestBodyBytes > 0),
       _websiteUri = websiteUri ?? defaultWebsiteUri;

  final AgentRouter _router;
  final Uri _websiteUri;
  final int maxRequestBodyBytes;
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
    server.idleTimeout = const Duration(seconds: 15);
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
      if (request.method == 'GET' && request.uri.path == '/') {
        request.response
          ..statusCode = HttpStatus.found
          ..headers.set(HttpHeaders.locationHeader, _websiteUri.toString())
          ..headers.set(HttpHeaders.cacheControlHeader, 'no-store');
        return;
      }
      if (_isBrowserCrossOriginRequest(request)) {
        _writeJson(
          request.response,
          HttpStatus.forbidden,
          const <String, Object?>{
            'status': 'error',
            'message': 'Browser cross-origin requests are not allowed.',
          },
        );
        return;
      }
      if (_requiresJsonContentType(request) &&
          !_hasJsonContentType(request.headers.contentType)) {
        _writeJson(
          request.response,
          HttpStatus.unsupportedMediaType,
          const <String, Object?>{
            'status': 'error',
            'message': 'POST and PATCH requests require application/json.',
          },
        );
        return;
      }
      final String body = await _readBody(
        request,
        maximumBytes: maxRequestBodyBytes,
      );
      final HttpResponseData routed = await _router.route(
        HttpRequestData(
          method: request.method,
          uri: request.uri.toString(),
          body: body,
        ),
      );
      _writeJson(request.response, routed.statusCode, routed.json);
    } on _RequestBodyTooLarge {
      _writeJson(
        request.response,
        HttpStatus.requestEntityTooLarge,
        <String, Object?>{
          'status': 'error',
          'message': 'Request body exceeds $maxRequestBodyBytes bytes.',
        },
      );
    } on _InvalidRequestEncoding {
      _writeJson(
        request.response,
        HttpStatus.badRequest,
        const <String, Object?>{
          'status': 'error',
          'message': 'Request body must be valid UTF-8.',
        },
      );
    } on Object {
      _writeJson(
        request.response,
        HttpStatus.internalServerError,
        const <String, Object?>{
          'status': 'error',
          'message': 'Internal server error',
        },
      );
    } finally {
      await request.response.close();
    }
  }
}

bool _isBrowserCrossOriginRequest(HttpRequest request) {
  if (request.method == 'GET' && request.uri.path == '/health') {
    return false;
  }
  final String? origin = request.headers.value('origin');
  if (origin != null && origin.trim().isNotEmpty) {
    return true;
  }
  final String? fetchSite = request.headers
      .value('sec-fetch-site')
      ?.trim()
      .toLowerCase();
  return fetchSite != null && fetchSite != 'none' && fetchSite != 'same-origin';
}

bool _requiresJsonContentType(HttpRequest request) =>
    request.method == 'POST' || request.method == 'PATCH';

bool _hasJsonContentType(ContentType? contentType) {
  final String? mimeType = contentType?.mimeType.toLowerCase();
  return mimeType == 'application/json' ||
      (mimeType?.endsWith('+json') ?? false);
}

Future<String> _readBody(
  HttpRequest request, {
  required int maximumBytes,
}) async {
  final BytesBuilder bytes = BytesBuilder(copy: false);
  var length = 0;
  var isTooLarge = request.contentLength > maximumBytes;
  await for (final List<int> chunk in request) {
    length += chunk.length;
    if (length > maximumBytes) {
      isTooLarge = true;
    }
    if (!isTooLarge) {
      bytes.add(chunk);
    }
  }
  if (isTooLarge) {
    throw const _RequestBodyTooLarge();
  }
  try {
    return utf8.decode(bytes.takeBytes());
  } on FormatException {
    throw const _InvalidRequestEncoding();
  }
}

void _writeJson(
  HttpResponse response,
  int statusCode,
  Map<String, Object?> body,
) {
  response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
    ..headers.set('x-content-type-options', 'nosniff')
    ..write(jsonEncode(body));
}

final class _RequestBodyTooLarge implements Exception {
  const _RequestBodyTooLarge();
}

final class _InvalidRequestEncoding implements Exception {
  const _InvalidRequestEncoding();
}
