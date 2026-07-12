import 'dart:convert';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';

/// Clipboard-specific HTTP handlers with privacy-safe defaults.
final class ClipboardRoutes {
  ClipboardRoutes(this._store, {DateTime Function()? now})
    : _now = now ?? _utcNow;

  final ClipboardStore _store;
  final DateTime Function() _now;

  ClipboardRecord? findById(String id) {
    for (final ClipboardRecord record in _store.list(limit: 5000)) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  HttpResponseData history(Map<String, String> query) {
    final bool? includeContent = _parseBool(query['includeContent']);
    final bool? includeSensitive = _parseBool(
      query['includeSensitiveClipboard'],
    );
    if ((query.containsKey('includeContent') && includeContent == null) ||
        (query.containsKey('includeSensitiveClipboard') &&
            includeSensitive == null)) {
      return const HttpResponseData(
        statusCode: 400,
        json: <String, Object?>{
          'status': 'error',
          'message':
              'includeContent and includeSensitiveClipboard must be true or false',
        },
      );
    }
    final int limit = (int.tryParse(query['limit'] ?? '') ?? 20).clamp(0, 50);
    final String needle = query['q']?.trim().toLowerCase() ?? '';
    final String? group = _trimmedOrNull(query['group']);
    final String selectedFilter =
        _trimmedOrNull(query['filter'])?.toLowerCase() ?? 'all';
    const Set<String> filters = <String>{
      'all',
      'url',
      'command',
      'code',
      'json',
      'path',
      'image',
      'file',
      'email',
      'sensitive',
    };
    if (!filters.contains(selectedFilter)) {
      return const HttpResponseData(
        statusCode: 400,
        json: <String, Object?>{
          'status': 'error',
          'message':
              'filter must be one of all, url, command, code, json, path, image, file, email, or sensitive',
        },
      );
    }
    final List<ClipboardRecord> matched = _store
        .list(limit: 5000)
        .where((ClipboardRecord record) => _matches(record, needle))
        .where(
          (ClipboardRecord record) =>
              group == null ||
              record.group.toLowerCase() == group.toLowerCase(),
        )
        .where(
          (ClipboardRecord record) =>
              selectedFilter == 'all' || record.tags.contains(selectedFilter),
        )
        .toList(growable: false);
    final bool sensitiveIncluded = includeSensitive ?? false;
    final int hiddenSensitive = sensitiveIncluded
        ? 0
        : matched.where((ClipboardRecord record) => record.sensitive).length;
    final List<ClipboardRecord> visible = sensitiveIncluded
        ? matched
        : matched
              .where((ClipboardRecord record) => !record.sensitive)
              .toList(growable: false);
    final List<ClipboardRecord> returned = visible.take(limit).toList();
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'ok',
        'filter': <String, Object?>{
          'q': query['q'] ?? '',
          'group': group ?? 'all',
          'filter': selectedFilter,
          'limit': limit,
          'includeContent': includeContent ?? false,
          'includeSensitiveClipboard': sensitiveIncluded,
        },
        'counts': <String, Object?>{
          'matched': matched.length,
          'visible': visible.length,
          'returned': returned.length,
          'hiddenSensitive': hiddenSensitive,
        },
        'privacy': <String, Object?>{
          'contentIncluded': includeContent ?? false,
          'sensitiveClipboardIncluded': sensitiveIncluded,
          'default':
              'clipboard history returns metadata only; pass includeContent=true to read content',
          'sensitiveDefault':
              'sensitive clipboard records are hidden unless includeSensitiveClipboard=true',
        },
        'items': returned
            .map(
              (ClipboardRecord record) =>
                  record.toHistoryJson(includeContent: includeContent ?? false),
            )
            .toList(growable: false),
      },
    );
  }

  HttpResponseData overview() {
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'ok',
        'service': 'DingDong',
        'overview': _overviewObject(_store.list(limit: 5000)),
      },
    );
  }

  HttpResponseData groups() {
    final List<ClipboardRecord> records = _store.list(limit: 5000);
    final Map<String, List<ClipboardRecord>> buckets =
        <String, List<ClipboardRecord>>{};
    for (final ClipboardRecord record in records) {
      buckets.putIfAbsent(record.group, () => <ClipboardRecord>[]).add(record);
    }
    final List<Map<String, Object?>> groups =
        buckets.entries
            .map((entry) {
              final DateTime latest = entry.value
                  .map((ClipboardRecord record) => record.updatedAt)
                  .reduce(
                    (DateTime left, DateTime right) =>
                        left.isAfter(right) ? left : right,
                  );
              return <String, Object?>{
                'type': 'clipboard',
                'group': entry.key,
                'count': entry.value.length,
                'pinnedCount': entry.value
                    .where((ClipboardRecord record) => record.pinned)
                    .length,
                'latestUpdatedAt': latest.toUtc().toIso8601String(),
              };
            })
            .toList(growable: false)
          ..sort((left, right) {
            final int pinned = (right['pinnedCount'] as int).compareTo(
              left['pinnedCount'] as int,
            );
            if (pinned != 0) {
              return pinned;
            }
            final int count = (right['count'] as int).compareTo(
              left['count'] as int,
            );
            return count != 0
                ? count
                : (left['group'] as String).toLowerCase().compareTo(
                    (right['group'] as String).toLowerCase(),
                  );
          });
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'ok',
        'groups': groups,
        'overview': _overviewObject(records),
      },
    );
  }

  HttpResponseData update(String id, String body) {
    try {
      final Object? decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?> ||
          !decoded.keys.any(
            <String>{'title', 'group', 'tags', 'pinned'}.contains,
          )) {
        return _invalidPatch('title, group, tags, or pinned is required');
      }
      if (decoded.keys.any(<String>{'type', 'content', 'source'}.contains)) {
        return _invalidPatch(
          'clipboard patch cannot change type, content, or source',
        );
      }
      final String? title = decoded['title'] as String?;
      if (title != null && title.trim().isEmpty) {
        return _invalidPatch('title cannot be empty');
      }
      final ClipboardRecord? existing = findById(id);
      if (existing == null) {
        return _clipboardNotFound();
      }
      final List<String>? requestedTags = decoded.containsKey('tags')
          ? (decoded['tags'] as List<Object?>)
                .map((Object? tag) => tag as String)
                .toList(growable: false)
          : null;
      final ClipboardRecord updated = existing.copyWith(
        title: title,
        group: decoded['group'] as String?,
        tags: requestedTags == null
            ? null
            : _uniqueTags(<String>[...existing.tags, ...requestedTags]),
        pinned: decoded['pinned'] as bool?,
        updatedAt: _now().toUtc(),
      );
      _store.save(updated);
      return HttpResponseData(
        statusCode: 200,
        json: <String, Object?>{
          'status': 'updated',
          'item': updated.toHistoryJson(includeContent: false),
        },
      );
    } on Object {
      return const HttpResponseData(
        statusCode: 400,
        json: <String, Object?>{
          'status': 'error',
          'message': 'Invalid clipboard patch JSON body',
        },
      );
    }
  }
}

Map<String, Object?> _overviewObject(List<ClipboardRecord> records) {
  final Map<String, int> classifications = <String, int>{
    for (final String tag in <String>[
      'url',
      'command',
      'code',
      'json',
      'path',
      'email',
      'sensitive',
      'text',
    ])
      tag: records
          .where((ClipboardRecord record) => record.tags.contains(tag))
          .length,
  };
  return <String, Object?>{
    'total': records.length,
    'pinned': records.where((ClipboardRecord record) => record.pinned).length,
    'classificationCounts': classifications,
    'groups': _buckets(
      records.map((ClipboardRecord record) => record.group),
      limit: 8,
    ),
    'topTags': _buckets(
      records
          .expand((ClipboardRecord record) => record.tags)
          .where((String tag) => tag != 'clipboard'),
      limit: 12,
    ),
    'privacy': const <String, Object?>{
      'contentIncluded': false,
      'sensitiveContentIncluded': false,
      'note':
          'Overview returns counts only; use /agent/context with explicit flags for clipboard content.',
    },
    'agentHints': const <String>[
      'Use classification counts before deciding whether clipboard context is needed.',
      'Use /clipboard/history with explicit flags for bounded content.',
      'Sensitive clipboard content still requires includeSensitiveClipboard=true.',
    ],
  };
}

List<Map<String, Object?>> _buckets(
  Iterable<String> values, {
  required int limit,
}) {
  final Map<String, int> counts = <String, int>{};
  for (final String value in values) {
    final String trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      counts.update(trimmed, (int count) => count + 1, ifAbsent: () => 1);
    }
  }
  final List<MapEntry<String, int>> sorted = counts.entries.toList()
    ..sort((left, right) {
      final int count = right.value.compareTo(left.value);
      return count != 0
          ? count
          : left.key.toLowerCase().compareTo(right.key.toLowerCase());
    });
  return sorted
      .take(limit)
      .map(
        (MapEntry<String, int> entry) => <String, Object?>{
          'name': entry.key,
          'count': entry.value,
        },
      )
      .toList(growable: false);
}

List<String> _uniqueTags(List<String> values) {
  final Set<String> seen = <String>{};
  return values
      .where((String value) {
        final String normalized = value.trim().toLowerCase();
        return normalized.isNotEmpty && seen.add(normalized);
      })
      .map((String value) => value.trim())
      .toList(growable: false);
}

HttpResponseData _invalidPatch(String message) {
  return HttpResponseData(
    statusCode: 400,
    json: <String, Object?>{'status': 'error', 'message': message},
  );
}

HttpResponseData _clipboardNotFound() {
  return const HttpResponseData(
    statusCode: 404,
    json: <String, Object?>{
      'status': 'error',
      'message': 'Clipboard record not found',
    },
  );
}

DateTime _utcNow() => DateTime.now().toUtc();

bool _matches(ClipboardRecord record, String needle) {
  return needle.isEmpty ||
      record.title.toLowerCase().contains(needle) ||
      record.content.toLowerCase().contains(needle) ||
      record.group.toLowerCase().contains(needle) ||
      record.tags.any((String tag) => tag.toLowerCase().contains(needle));
}

bool? _parseBool(String? value) {
  return switch (value?.toLowerCase()) {
    null => null,
    'true' || '1' || 'yes' || 'on' => true,
    'false' || '0' || 'no' || 'off' => false,
    _ => null,
  };
}

String? _trimmedOrNull(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
