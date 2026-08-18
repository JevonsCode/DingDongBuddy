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

  /// Resource kinds currently exposed by the lightweight configuration UI.
  ///
  /// Knowledge remains available to the Agent API and import flows, but is
  /// kept out of direct resource authoring until it has a dedicated workflow.
  bool get isConfigurableAgentResource =>
      this == ResourceType.prompt ||
      this == ResourceType.skill ||
      this == ResourceType.mcp;

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

/// How one Agent receives a Skill whose master switch is enabled.
enum SkillDeliveryMode {
  dynamic,
  nativeUser,
  nativeProject;

  static SkillDeliveryMode parse(Object? value) {
    return values.firstWhere(
      (SkillDeliveryMode mode) => mode.name == value,
      orElse: () =>
          throw FormatException('Unknown Skill delivery mode: $value'),
    );
  }
}

/// Maximum number of characters accepted for the name shown while an Agent
/// loads this resource into a conversation.
const int maximumAgentSessionNameCharacters = 7;

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
    String? packagePath,
    String? note,
    String? agentSessionName,
    this.hideInAgentConversation = false,
    this.pinned = false,
    this.enabled = true,
    ResourceActivation? activation,
    List<String> triggerGroupIds = const <String>[],
    bool strictProjectSkill = false,
    List<String> skillProjectPaths = const <String>[],
    Map<String, SkillDeliveryMode> skillDeliveryByAgent =
        const <String, SkillDeliveryMode>{},
    Map<String, bool> skillHooksEnabledByAgent = const <String, bool>{},
    String? skillPackageDigest,
    this.sortOrder,
    this.candidateCount = 0,
    this.lastCandidateAt,
    this.usageCount = 0,
    this.lastUsedAt,
    this.invocationCount = 0,
    this.lastInvokedAt,
  }) : group = _trimmedOrNull(group) ?? type.defaultGroup,
       title = title.trim(),
       tags = List<String>.unmodifiable(
         tags
             .map((String tag) => tag.trim())
             .where((String tag) => tag.isNotEmpty),
       ),
       source = _trimmedOrNull(source),
       updateUrl = _trimmedOrNull(updateUrl),
       packagePath = _trimmedOrNull(packagePath),
       note = _trimmedOrNull(note),
       agentSessionName = _sanitizeAgentSessionName(agentSessionName),
       triggerGroupIds = List<String>.unmodifiable(
         triggerGroupIds
             .map((String id) => id.trim())
             .where((String id) => id.isNotEmpty)
             .toSet(),
       ),
       strictProjectSkill = type == ResourceType.skill && strictProjectSkill,
       skillProjectPaths = List<String>.unmodifiable(
         skillProjectPaths
             .map((String projectPath) => projectPath.trim())
             .where((String projectPath) => projectPath.isNotEmpty)
             .toSet(),
       ),
       skillDeliveryByAgent = type == ResourceType.skill
           ? _normalizedAgentMap(skillDeliveryByAgent)
           : const <String, SkillDeliveryMode>{},
       skillHooksEnabledByAgent = type == ResourceType.skill
           ? _normalizedAgentMap(skillHooksEnabledByAgent)
           : const <String, bool>{},
       skillPackageDigest = type == ResourceType.skill
           ? _trimmedOrNull(skillPackageDigest)
           : null,
       activation =
           activation ??
           (pinned ? ResourceActivation.always : ResourceActivation.taskMatch);

  factory Resource.fromJson(Map<String, Object?> json) {
    final bool pinned = json['pinned'] as bool? ?? false;
    final ResourceType type = ResourceType.parse(json['type']);
    final int usageCount = json['usageCount'] as int? ?? 0;
    final DateTime? lastUsedAt = json['lastUsedAt'] == null
        ? null
        : DateTime.parse(json['lastUsedAt'] as String).toUtc();
    final List<String> skillProjectPaths =
        (json['skillProjectPaths'] as List<Object?>? ?? const <Object?>[])
            .map((Object? value) => value as String)
            .toList(growable: false);
    return Resource(
      id: _requiredString(json, 'id'),
      type: type,
      group: _requiredString(json, 'group'),
      title: _requiredString(json, 'title'),
      content: _requiredString(json, 'content'),
      tags: (json['tags'] as List<Object?>? ?? const <Object?>[])
          .map((Object? value) => value as String)
          .toList(growable: false),
      source: json['source'] as String?,
      updateUrl: json['updateURL'] as String?,
      packagePath: json['packagePath'] as String?,
      note: json['note'] as String?,
      agentSessionName: json['agentSessionName'] as String?,
      hideInAgentConversation:
          json['hideInAgentConversation'] as bool? ?? false,
      pinned: pinned,
      enabled: json['enabled'] as bool? ?? true,
      activation: ResourceActivation.parse(json['activation'], pinned: pinned),
      triggerGroupIds:
          (json['triggerGroupIds'] as List<Object?>? ?? const <Object?>[])
              .map((Object? value) => value as String)
              .toList(growable: false),
      strictProjectSkill:
          json['strictProjectSkill'] as bool? ??
          (type == ResourceType.skill && skillProjectPaths.isNotEmpty),
      skillProjectPaths: skillProjectPaths,
      skillDeliveryByAgent: _skillDeliveryByAgentFromJson(
        json['skillDeliveryByAgent'],
      ),
      skillHooksEnabledByAgent: _boolByAgentFromJson(
        json['skillHooksEnabledByAgent'],
        field: 'skillHooksEnabledByAgent',
      ),
      skillPackageDigest: json['skillPackageDigest'] as String?,
      sortOrder: json['sortOrder'] as int?,
      candidateCount:
          json['candidateCount'] as int? ??
          (type == ResourceType.mcp ? usageCount : 0),
      lastCandidateAt: json['lastCandidateAt'] == null
          ? (type == ResourceType.mcp ? lastUsedAt : null)
          : DateTime.parse(json['lastCandidateAt'] as String).toUtc(),
      usageCount: usageCount,
      lastUsedAt: lastUsedAt,
      invocationCount: json['invocationCount'] as int? ?? 0,
      lastInvokedAt: json['lastInvokedAt'] == null
          ? null
          : DateTime.parse(json['lastInvokedAt'] as String).toUtc(),
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

  /// Local root of a complete Agent Skill package (SKILL.md + siblings).
  final String? packagePath;
  final String? note;

  /// Optional short name shown in the Agent conversation loading summary.
  ///
  /// When absent, the resource title is used instead.
  final String? agentSessionName;

  /// Keeps the resource loaded while omitting its name from the user-facing
  /// Agent conversation loading summary.
  final bool hideInAgentConversation;
  final bool pinned;
  final bool enabled;
  final ResourceActivation activation;
  final List<String> triggerGroupIds;
  final bool strictProjectSkill;

  /// Whether this Skill is limited to an explicit trigger scope.
  ///
  /// Project paths are a derived synchronization result, so the persisted
  /// trigger-group relationship remains the source of truth.
  bool get isScopedSkill =>
      type == ResourceType.skill && triggerGroupIds.isNotEmpty;

  /// Canonical project roots derived for strict Skill loading.
  ///
  /// Retained in persisted data for exact-scope validation and cleanup of
  /// DingDong-managed native mirrors.
  final List<String> skillProjectPaths;
  final Map<String, SkillDeliveryMode> skillDeliveryByAgent;
  final Map<String, bool> skillHooksEnabledByAgent;
  final String? skillPackageDigest;

  SkillDeliveryMode skillDeliveryForAgent(String agentId) =>
      skillDeliveryByAgent[agentId.trim()] ?? SkillDeliveryMode.dynamic;

  bool skillHooksEnabledForAgent(String agentId) =>
      skillHooksEnabledByAgent[agentId.trim()] ?? false;
  final int? sortOrder;
  final int candidateCount;
  final DateTime? lastCandidateAt;
  final int usageCount;
  final DateTime? lastUsedAt;
  final int invocationCount;
  final DateTime? lastInvokedAt;
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
      if (packagePath != null) 'packagePath': packagePath,
      if (note != null) 'note': note,
      if (agentSessionName != null) 'agentSessionName': agentSessionName,
      if (hideInAgentConversation) 'hideInAgentConversation': true,
      'pinned': pinned,
      'enabled': enabled,
      'activation': activation.name,
      if (triggerGroupIds.isNotEmpty) 'triggerGroupIds': triggerGroupIds,
      if (type == ResourceType.skill) 'strictProjectSkill': strictProjectSkill,
      if (skillProjectPaths.isNotEmpty) 'skillProjectPaths': skillProjectPaths,
      if (skillDeliveryByAgent.isNotEmpty)
        'skillDeliveryByAgent': <String, String>{
          for (final MapEntry<String, SkillDeliveryMode> entry
              in skillDeliveryByAgent.entries)
            entry.key: entry.value.name,
        },
      if (skillHooksEnabledByAgent.isNotEmpty)
        'skillHooksEnabledByAgent': skillHooksEnabledByAgent,
      if (skillPackageDigest != null) 'skillPackageDigest': skillPackageDigest,
      if (sortOrder != null) 'sortOrder': sortOrder,
      'candidateCount': candidateCount,
      if (lastCandidateAt != null)
        'lastCandidateAt': lastCandidateAt!.toUtc().toIso8601String(),
      'usageCount': usageCount,
      if (lastUsedAt != null)
        'lastUsedAt': lastUsedAt!.toUtc().toIso8601String(),
      'invocationCount': invocationCount,
      if (lastInvokedAt != null)
        'lastInvokedAt': lastInvokedAt!.toUtc().toIso8601String(),
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
      'triggerGroupIds': triggerGroupIds,
      if (type == ResourceType.skill) 'strictProjectSkill': strictProjectSkill,
      if (skillProjectPaths.isNotEmpty) 'skillProjectPaths': skillProjectPaths,
      if (type == ResourceType.skill) ...<String, Object?>{
        'skillDeliveryByAgent': <String, String>{
          for (final MapEntry<String, SkillDeliveryMode> entry
              in skillDeliveryByAgent.entries)
            entry.key: entry.value.name,
        },
        'skillHooksEnabledByAgent': skillHooksEnabledByAgent,
        if (skillPackageDigest != null)
          'skillPackageDigest': skillPackageDigest,
      },
      if (agentSessionName != null) 'agentSessionName': agentSessionName,
      if (hideInAgentConversation) 'hideInAgentConversation': true,
      'candidateCount': candidateCount,
      if (lastCandidateAt != null)
        'lastCandidateAt': lastCandidateAt!.toUtc().toIso8601String(),
      'usageCount': usageCount,
      if (lastUsedAt != null)
        'lastUsedAt': lastUsedAt!.toUtc().toIso8601String(),
      'invocationCount': invocationCount,
      if (lastInvokedAt != null)
        'lastInvokedAt': lastInvokedAt!.toUtc().toIso8601String(),
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (source != null) 'source': source,
      if (note != null) 'note': note,
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
      'triggerGroupIds': triggerGroupIds,
      if (type == ResourceType.skill) 'strictProjectSkill': strictProjectSkill,
      if (skillProjectPaths.isNotEmpty) 'skillProjectPaths': skillProjectPaths,
      if (type == ResourceType.skill) ...<String, Object?>{
        'skillDeliveryByAgent': <String, String>{
          for (final MapEntry<String, SkillDeliveryMode> entry
              in skillDeliveryByAgent.entries)
            entry.key: entry.value.name,
        },
        'skillHooksEnabledByAgent': skillHooksEnabledByAgent,
        if (skillPackageDigest != null)
          'skillPackageDigest': skillPackageDigest,
      },
      if (agentSessionName != null) 'agentSessionName': agentSessionName,
      if (hideInAgentConversation) 'hideInAgentConversation': true,
      'candidateCount': candidateCount,
      if (lastCandidateAt != null)
        'lastCandidateAt': lastCandidateAt!.toUtc().toIso8601String(),
      'usageCount': usageCount,
      if (lastUsedAt != null)
        'lastUsedAt': lastUsedAt!.toUtc().toIso8601String(),
      'invocationCount': invocationCount,
      if (lastInvokedAt != null)
        'lastInvokedAt': lastInvokedAt!.toUtc().toIso8601String(),
      'contentCharacterCount': content.length,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (source != null) 'source': source,
      if (note != null) 'note': note,
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
    String? packagePath,
    String? note,
    String? agentSessionName,
    bool? hideInAgentConversation,
    bool? pinned,
    bool? enabled,
    ResourceActivation? activation,
    List<String>? triggerGroupIds,
    bool? strictProjectSkill,
    List<String>? skillProjectPaths,
    Map<String, SkillDeliveryMode>? skillDeliveryByAgent,
    Map<String, bool>? skillHooksEnabledByAgent,
    Object? skillPackageDigest = _unset,
    int? sortOrder,
    int? candidateCount,
    DateTime? lastCandidateAt,
    int? usageCount,
    DateTime? lastUsedAt,
    int? invocationCount,
    DateTime? lastInvokedAt,
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
      packagePath: packagePath ?? this.packagePath,
      note: note ?? this.note,
      agentSessionName: agentSessionName ?? this.agentSessionName,
      hideInAgentConversation:
          hideInAgentConversation ?? this.hideInAgentConversation,
      pinned: resolvedPinned,
      enabled: enabled ?? this.enabled,
      activation: resolvedActivation,
      triggerGroupIds: triggerGroupIds ?? this.triggerGroupIds,
      strictProjectSkill: strictProjectSkill ?? this.strictProjectSkill,
      skillProjectPaths: skillProjectPaths ?? this.skillProjectPaths,
      skillDeliveryByAgent: skillDeliveryByAgent ?? this.skillDeliveryByAgent,
      skillHooksEnabledByAgent:
          skillHooksEnabledByAgent ?? this.skillHooksEnabledByAgent,
      skillPackageDigest: identical(skillPackageDigest, _unset)
          ? this.skillPackageDigest
          : skillPackageDigest as String?,
      sortOrder: sortOrder ?? this.sortOrder,
      candidateCount: candidateCount ?? this.candidateCount,
      lastCandidateAt: lastCandidateAt ?? this.lastCandidateAt,
      usageCount: usageCount ?? this.usageCount,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      invocationCount: invocationCount ?? this.invocationCount,
      lastInvokedAt: lastInvokedAt ?? this.lastInvokedAt,
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
            packagePath == other.packagePath &&
            note == other.note &&
            agentSessionName == other.agentSessionName &&
            hideInAgentConversation == other.hideInAgentConversation &&
            pinned == other.pinned &&
            enabled == other.enabled &&
            activation == other.activation &&
            _listEquals(triggerGroupIds, other.triggerGroupIds) &&
            strictProjectSkill == other.strictProjectSkill &&
            _listEquals(skillProjectPaths, other.skillProjectPaths) &&
            _mapEquals(skillDeliveryByAgent, other.skillDeliveryByAgent) &&
            _mapEquals(
              skillHooksEnabledByAgent,
              other.skillHooksEnabledByAgent,
            ) &&
            skillPackageDigest == other.skillPackageDigest &&
            sortOrder == other.sortOrder &&
            candidateCount == other.candidateCount &&
            lastCandidateAt == other.lastCandidateAt &&
            usageCount == other.usageCount &&
            lastUsedAt == other.lastUsedAt &&
            invocationCount == other.invocationCount &&
            lastInvokedAt == other.lastInvokedAt &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
    id,
    type,
    group,
    title,
    content,
    Object.hashAll(tags),
    source,
    updateUrl,
    packagePath,
    note,
    agentSessionName,
    hideInAgentConversation,
    pinned,
    enabled,
    activation,
    Object.hashAll(triggerGroupIds),
    strictProjectSkill,
    Object.hashAll(skillProjectPaths),
    Object.hashAll(skillDeliveryByAgent.entries),
    Object.hashAll(skillHooksEnabledByAgent.entries),
    skillPackageDigest,
    sortOrder,
    candidateCount,
    lastCandidateAt,
    usageCount,
    lastUsedAt,
    invocationCount,
    lastInvokedAt,
    createdAt,
    updatedAt,
  ]);
}

const Object _unset = Object();

Map<String, SkillDeliveryMode> _skillDeliveryByAgentFromJson(Object? value) {
  if (value == null) {
    return const <String, SkillDeliveryMode>{};
  }
  if (value is! Map) {
    throw const FormatException(
      'Resource field "skillDeliveryByAgent" must be an object.',
    );
  }
  return <String, SkillDeliveryMode>{
    for (final MapEntry<Object?, Object?> entry in value.entries)
      entry.key as String: SkillDeliveryMode.parse(entry.value),
  };
}

Map<String, bool> _boolByAgentFromJson(Object? value, {required String field}) {
  if (value == null) {
    return const <String, bool>{};
  }
  if (value is! Map) {
    throw FormatException('Resource field "$field" must be an object.');
  }
  return <String, bool>{
    for (final MapEntry<Object?, Object?> entry in value.entries)
      entry.key as String: entry.value as bool,
  };
}

Map<String, V> _normalizedAgentMap<V>(Map<String, V> values) {
  final List<MapEntry<String, V>> entries =
      values.entries
          .map(
            (MapEntry<String, V> entry) =>
                MapEntry<String, V>(entry.key.trim(), entry.value),
          )
          .where((MapEntry<String, V> entry) => entry.key.isNotEmpty)
          .toList(growable: false)
        ..sort(
          (MapEntry<String, V> left, MapEntry<String, V> right) =>
              left.key.compareTo(right.key),
        );
  return Map<String, V>.unmodifiable(<String, V>{
    for (final MapEntry<String, V> entry in entries) entry.key: entry.value,
  });
}

bool _mapEquals<K, V>(Map<K, V> left, Map<K, V> right) {
  if (identical(left, right)) {
    return true;
  }
  if (left.length != right.length) {
    return false;
  }
  for (final MapEntry<K, V> entry in left.entries) {
    if (right[entry.key] != entry.value || !right.containsKey(entry.key)) {
      return false;
    }
  }
  return true;
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

String? _sanitizeAgentSessionName(String? value) {
  final String? trimmed = _trimmedOrNull(value);
  if (trimmed == null) {
    return null;
  }
  final List<int> characters = trimmed.runes.toList(growable: false);
  return String.fromCharCodes(
    characters.take(maximumAgentSessionNameCharacters),
  );
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
