part of 'clipboard_workflow_routes.dart';

extension ClipboardWorkflowActions on ClipboardWorkflowRoutes {
  Future<HttpResponseData> restoreSnippet(
    String alias,
    Map<String, String> query,
  ) async {
    final String? normalized = _normalizedAlias(alias);
    final bool? includeSensitive = _parseBool(
      query['includeSensitiveClipboard'],
    );
    if (normalized == null ||
        (query.containsKey('includeSensitiveClipboard') &&
            includeSensitive == null)) {
      return _badRequest('Invalid clipboard snippet alias');
    }
    final List<ClipboardRecord> matches =
        _store
            .list(limit: 5000)
            .where(
              (ClipboardRecord item) => _aliases(item).contains(normalized),
            )
            .where(
              (ClipboardRecord item) =>
                  (includeSensitive ?? false) || !item.sensitive,
            )
            .toList()
          ..sort((ClipboardRecord left, ClipboardRecord right) {
            if (left.pinned != right.pinned) {
              return left.pinned ? -1 : 1;
            }
            return right.updatedAt.compareTo(left.updatedAt);
          });
    if (matches.isEmpty) {
      return const HttpResponseData(
        statusCode: 404,
        json: <String, Object?>{
          'status': 'error',
          'message': 'Clipboard snippet not found',
        },
      );
    }
    final ClipboardGateway? gateway = _gateway;
    if (gateway == null) {
      return _unavailable('Could not restore clipboard snippet');
    }
    final ClipboardRecord record = matches.first;
    await gateway.writeText(record.content);
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'restored',
        'alias': normalized,
        'id': record.id,
        'title': record.title,
        'contentCharacterCount': record.content.length,
      },
    );
  }

  Future<HttpResponseData> promote(String id, String body) async {
    final ClipboardRecord? clipboard = _store
        .list(limit: 5000)
        .where((ClipboardRecord record) => record.id == id)
        .firstOrNull;
    if (clipboard == null) {
      return const HttpResponseData(
        statusCode: 404,
        json: <String, Object?>{
          'status': 'error',
          'message': 'Clipboard record not found',
        },
      );
    }
    final ResourceStore? resourceStore = _resourceStore;
    if (resourceStore == null) {
      return _unavailable('Resource library is not available');
    }
    try {
      final Map<String, Object?> payload = body.trim().isEmpty
          ? <String, Object?>{}
          : jsonDecode(body) as Map<String, Object?>;
      final ResourceType type = payload['targetType'] == null
          ? ResourceType.prompt
          : ResourceType.parse(payload['targetType']);
      if (!type.isLibraryResource) {
        return _badRequest('targetType cannot be clipboard');
      }
      final DateTime timestamp = _now().toUtc();
      final Resource promoted = Resource(
        id: _idGenerator(),
        type: type,
        group: payload['group'] as String?,
        title: (payload['title'] as String?)?.trim().isNotEmpty ?? false
            ? (payload['title'] as String).trim()
            : clipboard.title,
        content: clipboard.content,
        tags: _unique(<String>[
          ...(payload['tags'] as List<Object?>? ?? clipboard.tags).map(
            (Object? tag) => tag as String,
          ),
          'from-clipboard',
        ]),
        source: 'Clipboard',
        pinned: payload['pinned'] as bool? ?? false,
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      await resourceStore.save(<Resource>[
        ...await resourceStore.load(),
        promoted,
      ]);
      return HttpResponseData(
        statusCode: 201,
        json: <String, Object?>{
          'status': 'promoted',
          'sourceID': clipboard.id,
          'item': promoted.toApiJson(),
        },
      );
    } on Object {
      return _badRequest('Invalid promotion JSON body');
    }
  }
}
