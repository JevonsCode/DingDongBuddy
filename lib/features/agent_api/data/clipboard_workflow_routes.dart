// ignore_for_file: prefer_initializing_formals

import 'dart:convert';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/platform/clipboard_gateway.dart';
import 'package:dingdong/core/utils/uuid.dart';
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
       _idGenerator = idGenerator ?? generateUuid,
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

/// Text an Agent may search; clipboard title and content only when the user
/// allows Agent clipboard-content access.
String _searchableText(ClipboardRecord item, {required bool revealText}) =>
    <String>[
      if (revealText) item.title,
      ...item.groupNames,
      if (revealText) item.content,
      ...item.tags,
    ].join(' ').toLowerCase();

bool _matches(
  ClipboardRecord item,
  String needle, {
  required bool revealText,
}) =>
    needle.isEmpty ||
    _searchableText(item, revealText: revealText).contains(needle);

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

Map<String, Object?> _candidate(
  ClipboardRecord record, {
  required bool revealText,
}) => <String, Object?>{
  ...record.toHistoryJson(includeContent: false, includeTitle: revealText),
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
  final bool? content = parseQueryBool(query['includeContent']);
  final bool? sensitive = parseQueryBool(query['includeSensitiveClipboard']);
  if ((query.containsKey('includeContent') && content == null) ||
      (query.containsKey('includeSensitiveClipboard') && sensitive == null)) {
    return null;
  }
  return (
    includeContent: content ?? false,
    includeSensitive: sensitive ?? false,
  );
}

List<String> _unique(List<String> values) => values.toSet().toList();

HttpResponseData _invalidPrivacy() => HttpResponseData.badRequest(
  'includeContent and includeSensitiveClipboard must be true or false',
);

HttpResponseData _unavailable(String message) =>
    HttpResponseData.error(503, message);

DateTime _utcNow() => DateTime.now().toUtc();
