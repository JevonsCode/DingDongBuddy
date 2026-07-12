/// Resource kinds supported by DingDong's public library contract.
enum ResourceType {
  prompt('Prompts'),
  skill('Skills'),
  mcp('MCP'),
  knowledge('Knowledge'),
  clipboard('Clipboard');

  const ResourceType(this.defaultGroup);

  final String defaultGroup;

  bool get isLibraryResource => this != ResourceType.clipboard;

  bool get supportsAgentActivation => isLibraryResource;

  static ResourceType parse(Object? value) {
    return values.firstWhere(
      (ResourceType type) => type.name == value,
      orElse: () => throw FormatException('Unknown resource type: $value'),
    );
  }
}

/// Controls when a resource is included in agent context.
enum ResourceActivation {
  always,
  taskMatch,
  manual;

  static ResourceActivation parse(Object? value, {required bool pinned}) {
    if (value == null) {
      return pinned ? ResourceActivation.always : ResourceActivation.taskMatch;
    }
    return values.firstWhere(
      (ResourceActivation activation) => activation.name == value,
      orElse: () =>
          throw FormatException('Unknown resource activation: $value'),
    );
  }
}

/// Durable resource data shared by the desktop UI, HTTP API, and MCP bridge.
final class Resource {
  Resource({
    required this.id,
    required this.type,
    required String title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    String? group,
    List<String> tags = const <String>[],
    String? source,
    String? updateUrl,
    this.pinned = false,
    this.enabled = true,
    ResourceActivation? activation,
    this.sortOrder,
    this.usageCount = 0,
    this.lastUsedAt,
  }) : group = _trimmedOrNull(group) ?? type.defaultGroup,
       title = title.trim(),
       tags = List<String>.unmodifiable(
         tags
             .map((String tag) => tag.trim())
             .where((String tag) => tag.isNotEmpty),
       ),
       source = _trimmedOrNull(source),
       updateUrl = _trimmedOrNull(updateUrl),
       activation =
           activation ??
           (pinned ? ResourceActivation.always : ResourceActivation.taskMatch);

  factory Resource.fromJson(Map<String, Object?> json) {
    final bool pinned = json['pinned'] as bool? ?? false;
    return Resource(
      id: _requiredString(json, 'id'),
      type: ResourceType.parse(json['type']),
      group: _requiredString(json, 'group'),
      title: _requiredString(json, 'title'),
      content: _requiredString(json, 'content'),
      tags: (json['tags'] as List<Object?>? ?? const <Object?>[])
          .map((Object? value) => value as String)
          .toList(growable: false),
      source: json['source'] as String?,
      updateUrl: json['updateURL'] as String?,
      pinned: pinned,
      enabled: json['enabled'] as bool? ?? true,
      activation: ResourceActivation.parse(json['activation'], pinned: pinned),
      sortOrder: json['sortOrder'] as int?,
      usageCount: json['usageCount'] as int? ?? 0,
      lastUsedAt: json['lastUsedAt'] == null
          ? null
          : DateTime.parse(json['lastUsedAt'] as String).toUtc(),
      createdAt: DateTime.parse(_requiredString(json, 'createdAt')).toUtc(),
      updatedAt: DateTime.parse(_requiredString(json, 'updatedAt')).toUtc(),
    );
  }

  final String id;
  final ResourceType type;
  final String group;
  final String title;
  final String content;
  final List<String> tags;
  final String? source;
  final String? updateUrl;
  final bool pinned;
  final bool enabled;
  final ResourceActivation activation;
  final int? sortOrder;
  final int usageCount;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'type': type.name,
      'group': group,
      'title': title,
      'content': content,
      'tags': tags,
      if (source != null) 'source': source,
      if (updateUrl != null) 'updateURL': updateUrl,
      'pinned': pinned,
      'enabled': enabled,
      'activation': activation.name,
      if (sortOrder != null) 'sortOrder': sortOrder,
      'usageCount': usageCount,
      if (lastUsedAt != null)
        'lastUsedAt': lastUsedAt!.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
    };
  }

  Map<String, Object?> toApiJson() {
    return <String, Object?>{
      'id': id,
      'type': type.name,
      'group': group,
      'title': title,
      'content': content,
      'tags': tags,
      'pinned': pinned,
      'enabled': enabled,
      'activation': activation.name,
      'usageCount': usageCount,
      if (lastUsedAt != null)
        'lastUsedAt': lastUsedAt!.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (source != null) 'source': source,
    };
  }

  Map<String, Object?> toSummaryApiJson() {
    return <String, Object?>{
      'id': id,
      'type': type.name,
      'group': group,
      'title': title,
      'tags': tags,
      'pinned': pinned,
      'enabled': enabled,
      'activation': activation.name,
      'usageCount': usageCount,
      if (lastUsedAt != null)
        'lastUsedAt': lastUsedAt!.toUtc().toIso8601String(),
      'contentCharacterCount': content.length,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (source != null) 'source': source,
    };
  }

  Resource copyWith({
    ResourceType? type,
    String? group,
    String? title,
    String? content,
    List<String>? tags,
    String? source,
    String? updateUrl,
    bool? pinned,
    bool? enabled,
    ResourceActivation? activation,
    int? sortOrder,
    int? usageCount,
    DateTime? lastUsedAt,
    DateTime? updatedAt,
  }) {
    final bool resolvedPinned = pinned ?? this.pinned;
    final ResourceActivation resolvedActivation =
        activation ??
        (pinned == true && this.activation == ResourceActivation.taskMatch
            ? ResourceActivation.always
            : this.activation);
    return Resource(
      id: id,
      type: type ?? this.type,
      group: group ?? this.group,
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      source: source ?? this.source,
      updateUrl: updateUrl ?? this.updateUrl,
      pinned: resolvedPinned,
      enabled: enabled ?? this.enabled,
      activation: resolvedActivation,
      sortOrder: sortOrder ?? this.sortOrder,
      usageCount: usageCount ?? this.usageCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is Resource &&
            id == other.id &&
            type == other.type &&
            group == other.group &&
            title == other.title &&
            content == other.content &&
            _listEquals(tags, other.tags) &&
            source == other.source &&
            updateUrl == other.updateUrl &&
            pinned == other.pinned &&
            enabled == other.enabled &&
            activation == other.activation &&
            sortOrder == other.sortOrder &&
            usageCount == other.usageCount &&
            lastUsedAt == other.lastUsedAt &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    group,
    title,
    content,
    Object.hashAll(tags),
    source,
    updateUrl,
    pinned,
    enabled,
    activation,
    sortOrder,
    usageCount,
    lastUsedAt,
    createdAt,
    updatedAt,
  );
}

String _requiredString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String) {
    throw FormatException('Resource field "$key" must be a string.');
  }
  return value;
}

String? _trimmedOrNull(String? value) {
  final String? trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _listEquals(List<String> left, List<String> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
