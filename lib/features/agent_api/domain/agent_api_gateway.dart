import 'dart:convert';
import 'dart:io';

/// User-facing operations performed against DingDong's own loopback API.
abstract interface class AgentApiGateway {
  Future<void> testDing(Uri baseUri);
}

/// Sends a bounded test request to the currently running loopback server.
final class HttpAgentApiGateway implements AgentApiGateway {
  HttpAgentApiGateway({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<void> testDing(Uri baseUri) async {
    final HttpClientRequest request = await _client
        .postUrl(baseUri.resolve('/ding'))
        .timeout(_timeout);
    request.headers.contentType = ContentType.json;
    request.write(
      jsonEncode(<String, Object?>{
        'message': 'DingDong connection test',
        'source': 'DingDong',
        'flashCount': 4,
      }),
    );
    final HttpClientResponse response = await request.close().timeout(_timeout);
    await response.drain<void>();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Ding test returned HTTP ${response.statusCode}',
        uri: baseUri,
      );
    }
  }
}

const Duration _timeout = Duration(seconds: 5);
