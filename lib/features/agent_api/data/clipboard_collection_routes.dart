import 'dart:convert';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_api/data/http_response_data.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';

/// Converts explicitly selected task clipboard context into durable knowledge.
final class ClipboardCollectionRoutes {
  const ClipboardCollectionRoutes({
    required this.clipboardStore,
    required this.resourceStore,
    required this.idGenerator,
    required this.now,
  });

  final ClipboardStore clipboardStore;
  final ResourceStore resourceStore;
  final String Function() idGenerator;
  final DateTime Function() now;

  Future<HttpResponseData> collect(String body) async {
    try {
      final Map<String, Object?> payload =
          jsonDecode(body) as Map<String, Object?>;
      final String title = (payload['title'] as String? ?? '').trim();
      if (title.isEmpty) {
        return _badRequest('title is required');
      }
      final String task =
          (payload['task'] as String? ?? payload['q'] as String? ?? '').trim();
      final Set<String> ids =
          (payload['ids'] as List<Object?>? ?? const <Object?>[])
              .cast<String>()
              .toSet();
      if (task.isEmpty && ids.isEmpty) {
        return _badRequest('task, q, or ids is required');
      }
      final bool includeSensitive =
          payload['includeSensitiveClipboard'] as bool? ?? false;
      final int limit = (payload['limit'] as int? ?? 12).clamp(1, 30);
      final List<ClipboardRecord> selected = clipboardStore
          .list(limit: 5000)
          .where((ClipboardRecord item) => includeSensitive || !item.sensitive)
          .where(
            (ClipboardRecord item) =>
                ids.contains(item.id) || _matches(item, task),
          )
          .take(limit)
          .toList(growable: false);
      if (selected.isEmpty) {
        return const HttpResponseData(
          statusCode: 404,
          json: <String, Object?>{
            'status': 'error',
            'message': 'No matching clipboard records',
          },
        );
      }
      final DateTime timestamp = now().toUtc();
      final Resource collection = Resource(
        id: idGenerator(),
        type: ResourceType.knowledge,
        group: payload['group'] as String? ?? 'Clipboard Collections',
        title: title,
        content: _collectionContent(title, task, selected),
        tags: <String>[
          'clipboard-collection',
          ...(payload['tags'] as List<Object?>? ?? const <Object?>[])
              .cast<String>(),
        ],
        source: payload['source'] as String? ?? 'Clipboard Collection',
        pinned: payload['pinned'] as bool? ?? false,
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      await resourceStore.save(<Resource>[
        ...await resourceStore.load(),
        collection,
      ]);
      return HttpResponseData(
        statusCode: 201,
        json: <String, Object?>{
          'status': 'created',
          'item': collection.toApiJson(),
          'included': selected
              .map(
                (ClipboardRecord item) =>
                    item.toHistoryJson(includeContent: false),
              )
              .toList(growable: false),
          'privacy': <String, Object?>{
            'sensitiveClipboardIncluded': includeSensitive,
            'default':
                'clipboard collections exclude sensitive records unless explicitly included',
          },
        },
      );
    } on Object {
      return _badRequest('Invalid clipboard collection JSON body');
    }
  }
}

bool _matches(ClipboardRecord item, String task) {
  if (task.isEmpty) {
    return false;
  }
  final Set<String> tokens = task
      .toLowerCase()
      .split(RegExp(r'[^\p{L}\p{N}_-]+', unicode: true))
      .where((String token) => token.length >= 2)
      .toSet();
  final String haystack = <String>[
    item.title,
    ...item.groupNames,
    item.content,
    ...item.tags,
  ].join(' ').toLowerCase();
  return tokens.any(haystack.contains);
}

String _collectionContent(
  String title,
  String task,
  List<ClipboardRecord> items,
) {
  final StringBuffer output = StringBuffer('# $title\n');
  if (task.isNotEmpty) {
    output.writeln('\nTask: $task');
  }
  for (final ClipboardRecord item in items) {
    output
      ..writeln('\n## ${item.title}')
      ..writeln(item.content);
  }
  return output.toString().trim();
}

HttpResponseData _badRequest(String message) => HttpResponseData(
  statusCode: 400,
  json: <String, Object?>{'status': 'error', 'message': message},
);
