import 'dart:convert';

import 'package:dingdong/features/agent_api/data/http_response_data.dart';

/// Routes API requests that must be handed to live desktop application state.
final class DesktopControlRoutes {
  const DesktopControlRoutes({this.onClipboardMonitoring, this.onShowUi});

  final void Function(bool value)? onClipboardMonitoring;
  final void Function(int index)? onShowUi;

  HttpResponseData? route({
    required String method,
    required String path,
    required Map<String, String> query,
    required String body,
  }) {
    if (method == 'POST' && path == '/clipboard/monitor') {
      return _monitor(query, body);
    }
    if (method == 'POST' && path == '/ui/show') {
      return _show(query, body);
    }
    return null;
  }

  HttpResponseData _monitor(Map<String, String> query, String body) {
    try {
      final Map<String, Object?> payload = body.trim().isEmpty
          ? const <String, Object?>{}
          : jsonDecode(body) as Map<String, Object?>;
      final bool? enabled =
          parseQueryBool(query['enabled']) ??
          (payload['enabled'] is bool ? payload['enabled']! as bool : null);
      if (enabled == null) {
        return HttpResponseData.badRequest('enabled must be true or false');
      }
      onClipboardMonitoring?.call(enabled);
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': enabled ? 'enabled' : 'disabled',
          'feature': 'clipboard-monitor',
        },
      );
    } on Object {
      return HttpResponseData.badRequest('enabled must be true or false');
    }
  }

  HttpResponseData _show(Map<String, String> query, String body) {
    try {
      final Map<String, Object?> payload = body.trim().isEmpty
          ? const <String, Object?>{}
          : jsonDecode(body) as Map<String, Object?>;
      final String tab = (query['tab'] ?? payload['tab'] as String? ?? 'today')
          .trim()
          .toLowerCase();
      final int? index = switch (tab) {
        'today' || 'home' => 0,
        'library' || 'resources' => 1,
        'clipboard' => 2,
        'api' || 'agent-api' => 3,
        'settings' => 4,
        'plugins' || 'market' => 5,
        _ => null,
      };
      if (index == null) {
        return HttpResponseData.badRequest('Invalid UI tab');
      }
      onShowUi?.call(index);
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': 'shown',
          'service': 'DingDong',
          'tab': switch (index) {
            0 => 'today',
            1 => 'library',
            2 => 'clipboard',
            3 => 'api',
            4 => 'settings',
            _ => 'plugins',
          },
        },
      );
    } on Object {
      return HttpResponseData.badRequest('Invalid UI show JSON body');
    }
  }
}
