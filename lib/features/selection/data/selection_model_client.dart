import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/selection/domain/selection_plugin_configuration.dart';

/// Each operation owns its connection. Cancelling cannot abort a newer request.
final class SelectionCancellation {
  bool cancelled = false;
  void Function()? _abort;
  void cancel() {
    cancelled = true;
    _abort?.call();
  }
}

final class SelectionModelFailure implements Exception {
  const SelectionModelFailure(this.code);
  final String code;
}

abstract interface class SelectionModelClient {
  Future<String> complete({
    required SelectionPluginConfiguration configuration,
    required String? token,
    required List<Map<String, String>> messages,
    required SelectionCancellation cancellation,
  });
}

/// OpenRouter, LM Studio and Gemini's configured OpenAI endpoint share the
/// OpenAI chat protocol. Ollama and Anthropic use their native protocols.
final class HttpSelectionModelClient implements SelectionModelClient {
  HttpSelectionModelClient({
    this.timeout = const Duration(seconds: 60),
    this.maxResponseBytes = 1024 * 1024,
  });

  final Duration timeout;
  final int maxResponseBytes;

  @override
  Future<String> complete({
    required SelectionPluginConfiguration configuration,
    required String? token,
    required List<Map<String, String>> messages,
    required SelectionCancellation cancellation,
  }) async {
    if (configuration.validationError != null) {
      throw const SelectionModelFailure('configuration');
    }
    if (configuration.requiresToken && (token == null || token.isEmpty)) {
      throw const SelectionModelFailure('token_required');
    }
    if (cancellation.cancelled) {
      throw const SelectionModelFailure('cancelled');
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    cancellation._abort = () => client.close(force: true);
    try {
      return await _request(
        client,
        configuration,
        token,
        messages,
      ).timeout(timeout);
    } on SelectionModelFailure {
      rethrow;
    } on TimeoutException {
      throw const SelectionModelFailure('timeout');
    } catch (_) {
      // Never return server bodies, URLs, credentials or exception descriptions
      // to the child window or logs.
      throw SelectionModelFailure(
        cancellation.cancelled ? 'cancelled' : 'network',
      );
    } finally {
      cancellation._abort = null;
      client.close(force: true);
    }
  }

  Future<String> _request(
    HttpClient client,
    SelectionPluginConfiguration config,
    String? token,
    List<Map<String, String>> messages,
  ) async {
    final ollama = config.provider == SelectionModelProvider.ollama;
    final anthropic =
        config.provider == SelectionModelProvider.anthropicCompatible;
    final base = config.endpoint.trim().replaceFirst(RegExp(r'/+$'), '');
    final suffix = ollama
        ? '/api/chat'
        : anthropic
        ? '/messages'
        : '/chat/completions';
    final uri = Uri.parse(base.endsWith(suffix) ? base : '$base$suffix');
    final request = await client.postUrl(uri);
    request.followRedirects =
        false; // Credentials must stay on the configured host.
    request.headers.contentType = ContentType.json;
    if (token != null && token.isNotEmpty) {
      request.headers.set(
        anthropic ? 'x-api-key' : 'Authorization',
        anthropic ? token : 'Bearer $token',
      );
    }
    if (anthropic) request.headers.set('anthropic-version', '2023-06-01');
    request.write(
      jsonEncode(<String, Object>{
        'model': config.model,
        'stream': false,
        'messages': anthropic
            ? messages.where((m) => m['role'] != 'system').toList()
            : messages,
        if (anthropic)
          'system': messages
              .where((m) => m['role'] == 'system')
              .map((m) => m['content'])
              .join('\n'),
        if (!ollama) 'max_tokens': 2048,
        if (ollama) 'options': <String, int>{'num_predict': 2048},
        if (ollama && config.unloadLocalModelAfterResponse) 'keep_alive': 0,
      }),
    );
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw SelectionModelFailure(switch (response.statusCode) {
        401 || 403 => 'authentication',
        429 => 'rate_limit',
        _ => 'server',
      });
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 15))) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const SelectionModelFailure('response_too_large');
      }
      bytes.addAll(chunk);
    }
    final body = jsonDecode(utf8.decode(bytes));
    Object? output;
    if (body is Map<String, dynamic>) {
      if (ollama) {
        final message = body['message'];
        if (message is Map) output = message['content'];
      } else if (anthropic) {
        final content = body['content'];
        if (content is List) {
          output = content
              .whereType<Map>()
              .where((e) => e['type'] == 'text')
              .map((e) => e['text'])
              .whereType<String>()
              .join('\n');
        }
      } else {
        final choices = body['choices'];
        if (choices is List && choices.isNotEmpty && choices.first is Map) {
          final message = (choices.first as Map)['message'];
          if (message is Map) output = message['content'];
        }
      }
    }
    if (output is! String || output.trim().isEmpty) {
      throw const SelectionModelFailure('empty_response');
    }
    return output.trim();
  }
}
