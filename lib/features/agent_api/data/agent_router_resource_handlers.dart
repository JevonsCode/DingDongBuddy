part of 'agent_router.dart';

extension _AgentRouterResourceHandlers on AgentRouter {
  Future<HttpResponseData> _createResource(String body) async {
    final ResourceStore? store = _resourceStore;
    if (store == null) {
      return _resourceUnavailable();
    }
    try {
      final Map<String, Object?> json =
          jsonDecode(body) as Map<String, Object?>;
      final ResourceType type = ResourceType.parse(json['type']);
      if (!type.isLibraryResource) {
        return const HttpResponseData(
          statusCode: 400,
          json: <String, Object?>{
            'status': 'error',
            'message':
                'Clipboard history must be captured through /clipboard/capture',
          },
        );
      }
      final String title = (json['title'] as String? ?? '').trim();
      final String content = json['content'] as String? ?? '';
      if (title.isEmpty || content.trim().isEmpty) {
        return const HttpResponseData(
          statusCode: 400,
          json: <String, Object?>{
            'status': 'error',
            'message': 'title and content are required',
          },
        );
      }
      if (content.length > 100000) {
        return const HttpResponseData(
          statusCode: 413,
          json: <String, Object?>{
            'status': 'error',
            'message': 'content exceeds the 100000 character limit',
          },
        );
      }
      final bool pinned = json['pinned'] as bool? ?? false;
      final List<String> triggerGroupIds =
          (json['triggerGroupIds'] as List<Object?>? ?? const <Object?>[])
              .map((Object? value) => value as String)
              .toList(growable: false);
      final TriggerGroupStore? triggerGroups = _triggerGroupStore;
      if (triggerGroups != null && triggerGroupIds.isNotEmpty) {
        final Set<String> knownIds = (await triggerGroups.load())
            .map((TriggerGroup group) => group.id)
            .toSet();
        final List<String> unknownIds =
            triggerGroupIds
                .where((String id) => !knownIds.contains(id))
                .toSet()
                .toList(growable: false)
              ..sort();
        if (unknownIds.isNotEmpty) {
          return HttpResponseData(
            statusCode: 400,
            json: <String, Object?>{
              'status': 'error',
              'message': 'Unknown trigger group IDs: ${unknownIds.join(', ')}',
            },
          );
        }
      }
      final DateTime timestamp = _now().toUtc();
      final Resource resource = Resource(
        id: _idGenerator(),
        type: type,
        group: json['group'] as String?,
        title: title,
        content: content,
        tags: (json['tags'] as List<Object?>? ?? const <Object?>[])
            .map((Object? value) => value as String)
            .toList(growable: false),
        source: json['source'] as String?,
        updateUrl: json['updateURL'] as String?,
        pinned: pinned,
        enabled: json['enabled'] as bool? ?? true,
        activation: ResourceActivation.parse(
          json['activation'],
          pinned: pinned,
        ),
        triggerGroupIds: triggerGroupIds,
        sortOrder: json['sortOrder'] as int?,
        createdAt: timestamp,
        updatedAt: timestamp,
      );
      final List<Resource> resources = await store.load();
      await store.save(<Resource>[...resources, resource]);
      return HttpResponseData(
        statusCode: 201,
        json: <String, Object?>{
          'status': 'created',
          'item': resource.toApiJson(),
        },
      );
    } on Object {
      return const HttpResponseData(
        statusCode: 400,
        json: <String, Object?>{
          'status': 'error',
          'message': 'Invalid resource JSON body',
        },
      );
    }
  }

  Future<HttpResponseData> _listResources(Map<String, String> query) async {
    final ResourceStore? store = _resourceStore;
    if (store == null) {
      return _resourceUnavailable();
    }
    final String? typeName = query['type'];
    ResourceType? selectedType;
    if (typeName != null) {
      try {
        selectedType = ResourceType.parse(typeName);
      } on FormatException {
        return _invalidResourceType();
      }
      if (!selectedType.isLibraryResource) {
        return _invalidResourceType();
      }
    }
    final String needle =
        (query['q'] ?? query['query'])?.trim().toLowerCase() ?? '';
    final int? requestedLimit = int.tryParse(query['limit'] ?? '');
    final List<Resource> resources =
        (await store.load())
            .where((Resource resource) => resource.type.isLibraryResource)
            .where(
              (Resource resource) =>
                  selectedType == null || resource.type == selectedType,
            )
            .where((Resource resource) => matchesResource(resource, needle))
            .toList()
          ..sort(compareResources);
    final List<Resource> limited = requestedLimit == null
        ? resources
        : resources.take(requestedLimit.clamp(0, 1 << 31)).toList();
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'ok',
        'items': limited
            .map((Resource resource) => resource.toApiJson())
            .toList(growable: false),
      },
    );
  }

  Future<HttpResponseData> _getResource(
    String id,
    Map<String, String> query,
  ) async {
    final ResourceStore? store = _resourceStore;
    if (store == null) {
      return _resourceUnavailable();
    }
    final List<Resource> resources = await store.load();
    final int resourceIndex = resources.indexWhere(
      (Resource item) => item.id == id,
    );
    Resource? resource = resourceIndex < 0 ? null : resources[resourceIndex];
    if (resource == null || !resource.type.isLibraryResource) {
      return const HttpResponseData(
        statusCode: 404,
        json: <String, Object?>{
          'status': 'error',
          'message': 'Resource not found',
        },
      );
    }
    final String? expectedType = query['expectedType'];
    if (expectedType != null && resource.type.name != expectedType) {
      return const HttpResponseData(
        statusCode: 404,
        json: <String, Object?>{
          'status': 'error',
          'message': 'Resource type does not match',
        },
      );
    }
    if (query['trackUsage'] == 'true') {
      resource = resource.copyWith(
        usageCount: resource.usageCount + 1,
        lastUsedAt: _now().toUtc(),
      );
      resources[resourceIndex] = resource;
      await store.save(resources);
    }
    final bool full = query['mode'] == 'full';
    return HttpResponseData(
      statusCode: 200,
      json: <String, Object?>{
        'status': 'ok',
        'item': full ? resource.toApiJson() : resource.toSummaryApiJson(),
      },
    );
  }
}
