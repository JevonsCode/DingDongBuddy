import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';

/// Delivers the durable completion notification used by Agent stop hooks.
final class CompletionHookNotifier {
  CompletionHookNotifier(this._transport);

  final McpHttpTransport _transport;

  Future<Map<String, Object?>> notify(
    String hookInput, {
    String? sourceOverride,
  }) async {
    final Map<String, Object?> input = _decodeInput(hookInput);
    final String source = _source(input, sourceOverride: sourceOverride);
    final String? summary = await _completionSummary(input);
    return _transport.request(
      method: 'POST',
      path: '/ding',
      body: <String, Object?>{
        'message': summary ?? '$source 已完成本轮任务',
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

String _source(Map<String, Object?> input, {String? sourceOverride}) {
  final String explicit = (sourceOverride ?? '').trim();
  if (explicit.isNotEmpty) {
    return explicit;
  }
  final String configured = (input['agent_name'] as String? ?? '').trim();
  if (configured.isNotEmpty) {
    return configured;
  }
  return 'Codex';
}

Future<String?> _completionSummary(Map<String, Object?> input) async {
  for (final String key in const <String>[
    'summary',
    'last_assistant_message',
    'last-assistant-message',
    'lastAssistantMessage',
    'assistant_message',
    'prompt_response',
    'text',
  ]) {
    final String? summary = _oneLineSummary(input[key]);
    if (summary != null) {
      return summary;
    }
  }

  final String transcriptPath = (input['transcript_path'] as String? ?? '')
      .trim();
  if (transcriptPath.isEmpty) {
    return null;
  }
  try {
    final String? message = await _lastAssistantMessage(File(transcriptPath));
    return _oneLineSummary(message);
  } on Object {
    return null;
  }
}

Future<String?> _lastAssistantMessage(File transcript) async {
  if (!await transcript.exists()) {
    return null;
  }
  final RandomAccessFile handle = await transcript.open();
  try {
    final int length = await handle.length();
    if (length == 0) {
      return null;
    }
    const int maximumBytes = 1024 * 1024;
    final int start = math.max(0, length - maximumBytes);
    await handle.setPosition(start);
    String text = utf8.decode(
      await handle.read(length - start),
      allowMalformed: true,
    );
    if (start > 0) {
      final int firstNewline = text.indexOf('\n');
      if (firstNewline < 0) {
        return null;
      }
      text = text.substring(firstNewline + 1);
    }

    String? latestAssistantMessage;
    final List<String> lines = const LineSplitter().convert(text);
    for (final String line in lines.reversed) {
      final _TranscriptMessage? message = _decodeTranscriptMessage(line);
      if (message == null) {
        continue;
      }
      latestAssistantMessage ??= message.text;
      if (message.finalAnswer) {
        return message.text;
      }
    }
    return latestAssistantMessage;
  } finally {
    await handle.close();
  }
}

_TranscriptMessage? _decodeTranscriptMessage(String line) {
  try {
    final Object? decoded = jsonDecode(line);
    if (decoded is! Map<String, Object?>) {
      return null;
    }

    // Codex JSONL transcript entry.
    final Object? rawPayload = decoded['payload'];
    if (decoded['type'] == 'response_item' &&
        rawPayload is Map<String, Object?> &&
        rawPayload['type'] == 'message' &&
        rawPayload['role'] == 'assistant') {
      final String? text = _textContent(rawPayload['content']);
      return text == null
          ? null
          : _TranscriptMessage(
              text,
              finalAnswer: rawPayload['phase'] == 'final_answer',
            );
    }

    // Claude Code and compatible JSONL transcript entry.
    final Object? rawMessage = decoded['message'];
    if (decoded['type'] == 'assistant' &&
        rawMessage is Map<String, Object?> &&
        rawMessage['role'] == 'assistant') {
      final String? text = _textContent(rawMessage['content']);
      return text == null ? null : _TranscriptMessage(text, finalAnswer: true);
    }
  } on Object {
    return null;
  }
  return null;
}

String? _textContent(Object? rawContent) {
  if (rawContent is String) {
    return rawContent.trim().isEmpty ? null : rawContent;
  }
  if (rawContent is! List<Object?>) {
    return null;
  }
  final String text = rawContent
      .whereType<Map<String, Object?>>()
      .where(
        (Map<String, Object?> item) =>
            item['type'] == 'output_text' || item['type'] == 'text',
      )
      .map((Map<String, Object?> item) => item['text'])
      .whereType<String>()
      .join('\n')
      .trim();
  return text.isEmpty ? null : text;
}

String? _oneLineSummary(Object? rawMessage) {
  if (rawMessage is! String || rawMessage.trim().isEmpty) {
    return null;
  }
  final Iterable<String> candidates = rawMessage
      .replaceAll('\r', '')
      .split('\n')
      .map(_cleanMarkdownLine)
      .where((String line) => line.isNotEmpty && !_genericHeading(line));
  final String? first = candidates.firstOrNull;
  if (first == null) {
    return null;
  }
  final String sentence = _firstSentence(
    first,
  ).replaceFirst(RegExp(r'[:：]\s*$'), '');
  const int maximumRunes = 96;
  final List<int> runes = sentence.runes.toList(growable: false);
  if (runes.length <= maximumRunes) {
    return sentence;
  }
  return '${String.fromCharCodes(runes.take(maximumRunes))}…';
}

String _cleanMarkdownLine(String rawLine) {
  String line = rawLine.trim();
  if (line.isEmpty ||
      line.startsWith('```') ||
      line.startsWith('::') ||
      line.startsWith('![')) {
    return '';
  }
  line = line
      .replaceFirst(RegExp(r'^#{1,6}\s+'), '')
      .replaceFirst(RegExp(r'^(?:[-*+]\s+|\d+[.)]\s+)'), '')
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]+\)'),
        (Match match) => match.group(1) ?? '',
      )
      .replaceAll(RegExp(r'[*_`]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return line;
}

bool _genericHeading(String line) {
  return RegExp(
    r'^(?:完成|完成情况|结果|总结|结论|done|result|summary)[:：]?$',
    caseSensitive: false,
  ).hasMatch(line);
}

String _firstSentence(String line) {
  final Match? match = RegExp(r'^(.{8,}?[。！？!?])(?:\s|$)').firstMatch(line);
  return match?.group(1) ?? line;
}

final class _TranscriptMessage {
  const _TranscriptMessage(this.text, {required this.finalAnswer});

  final String text;
  final bool finalAnswer;
}
