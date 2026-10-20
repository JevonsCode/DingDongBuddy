import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/ai_companion/domain/ai_companion_analyzer.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_models.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_privacy.dart';

final class AiCompanionHttpResponse {
  const AiCompanionHttpResponse(this.statusCode, this.body);
  final int statusCode;
  final String body;
}

abstract interface class AiCompanionTransport {
  Future<AiCompanionHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  });
  void close();
}

/// Does not follow redirects: credentials and chat must stay at the explicitly
/// configured endpoint. Both total time and response bytes are bounded.
final class IoAiCompanionTransport implements AiCompanionTransport {
  IoAiCompanionTransport({HttpClient? client})
    // Keep the injectable named argument public while the field stays private.
    // ignore: prefer_initializing_formals
    : _client = client;
  HttpClient? _client;
  @override
  Future<AiCompanionHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    final HttpClient client = _client ??= HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);
    final HttpClientRequest request = await client.postUrl(uri);
    request.followRedirects = false;
    request.maxRedirects = 0;
    headers.forEach(request.headers.set);
    request.add(utf8.encode(body));
    final HttpClientResponse response = await request.close();
    // A failure body may echo the key or request. Never read or propagate it.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      request.abort();
      return AiCompanionHttpResponse(response.statusCode, '');
    }
    final List<int> bytes = <int>[];
    await for (final List<int> chunk in response) {
      if (bytes.length + chunk.length > 65536) {
        request.abort();
        throw const AiCompanionException(AiCompanionError.invalidResponse);
      }
      bytes.addAll(chunk);
    }
    return AiCompanionHttpResponse(response.statusCode, utf8.decode(bytes));
  }

  @override
  void close() {
    _client?.close(force: true);
    _client = null;
  }
}

final class AiCompanionClient {
  AiCompanionClient({
    AiCompanionTransport? transport,
    this.timeout = const Duration(seconds: 30),
    AiCompanionPrivacy privacy = const AiCompanionPrivacy(),
  }) : _transport = transport ?? IoAiCompanionTransport(),
       // ignore: prefer_initializing_formals
       _privacy = privacy;
  final AiCompanionTransport _transport;
  final AiCompanionPrivacy _privacy;
  final Duration timeout;

  static bool isLoopback(Uri endpoint) => <String>{
    'localhost',
    '127.0.0.1',
    '::1',
    '[::1]',
  }.contains(endpoint.host.toLowerCase());

  static Uri validateProvider(AiCompanionSettings settings) {
    final Uri? uri = Uri.tryParse(settings.providerEndpoint.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && isLoopback(uri))) ||
        !RegExp(
          r'^[A-Za-z0-9][A-Za-z0-9._:/-]{0,127}$',
        ).hasMatch(settings.model.trim())) {
      throw const AiCompanionException(AiCompanionError.invalidProvider);
    }
    String path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    if (path.isEmpty) path = '/v1';
    if (!path.endsWith('/chat/completions')) path = '$path/chat/completions';
    return uri.replace(path: path);
  }

  static void validateApiKey(Uri endpoint, String? key) {
    if ((key == null || key.isEmpty) && !isLoopback(endpoint)) {
      throw const AiCompanionException(AiCompanionError.missingApiKey);
    }
    if (key != null && (key.length > 512 || RegExp(r'\s').hasMatch(key))) {
      throw const AiCompanionException(AiCompanionError.invalidProvider);
    }
  }

  Future<String> analyze(
    AiCompanionSettings settings,
    String? key,
    AiCompanionMetadata metadata,
  ) async {
    if (!settings.cloudAnalysis || !settings.analysisEnabled) {
      throw const AiCompanionException(AiCompanionError.disabled);
    }
    return _complete(settings, key, <Map<String, String>>[
      <String, String>{
        'role': 'system',
        'content':
            'Suggest concise read-only improvements from these anonymous '
            'counts only. Candidates are not actual usage: Skills are loaded; '
            'Prompts activated; MCPs invoked. Never infer private content or '
            'claim measurements not provided. Do not request files or secrets.',
      },
      <String, String>{
        'role': 'user',
        'content': jsonEncode(
          const AiCompanionAnalyzer().cloudMetadata(settings, metadata),
        ),
      },
    ]);
  }

  Future<String> chat(
    AiCompanionSettings settings,
    String? key,
    List<AiChatMessage> messages,
  ) async {
    if (!settings.emotionalSupport) {
      throw const AiCompanionException(AiCompanionError.disabled);
    }
    for (final AiChatMessage message in messages) {
      if (message.text.length > 4000 ||
          !_privacy.isSafeText(message.text, providerKey: key)) {
        throw const AiCompanionException(AiCompanionError.sensitiveInput);
      }
    }
    return _complete(settings, key, <Map<String, String>>[
      <String, String>{
        'role': 'system',
        'content':
            'You are DingDong, a warm desktop companion. Listen and give '
            'brief practical support. You have no access to files, clipboard, '
            'tools or user resources. Never request or repeat credentials, '
            'passwords, tokens, private file paths or uploads. You cannot take '
            'actions. Do not claim professional diagnosis or real-world access.',
      },
      for (final AiChatMessage message in messages.skip(
        messages.length > 10 ? messages.length - 10 : 0,
      ))
        <String, String>{
          'role': message.role == 'assistant' ? 'assistant' : 'user',
          'content': message.text,
        },
    ]);
  }

  /// Explicit user action, with a constant probe and no local metadata.
  Future<void> testConnection(AiCompanionSettings settings, String? key) async {
    await _complete(settings, key, <Map<String, String>>[
      <String, String>{'role': 'user', 'content': 'Reply with OK.'},
    ]);
  }

  Future<String> _complete(
    AiCompanionSettings settings,
    String? key,
    List<Map<String, String>> messages,
  ) async {
    final Uri endpoint = validateProvider(settings);
    validateApiKey(endpoint, key);
    final String body = jsonEncode(<String, Object>{
      'model': settings.model.trim(),
      'messages': messages,
      'stream': false,
      'max_tokens': 600,
    });
    if (utf8.encode(body).length > 65536) {
      throw const AiCompanionException(AiCompanionError.messageTooLong);
    }
    try {
      final AiCompanionHttpResponse response = await _transport
          .post(
            endpoint,
            headers: <String, String>{
              'Content-Type': 'application/json',
              if (key != null && key.isNotEmpty) 'Authorization': 'Bearer $key',
            },
            body: body,
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const AiCompanionException(AiCompanionError.providerUnavailable);
      }
      if (utf8.encode(response.body).length > 65536) {
        throw const AiCompanionException(AiCompanionError.invalidResponse);
      }
      final Object? decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) {
        throw const AiCompanionException(AiCompanionError.invalidResponse);
      }
      final Object? choices = decoded['choices'];
      if (choices is! List || choices.isEmpty || choices.first is! Map) {
        throw const AiCompanionException(AiCompanionError.invalidResponse);
      }
      final Object? message = (choices.first as Map)['message'];
      final Object? content = message is Map ? message['content'] : null;
      if (content is! String ||
          content.trim().isEmpty ||
          content.length > 4000) {
        throw const AiCompanionException(AiCompanionError.invalidResponse);
      }
      if (!_privacy.isSafeText(content, providerKey: key)) {
        throw const AiCompanionException(AiCompanionError.sensitiveOutput);
      }
      return content.trim();
    } on AiCompanionException {
      rethrow;
    } on TimeoutException {
      // Closing also aborts a response that never finishes sending its body.
      _transport.close();
      throw const AiCompanionException(AiCompanionError.timeout);
    } on FormatException {
      throw const AiCompanionException(AiCompanionError.invalidResponse);
    } on Object {
      throw const AiCompanionException(AiCompanionError.providerUnavailable);
    }
  }

  void dispose() => _transport.close();
}
