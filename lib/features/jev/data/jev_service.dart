import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/jev/data/jev_store.dart';

abstract interface class JevVault {
  Future<bool> containsKey();
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

final class JevException implements Exception {
  const JevException(this.code);
  final String code;
  @override
  String toString() => 'Jev: $code';
}

typedef JevTransport =
    Future<Map<String, Object?>> Function(
      String key,
      Map<String, Object?> body,
    );

/// No background requests or retries. Configuration is a local UI-only API.
final class JevService {
  JevService(
    this.store,
    this.vault, {
    JevTransport? transport,
    DateTime Function()? now,
  }) : _transport = transport ?? sendJevRequest,
       _now = now ?? DateTime.now;
  static const model = 'jev-1.13.0';
  final JevStore store;
  final JevVault vault;
  final JevTransport _transport;
  final DateTime Function() _now;
  Future<void> _writes = Future<void>.value();

  Future<Map<String, Object?>> manage(
    String action,
    Map<String, Object?> arguments,
  ) async {
    try {
      switch (action) {
        case 'status':
          break;
        case 'install':
          await install();
        case 'saveKey':
          await saveKey(arguments['key'] as String);
        case 'removeKey':
          await removeKey();
        case 'enable':
          await setEnabled(arguments['enabled'] == true);
        case 'uninstall':
          await uninstall();
        case 'verify':
          await decide('noul', {
            'state': 'A box contains exactly three red balls.',
            'instructions': 'Does the box contain at least one red ball?',
            'source': 'DingDong',
          });
        default:
          throw const JevException('invalid_request');
      }
      return {
        ...await status(),
        if (action == 'verify') 'verificationSucceeded': true,
      };
    } on JevException {
      rethrow;
    } on Object {
      throw const JevException('local_storage_failed');
    }
  }

  Future<void> _mutate(Future<void> Function() operation) {
    final next = _writes.then((_) => operation());
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<Map<String, Object?>> status() async {
    final installed = store.installed;
    var configured = false;
    if (installed) {
      try {
        // Status needs presence metadata, not a credential read that may prompt.
        configured = await vault.containsKey().timeout(
          const Duration(seconds: 2),
        );
      } on Object {
        throw const JevException('local_storage_failed');
      }
    }
    final now = _now();
    return {
      'installed': installed,
      'enabled': store.enabled,
      'configured': configured,
      'ready': installed && configured && store.enabled,
      'model': model,
      'usage': store.usage(),
      'today': store.usage(since: DateTime(now.year, now.month, now.day)),
      'input_usd_per_million_tokens': 0.042,
      'output_usd': 0,
      'price_checked': '2026-09-21',
    };
  }

  Future<void> install() => _mutate(() async {
    store.install();
  });
  Future<void> saveKey(String value) => _mutate(() async {
    if (!store.installed) throw const JevException('not_installed');
    final key = value.trim();
    if (key.length < 20 || key.length > 4096 || RegExp(r'\s').hasMatch(key)) {
      throw const JevException('invalid_key');
    }
    store.setEnabled(false);
    await vault.write(key);
  });
  Future<void> setEnabled(bool enabled) => _mutate(() async {
    if (!store.installed) throw const JevException('not_installed');
    if (enabled && (await vault.read())?.isNotEmpty != true) {
      throw const JevException('key_required');
    }
    store.setEnabled(enabled);
  });
  Future<void> removeKey() => _mutate(() async {
    store.setEnabled(false);
    await vault.delete();
  });
  Future<void> uninstall() => _mutate(() async {
    store.setEnabled(false);
    await vault.delete();
    store.uninstall(); // Usage remains available after reinstall.
  });

  Future<Map<String, Object?>> decide(
    String type,
    Map<String, Object?> arguments,
  ) async {
    if (!store.enabled) throw const JevException('disabled');
    final state = arguments['state'];
    final instructions = arguments['instructions'];
    if (state is! String ||
        state.trim().isEmpty ||
        state.length > 20000 ||
        instructions is! String ||
        instructions.trim().isEmpty ||
        instructions.length > 2000) {
      throw const JevException('invalid_request');
    }
    final criteria = arguments['criteria'];
    if (!['noul', 'choice', 'score'].contains(type) ||
        (type == 'choice' &&
            (criteria is! Map<String, Object?> ||
                criteria.length < 2 ||
                criteria.length > 255 ||
                criteria.entries.any(
                  (e) =>
                      e.key.isEmpty ||
                      e.key.length > 200 ||
                      (e.value != null &&
                          (e.value is! String ||
                              (e.value as String).length > 1000)),
                ))) ||
        (type == 'score' &&
            (criteria is! List ||
                criteria.length < 2 ||
                criteria.length > 10 ||
                criteria.any(
                  (e) => e is! String || e.isEmpty || e.length > 1000,
                )))) {
      throw const JevException('invalid_request');
    }
    final question = <String, Object?>{
      'type': type,
      'instructions': instructions,
      if (type != 'noul') 'criteria': criteria,
    };
    final body = <String, Object?>{
      'model': model,
      'state': state,
      'questions': {'decision': question},
    };
    if (utf8.encode(jsonEncode(body)).length > 24000) {
      throw const JevException('request_too_large');
    }
    String contextValue(String name) {
      final value = arguments[name];
      if (value != null && (value is! String || value.length > 200)) {
        throw const JevException('invalid_request');
      }
      return (value as String? ?? '').trim();
    }

    final source = contextValue('source').toLowerCase();
    final conversation = contextValue('conversationId');
    final key = await vault.read();
    if (key == null || key.isEmpty) throw const JevException('key_required');
    if (!store.enabled) throw const JevException('disabled');
    // Commit unknown usage BEFORE sending. A crash cannot silently become zero.
    final id = store.begin(_now(), source, conversation);
    int? input;
    int? output;
    try {
      final data = await _transport(key, body);
      final usage = data['usage'];
      if (usage is Map) {
        final i = usage['input_tokens'];
        final o = usage['output_tokens'];
        if (i is int && i >= 0) input = i;
        if (o is int && o >= 0) output = o;
      }
      final answers = data['answers'];
      final answer = answers is Map ? answers['decision'] : null;
      if (data['model'] != model ||
          input == null ||
          output == null ||
          !_validAnswer(answer, question)) {
        throw const JevException('invalid_response');
      }
      store.finish(id, 'success', input: input, output: output);
      return {
        'status': 'ok',
        'model': model,
        'answer': answer,
        'usage': {'input_tokens': input, 'output_tokens': output},
        'estimated_usd': input * 0.042 / 1000000,
        'price_checked': '2026-09-21',
        'is_bill': false,
        'jev_conversation_usage': conversation.isEmpty
            ? null
            : store.usage(source: source, conversation: conversation),
      };
    } catch (error) {
      store.finish(id, 'failed', input: input, output: output);
      if (error is JevException) rethrow;
      throw const JevException(
        'request_failed',
      ); // Never expose keys or bodies in exception messages.
    }
  }
}

bool _probability(Object? value) =>
    value is num && value.isFinite && value >= 0 && value <= 1;
bool _validAnswer(Object? value, Map<String, Object?> question) {
  if (value is! Map || value['type'] != question['type']) return false;
  if (question['type'] == 'noul') return _probability(value['noul']);
  final probs = value['probabilities'];
  if (!_probability(value['confidence']) ||
      probs is! Map ||
      probs.isEmpty ||
      !probs.values.every(_probability)) {
    return false;
  }
  final keys = question['type'] == 'choice'
      ? (question['criteria'] as Map).keys.toSet()
      : List.generate(
          (question['criteria'] as List).length,
          (i) => '$i',
        ).toSet();
  if (probs.length != keys.length ||
      !keys.every(probs.containsKey) ||
      ((probs.values.cast<num>().fold<double>(0, (a, b) => a + b)) - 1).abs() >
          0.01) {
    return false;
  }
  if (question['type'] == 'choice') return keys.contains(value['choice']);
  final score = value['score'];
  return score is num &&
      score.isFinite &&
      score >= 0 &&
      score <= keys.length - 1;
}

Future<Map<String, Object?>> sendJevRequest(
  String key,
  Map<String, Object?> body,
) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 25);
  try {
    return await (() async {
      final request = await client.postUrl(
        Uri.parse('https://api.typesafe.ai/v1/systemone'),
      );
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $key');
      request.write(jsonEncode(body));
      final response = await request.close();
      if (response.statusCode != 200) {
        throw JevException('http_${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response) {
        bytes.addAll(chunk);
        if (bytes.length > 262144) throw const JevException('invalid_response');
      }
      return jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    })().timeout(const Duration(seconds: 25));
  } on JevException {
    rethrow;
  } on Object {
    throw const JevException('request_failed');
  } finally {
    client.close(force: true);
  }
}
