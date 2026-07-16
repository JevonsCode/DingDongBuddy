// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:math';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';

part 'clipboard_workflow_actions.dart';
part 'clipboard_workflow_queries.dart';

/// Higher-level clipboard workflows kept separate from history CRUD routes.
final class ClipboardWorkflowRoutes {
  ClipboardWorkflowRoutes({
    required ClipboardStore store,
    ClipboardGateway? gateway,
    ResourceStore? resourceStore,
    String Function()? idGenerator,
    DateTime Function()? now,
  }) : _store = store,
       _gateway = gateway,
       _resourceStore = resourceStore,
       _idGenerator = idGenerator ?? _generateUuid,
       _now = now ?? _utcNow;

  final ClipboardStore _store;
  final ClipboardGateway? _gateway;
  final ResourceStore? _resourceStore;
  final String Function() _idGenerator;
  final DateTime Function() _now;
}

List<String> _aliases(ClipboardRecord record) => record.tags
    .map(_normalizedAlias)
    .whereType<String>()
    .where((String alias) => alias.startsWith('alias:'))
    .map((String alias) => alias.substring(6))
    .toSet()
    .toList(growable: false);

String? _normalizedAlias(String? value) {
  final String normalized = Uri.decodeComponent(
    value ?? '',
  ).trim().toLowerCase();
  return normalized.isEmpty ? null : normalized;
}

bool _matches(ClipboardRecord item, String needle) =>
    needle.isEmpty ||
    <String>[
      item.title,
      ...item.groupNames,
      item.content,
      ...item.tags,
    ].join(' ').toLowerCase().contains(needle);

List<Map<String, Object?>> _aliasSummaries(List<ClipboardRecord> records) {
  final Map<String, List<ClipboardRecord>> buckets =
      <String, List<ClipboardRecord>>{};
  for (final ClipboardRecord record in records) {
    for (final String alias in _aliases(record)) {
      buckets.putIfAbsent(alias, () => <ClipboardRecord>[]).add(record);
    }
  }
  final List<String> names = buckets.keys.toList()..sort();
  return names
      .map(
        (String alias) => <String, Object?>{
          'alias': alias,
          'count': buckets[alias]!.length,
          'pinnedCount': buckets[alias]!
              .where((ClipboardRecord item) => item.pinned)
              .length,
        },
      )
      .toList(growable: false);
}

List<Map<String, Object?>> _groupSummaries(List<ClipboardRecord> records) {
  final Map<String, List<ClipboardRecord>> groups =
      <String, List<ClipboardRecord>>{};
  for (final ClipboardRecord record in records) {
    for (final String group in record.groupNames) {
      groups.putIfAbsent(group, () => <ClipboardRecord>[]).add(record);
    }
  }
  return groups.entries
      .map(
        (entry) => <String, Object?>{
          'group': entry.key,
          'count': entry.value.length,
          'pinned': entry.value.where((item) => item.pinned).length,
          'classifications': _classificationCounts(entry.value),
        },
      )
      .toList(growable: false);
}

Map<String, int> _classificationCounts(List<ClipboardRecord> records) {
  final Map<String, int> counts = <String, int>{};
  for (final ClipboardRecord record in records) {
    counts.update(
      record.kind.name,
      (int value) => value + 1,
      ifAbsent: () => 1,
    );
  }
  return counts;
}

Map<String, Object?> _candidate(ClipboardRecord record) => <String, Object?>{
  ...record.toHistoryJson(includeContent: false),
  'aliases': _aliases(record),
  'suggestedActions': <String>[
    'PATCH /clipboard/{id}',
    'POST /clipboard/promote/{id}',
  ],
};

List<Map<String, Object?>> _recommendations(List<ClipboardRecord> records) {
  final int commands = records
      .where((ClipboardRecord record) => record.tags.contains('command'))
      .length;
  return <Map<String, Object?>>[
    if (commands > 0)
      <String, Object?>{
        'id': 'alias-frequent-commands',
        'title': 'Create aliases for repeat commands',
        'reason': '$commands command clipboard records can become snippets.',
        'action': 'PATCH /clipboard/{id} with tags including alias:name',
      },
  ];
}

({bool includeContent, bool includeSensitive})? _privacyQuery(
  Map<String, String> query,
) {
  final bool? content = _parseBool(query['includeContent']);
  final bool? sensitive = _parseBool(query['includeSensitiveClipboard']);
  if ((query.containsKey('includeContent') && content == null) ||
      (query.containsKey('includeSensitiveClipboard') && sensitive == null)) {
    return null;
  }
  return (
    includeContent: content ?? false,
    includeSensitive: sensitive ?? false,
  );
}

bool? _parseBool(String? value) => switch (value?.toLowerCase()) {
  null => null,
  'true' || '1' || 'yes' || 'on' => true,
  'false' || '0' || 'no' || 'off' => false,
  _ => null,
};

List<String> _unique(List<String> values) => values.toSet().toList();

HttpResponseData _badRequest(String message) => HttpResponseData(
  statusCode: 400,
  json: <String, Object?>{'status': 'error', 'message': message},
);

HttpResponseData _invalidPrivacy() => _badRequest(
  'includeContent and includeSensitiveClipboard must be true or false',
);

HttpResponseData _unavailable(String message) => HttpResponseData(
  statusCode: 503,
  json: <String, Object?>{'status': 'error', 'message': message},
);

DateTime _utcNow() => DateTime.now().toUtc();

String _generateUuid() {
  final Random random = Random.secure();
  final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final String hex = bytes
      .map((int byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
          '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
          '${hex.substring(20)}'
      .toUpperCase();
}
