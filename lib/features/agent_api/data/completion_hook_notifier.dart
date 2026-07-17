import 'dart:convert';

import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';

/// Delivers the durable completion notification used by Agent stop hooks.
final class CompletionHookNotifier {
  CompletionHookNotifier(this._transport);

  final McpHttpTransport _transport;

  Future<Map<String, Object?>> notify(String hookInput) {
    final Map<String, Object?> input = _decodeInput(hookInput);
    final String source = _source(input);
    return _transport.request(
      method: 'POST',
      path: '/ding',
      body: <String, Object?>{
        'message': source == 'Codex' ? 'Codex 已完成本轮任务' : '$source 已完成本轮任务',
        'source': source,
        'flashCount': 4,
        'fallback': true,
      },
    );
  }
}

Map<String, Object?> _decodeInput(String input) {
  if (input.trim().isEmpty) {
    return <String, Object?>{};
  }
  try {
    return jsonDecode(input) as Map<String, Object?>;
  } on Object {
    return <String, Object?>{};
  }
}

String _source(Map<String, Object?> input) {
  final String configured = (input['agent_name'] as String? ?? '').trim();
  if (configured.isNotEmpty) {
    return configured;
  }
  return 'Codex';
}
