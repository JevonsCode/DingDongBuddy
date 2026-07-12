part of 'clipboard_workflow_routes.dart';

extension ClipboardWorkflowQueries on ClipboardWorkflowRoutes {
  HttpResponseData snippets(Map<String, String> query) {
    final ({bool includeContent, bool includeSensitive})? privacy =
        _privacyQuery(query);
    if (privacy == null) {
      return _invalidPrivacy();
    }
    final String? selectedAlias = _normalizedAlias(query['alias']);
    if (query.containsKey('alias') && selectedAlias == null) {
      return _badRequest('alias cannot be empty');
    }
    final String needle = (query['q'] ?? '').trim().toLowerCase();
    final int limit = (int.tryParse(query['limit'] ?? '') ?? 20).clamp(0, 50);
    final List<ClipboardRecord> snippets = _store
        .list(limit: 5000)
        .where((ClipboardRecord record) => _aliases(record).isNotEmpty)
        .where(
          (ClipboardRecord record) =>
              selectedAlias == null || _aliases(record).contains(selectedAlias),
        )
        .where((ClipboardRecord record) => _matches(record, needle))
        .toList(growable: false);
    final int hiddenSensitive = privacy.includeSensitive
        ? 0
        : snippets.where((ClipboardRecord item) => item.sensitive).length;
    final List<ClipboardRecord> visible = privacy.includeSensitive
        ? snippets
        : snippets
              .where((ClipboardRecord item) => !item.sensitive)
              .toList(growable: false);
    final List<ClipboardRecord> returned = visible.take(limit).toList();
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'ok',
        'filter': <String, Object?>{
          'alias': selectedAlias ?? 'all',
          'q': query['q'] ?? '',
          'limit': limit,
          'includeContent': privacy.includeContent,
          'includeSensitiveClipboard': privacy.includeSensitive,
        },
        'counts': <String, Object?>{
          'snippetRecords': snippets.length,
          'matched': snippets.length,
          'visible': visible.length,
          'returned': returned.length,
          'hiddenSensitive': hiddenSensitive,
        },
        'aliases': _aliasSummaries(visible),
        'privacy': <String, Object?>{
          'contentIncluded': privacy.includeContent,
          'sensitiveClipboardIncluded': privacy.includeSensitive,
          'default':
              'clipboard snippets return metadata only; pass includeContent=true to read content',
        },
        'items': returned
            .map(
              (ClipboardRecord record) => <String, Object?>{
                ...record.toHistoryJson(includeContent: privacy.includeContent),
                'aliases': _aliases(record),
              },
            )
            .toList(growable: false),
      },
    );
  }

  HttpResponseData digest(Map<String, String> query) {
    final String task = (query['q'] ?? query['task'] ?? '').trim();
    if (task.isEmpty) {
      return _badRequest('q or task is required');
    }
    final ({bool includeContent, bool includeSensitive})? privacy =
        _privacyQuery(query);
    if (privacy == null) {
      return _invalidPrivacy();
    }
    final int requestedLimit = int.tryParse(query['limit'] ?? '') ?? 8;
    final int limit = requestedLimit.clamp(0, 30);
    final Set<String> tokens = task
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9\u4e00-\u9fff]+'))
        .where((String token) => token.length >= 2)
        .toSet();
    final List<ClipboardRecord> matched = _store
        .list(limit: 5000)
        .where((ClipboardRecord item) {
          final String haystack = <String>[
            item.title,
            item.group,
            item.content,
            ...item.tags,
          ].join(' ').toLowerCase();
          return tokens.isEmpty || tokens.any(haystack.contains);
        })
        .toList(growable: false);
    final int hidden = privacy.includeSensitive
        ? 0
        : matched.where((ClipboardRecord item) => item.sensitive).length;
    final List<ClipboardRecord> visible = privacy.includeSensitive
        ? matched
        : matched
              .where((ClipboardRecord item) => !item.sensitive)
              .toList(growable: false);
    final List<ClipboardRecord> returned = visible.take(limit).toList();
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'ok',
        'service': 'DingDong',
        'generatedAt': _now().toUtc().toIso8601String(),
        'purpose':
            'Task-scoped clipboard digest for local AI agents, with content hidden by default.',
        'task': task,
        'privacy': <String, Object?>{
          'contentIncluded': privacy.includeContent,
          'sensitiveClipboardIncluded': privacy.includeSensitive,
          'hiddenSensitiveItems': hidden,
        },
        'counts': <String, Object?>{
          'totalClipboard': _store.list(limit: 5000).length,
          'matched': matched.length,
          'visible': visible.length,
          'returned': returned.length,
          'hiddenSensitive': hidden,
        },
        'byGroup': _groupSummaries(visible),
        'byClassification': _classificationCounts(visible),
        'candidates': returned
            .map(
              (ClipboardRecord record) => <String, Object?>{
                ...record.toHistoryJson(includeContent: privacy.includeContent),
                'aliases': _aliases(record),
                if (privacy.includeContent)
                  'contentExcerpt': record.content.length <= 420
                      ? record.content
                      : '${record.content.substring(0, 420)}\n[truncated]',
              },
            )
            .toList(growable: false),
        'agentActions': <String>[
          'GET /clipboard/history?q=${Uri.encodeQueryComponent(task)}&limit=20',
          'GET /clipboard/groups',
        ],
      },
    );
  }

  HttpResponseData insights(Map<String, String> query) {
    final bool? includeSensitive = _parseBool(
      query['includeSensitiveClipboard'],
    );
    if (query.containsKey('includeSensitiveClipboard') &&
        includeSensitive == null) {
      return _badRequest('includeSensitiveClipboard must be true or false');
    }
    final int limit = (int.tryParse(query['limit'] ?? '') ?? 8).clamp(0, 20);
    final List<ClipboardRecord> all = _store.list(limit: 5000);
    final List<ClipboardRecord> visible = includeSensitive ?? false
        ? all
        : all
              .where((ClipboardRecord record) => !record.sensitive)
              .toList(growable: false);
    final List<ClipboardRecord> snippetCandidates = visible
        .where((ClipboardRecord record) => _aliases(record).isNotEmpty)
        .toList(growable: false);
    final List<ClipboardRecord> promoteCandidates = visible
        .where(
          (ClipboardRecord record) =>
              !record.pinned &&
              record.tags.any(
                <String>{
                  'command',
                  'code',
                  'json',
                  'url',
                  'path',
                  'text',
                }.contains,
              ),
        )
        .toList(growable: false);
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'ok',
        'service': 'DingDong',
        'generatedAt': _now().toUtc().toIso8601String(),
        'counts': <String, Object?>{
          'total': all.length,
          'visible': visible.length,
          'pinned': visible.where((ClipboardRecord item) => item.pinned).length,
          'snippetCandidates': snippetCandidates.length,
          'promoteCandidates': promoteCandidates.length,
        },
        'recommendations': _recommendations(visible),
        'snippetCandidates': snippetCandidates
            .take(limit)
            .map(_candidate)
            .toList(growable: false),
        'promoteCandidates': promoteCandidates
            .take(limit)
            .map(_candidate)
            .toList(growable: false),
      },
    );
  }
}
