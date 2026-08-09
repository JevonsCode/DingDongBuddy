import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/telemetry/domain/lifecycle_telemetry.dart';

final class HttpLifecycleTelemetryGateway implements LifecycleTelemetryGateway {
  HttpLifecycleTelemetryGateway({HttpClient? client, Uri? endpoint})
    : _client = client ?? HttpClient(),
      endpoint = endpoint ?? defaultLifecycleTelemetryEndpoint;

  final HttpClient _client;
  final Uri endpoint;

  @override
  Future<void> send(LifecycleTelemetryEvent event) async {
    final HttpClientRequest request = await _client
        .postUrl(endpoint)
        .timeout(_timeout);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'DingDong/${event.currentVersion}',
    );
    request.write(jsonEncode(event.toJson()));
    final HttpClientResponse response = await request.close().timeout(_timeout);
    await response.drain<void>().timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Lifecycle statistics returned HTTP ${response.statusCode}',
        uri: endpoint,
      );
    }
  }
}

final Uri defaultLifecycleTelemetryEndpoint = Uri.parse(
  'https://dingdong.xn--m8txu.com/v1/telemetry/lifecycle',
);

const Duration _timeout = Duration(seconds: 8);
