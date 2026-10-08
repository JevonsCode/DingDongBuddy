import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../domain/token_usage_models.dart';
import 'token_usage_store.dart';

Future<String> tokenUsageHash(String value) =>
    tokenUsageBytesHash(utf8.encode(value));

Future<String> tokenUsageBytesHash(List<int> value) async {
  final digest = await Sha256().hash(value);
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}

/// Consumes one bounded JSONL row at a time. Only identifiers, timestamps and
/// usage counters leave this parser; message contents are never persisted.
final class TokenUsageTranscriptParser {
  TokenUsageTranscriptParser({
    required this.source,
    required this.sessionHash,
    this.lastCounterHash,
  });

  final ConversationTokenUsageSource source;
  String sessionHash;
  String? lastCounterHash;
  int malformedRows = 0;
  int undatedRows = 0;

  Future<TokenUsageImportEvent?> parse(String line) async {
    Map<String, Object?>? json;
    try {
      json = _object(jsonDecode(line));
    } on FormatException {
      malformedRows++;
      return null;
    }
    if (json == null) {
      malformedRows++;
      return null;
    }
    final type = json['type'];
    final payload = _object(json['payload']);
    final message = _object(json['message']);
    if (source == ConversationTokenUsageSource.codex &&
        type == 'session_meta') {
      final id = _text(payload?['id']);
      if (id != null) {
        final next = await tokenUsageHash('codex:session:$id');
        if (next != sessionHash) lastCounterHash = null;
        sessionHash = next;
      }
      return null;
    }
    if (source == ConversationTokenUsageSource.pi && type == 'session') {
      final id = _text(json['id']);
      if (id != null) sessionHash = await tokenUsageHash('pi:session:$id');
      return null;
    }
    if (source == ConversationTokenUsageSource.claudeCode) {
      final id = _text(json['sessionId']);
      final agentId = _text(json['agentId']);
      if (id != null) {
        sessionHash = await tokenUsageHash(
          'claude-code:session:$id:agent:${agentId ?? ''}',
        );
      }
    }
    Map<String, Object?>? usage;
    switch (source) {
      case ConversationTokenUsageSource.codex:
        if (type == 'event_msg' && payload?['type'] == 'token_count') {
          usage = _object(_object(payload?['info'])?['total_token_usage']);
        }
      case ConversationTokenUsageSource.claudeCode:
        if (type == 'assistant') usage = _object(message?['usage']);
      case ConversationTokenUsageSource.pi:
        if (type == 'message' &&
            (message?['role'] == 'assistant' ||
                message?['role'] == 'toolResult')) {
          usage = _object(message?['usage']);
        } else if (type == 'compaction' || type == 'branch_summary') {
          usage = _object(json['usage']);
        }
    }
    if (usage == null) return null;
    final at =
        _timestamp(json['timestamp']) ??
        _timestamp(message?['timestamp']) ??
        _timestamp(payload?['timestamp']);
    if (at == null) {
      // File mtime and import time do not prove when tokens were consumed.
      undatedRows++;
      return null;
    }
    final totals = _readCounts(usage);
    if (totals == null) {
      malformedRows++;
      return null;
    }
    final cumulative = source == ConversationTokenUsageSource.codex;
    final String identity;
    if (cumulative) {
      identity =
          '$sessionHash:${at.microsecondsSinceEpoch}:${totals.totalTokens}';
    } else {
      final responseId = source == ConversationTokenUsageSource.claudeCode
          ? _text(json['requestId']) ??
                _text(message?['id']) ??
                _text(json['uuid'])
          : _text(json['id']) ?? _text(message?['id']);
      // Response ids deduplicate streamed updates and copied transcripts. A
      // timestamp+counter fallback remains deterministic across restarts.
      identity = responseId != null
          ? '$sessionHash:response:$responseId'
          : '$sessionHash:${at.microsecondsSinceEpoch}:$type:${_counterIdentity(totals)}';
    }
    final identityHash = await tokenUsageHash('${source.apiValue}:$identity');
    final predecessor = lastCounterHash == identityHash
        ? null
        : lastCounterHash;
    if (cumulative) lastCounterHash = identityHash;
    return TokenUsageImportEvent(
      source: source,
      sessionHash: sessionHash,
      identityHash: identityHash,
      occurredAt: at,
      totals: totals,
      cumulative: cumulative,
      precedingCounterHash: cumulative ? predecessor : null,
    );
  }

  TokenUsageTotals? _readCounts(Map<String, Object?> usage) {
    final codex = source == ConversationTokenUsageSource.codex;
    final pi = source == ConversationTokenUsageSource.pi;
    final fresh = _integer(usage[pi ? 'input' : 'input_tokens']);
    final output = _integer(usage[pi ? 'output' : 'output_tokens']);
    final cached = _integer(
      usage[pi
          ? 'cacheRead'
          : codex
          ? 'cached_input_tokens'
          : 'cache_read_input_tokens'],
    );
    final write = codex
        ? usage.containsKey('cache_write_input_tokens')
              ? _integer(usage['cache_write_input_tokens'])
              : 0
        : _integer(usage[pi ? 'cacheWrite' : 'cache_creation_input_tokens']);
    final reasoning = _integer(
      usage[pi ? 'reasoning' : 'reasoning_output_tokens'],
    );
    final input = codex
        ? fresh
        : fresh == null || cached == null || write == null
        ? null
        : fresh + cached + write;
    final reported = _integer(usage[pi ? 'totalTokens' : 'total_tokens']);
    final componentsComplete = input != null && output != null;
    final knownTotal =
        (fresh ?? 0) +
        (output ?? 0) +
        (codex ? 0 : (cached ?? 0) + (write ?? 0));
    final total = reported ?? knownTotal;
    if (reported == null &&
        fresh == null &&
        output == null &&
        cached == null &&
        write == null) {
      return null;
    }
    return TokenUsageTotals(
      totalTokens: total,
      inputTokens: input,
      outputTokens: output,
      cachedInputTokens: cached,
      cacheWriteInputTokens: write,
      reasoningOutputTokens:
          reasoning != null && (output == null || reasoning <= output)
          ? reasoning
          : null,
      totalIsExact: reported != null || componentsComplete,
    );
  }

  static String _counterIdentity(TokenUsageTotals totals) => [
    totals.totalTokens,
    totals.inputTokens,
    totals.outputTokens,
    totals.cachedInputTokens,
    totals.cacheWriteInputTokens,
    totals.reasoningOutputTokens,
    totals.totalIsExact,
  ].join(':');

  static Map<String, Object?>? _object(Object? value) => value is Map
      ? <String, Object?>{
          for (final entry in value.entries)
            if (entry.key is String) entry.key as String: entry.value,
        }
      : null;

  static String? _text(Object? value) =>
      value is String && value.isNotEmpty ? value : null;

  static int? _integer(Object? value) {
    final number = value is int
        ? value
        : value is num && value.isFinite && value == value.roundToDouble()
        ? value.toInt()
        : value is String
        ? int.tryParse(value)
        : null;
    return number != null && number >= 0 && number <= 0x1fffffffffffff
        ? number
        : null;
  }

  static DateTime? _timestamp(Object? value) {
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    if (value is num && value.isFinite && value >= 0) {
      final micros = value >= 100000000000000
          ? value.toInt()
          : value >= 100000000000
          ? (value * 1000).toInt()
          : (value * 1000000).toInt();
      try {
        return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
      } on ArgumentError {
        return null;
      }
    }
    return null;
  }
}
