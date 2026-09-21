import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:path/path.dart' as path;

/// A local-only renderer. Only matched DingDong tool results supply resources;
/// user text and other tools cannot create badges or confirm resource use.
final class ClaudeConversationStatusLine {
  final Map<String, String> _calls = <String, String>{};
  final Map<String, Map<String, Object?>> _items =
      <String, Map<String, Object?>>{};
  final Map<String, int> _usage = <String, int>{};
  bool _loaded = false;
  bool _showTokens = false;
  int _anonymousResponse = 0;

  void accept(Map<String, Object?> row) {
    final message = _object(row['message']);
    final content = message?['content'];
    if (row['type'] == 'user' &&
        row['isMeta'] != true &&
        (content is String ||
            content is List &&
                content.any((b) => _object(b)?['type'] == 'text'))) {
      _items.clear();
      _calls.clear();
      _loaded = false;
    }
    if (row['type'] == 'assistant') {
      final usage = _object(message?['usage']);
      if (usage != null) {
        final identity =
            row['requestId'] ??
            message?['id'] ??
            row['uuid'] ??
            'anonymous-${_anonymousResponse++}';
        _usage[identity.toString()] = <String>[
          'input_tokens',
          'output_tokens',
          'cache_read_input_tokens',
          'cache_creation_input_tokens',
        ].fold(0, (total, key) => total + _count(usage[key]));
      }
    }
    if (content is! List) return;
    for (final raw in content) {
      final block = _object(raw);
      if (block == null) continue;
      if (row['type'] == 'assistant' && block['type'] == 'tool_use') {
        final name = block['name'];
        if (name is String &&
            const <String>{
              'mcp__dingdong__dingdong_bridge',
              'mcp__dingdong__dingdong_load_skill',
              'mcp__dingdong__dingdong_confirm_mcp_use',
            }.contains(name) &&
            block['id'] is String) {
          _calls[block['id']! as String] = name;
        }
      }
      if (row['type'] != 'user' || block['type'] != 'tool_result') continue;
      final name = _calls.remove(block['tool_use_id']);
      if (name == null) continue;
      final isBridge = name.endsWith('__dingdong_bridge');
      if (isBridge) {
        _items.clear();
        _loaded = false;
      }
      if (block['is_error'] == true) continue;
      final result = _result(block['content']);
      if (result?['status'] != 'ok') continue;
      final conversation = _object(result?['conversation']);
      if (isBridge) {
        _loaded = true;
        final capsule = _object(conversation?['capsule']);
        _showTokens = capsule?['tokenUsage'] != null;
        if (conversation?['visible'] != true) continue;
        final items = capsule?['items'];
        if (items is List) {
          for (final rawItem in items.take(24)) {
            final item = _object(rawItem);
            if (item?['mergeKey'] is String) {
              _items[item!['mergeKey']! as String] = item;
            }
          }
        }
      } else {
        final item = _object(conversation?['item']);
        final key = item?['mergeKey'];
        if (key is String &&
            _items.containsKey(key) &&
            item?['confirmedUse'] == true) {
          _items[key] = item!;
        }
      }
    }
  }

  String render({bool ansi = true}) {
    String color(String value, int code) =>
        ansi ? '\u001b[38;5;${code}m$value\u001b[0m' : value;
    final tokens = <String>[];
    for (final item in _items.values) {
      final raw = item['lineToken'];
      if (raw is! String) continue;
      // Escape sequences from transcript content must never control the terminal.
      final value = raw
          .replaceAll(RegExp(r'[\x00-\x1f\x7f-\x9f\u2028\u2029]'), '')
          .replaceAll(r'\*', '*')
          .replaceAll(r'\|', '|');
      if (value.isEmpty) continue;
      final safe = String.fromCharCodes(value.runes.take(128));
      tokens.add(
        color(safe, switch (item['type']) {
          'prompt' => 178,
          'skill' => 69,
          _ => 71,
        }),
      );
    }
    final parts = <String>[
      'DingDong',
      if (tokens.isNotEmpty)
        tokens.join(' | ')
      else if (!_loaded)
        '本轮未加载'
      else
        '本轮无可见资源',
    ];
    final total = _usage.values.fold(0, (a, b) => a + b);
    if (_showTokens && total > 0) {
      parts.add('${formatCompactConversationTokenCount(total)} Token');
    }
    return parts.join(' · ');
  }

  static Future<String> fromInput(String input) async {
    try {
      final payload = _object(jsonDecode(input));
      final transcript = payload?['transcript_path'];
      final session = payload?['session_id'];
      if (transcript is! String ||
          session is! String ||
          !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(session)) {
        return '';
      }
      final file = File(transcript);
      if (!file.isAbsolute ||
          path.basename(file.path) != '$session.jsonl' ||
          !await file.exists()) {
        return '';
      }
      final renderer = ClaudeConversationStatusLine();
      await for (final line
          in file
              .openRead()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        try {
          final row = _object(jsonDecode(line));
          if (row != null &&
              (row['sessionId'] == null || row['sessionId'] == session)) {
            renderer.accept(row);
          }
        } on FormatException {
          /* An in-progress JSONL tail is normal. */
        }
      }
      return renderer.render();
    } on Object {
      return '';
    }
  }
}

Map<String, Object?>? _object(Object? value) =>
    value is Map<String, Object?> ? value : null;
int _count(Object? value) => value is int && value >= 0 ? value : 0;
Map<String, Object?>? _result(Object? content) {
  final texts = content is String
      ? <String>[content]
      : content is List
      ? content.map((item) => _object(item)?['text']).whereType<String>()
      : const <String>[];
  for (final text in texts) {
    try {
      final result = _object(jsonDecode(text));
      if (result != null) return result;
    } on FormatException {
      /* Non-JSON tool output is not a footer receipt. */
    }
  }
  return null;
}

/// Preserve an existing user status line by feeding it the same stdin payload.
Future<String> runPreviousClaudeStatusLine(
  String? configPath,
  String input,
) async {
  if (configPath == null) return '';
  Process? process;
  try {
    final config = _object(jsonDecode(await File(configPath).readAsString()));
    final command = config?['command'];
    if (command is! String ||
        command.isEmpty ||
        command.contains('--claude-statusline')) {
      return '';
    }
    process = await Process.start(
      Platform.isWindows ? 'cmd.exe' : '/bin/sh',
      Platform.isWindows
          ? <String>['/d', '/s', '/c', command]
          : <String>['-c', command],
    );
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.drain<void>();
    process.stdin.write(input);
    await process.stdin.close();
    final text = await output.timeout(const Duration(seconds: 3));
    await process.exitCode.timeout(const Duration(seconds: 1));
    await errors;
    return text.trimRight();
  } on Object {
    process?.kill();
    return '';
  }
}
