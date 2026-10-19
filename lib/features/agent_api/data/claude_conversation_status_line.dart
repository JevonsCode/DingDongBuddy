import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_api/domain/conversation_token_usage.dart';
import 'package:path/path.dart' as path;

/// A local-only renderer. Only matched DingDong tool results supply resources;
/// user text and other tools cannot create badges or confirm resource use.
///
/// Claude Code never echoes a DingDong footer. The Bridge returns a compact
/// `statusLine` receipt instead, and resource use is read passively from the
/// transcript: a Skill is marked after a successful `dingdong_load_skill`, and
/// a managed MCP after any of its tools returns a result.
final class ClaudeConversationStatusLine {
  final Map<String, String> _calls = <String, String>{};
  final List<String> _prompts = <String>[];
  final Map<String, String> _skills = <String, String>{};
  final Map<String, String> _mcps = <String, String>{};
  final Set<String> _marked = <String>{};
  final Map<String, Map<String, int?>> _usage = <String, Map<String, int?>>{};
  Map<String, Object?>? _lastReceipt;
  String? _lastHash;
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
      _clearResources();
      _calls.clear();
    }
    if (row['type'] == 'assistant') {
      final usage = _object(message?['usage']);
      if (usage != null) {
        final identity =
            row['requestId'] ??
            message?['id'] ??
            row['uuid'] ??
            'anonymous-${_anonymousResponse++}';
        _usage[identity.toString()] = {
          for (final key in const [
            'input_tokens',
            'output_tokens',
            'cache_read_input_tokens',
            'cache_creation_input_tokens',
          ])
            key: _count(usage[key]),
        };
      }
    }
    if (content is! List) return;
    for (final raw in content) {
      final block = _object(raw);
      if (block == null) continue;
      if (row['type'] == 'assistant' && block['type'] == 'tool_use') {
        final name = block['name'];
        if (name is String &&
            (name == _bridgeTool ||
                name == _loadSkillTool ||
                claudeManagedMcpServer(name) != null) &&
            block['id'] is String) {
          _calls[block['id']! as String] = name;
        }
      }
      if (row['type'] != 'user' || block['type'] != 'tool_result') continue;
      final name = _calls.remove(block['tool_use_id']);
      if (name == null) continue;
      if (name == _bridgeTool) {
        _clearResources();
      } else if (name != _loadSkillTool) {
        // A finished call counts even when the tool reported an error: the
        // marker means "called", not "succeeded".
        final server = claudeManagedMcpServer(name)!;
        if (_mcps.containsKey(server)) _marked.add('mcp:$server');
        continue;
      }
      if (block['is_error'] == true) continue;
      final result = _result(block['content']);
      if (result?['status'] != 'ok') continue;
      if (name == _bridgeTool) {
        final receipt = result?['unchanged'] == true
            ? (result?['hash'] == _lastHash ? _lastReceipt : null)
            : _object(result?['statusLine']);
        if (receipt == null) continue;
        _loaded = true;
        _lastReceipt = receipt;
        _lastHash = result?['hash'] as String?;
        _showTokens = receipt['tokens'] == true;
        final prompts = receipt['prompts'];
        if (prompts is List) _prompts.addAll(prompts.whereType<String>());
        _skills.addAll(_tokens(receipt['skills']));
        _mcps.addAll(_tokens(receipt['mcps']));
      } else {
        final id = _object(result?['skill'])?['id'];
        if (id is String && _skills.containsKey(id)) _marked.add('skill:$id');
      }
    }
  }

  void _clearResources() {
    _prompts.clear();
    _skills.clear();
    _mcps.clear();
    _marked.clear();
    _loaded = false;
  }

  String render({bool ansi = true}) {
    String color(String value, int code) =>
        ansi ? '\u001b[38;5;${code}m$value\u001b[0m' : value;
    final tokens = <String>[];
    void add(String raw, int code, {bool marked = false}) {
      if (tokens.length >= 24) return;
      // Escape sequences from transcript content must never control the terminal.
      final value = raw.replaceAll(
        RegExp(r'[\x00-\x1f\x7f-\x9f\u2028\u2029]'),
        '',
      );
      if (value.isEmpty) return;
      final safe = String.fromCharCodes(value.runes.take(128));
      tokens.add(color(marked ? '$safe*' : safe, code));
    }

    for (final token in _prompts) {
      add(token, 178);
    }
    for (final MapEntry(:key, :value) in _skills.entries) {
      add(value, 69, marked: _marked.contains('skill:$key'));
    }
    for (final MapEntry(:key, :value) in _mcps.entries) {
      add(value, 71, marked: _marked.contains('mcp:$key'));
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
    int sum(String key) => _usage.values.fold(0, (a, b) => a + (b[key] ?? 0));
    final input = sum('input_tokens');
    final output = sum('output_tokens');
    final cacheRead = sum('cache_read_input_tokens');
    final cacheWrite = sum('cache_creation_input_tokens');
    final total = input + output + cacheRead + cacheWrite;
    if (_showTokens && total > 0) {
      parts.add(
        formatConversationTokenUsage(
          ConversationTokenUsage(
            source: ConversationTokenUsageSource.claudeCode,
            breakdownComplete: _usage.values.every(
              (counts) => counts.values.every((count) => count != null),
            ),
            totalTokens: total,
            inputTokens: input,
            outputTokens: output,
            cachedInputTokens: cacheRead,
            cacheWriteInputTokens: cacheWrite,
          ),
        ),
      );
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

const String _bridgeTool = 'mcp__dingdong__dingdong_bridge';
const String _loadSkillTool = 'mcp__dingdong__dingdong_load_skill';

/// Managed DingDong MCP server named by a Claude Code tool such as
/// `mcp__dingdong-gitlab-abc123__search`, or null for any other tool.
String? claudeManagedMcpServer(String toolName) {
  if (!toolName.startsWith('mcp__')) return null;
  final rest = toolName.substring(5);
  final end = rest.indexOf('__');
  if (end <= 0) return null;
  final server = rest.substring(0, end).toLowerCase().replaceAll('_', '-');
  return server.startsWith('dingdong-') ? server : null;
}

Map<String, String> _tokens(Object? value) => <String, String>{
  if (value is Map)
    for (final MapEntry(:key, :value) in value.entries)
      if (key is String && value is String) key: value,
};

Map<String, Object?>? _object(Object? value) =>
    value is Map<String, Object?> ? value : null;
int? _count(Object? value) => value is int && value >= 0 ? value : null;
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
