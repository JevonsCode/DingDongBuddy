import 'dart:convert';
import 'package:dingdong/features/agent_api/data/http_request_data.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/jev/data/jev_service.dart';

/// Credentials, install/uninstall and opt-in deliberately have no Agent route.
final class JevRoutes {
  const JevRoutes(this.service);
  final JevService service;
  Future<HttpResponseData?> route(HttpRequestData request) async {
    final path = request.parsedUri.path;
    if (!path.startsWith('/plugins/jev/')) return null;
    try {
      if (path == '/plugins/jev/status' && request.method == 'GET') {
        return HttpResponseData(statusCode: 200, json: await service.status());
      }
      final type = switch (path) {
        '/plugins/jev/check' => 'noul',
        '/plugins/jev/choose' => 'choice',
        '/plugins/jev/score' => 'score',
        _ => null,
      };
      if (type != null && request.method == 'POST') {
        return HttpResponseData(
          statusCode: 200,
          json: await service.decide(
            type,
            jsonDecode(request.body) as Map<String, Object?>,
          ),
        );
      }
      return const HttpResponseData(
        statusCode: 404,
        json: {'status': 'not_found'},
      );
    } on JevException catch (error) {
      return HttpResponseData(
        statusCode: 400,
        json: {
          'status': 'error',
          'message': error.code,
          'guidance':
              'Configure Jev in DingDong Settings. Requests are not retried; failed requests may have unknown usage.',
        },
      );
    } on Object {
      return const HttpResponseData(
        statusCode: 400,
        json: {
          'status': 'error',
          'message': 'Jev request unavailable. Check local settings.',
        },
      );
    }
  }
}
